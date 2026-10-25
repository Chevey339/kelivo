import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../database/app_database.dart';
import '../../models/message_part.dart';
import '../../models/mcp_presentation.dart';
import '../../../shared/markdown/markdown_image_sources.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/kelivo_file_uri.dart';
import '../../../utils/mcp_structured_image.dart';
import '../../../utils/sandbox_path_resolver.dart';

enum StorageImageKind { chat, tool, avatar }

/// A fresh view of persisted image uses. A file may have several references;
/// appearance assets take precedence so a chat cleanup cannot remove them.
class StorageImageUsage {
  StorageImageUsage._(this._root, this._appearance, this._tools, this._chat);

  final String _root;
  final Set<String> _appearance;
  final Set<String> _tools;
  final Set<String> _chat;

  static Future<StorageImageUsage> load({bool includeMessages = true}) async {
    final root = await AppDirectories.getContentDirectory();
    final databaseRoot = await AppDirectories.getAppDataDirectory();
    final databasePath = p.join(
      databaseRoot.path,
      AppDatabase.databaseFileName,
    );
    final raw = await Isolate.run(
      () => _readReferences(databasePath, includeMessages: includeMessages),
    );

    Future<Set<String>> resolve(Set<String> uris) async {
      final paths = <String>{};
      for (final uri in uris) {
        if (uri.startsWith('http:') ||
            uri.startsWith('https:') ||
            uri.startsWith('data:')) {
          continue;
        }
        final path = KelivoFileUri.isKelivoFileUri(uri)
            ? KelivoFileUri.resolveToAbsolute(uri, root: root.path)
            : SandboxPathResolver.resolveForIo(SandboxPathResolver.fix(uri));
        if (path == null || !p.isAbsolute(path)) continue;
        paths.add(p.normalize(path));
        try {
          paths.add(p.normalize(await File(path).resolveSymbolicLinks()));
        } on FileSystemException {
          // Keep references to missing files as well.
        }
      }
      return paths;
    }

    return StorageImageUsage._(
      p.normalize(root.absolute.path),
      await resolve(raw.appearance),
      await resolve(raw.tools),
      await resolve(raw.chat),
    );
  }

  bool isInUse(String path) => _appearance.contains(p.normalize(path));

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

typedef _ImageReferences = ({
  Set<String> appearance,
  Set<String> tools,
  Set<String> chat,
});

_ImageReferences _readReferences(String path, {required bool includeMessages}) {
  final appearance = <String>{};
  final tools = <String>{};
  final chat = <String>{};
  final result = (appearance: appearance, tools: tools, chat: chat);
  if (!File(path).existsSync()) return result;
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  void add(Set<String> target, Object? value) {
    if (value is String && value.trim().isNotEmpty) target.add(value.trim());
  }

  try {
    // One snapshot keeps references consistent across the business tables.
    // Read/decoding errors propagate: failed inspection must never authorize
    // deleting a possibly active avatar or background.
    database.execute('BEGIN');
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
      for (final row in database.select(
        "SELECT kind, payload FROM message_part_rows WHERE kind = 'image' "
        "OR (kind = 'text' AND (instr(payload, '![') > 0 "
        "OR instr(lower(payload), '<img') > 0)) "
        "OR (kind = 'tool_call' AND (payload LIKE '%\"mcpResult\"%' "
        "OR payload LIKE '%\"previewImage\"%'))",
      )) {
        if (row['kind'] == 'text') {
          chat.addAll(markdownImageSources(row['payload'] as String));
          continue;
        }
        try {
          final payload = jsonDecode(row['payload'] as String);
          if (payload is! Map) continue;
          if (row['kind'] == 'image') {
            add(chat, payload['uri']);
          } else {
            add(tools, browserPreviewImageFromToolEvent(payload));
            final metadata = payload['metadata'];
            if (metadata is Map) {
              tools.addAll(
                mcpResultImageUris(
                  readMcpResultMetadata(Map<String, dynamic>.from(metadata)),
                ),
              );
            }
          }
        } on FormatException {
          // Malformed historical message parts have no trustworthy usage.
        }
      }
    }
    return result;
  } finally {
    database.close();
  }
}
