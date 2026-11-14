import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../database/app_database.dart';
import '../../database/chat_database_repository.dart' show assetLocalPaths;
import '../workspace/workspace_file_coordinator.dart';
import '../workspace/file_link_resolver.dart';
import 'attachment_file_lock.dart';
import '../../models/avatar_config.dart';
import '../../utils/chat_image_result.dart';
import '../../models/mcp_presentation.dart';
import '../../../shared/markdown/markdown_image_sources.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/kelivo_file_uri.dart';

enum StorageImageKind { chat, tool, avatar }

/// One persisted snapshot for association labels and deletion protection.
/// Message parts cover references whose asset-index backfill is still pending.
class StorageAttachmentUsage {
  StorageAttachmentUsage._(this._root, this._references) {
    _appearance = _resolveSet(_references.appearance);
    _tools = _resolveSet(_references.tools);
    _chat = _resolveSet(_references.chat);
    _protected = _resolveSet(_references.protected);
    for (final entry in _references.conversations.entries) {
      for (final path in _paths(entry.key, _root)) {
        _conversations.putIfAbsent(path, () => {}).addAll(entry.value);
      }
    }
    for (final entry in _references.pending.entries) {
      for (final path in _paths(entry.key, _root)) {
        _pending[path] = DateTime.fromMicrosecondsSinceEpoch(entry.value);
      }
    }
  }

  final String _root;
  final _AttachmentReferences _references;
  late final Set<String> _appearance, _tools, _chat, _protected;
  final _conversations = <String, Map<String, String>>{};
  final _pending = <String, DateTime>{};

  Set<String> _resolveSet(Set<String> uris) => {
    for (final uri in uris) ..._paths(uri, _root),
  };

  static Future<StorageAttachmentUsage> load({
    bool includeMessages = true,
  }) async {
    final root = (await AppDirectories.getContentDirectory()).path;
    final databasePath = p.join(
      (await AppDirectories.getAppDataDirectory()).path,
      AppDatabase.databaseFileName,
    );
    final usage = await Isolate.run(
      () => _load(databasePath, root, includeMessages),
    );
    usage.includeConversations(
      AttachmentFileLock.transientReferences,
      generationActive: AttachmentFileLock.hasActiveTransientGeneration,
    );
    return usage;
  }

