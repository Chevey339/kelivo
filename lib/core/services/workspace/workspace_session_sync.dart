import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';
import '../../models/message_part.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/kelivo_file_uri.dart';
import 'workspace_tool_context.dart';

class AttachmentInfo {
  const AttachmentInfo({
    required this.name,
    required this.size,
    required this.modelPath,
    this.sourceUri = '',
  });

  final String name;
  final int size;
  final String modelPath;
  final String sourceUri;
}

final _syncTails = <String, Future<void>>{};

/// Copies user-message files/images into the conversation session attachments
/// folder before generation. A failed local copy must stop preparation, rather
/// than claiming the model has access to a file that is missing.
Future<List<AttachmentInfo>> syncAttachments(
  WorkspaceToolContext ctx,
  List<ChatMessage> messages,
) {
  return _serializeSessionMutation(
    ctx.sessionDir,
    () => _syncAttachments(ctx, messages),
  );
}

Future<T> _serializeSessionMutation<T>(
  Directory session,
  Future<T> Function() action,
) {
  final key = p.normalize(session.absolute.path);
  final result = (_syncTails[key] ?? Future<void>.value()).then(
    (_) => action(),
  );
  final tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  _syncTails[key] = tail;
  tail.then((_) {
    if (identical(_syncTails[key], tail)) _syncTails.remove(key);
  });
  return result;
}

