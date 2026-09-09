import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Imported icons are owned thumbnails, never references to picker cache files.
class BackgroundIconStore {
  BackgroundIconStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;

  Future<Directory> _directory() async {
    final support = await _supportDirectory();
    return Directory(
      p.join(support.path, 'background-icons'),
    ).create(recursive: true);
  }

  Future<String> importImage(String source) async {
    final file = File(source);
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException('Image is too large');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    ui.Image? thumbnail;
    ui.Picture? picture;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 || descriptor.height <= 0) {
        throw const FormatException('Invalid image dimensions');
      }
      final longest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = longest > 512 ? 512 / longest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, 512),
        targetHeight: (descriptor.height * scale).round().clamp(1, 512),
      );
      decoded = (await codec.getNextFrame()).image;
      final side = decoded.width < decoded.height
          ? decoded.width
          : decoded.height;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        decoded,
        ui.Rect.fromLTWH(
          (decoded.width - side) / 2,
          (decoded.height - side) / 2,
          side.toDouble(),
          side.toDouble(),
        ),
        const ui.Rect.fromLTWH(0, 0, 256, 256),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      picture = recorder.endRecording();
      thumbnail = await picture.toImage(256, 256);
      final bytes = await thumbnail.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const FormatException('Cannot encode image');
      final directory = await _directory();
      final destination = File(
        p.join(
          directory.path,
          'icon-${DateTime.now().microsecondsSinceEpoch}.png',
        ),
      );
      await destination.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return destination.path;
    } finally {
      thumbnail?.dispose();
      picture?.dispose();
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<void> deleteOwnedImage(String path) async {
    if (path.isEmpty) return;
    final directory = await _directory();
    final file = File(path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      return;
    }
    if (!p.basename(path).startsWith('icon-') || p.extension(path) != '.png') {
      return;
    }
    if (await file.parent.resolveSymbolicLinks() !=
        await directory.resolveSymbolicLinks()) {
      return;
    }
    await file.delete();
  }
}