  static StorageAttachmentUsage _load(String path, String root, bool messages) {
    if (!File(path).existsSync()) {
      return StorageAttachmentUsage._(root, _AttachmentReferences());
    }
    final database = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      database.execute('BEGIN');
      return StorageAttachmentUsage._(
        root,
        _readReferences(database, messages, root),
      );
    } finally {
      database.close();
    }
  }

  void includeConversations(
    Map<String, Map<String, String>> references, {
    bool generationActive = false,
  }) {
    _references.hasActiveGenerations |= generationActive;
    for (final entry in references.entries) {
      for (final conversation in entry.value.entries) {
        for (final path in _paths(
          resolveStorageSessionReference(entry.key, conversation.key, _root),
          _root,
        )) {
          _conversations.putIfAbsent(path, () => {})[conversation.key] =
              conversation.value;
        }
      }
    }
  }

  bool isInUse(String path) {
    final normalized = p.normalize(path);
    if (_references.hasActiveGenerations && p.isWithin(_root, normalized)) {
      return true;
    }
    return _appearance.contains(normalized) ||
        _protected.contains(normalized) ||
        _conversations.containsKey(normalized);
  }

  bool hasReferencesWithin(String directory) => {
    ..._appearance,
    ..._protected,
    ..._conversations.keys,
  }.any((path) => p.equals(directory, path) || p.isWithin(directory, path));

  Map<String, String> conversationsFor(String path) =>
      Map.unmodifiable(_conversations[p.normalize(path)] ?? const {});

  DateTime? pendingDeletionFor(String path) => _pending[p.normalize(path)];

  /// Run the final reference check and physical deletions under the SQLite
  /// writer lock in a worker. A concurrent message/fork cannot commit a new
  /// reference between that check and unlinking the file.
  static Future<Set<String>> deleteUnusedFiles(
    Iterable<String> paths, {
    Set<String> protectedPaths = const {},
    bool sessionCopies = false,
    bool generationActive = false,
  }) async {
    final root = (await AppDirectories.getContentDirectory()).path;
    final databasePath = p.join(
      (await AppDirectories.getAppDataDirectory()).path,
      AppDatabase.databaseFileName,
    );
    final transient = AttachmentFileLock.transientReferences;
    generationActive |= AttachmentFileLock.hasActiveTransientGeneration;
    final targets = paths.toSet();
    if (targets.isEmpty) return {};
    return Isolate.run(() {
      final database = File(databasePath).existsSync()
          ? sqlite3.open(databasePath, mode: OpenMode.readWrite)
          : null;
      try {
        database?.execute('PRAGMA busy_timeout = 5000');
        database?.execute('BEGIN IMMEDIATE');
        final usage = StorageAttachmentUsage._(
          root,
          database == null
              ? _AttachmentReferences()
              : _readReferences(database, true, root),
        );
        usage.includeConversations(
          transient,
          generationActive: generationActive,
        );
        final protected = usage._resolveSet(protectedPaths);
        final roots = [
          for (final dir
              in (sessionCopies
                  ? ['sessions']
                  : ['upload', 'images', 'avatars']))
            p.normalize(p.join(root, dir)),
        ];
        final realRoots = [
          for (final dir in roots)
            if (Directory(dir).existsSync())
              Directory(dir).resolveSymbolicLinksSync(),
        ];
        final removed = <String>{};
        for (final path in targets) {
          final normalized = p.normalize(p.absolute(path));
          if (!roots.any((dir) => p.isWithin(dir, normalized))) continue;
          if (FileSystemEntity.typeSync(normalized, followLinks: false) !=
              FileSystemEntityType.file) {
            continue;
          }
          final real = File(normalized).resolveSymbolicLinksSync();
          if (!realRoots.any((dir) => p.isWithin(dir, real))) continue;
          if (usage.isInUse(normalized) ||
              usage.isInUse(real) ||
              protected.contains(normalized) ||
              protected.contains(real)) {
            continue;
          }
          File(normalized).deleteSync();
          removed.add(normalized);
        }
        database?.execute('COMMIT');
        return removed;
      } finally {
        database?.close();
      }
    });
  }

  /// Empty roots may contain only the attachment index and empty directories.
  /// Workspaces/shells and attachment copying use the same directory lock.
  static Future<({int bytes, int files, int directories})> cleanSessions({
    bool includeOrphans = false,
    Directory? sessionsDirectory,
    Set<String>? conversationIds,
    Set<String> protectedPaths = const {},
  }) async {
    final sessions =
        sessionsDirectory ?? await AppDirectories.getSessionsDirectory();
    final root = (await AppDirectories.getContentDirectory()).path;
    final databasePath = p.join(
      (await AppDirectories.getAppDataDirectory()).path,
      AppDatabase.databaseFileName,
    );
    final transient = AttachmentFileLock.transientReferences;
    final generationActive = AttachmentFileLock.hasActiveTransientGeneration;
    return WorkspaceFileCoordinator.run(
      sessions.path,
      () => Isolate.run(() {
        // Empty roots contain no user data. Avoid a database writer lock (and
        // a full reference scan) for the routine post-deletion pruning pass.
        if (!includeOrphans) return _pruneEmptySessions(sessions);
        if (!sessions.existsSync() ||
            sessions.listSync(followLinks: false).isEmpty) {
          return (bytes: 0, files: 0, directories: 0);
        }
        final database = File(databasePath).existsSync()
            ? sqlite3.open(databasePath, mode: OpenMode.readWrite)
            : null;
        try {
          database?.execute('PRAGMA busy_timeout = 5000');
          database?.execute('BEGIN IMMEDIATE');
          final usage = StorageAttachmentUsage._(
            root,
            database == null
                ? _AttachmentReferences()
                : _readReferences(database, true, root),
          );
          usage.includeConversations(
            transient,
            generationActive: generationActive,
          );
          usage._protected.addAll(usage._resolveSet(protectedPaths));
          final ids = database == null
              ? (conversationIds ?? <String>{})
              : {
                  for (final row in database.select(
                    'SELECT id FROM conversation_rows',
                  ))
                    row['id'] as String,
                  for (final row in database.select(
                    "SELECT id FROM extension_entity_rows WHERE kind = 'composerDraft'",
                  ))
                    row['id'] as String,
                };
          var bytes = 0, files = 0, directories = 0;
          if (!sessions.existsSync()) {
            return (bytes: bytes, files: files, directories: directories);
          }
          for (final session in sessions.listSync(followLinks: false)) {
            if (session is! Directory) continue;
            final entries = session.listSync(
              recursive: true,
              followLinks: false,
            );
            if (entries.any((entry) => entry is Link)) continue;
            final content = entries.whereType<File>().toList();
            final empty = content.every(
              (file) => p.equals(
                file.path,
                p.join(session.path, '.attachment-index.json'),
              ),
            );
            if (!empty && usage.hasReferencesWithin(session.path)) continue;
            if (!empty &&
                !(includeOrphans &&
                    !usage._references.hasActiveGenerations &&
                    !ids.contains(p.basename(session.path)))) {
              continue;
            }
            final size = content.fold<int>(
              0,
              (sum, file) => sum + file.lengthSync(),
            );
            session.deleteSync(recursive: true);
            bytes += size;
            files += content.length;
            directories++;
          }
          database?.execute('COMMIT');
          return (bytes: bytes, files: files, directories: directories);
        } finally {
          database?.close();
        }
      }),
    );
  }

  StorageImageKind? kindFor(String path, {String? realPath}) {
    final normalized = p.normalize(path);
    bool contains(Set<String> paths) =>
        paths.contains(normalized) ||
        (realPath != null && paths.contains(p.normalize(realPath)));
    if (contains(_appearance) ||
        p.isWithin(p.join(_root, 'avatars'), normalized)) {
      return StorageImageKind.avatar;
    }
    if (contains(_tools)) return StorageImageKind.tool;
    if (contains(_chat)) return StorageImageKind.chat;

    // These are filenames assigned by the owning writers, including files
    // whose conversation/assistant has since been deleted. Arbitrary images
    // have no inferred sender or use and remain visible in All only.
    if (p.isWithin(p.join(_root, 'images'), normalized)) {
      final name = p.basename(normalized);
      if (name.startsWith('background_')) return StorageImageKind.avatar;
      if (name.startsWith('mcp_img_') || name.startsWith('view_image_')) {
        return StorageImageKind.tool;
      }
    }
    if (p.isWithin(p.join(_root, 'upload'), normalized)) {
      return StorageImageKind.chat;
    }
    return null;
  }
}

