import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';

import '../../../utils/clipboard_images.dart';

class ComposerClipboardData {
  const ComposerClipboardData({
    this.text,
    this.bytes,
    this.format,
    this.paths = const [],
  });
  final String? text;
  final Uint8List? bytes;
  final String? format;
  final List<String> paths;
}

/// Android composer clipboard IO, independent of a widget or its context.
abstract final class ComposerClipboard {
  static Future<ComposerClipboardData> read() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final reader = await clipboard.read();
        for (final source in <DataReader>[reader, ...reader.items]) {
          for (final (format, name) in [
            (Formats.png, 'png'),
            (Formats.jpeg, 'jpeg'),
            (Formats.gif, 'gif'),
            (Formats.webp, 'webp'),
          ]) {
            if (!source.canProvide(format)) continue;
            final bytes = await _readFile(source, format);
            if (bytes != null && bytes.isNotEmpty) {
              return ComposerClipboardData(bytes: bytes, format: name);
            }
          }
        }
        if (reader.canProvide(Formats.plainText)) {
          final text = await reader.readValue(Formats.plainText);
          if (text != null && text.isNotEmpty) {
            return ComposerClipboardData(text: text);
          }
        }
      }
    } catch (_) {
      // The platform clipboard remains available without super_clipboard.
    }
    final images = await ClipboardImages.getImagePaths();
    if (images.isNotEmpty) return ComposerClipboardData(paths: images);
    return ComposerClipboardData(
      text: (await Clipboard.getData(Clipboard.kTextPlain))?.text,
    );
  }

  static Future<Uint8List?> _readFile(
    DataReader reader,
    FileFormat format,
  ) async {
    final result = Completer<Uint8List?>();
    try {
      final progress = reader.getFile(
        format,
        (file) async {
          try {
            final bytes = await file.readAll();
            if (!result.isCompleted) result.complete(bytes);
          } catch (_) {
            if (!result.isCompleted) result.complete(null);
          }
        },
        onError: (_) {
          if (!result.isCompleted) result.complete(null);
        },
      );
      if (progress == null && !result.isCompleted) result.complete(null);
      return await result.future;
    } catch (_) {
      return null;
    }
  }

  static Future<File> reserve(
    Directory directory,
    String prefix,
    String extension,
  ) async {
    await directory.create(recursive: true);
    final base = '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
    for (var counter = 0; ; counter++) {
      final suffix = counter == 0 ? '' : '_$counter';
      final file = File(p.join(directory.path, '$base$suffix.$extension'));
      try {
        return await file.create(exclusive: true);
      } on FileSystemException {
        if (!await file.exists()) rethrow;
      }
    }
  }

  static Future<void> discard(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup must not prevent the original text paste from completing.
    }
  }
}
