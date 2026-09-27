import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'host_file_tools.dart';

/// A static, bounded image snapshot for tool results and later history replay.
class WorkspaceImage {
  const WorkspaceImage(this.bytes, this.mime, this.width, this.height);

  final Uint8List bytes;
  final String mime;
  final int width;
  final int height;

  static const maxFileBytes = 20 * 1024 * 1024;
  static const maxPixels = 40 * 1000 * 1000;
  static const maxLongEdge = 2048;

  static Future<WorkspaceImage> read(String hostPath) async {
    if (await FileSystemEntity.type(hostPath) != FileSystemEntityType.file) {
      throw const HostFileException(
        'Image path must refer to an existing file',
      );
    }
    final handle = await File(hostPath).open();
    late Uint8List bytes;
    try {
      if (await handle.length() > maxFileBytes) {
        throw const HostFileException('Image exceeds the 20 MiB file limit');
      }
      bytes = await handle.read(maxFileBytes + 1);
      if (bytes.length > maxFileBytes) {
        throw const HostFileException('Image exceeds the 20 MiB file limit');
      }
    } finally {
      await handle.close();
    }
    return compute(_prepare, bytes);
  }

  static WorkspaceImage _prepare(Uint8List bytes) {
    try {
      final decoder = img.findDecoderForData(bytes);
      if (decoder == null ||
          !{
            img.ImageFormat.png,
            img.ImageFormat.jpg,
            img.ImageFormat.gif,
            img.ImageFormat.webp,
            img.ImageFormat.bmp,
          }.contains(decoder.format)) {
        throw const HostFileException(
          'Unsupported image. Use PNG, JPEG, GIF, WebP, or BMP.',
        );
      }
      final info = decoder.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) {
        throw const HostFileException('Image could not be decoded');
      }
      if (info.width * info.height > maxPixels) {
        throw const HostFileException('Image exceeds the 40 megapixel limit');
      }
      final frame = decoder.decodeFrame(0);
      if (frame == null) {
        throw const HostFileException('Image could not be decoded');
      }
      var image = img.bakeOrientation(frame);
      if (image.width > maxLongEdge || image.height > maxLongEdge) {
        final longEdge = image.width > image.height
            ? image.width
            : image.height;
        final scale = maxLongEdge / longEdge;
        image = img.copyResize(
          image,
          width: (image.width * scale).round().clamp(1, maxLongEdge),
          height: (image.height * scale).round().clamp(1, maxLongEdge),
          interpolation: img.Interpolation.average,
        );
      }
      final png = img.encodePng(image);
      // Keep each result below common provider image-byte limits.
      if (png.length <= 4 * 1024 * 1024) {
        return WorkspaceImage(png, 'image/png', image.width, image.height);
      }
      return WorkspaceImage(
        img.encodeJpg(image, quality: 85),
        'image/jpeg',
        image.width,
        image.height,
      );
    } on HostFileException {
      rethrow;
    } catch (_) {
      throw const HostFileException('Image could not be decoded');
    }
  }
}