({int bytes, int files, int directories}) _pruneEmptySessions(
  Directory sessions,
) {
  var bytes = 0, files = 0, directories = 0;
  if (!sessions.existsSync()) {
    return (bytes: bytes, files: files, directories: directories);
  }
  for (final session in sessions.listSync(followLinks: false)) {
    if (session is! Directory) continue;
    final entries = session.listSync(recursive: true, followLinks: false);
    if (entries.any((entry) => entry is Link)) continue;
    final content = entries.whereType<File>().toList();
    if (content.any(
      (file) =>
          !p.equals(file.path, p.join(session.path, '.attachment-index.json')),
    )) {
      continue;
    }
    final size = content.fold<int>(0, (sum, file) => sum + file.lengthSync());
    session.deleteSync(recursive: true);
    bytes += size;
    files += content.length;
    directories++;
  }
  return (bytes: bytes, files: files, directories: directories);
}

class _AttachmentReferences {
  bool hasActiveGenerations = false;
  final appearance = <String>{};
  final tools = <String>{};
  final chat = <String>{};
  final protected = <String>{};
  final conversations = <String, Map<String, String>>{};
  final pending = <String, int>{};
}

String resolveStorageSessionReference(
  String uri,
  String conversationId,
  String root,
) {
  final link = KelivoLink.tryParse(uri);
  if (link != null) {
    final folder = switch (link.kind) {
      KelivoLinkKind.chatFile => '',
      KelivoLinkKind.chatAttachment => 'attachments',
      KelivoLinkKind.chatOutput => 'outputs',
      KelivoLinkKind.temporaryFile => 'tmp',
      _ => null,
    };
    if (folder != null) {
      return p.join(
        root,
        'sessions',
        link.conversationId ?? conversationId,
        folder,
        link.relativePath,
      );
    }
  }
  // Model-visible session paths are relative to the message's conversation.
  if (uri == '/chat' || uri.startsWith('/chat/')) {
    return p.join(
      root,
      'sessions',
      conversationId,
      p.posix.relative(uri, from: '/chat'),
    );
  }
  return uri;
}

