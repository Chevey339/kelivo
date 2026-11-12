import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A static, bounded image snapshot for tool results and later history replay.
class ToolImage {
  const ToolImage(this.bytes, this.mime, this.width, this.height);

  final Uint8List bytes;
  final String mime;
  final int width;
  final int height;

  static const maxFileBytes = 20 * 1024 * 1024;
  static const maxPixels = 40 * 1000 * 1000;
  // Also fits Claude's stricter limit when history contains many images.
  static const maxLongEdge = 2000;
  // Base64 stays below the 5 MB image limit used by hosted providers.
  static const maxEncodedBytes = 3 * 1024 * 1024;

  static Future<ToolImage> read(String hostPath) async =>
      fromBytes(await readBytes(hostPath));

  static Future<Uint8List> readBytes(String hostPath) async {
    if (await FileSystemEntity.type(hostPath) != FileSystemEntityType.file) {
      throw const ToolImageException(
        'Image path must refer to an existing file',
      );
    }
    final handle = await File(hostPath).open();
    late Uint8List bytes;
    try {
      if (await handle.length() > maxFileBytes) {
        throw const ToolImageException('Image exceeds the 20 MiB file limit');
      }
      bytes = await handle.read(maxFileBytes + 1);
      if (bytes.length > maxFileBytes) {
        throw const ToolImageException('Image exceeds the 20 MiB file limit');
      }
    } finally {
      await handle.close();
    }
    return bytes;
  }

  /// Sniff the encoding; filenames and remote MIME declarations are not proof.
  static Future<ToolImage> fromBytes(Uint8List bytes) {
    if (bytes.length > maxFileBytes) {
      throw const ToolImageException('Image exceeds the 20 MiB file limit');
    }
    return compute(_prepare, bytes);
  }

  static ToolImage _prepare(Uint8List bytes) {
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
        throw const ToolImageException(
          'Unsupported image. Use PNG, JPEG, GIF, WebP, or BMP.',
        );
      }
      final info = decoder.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) {
        throw const ToolImageException('Image could not be decoded');
      }
      if (info.width * info.height > maxPixels) {
        throw const ToolImageException('Image exceeds the 40 megapixel limit');
      }
      // The JPEG decoder bakes orientation and clears the decoded EXIF tag.
      // Check the source tag before deciding whether its bytes can be reused.
      final jpegOrientation = decoder.format == img.ImageFormat.jpg
          ? img.decodeJpgExif(bytes)?.imageIfd.orientation
          : null;
      final frame = decoder.decodeFrame(0);
      if (frame == null) {
        throw const ToolImageException('Image could not be decoded');
      }
      // Already suitable snapshots retain their bytes on every history replay.
      if ((decoder.format == img.ImageFormat.png ||
              decoder.format == img.ImageFormat.jpg) &&
          info.numFrames == 1 &&
          frame.width <= maxLongEdge &&
          frame.height <= maxLongEdge &&
          bytes.length <= maxEncodedBytes &&
          (jpegOrientation == null || jpegOrientation == 1) &&
          (!frame.exif.imageIfd.hasOrientation ||
              frame.exif.imageIfd.orientation == 1)) {
        return ToolImage(
          bytes,
          decoder.format == img.ImageFormat.png ? 'image/png' : 'image/jpeg',
          frame.width,
          frame.height,
        );
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
      if (png.length <= maxEncodedBytes) {
        return ToolImage(png, 'image/png', image.width, image.height);
      }
      for (final quality in [85, 70, 55, 40]) {
        final jpeg = img.encodeJpg(image, quality: quality);
        if (jpeg.length <= maxEncodedBytes) {
          return ToolImage(jpeg, 'image/jpeg', image.width, image.height);
        }
      }
      throw const ToolImageException('Image exceeds the encoded size limit');
    } on ToolImageException {
      rethrow;
    } catch (_) {
      throw const ToolImageException('Image could not be decoded');
    }
  }
}

class ToolImageException implements Exception {
  const ToolImageException(this.message);

  final String message;

  @override
  String toString() => 'ToolImageException: $message';
}
