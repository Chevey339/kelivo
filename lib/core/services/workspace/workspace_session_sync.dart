import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../models/chat_message.dart';
import '../../models/message_part.dart';
import '../../../utils/sandbox_path_resolver.dart';
import 'workspace_tool_context.dart';

class AttachmentInfo {
  const AttachmentInfo({
    required this.name,
    required this.size,
    required this.modelPath,
  });

  final String name;
  final int size;
  final String modelPath;
}

/// Copies user-message files/images into the conversation session attachments
/// folder. Failures are logged and ignored.
Future<List<AttachmentInfo>> syncAttachments(
  WorkspaceToolContext ctx,
  List<ChatMessage> messages,
) async {
  final out = <AttachmentInfo>[];
  final attachmentsDir = Directory(p.join(ctx.sessionDir.path, 'attachments'));
  try {
    await attachmentsDir.create(recursive: true);
  } catch (e) {
    debugPrint('Workspace attachment dir failed: $e');
    return out;
  }

  for (final message in messages) {
    if (message.role != 'user') continue;
    for (final part in message.parts) {
      try {
        final info = await _syncPart(ctx, attachmentsDir, part);
        if (info != null) out.add(info);
      } catch (e) {
        debugPrint('Workspace attachment sync skipped: $e');
      }
    }
  }
  return out;
}

Future<AttachmentInfo?> _syncPart(
  WorkspaceToolContext ctx,
  Directory attachmentsDir,
  MessagePart part,
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
  if (sourcePath == null || sourcePath.isEmpty) return null;
  final source = File(sourcePath);
  if (!await source.exists()) return null;
  final sourceSize = await source.length();

  final destName = await _uniqueName(
    attachmentsDir,
    preferredName,
    sourceSize: sourceSize,
  );
  final dest = File(p.join(attachmentsDir.path, destName));
  if (!await dest.exists()) {
    await dest.copy(source.path);
  } else if (await dest.length() != sourceSize) {
    await dest.writeAsBytes(await source.readAsBytes());
  }
  final size = await dest.length();
  return AttachmentInfo(
    name: destName,
    size: size,
    modelPath: ctx.paths.toModelPath(dest.path),
  );
}

/// Picks [preferred] when missing or same-sized; otherwise `name (2).ext`.
Future<String> _uniqueName(
  Directory dir,
  String preferred, {
  required int sourceSize,
}) async {
  final cleaned = preferred.trim().isEmpty ? 'attachment' : preferred;
  var candidate = cleaned;
  var n = 2;
  while (true) {
    final file = File(p.join(dir.path, candidate));
    if (!await file.exists()) return candidate;
    if (await file.length() == sourceSize) return candidate;
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