Iterable<String> _paths(String uri, String root) sync* {
  if (uri.startsWith('http:') ||
      uri.startsWith('https:') ||
      uri.startsWith('data:')) {
    return;
  }
  final canonical = KelivoFileUri.isKelivoFileUri(uri)
      ? uri
      : KelivoFileUri.tryEncodeLegacyAbsolutePath(
          uri,
          allowGenericFallback: false,
        );
  final path = canonical != null
      ? KelivoFileUri.resolveToAbsolute(canonical, root: root)
      : uri.startsWith('file:')
      ? Uri.tryParse(uri)?.toFilePath()
      : uri;
  if (path == null || !p.isAbsolute(path)) return;
  yield p.normalize(path);
  try {
    yield p.normalize(File(path).resolveSymbolicLinksSync());
  } on FileSystemException {
    /* Keep missing references protected. */
  }
}

Iterable<String> _uris(Object? value) sync* {
  if (value is Map) {
    for (final item in value.values) {
      yield* _uris(item);
    }
  } else if (value is List) {
    for (final item in value) {
      yield* _uris(item);
    }
  } else if (value is String) {
    if (p.isAbsolute(value) ||
        value.startsWith('kelivo-file:') ||
        value.startsWith('kelivo:') ||
        value.startsWith('file:')) {
      yield value;
    }
    if (value.contains('![') || value.toLowerCase().contains('<img')) {
      yield* markdownImageSources(value);
    }
    for (final match in RegExp(
      r'''(?:kelivo-file|file):///[^\s<>"')\]]+|kelivo://[^\s<>"')\]]+''',
    ).allMatches(value)) {
      yield match.group(0)!;
    }
  }
}

Iterable<String> storageToolAttachmentUris(
  Object? payload,
  String root,
  String conversationId,
) sync* {
  // A tool result cannot acquire authority to arbitrary uploads by naming them.
  yield* chatImageAssetsFromToolEvent(
    payload,
  ).where((asset) => asset.directAsset).map((asset) => asset.uri);
  for (final uri in _uris(payload)) {
    if (_paths(
      resolveStorageSessionReference(uri, conversationId, root),
      root,
    ).any(
      (path) =>
          p.isWithin(p.join(root, 'images'), path) ||
          p.isWithin(p.join(root, 'sessions'), path),
    )) {
      yield uri;
    }
  }
}

