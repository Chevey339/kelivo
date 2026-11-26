import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:image/image.dart' as img;

import 'api/tool_call_cancellation.dart';

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
    _checkByteLength(bytes);
    return compute(_prepare, bytes);
  }

  static const _unsupportedFormat = ToolImageException(
    'Unsupported image. Use PNG, JPEG, GIF, WebP, or BMP.',
  );
  static const _decodeError = ToolImageException('Image could not be decoded');

  static Future<ToolImage> fromNetworkBytes(Uint8List bytes) async {
    _checkByteLength(bytes);
    if (!_hasSupportedSignature(bytes)) throw _unsupportedFormat;
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    _checkNetworkDecodeAvailable();
    final stopped = Completer<ToolImage>();
    final unregister = cancellation?.onCancel(
      () => stopped.completeError(StateError('tool_call_cancelled')),
    );
    var finished = false;
    void checkActive() {
      cancellation?.throwIfCancelled();
      if (finished) throw _decodeError;
      _checkNetworkDecodeAvailable();
    }

    try {
      return await Future.any([
        _decodeNetworkImage(bytes, checkActive),
        stopped.future,
      ]).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ToolImageException('Image preparation timed out');
    } on StateError {
      checkActive();
      throw _decodeError;
    } on ToolImageException {
      rethrow;
    } catch (_) {
      throw _decodeError;
    } finally {
      unregister?.call();
      finished = true;
    }
  }

  static void _checkNetworkDecodeAvailable() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final state = SchedulerBinding.instance.lifecycleState;
    if (state == ui.AppLifecycleState.hidden ||
        state == ui.AppLifecycleState.paused) {
      // Impeller queues GPU work while the iOS app is backgrounded.
      throw const ToolImageException(
        'Return to Kelivo to prepare this image on iOS',
      );
    }
  }

  static bool _hasSupportedSignature(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final header = ByteData.sublistView(bytes);
    final tag = header.getUint32(0);
    return header.getUint16(0) == 0xffd8 || // JPEG
        header.getUint16(0) == 0x424d || // BMP
        (tag == 0x89504e47 && header.getUint32(4) == 0x0d0a1a0a) || // PNG
        (tag == 0x47494638 &&
            (header.getUint16(4) == 0x3761 ||
                header.getUint16(4) == 0x3961)) || // GIF87a/GIF89a
        (tag == 0x52494646 && header.getUint32(8) == 0x57454250); // WebP
  }

  static Future<ToolImage> _decodeNetworkImage(
    Uint8List bytes,
    void Function() checkActive,
  ) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? frame;
    ui.Image? resized;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      checkActive();
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      checkActive();
      _checkDimensions(descriptor.width, descriptor.height);
      final (width, height) = _snapshotSize(
        descriptor.width,
        descriptor.height,
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: width,
        targetHeight: height,
      );
      checkActive();
      frame = (await codec.getNextFrame()).image;
      checkActive();
      _checkDimensions(frame.width, frame.height);
      // Animated codecs can return a full-size first frame.
      final (frameWidth, frameHeight) = _snapshotSize(
        frame.width,
        frame.height,
      );
      if (frameWidth != frame.width || frameHeight != frame.height) {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImageRect(
          frame,
          ui.Rect.fromLTWH(
            0,
            0,
            frame.width.toDouble(),
            frame.height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, frameWidth.toDouble(), frameHeight.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        try {
          resized = await picture.toImage(frameWidth, frameHeight);
        } finally {
          picture.dispose();
        }
        checkActive();
      }
      final snapshot = resized ?? frame;
      final png = await snapshot.toByteData(format: ui.ImageByteFormat.png);
      checkActive();
      if (png == null) throw _decodeError;
      final encoded = png.buffer.asUint8List(
        png.offsetInBytes,
        png.lengthInBytes,
      );
      if (encoded.length <= maxEncodedBytes) {
        return ToolImage(encoded, 'image/png', snapshot.width, snapshot.height);
      }
      return await fromBytes(encoded);
    } finally {
      resized?.dispose();
      frame?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static void _checkByteLength(Uint8List bytes) {
    if (bytes.length > maxFileBytes) {
      throw const ToolImageException('Image exceeds the 20 MiB file limit');
    }
  }

  static void _checkDimensions(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw const ToolImageException('Image could not be decoded');
    }
    if (height > maxPixels ~/ width) {
      throw const ToolImageException('Image exceeds the 40 megapixel limit');
    }
  }

  static (int, int) _snapshotSize(int width, int height) {
    final longEdge = width > height ? width : height;
    if (longEdge <= maxLongEdge) return (width, height);
    final scale = maxLongEdge / longEdge;
    return (
      (width * scale).round().clamp(1, maxLongEdge),
      (height * scale).round().clamp(1, maxLongEdge),
    );
  }

  static img.Decoder _supportedDecoder(Uint8List bytes) {
    final decoder = img.findDecoderForData(bytes);
    if (decoder == null ||
        !{
          img.ImageFormat.png,
          img.ImageFormat.jpg,
          img.ImageFormat.gif,
          img.ImageFormat.webp,
          img.ImageFormat.bmp,
        }.contains(decoder.format)) {
      throw _unsupportedFormat;
    }
    return decoder;
  }

  static ToolImage _prepare(Uint8List bytes) {
    try {
      final decoder = _supportedDecoder(bytes);
      final info = decoder.startDecode(bytes);
      if (info == null) {
        throw const ToolImageException('Image could not be decoded');
      }
      _checkDimensions(info.width, info.height);
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
      final (width, height) = _snapshotSize(image.width, image.height);
      if (width != image.width || height != image.height) {
        image = img.copyResize(
          image,
          width: width,
          height: height,
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