/// Removes only copies explicitly associated with deleted uploads. Shares the
/// copy queue so a copy already in flight cannot finish after cleanup.
Future<void> deleteSessionAttachmentCopies(
  Set<String> sourcePaths, {
  required Directory sessionsDirectory,
}) async {
  if (!await sessionsDirectory.exists()) return;
  final sources = sourcePaths
      .map((path) => p.normalize(p.absolute(path)))
      .toSet();
  final appRoot = sessionsDirectory.parent.path;
  await for (final session in sessionsDirectory.list(followLinks: false)) {
    if (session is! Directory) continue;
    await _serializeSessionMutation(session, () async {
      final attachments = Directory(p.join(session.path, 'attachments'));
      if (await FileSystemEntity.type(attachments.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return;
      }
      final indexFile = File(p.join(session.path, '.attachment-index.json'));
      if (!await indexFile.exists()) return;
      final Map<String, dynamic> index;
      try {
        final decoded = jsonDecode(await indexFile.readAsString());
        if (decoded is! Map<String, dynamic>) return;
        index = decoded;
      } on FormatException {
        return;
      }
      for (final entry in index.entries) {
        final record = entry.value;
        final savedName = record is Map ? record['name'] : null;
        if (savedName is! String || savedName != _safeName(savedName)) continue;
        final canonical = KelivoFileUri.isKelivoFileUri(entry.key)
            ? entry.key
            : KelivoFileUri.tryEncodeLegacyAbsolutePath(
                entry.key,
                allowGenericFallback: false,
              );
        final source =
            (canonical == null
                ? null
                : KelivoFileUri.resolveToAbsolute(canonical, root: appRoot)) ??
            SandboxPathResolver.resolveForIo(entry.key);
        if (source == null ||
            !sources.contains(p.normalize(p.absolute(source)))) {
          continue;
        }
        final copy = File(p.join(attachments.path, savedName));
        if (await FileSystemEntity.type(copy.path, followLinks: false) ==
            FileSystemEntityType.file) {
          await copy.delete();
        }
      }
      // Retain identity records: subsequent turns may still contain these old
      // message parts. Missing originals must not recreate deleted attachments
      // or block generation. Restoring an original allows a fresh copy again.
    });
  }
}

Future<List<AttachmentInfo>> _syncAttachments(
  WorkspaceToolContext ctx,
  List<ChatMessage> messages,
) async {
  final out = <AttachmentInfo>[];
  final attachmentsDir = Directory(p.join(ctx.sessionDir.path, 'attachments'));
  await attachmentsDir.create(recursive: true);
  // Keep identity outside the visible attachments directory. Equal filename
  // and size do not imply equal content; the original URI owns its saved name.
  final indexFile = File(p.join(ctx.sessionDir.path, '.attachment-index.json'));
  final index = await indexFile.exists()
      ? Map<String, dynamic>.from(
          jsonDecode(await indexFile.readAsString()) as Map,
        )
      : <String, dynamic>{};
  final seen = <String>{};

  for (final message in messages) {
    if (message.role != 'user') continue;
    for (final part in message.parts) {
      final info = await _syncPart(ctx, attachmentsDir, part, index, indexFile);
      if (info != null && seen.add(info.sourceUri)) out.add(info);
    }
  }
  return out;
}

Future<AttachmentInfo?> _syncPart(
  WorkspaceToolContext ctx,
  Directory attachmentsDir,
  MessagePart part,
  Map<String, dynamic> index,
  File indexFile,
) async {
  late final String uri;
  late final String preferredName;
  if (part is FilePart) {
    if (part.unavailable) return null;
    uri = part.uri;
    preferredName = part.name.trim().isEmpty
        ? _nameFromUri(part.uri)
        : part.name;
  } else if (part is ImagePart) {
    if (part.unavailable) return null;
    uri = part.uri;
    preferredName = _nameFromUri(part.uri, fallback: 'image.png');
  } else {
    return null;
  }

  final sourcePath = SandboxPathResolver.resolveForIo(uri);
  if (uri.startsWith('https://') ||
      uri.startsWith('http://') ||
      uri.startsWith('data:')) {
    return null;
  }
  if (sourcePath == null || sourcePath.isEmpty) {
    throw FileSystemException('Cannot read attachment $preferredName', uri);
  }
  final record = index[uri];
  final source = File(sourcePath);
  final stat = await source.stat();
  if (stat.type != FileSystemEntityType.file) {
    if (stat.type == FileSystemEntityType.notFound && record is Map) {
      return null;
    }
    throw FileSystemException(
      'Attachment is missing: $preferredName',
      sourcePath,
    );
  }
  final savedName = record is Map ? record['name'] : null;
  final destName = savedName is String && savedName == _safeName(savedName)
      ? savedName
      : await _uniqueName(attachmentsDir, _safeName(preferredName));
  final dest = File(p.join(attachmentsDir.path, destName));
  final sourceSize = stat.size;
  if (record is! Map ||
      record['size'] != sourceSize ||
      record['modified'] != stat.modified.microsecondsSinceEpoch ||
      !await dest.exists() ||
      await dest.length() != sourceSize) {
    final temp = File(
      p.join(ctx.sessionDir.path, '.attachment-${const Uuid().v4()}'),
    );
    try {
      await source.copy(temp.path);
      await temp.rename(dest.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    index[uri] = {
      'name': destName,
      'size': sourceSize,
      'modified': stat.modified.microsecondsSinceEpoch,
    };
    final tempIndex = File('${indexFile.path}.tmp');
    await tempIndex.writeAsString(jsonEncode(index), flush: true);
    await tempIndex.rename(indexFile.path);
  }
  final size = await dest.length();
  return AttachmentInfo(
    name: destName,
    size: size,
    modelPath: ctx.paths.toModelPath(dest.path),
    sourceUri: uri,
  );
}

String _safeName(String name) {
  final cleaned = name.replaceAll('\\', '/').split('/').last.trim();
  return cleaned.isEmpty || cleaned == '.' || cleaned == '..'
      ? 'attachment'
      : cleaned;
}

/// Picks a name that cannot overwrite a different attachment.
Future<String> _uniqueName(Directory dir, String preferred) async {
  final cleaned = preferred.trim().isEmpty ? 'attachment' : preferred;
  var candidate = cleaned;
  var n = 2;
  while (true) {
    final file = File(p.join(dir.path, candidate));
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return candidate;
    }
    candidate = _withSuffix(cleaned, n);
    n++;
  }
}

String _withSuffix(String name, int n) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return '$name ($n)';
  return '${name.substring(0, dot)} ($n)${name.substring(dot)}';
}

String _nameFromUri(String uri, {String fallback = 'attachment'}) {
  final resolved = SandboxPathResolver.resolveForIo(uri) ?? uri;
  var name = p.basename(resolved.split('?').first);
  if (name.isEmpty || name == '/' || name == '.') return fallback;
  return name;
}