_AttachmentReferences _readReferences(
  Database database,
  bool includeMessages,
  String root,
) {
  final result = _AttachmentReferences();
  final appearance = result.appearance;
  void add(Set<String> target, Object? value) {
    if (value is String && value.trim().isNotEmpty) target.add(value.trim());
  }

  for (final row in database.select('SELECT payload FROM assistant_rows')) {
    final payload = jsonDecode(row['payload'] as String) as Map;
    add(appearance, payload['avatar']);
    add(appearance, payload['background']);
  }
  for (final row in database.select('SELECT payload FROM provider_rows')) {
    final payload = jsonDecode(row['payload'] as String) as Map;
    if (payload['avatarType'] == 'file') {
      add(appearance, payload['avatarValue']);
    }
    final overrides = payload['modelOverrides'];
    if (overrides is Map) {
      for (final override in overrides.values) {
        final avatar = AvatarConfig.fromJson(
          override is Map ? override['avatar'] : null,
        );
        if (avatar?.type == AvatarType.file) add(appearance, avatar!.value);
      }
    }
  }
  for (final row in database.select(
    "SELECT key, value FROM preference_rows "
    "WHERE key IN ('avatar_value', 'mcp_presentation_v1')",
  )) {
    final value = jsonDecode(row['value'] as String);
    if (row['key'] == 'avatar_value') {
      add(appearance, value);
    } else if (value is String) {
      final presentation = McpPresentation.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
      for (final server in presentation.servers.values) {
        final icon = server.icon;
        if (icon?.type == McpIconType.file) {
          add(
            appearance,
            'kelivo-file:///avatars/${Uri.encodeComponent(icon!.value)}',
          );
        }
      }
    }
  }

  if (includeMessages) {
    result.hasActiveGenerations = database
        .select('SELECT 1 FROM message_rows WHERE is_streaming = 1 LIMIT 1')
        .isNotEmpty;
    void associate(String uri, String id, String title) {
      result.conversations.putIfAbsent(uri, () => {})[id] = title;
    }

    // Every version and fork participates, regardless of timeline selection.
    for (final row in database.select(
      'SELECT p.kind, p.payload, m.conversation_id, c.title '
      'FROM message_part_rows p JOIN message_rows m ON m.id = p.revision_id '
      'JOIN conversation_rows c ON c.id = m.conversation_id '
      "WHERE p.kind IN ('image', 'file', 'tool_call') OR "
      "(p.kind = 'text' AND (instr(p.payload, '![') > 0 OR "
      "instr(lower(p.payload), '<img') > 0 OR instr(p.payload, 'kelivo-file:') > 0 OR "
      "instr(p.payload, 'file:') > 0 OR instr(p.payload, 'kelivo:') > 0 OR instr(p.payload, '](/') > 0))",
    )) {
      final raw = row['payload'] as String;
      Object? payload = raw;
      if (row['kind'] != 'text' && row['kind'] != 'reasoning') {
        try {
          payload = jsonDecode(raw);
        } on FormatException {
          // A malformed attachment cannot establish a trustworthy unused set.
          if (row['kind'] == 'image' || row['kind'] == 'file') rethrow;
        }
      }
      final uris = row['kind'] == 'text'
          ? markdownImageSources(raw, includeLinks: true).toSet()
          : row['kind'] == 'tool_call'
          ? storageToolAttachmentUris(
              payload,
              root,
              row['conversation_id'] as String,
            ).toSet()
          : _uris(payload).toSet();
      (row['kind'] == 'tool_call' ? result.tools : result.chat).addAll(uris);
      for (final uri in uris) {
        associate(
          resolveStorageSessionReference(
            uri,
            row['conversation_id'] as String,
            root,
          ),
          row['conversation_id'] as String,
          row['title'] as String,
        );
      }
    }
    for (final row in database.select(
      'SELECT a.path, a.thumbnail_path, a.extras_json, c.id, c.title FROM asset_rows a '
      'JOIN message_asset_rows r ON r.asset_id = a.id '
      'JOIN conversation_rows c ON c.id = r.conversation_id',
    )) {
      for (final uri in [
        row['path'],
        row['thumbnail_path'],
      ].whereType<String>()) {
        associate(uri, row['id'] as String, row['title'] as String);
      }
    }
    for (final row in database.select(
      'SELECT a.path, a.extras_json, g.not_before FROM asset_gc_rows g '
      'JOIN asset_rows a ON a.id = g.asset_id',
    )) {
      for (final path in [
        row['path'] as String,
        ...assetLocalPaths(row['extras_json'] as String),
      ]) {
        result.pending[path] = row['not_before'] as int;
      }
    }
    for (final row in database.select(
      "SELECT kind, id, payload FROM extension_entity_rows "
      "WHERE kind IN ('composerDraft', 'composerPrivateFile')",
    )) {
      if (row['kind'] == 'composerPrivateFile') {
        result.protected.add(row['id'] as String);
      } else {
        result.protected.addAll(_uris(jsonDecode(row['payload'] as String)));
      }
    }
  }
  return result;
}
