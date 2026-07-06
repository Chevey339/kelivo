import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Image compression performed at STORAGE/INGESTION time.
///
/// [ImageCompressor.compressIfNeeded] decodes the image, applies EXIF
/// orientation, optionally resizes, and re-encodes it (JPEG, or PNG when
/// transparency is preserved). The original file is replaced (deleted after
/// the new file is written). Doing the work here shrinks both on-disk storage
/// AND the base64 payload sent to the model.
///
/// Format choice (in priority order):
///   - [keepPng] = true: always output PNG (user explicitly chose to keep
///     transparency).
///   - Source image has genuinely transparent pixels: output PNG.
///   - Everything else: output JPEG.
///
/// GIF / HEIC / HEIF are skipped entirely. Multi-frame images (animated WebP,
/// APNG) are also left untouched.
///
/// All heavy decode/resize/encode work runs in a background isolate via
/// [compute]. The method is defensive: on ANY failure, or when the result
/// would not be smaller than the original, it returns [srcPath] unchanged.
class ImageCompressor {
  /// Compress [srcPath] per settings. Returns the path to use afterwards
  /// (differs from srcPath only when the extension changed, e.g. .png -> .jpg).
  /// On ANY failure, or when compression is not beneficial (result >= original
  /// bytes), returns srcPath unchanged and leaves the original file intact.
  /// When it writes a new file with a DIFFERENT extension, it deletes the old.
  static Future<String> compressIfNeeded(
    String srcPath, {
    required bool enabled,
    required int quality, // JPEG quality 1..100, used only when output is JPEG
    int?
    maxDimension, // if set, longest edge resized to this value (aspect ratio preserved)
    bool keepPng = false, // if true, skip format detection, always output PNG
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
      final int? dim = maxDimension != null && maxDimension > 0
          ? maxDimension
          : null;

      // Do the heavy lifting in a background isolate.
      final _CompressResult? result = await compute(
        _runCompression,
        _CompressRequest(
          bytes: original,
          quality: q,
          maxDimension: dim,
          keepPng: keepPng,
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
  final int quality;
  final int? maxDimension;
  final bool keepPng;

  const _CompressRequest({
    required this.bytes,
    required this.quality,
    this.maxDimension,
    this.keepPng = false,
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

    // Resize if maxDimension is set (maintain aspect ratio).
    final int maxDim = req.maxDimension ?? 0;
    if (maxDim > 0) {
      final int longEdge = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      if (longEdge > maxDim) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? maxDim : null,
          height: decoded.height >= decoded.width ? maxDim : null,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // Determine format. Priority: user override (keepPng) > auto-detect.
    bool keepPng = req.keepPng;
    if (!keepPng && decoded.hasAlpha) {
      // Only keep PNG when the image actually has transparent pixels. `hasAlpha`
      // reports the presence of an alpha CHANNEL (numChannels == 2 || 4),
      // so opaque RGBA PNGs (screenshots, most exports) would otherwise stay
      // PNG and skip the much stronger JPEG compression. Scan for a real
      // non-opaque pixel; early-out on the first one to bound the cost.
      final num maxA = decoded.maxChannelValue;
      for (final px in decoded) {
        if (px.a < maxA) {
          keepPng = true;
          break;
        }
      }
    }
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
