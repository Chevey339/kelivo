import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Auto image compression performed at STORAGE/INGESTION time.
///
/// When an image is copied into the upload directory we run it through
/// [ImageCompressor.compressIfNeeded], which decodes the image, applies any EXIF
/// orientation, caps the longest edge to a configurable size, and re-encodes it.
/// The original file is REPLACED in place (no original is kept). Doing the work
/// here shrinks both on-disk storage AND the base64 payload sent to the model in
/// a single place.
///
/// Smart format choice:
///   - A source image with at least one genuinely transparent pixel stays PNG
///     (lossless, only resized) so transparency is preserved. Note an alpha
///     CHANNEL alone is not enough: opaque RGBA PNGs are re-encoded as JPEG.
///   - Everything else (jpg/jpeg, opaque png, webp, ...) is re-encoded as JPEG.
///     PNG -> JPEG also changes the file extension, since MIME is inferred from
///     the extension everywhere via `inferMediaMimeFromSource`.
///
/// GIF / HEIC / HEIF are skipped entirely (decode is unreliable for them).
/// Multi-frame/animated images (e.g. animated WebP, APNG) are also left
/// untouched so the animation is never flattened to a single still frame.
///
/// All heavy decode/resize/encode work runs in a background isolate via
/// [compute]; file IO happens on the calling thread. The method is defensive:
/// on ANY failure, or when the result would not be smaller than the original,
/// it returns [srcPath] unchanged and leaves the original file intact. It must
/// never crash a send.
class ImageCompressor {
  /// Compress [srcPath] in place per settings. Returns the path to USE afterwards
  /// (differs from srcPath only when the extension changed, e.g. .png -> .jpg).
  /// On ANY failure, or when compression is not beneficial (result >= original bytes),
  /// returns srcPath unchanged and leaves the original file intact.
  /// When it writes a new file with a DIFFERENT extension, it deletes the old file.
  static Future<String> compressIfNeeded(
    String srcPath, {
    required bool enabled,
    required int maxDimension, // longest-edge cap in px; <=0 means do not resize
    required int quality, // JPEG quality 1..100
    int minBytes = 60 * 1024, // skip files smaller than this (not worth it)
  }) async {
    if (!enabled) return srcPath;

    try {
      final File srcFile = File(srcPath);
      if (!await srcFile.exists()) return srcPath;

      // Skip formats we cannot reliably decode/re-encode.
      final String ext = p.extension(srcPath).toLowerCase();
      if (ext == '.gif' || ext == '.heic' || ext == '.heif') {
        return srcPath;
      }

      final Uint8List original = await srcFile.readAsBytes();
      final int originalBytes = original.length;

      // Not worth compressing tiny files.
      if (originalBytes < minBytes) return srcPath;

      // Clamp quality into a sane range.
      final int q = quality.clamp(1, 100);

      // Do the heavy lifting in a background isolate.
      final _CompressResult? result = await compute(
        _runCompression,
        _CompressRequest(
          bytes: original,
          maxDimension: maxDimension,
          quality: q,
        ),
      );

      // Decode failed or nothing useful came back -> leave original untouched.
      if (result == null) return srcPath;

      // Only adopt the result if it is actually smaller than the original.
      if (result.bytes.length >= originalBytes) return srcPath;

      // Determine the destination path / extension.
      final String dir = p.dirname(srcPath);
      final String baseName = p.basenameWithoutExtension(srcPath);
      final String newExt = result.isPng ? '.png' : '.jpg';
      final bool extChanged = newExt != ext;
      final String destPath = p.join(dir, '$baseName$newExt');

      // Preserve the original last-modified time to help cache keying.
      DateTime? srcModified;
      try {
        srcModified = (await srcFile.stat()).modified;
      } catch (_) {}

      // Write the compressed bytes.
      final File destFile = File(destPath);
      await destFile.writeAsBytes(result.bytes, flush: true);

      // If the extension changed (e.g. png -> jpg) delete the old file.
      if (extChanged) {
        try {
          await srcFile.delete();
        } catch (_) {}
      }

      if (srcModified != null) {
        try {
          await destFile.setLastModified(srcModified);
        } catch (_) {}
      }

      return destPath;
    } catch (_) {
      // Any failure -> return original path, leave the original file intact.
      return srcPath;
    }
  }
}

/// Primitive-only payload sent into the isolate. All fields are sendable.
class _CompressRequest {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;

  const _CompressRequest({
    required this.bytes,
    required this.maxDimension,
    required this.quality,
  });
}

/// Primitive-only result returned from the isolate.
class _CompressResult {
  final Uint8List bytes;
  final bool isPng;

  const _CompressResult({required this.bytes, required this.isPng});
}

/// Runs entirely inside a background isolate (no file IO here).
/// Returns null when the image cannot be decoded.
_CompressResult? _runCompression(_CompressRequest req) {
  try {
    img.Image? decoded = img.decodeImage(req.bytes);
    if (decoded == null) return null;

    // Multi-frame images (animated WebP / APNG / etc.) decode to a single
    // frame here; re-encoding would silently drop the animation. Never corrupt
    // content -> leave the original untouched by signalling no-op via null.
    if (decoded.numFrames > 1) return null;

    // Apply EXIF orientation before we strip metadata via re-encoding.
    decoded = img.bakeOrientation(decoded);

    // Cap the longest edge while preserving aspect ratio.
    if (req.maxDimension > 0) {
      final int w = decoded.width;
      final int h = decoded.height;
      final int longest = w >= h ? w : h;
      if (longest > req.maxDimension) {
        if (w >= h) {
          decoded = img.copyResize(decoded, width: req.maxDimension);
        } else {
          decoded = img.copyResize(decoded, height: req.maxDimension);
        }
      }
    }

    // Only keep PNG when the image actually has transparent pixels. `hasAlpha`
    // merely reports the presence of an alpha CHANNEL (numChannels == 2 || 4),
    // so opaque RGBA PNGs (screenshots, most exports) would otherwise stay PNG
    // and skip the much stronger JPEG compression. Scan for a real non-opaque
    // pixel; early-out on the first one to bound the cost.
    bool reallyTransparent = false;
    if (decoded.hasAlpha) {
      final num maxA = decoded.maxChannelValue;
      for (final px in decoded) {
        if (px.a < maxA) {
          reallyTransparent = true;
          break;
        }
      }
    }
    final bool keepPng = reallyTransparent;
    if (keepPng) {
      final Uint8List png = img.encodePng(decoded, level: 6);
      return _CompressResult(bytes: png, isPng: true);
    } else {
      final Uint8List jpg = img.encodeJpg(decoded, quality: req.quality);
      return _CompressResult(bytes: jpg, isPng: false);
    }
  } catch (_) {
    return null;
  }
}
