import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

const importToolboxUrl = 'https://kelivo.psycheas.top/tools/import';
const importToolboxSources = {
  'chatgpt',
  'claude',
  'deepseek',
  'gemini',
  'grok',
  'chatbox',
  'cherry',
  'openwebui',
  'nextchat',
  'lobechat',
};

/// File pickers may stage a local copy under a different name.
Future<bool> isToolboxChatImport(File file, {String? fileName}) async {
  final name = p.basename(fileName ?? file.path).toLowerCase();
  if (name.startsWith('kelivo-import-')) return true;
  if (name.startsWith('kelivo_backup_') ||
      name.startsWith('kelivo-backup-') ||
      name.endsWith('.kbackup')) {
    return false;
  }

  // Inspect only the root settings. A failed peek leaves both modes available.
  try {
    return await Isolate.run(() {
      final input = InputFileStream(file.path);
      try {
        if (!_hasZipDirectory(input)) return false;
        final directory = ZipDirectory()..read(input);
        final header = directory.fileHeaders.singleWhere(
          (entry) => entry.filename == 'settings.json',
        );
        final settings = header.file;
        const peekLimit = 16 * 1024 * 1024;
        if (settings == null ||
            settings.filename != 'settings.json' ||
            settings.compressedSize > peekLimit ||
            settings.uncompressedSize > peekLimit) {
          return false;
        }
        final bytes = settings.getStream().toUint8List();
        return bytes.length == settings.uncompressedSize &&
            getCrc32(bytes) == header.crc32 &&
            _hasToolboxSettings(jsonDecode(utf8.decode(bytes)));
      } finally {
        input.closeSync();
      }
    });
  } catch (_) {
    return false;
  }
}

// ZipDirectory searches back to the start on truncated files. A ZIP's end
// record must precede its comment, which is at most 65535 bytes long.
bool _hasZipDirectory(InputFileStream input) {
  const endSize = ZipDirectory.eocdSize;
  if (input.totalLength < endSize ||
      input.peekBytes(4).readUint32() != ZipFile.zipSignature) {
    return false;
  }
  final start = math.max(0, input.totalLength - endSize - 0xffff);
  final tail = ByteData.sublistView(
    input.subset(position: start).toUint8List(),
  );
  for (var offset = tail.lengthInBytes - endSize; offset >= 0; offset--) {
    if (tail.getUint32(offset, Endian.little) == ZipDirectory.eocdSignature &&
        tail.getUint16(offset + endSize - 2, Endian.little) ==
            tail.lengthInBytes - offset - endSize) {
      return true;
    }
  }
  return false;
}

Object? _decodeSetting(Object? value) =>
    value is String ? jsonDecode(value) : value;

final _toolboxAssistantIds = {
  for (final source in importToolboxSources) 'imported-$source-assistant',
};

bool _hasToolboxSettings(Object? settings) {
  if (settings is! Map<String, dynamic>) return false;
  if (settings.containsKey('assistants_v1')) {
    final assistants = _decodeSetting(settings['assistants_v1']);
    if (assistants is! List) return false;
    if (assistants.isNotEmpty) {
      return assistants.every(
        (item) => item is Map && _toolboxAssistantIds.contains(item['id']),
      );
    }
  }
  final providers = _decodeSetting(settings['provider_configs_v1']);
  return providers is Map<String, dynamic> &&
      providers.isNotEmpty &&
      providers.keys.every(
        (key) => importToolboxSources.any(
          (source) => key.startsWith('imported-$source-'),
        ),
      );
}
