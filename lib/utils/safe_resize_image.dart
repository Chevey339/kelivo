import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How [SafeResizeImage] maps a source onto the decode box.
///
/// [contain] keeps the full image inside the box (tool / viewer).
/// [cover] makes the crop region at least as large as the box (attachments).
enum SafeResizeFit { contain, cover }

/// Floor each axis, then nudge so the pixel product cannot exceed [maxPixels].
/// Both axes stay at least 1.
({int width, int height}) clampDecodedPixelSize({
  required double width,
  required double height,
  int? maxEdge,
  int? maxPixels,
}) {
  var w = math.max(1.0, width);
  var h = math.max(1.0, height);
  if (maxEdge != null && maxEdge > 0) {
    final longest = math.max(w, h);
    if (longest > maxEdge) {
      final edgeScale = maxEdge / longest;
      w *= edgeScale;
      h *= edgeScale;
    }
  }
  if (maxPixels != null && maxPixels > 0) {
    final pixels = w * h;
    if (pixels > maxPixels) {
      final pixelScale = math.sqrt(maxPixels / pixels);
      w *= pixelScale;
      h *= pixelScale;
    }
  }

  var outW = math.max(1, w.floor());
  var outH = math.max(1, h.floor());
  if (maxPixels != null && maxPixels > 0 && outW * outH > maxPixels) {
    final pixelScale = math.sqrt(maxPixels / (outW * outH));
    outW = math.max(1, (outW * pixelScale).floor());
    outH = math.max(1, (outH * pixelScale).floor());
    while (outW * outH > maxPixels && (outW > 1 || outH > 1)) {
      if (outW >= outH && outW > 1) {
        outW -= 1;
      } else if (outH > 1) {
        outH -= 1;
      } else {
        break;
      }
    }
  }
  return (width: outW, height: outH);
}

/// Decode box after knowing intrinsic size. Caps first, then floor, then
/// re-check. Both axes are at least 1. Never returns the uncapped original
/// when the source exceeds the budget.
@visibleForTesting
({int width, int height}) computeSafeResizeTarget({
  required int intrinsicWidth,
  required int intrinsicHeight,
  required int boxWidth,
  required int boxHeight,
  required SafeResizeFit fit,
  bool allowUpscaling = false,
  int? maxEdge,
  int? maxPixels,
}) {
  final srcW = math.max(1, intrinsicWidth);
  final srcH = math.max(1, intrinsicHeight);
  final boxW = math.max(1, boxWidth);
  final boxH = math.max(1, boxHeight);

  final widthScale = boxW / srcW;
  final heightScale = boxH / srcH;
  var scale = fit == SafeResizeFit.cover
      ? math.max(widthScale, heightScale)
      : math.min(widthScale, heightScale);
  if (!allowUpscaling && scale > 1) {
    scale = 1;
  }

  return clampDecodedPixelSize(
    width: srcW * scale,
    height: srcH * scale,
    maxEdge: maxEdge,
    maxPixels: maxPixels,
  );
}

/// ImageProvider that downsamples with a non-zero contain/cover target.
///
/// Unlike [ResizeImagePolicy.fit], the minor axis is never floored to 0.
///
/// Production code must use [SafeResizeImage.wrap], which only accepts
/// [NetworkImage], [FileImage], or [MemoryImage]. The unnamed constructor
/// is a test helper and may wrap custom providers.
class SafeResizeImage extends ImageProvider<SafeResizeImageKey> {
  const SafeResizeImage(
    this.imageProvider, {
    required this.width,
    required this.height,
    this.fit = SafeResizeFit.contain,
    this.allowUpscaling = false,
    this.maxEdge,
    this.maxPixels,
  });

  factory SafeResizeImage.wrap(
    ImageProvider imageProvider, {
    required int width,
    required int height,
    SafeResizeFit fit = SafeResizeFit.contain,
    bool allowUpscaling = false,
    int? maxEdge,
    int? maxPixels,
  }) {
    if (!_isSupportedBaseProvider(imageProvider)) {
      throw FlutterError(
        'SafeResizeImage.wrap only accepts NetworkImage, FileImage, or '
        'MemoryImage.',
      );
    }
    return SafeResizeImage(
      imageProvider,
      width: width,
      height: height,
      fit: fit,
      allowUpscaling: allowUpscaling,
      maxEdge: maxEdge,
      maxPixels: maxPixels,
    );
  }

  /// Widget entry point. Production sources are [NetworkImage], [FileImage],
  /// or [MemoryImage] and go through [wrap]. Custom providers (tests) use
  /// the core constructor so debug/release behavior stays aligned.
  factory SafeResizeImage.display(
    ImageProvider imageProvider, {
    required int width,
    required int height,
    SafeResizeFit fit = SafeResizeFit.contain,
    bool allowUpscaling = false,
    int? maxEdge,
    int? maxPixels,
  }) {
    if (_isSupportedBaseProvider(imageProvider)) {
      return SafeResizeImage.wrap(
        imageProvider,
        width: width,
        height: height,
        fit: fit,
        allowUpscaling: allowUpscaling,
        maxEdge: maxEdge,
        maxPixels: maxPixels,
      );
    }
    return SafeResizeImage(
      imageProvider,
      width: width,
      height: height,
      fit: fit,
      allowUpscaling: allowUpscaling,
      maxEdge: maxEdge,
      maxPixels: maxPixels,
    );
  }

  final ImageProvider imageProvider;
  final int width;
  final int height;
  final SafeResizeFit fit;
  final bool allowUpscaling;
  final int? maxEdge;
  final int? maxPixels;

  @override
  ImageStreamCompleter loadImage(
    SafeResizeImageKey key,
    ImageDecoderCallback decode,
  ) {
    _assertSupportedBaseProvider(imageProvider);
    Future<ui.Codec> decodeResize(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      assert(
        getTargetSize == null,
        'SafeResizeImage cannot wrap a provider that already applies '
        'getTargetSize.',
      );
      return decode(
        buffer,
        getTargetSize: (intrinsicWidth, intrinsicHeight) {
          final target = computeSafeResizeTarget(
            intrinsicWidth: intrinsicWidth,
            intrinsicHeight: intrinsicHeight,
            boxWidth: width,
            boxHeight: height,
            fit: fit,
            allowUpscaling: allowUpscaling,
            maxEdge: maxEdge,
            maxPixels: maxPixels,
          );
          return ui.TargetImageSize(width: target.width, height: target.height);
        },
      );
    }

    final completer = imageProvider.loadImage(
      key.providerCacheKey,
      decodeResize,
    );
    if (!kReleaseMode) {
      completer.debugLabel =
          '${completer.debugLabel} - SafeResized(${key.width}×${key.height})';
    }
    completer.addEphemeralErrorListener((exception, stackTrace) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    return completer;
  }

  @override
  Future<SafeResizeImageKey> obtainKey(ImageConfiguration configuration) {
    _assertSupportedBaseProvider(imageProvider);
    Completer<SafeResizeImageKey>? completer;
    SynchronousFuture<SafeResizeImageKey>? result;
    imageProvider
        .obtainKey(configuration)
        .then(
          (Object key) {
            final wrapped = SafeResizeImageKey(
              providerCacheKey: key,
              width: width,
              height: height,
              fit: fit,
              allowUpscaling: allowUpscaling,
              maxEdge: maxEdge,
              maxPixels: maxPixels,
            );
            if (completer == null) {
              result = SynchronousFuture<SafeResizeImageKey>(wrapped);
            } else if (!completer!.isCompleted) {
              completer!.complete(wrapped);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (completer == null) {
              completer = Completer<SafeResizeImageKey>()
                ..completeError(error, stack);
            } else if (!completer!.isCompleted) {
              completer!.completeError(error, stack);
            }
          },
        );
    if (result != null) {
      return result!;
    }
    completer ??= Completer<SafeResizeImageKey>();
    return completer!.future;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SafeResizeImage &&
        imageProvider == other.imageProvider &&
        width == other.width &&
        height == other.height &&
        fit == other.fit &&
        allowUpscaling == other.allowUpscaling &&
        maxEdge == other.maxEdge &&
        maxPixels == other.maxPixels;
  }

  @override
  int get hashCode => Object.hash(
    imageProvider,
    width,
    height,
    fit,
    allowUpscaling,
    maxEdge,
    maxPixels,
  );
}

bool _isSupportedBaseProvider(ImageProvider provider) {
  return provider is NetworkImage ||
      provider is FileImage ||
      provider is MemoryImage;
}

void _assertSupportedBaseProvider(ImageProvider provider) {
  assert(() {
    if (provider is ResizeImage || provider is SafeResizeImage) {
      throw FlutterError(
        'SafeResizeImage only accepts NetworkImage, FileImage, or '
        'MemoryImage. Do not wrap ResizeImage or SafeResizeImage.',
      );
    }
    return true;
  }());
}

@immutable
class SafeResizeImageKey {
  const SafeResizeImageKey({
    required this.providerCacheKey,
    required this.width,
    required this.height,
    required this.fit,
    required this.allowUpscaling,
    required this.maxEdge,
    required this.maxPixels,
  });

  final Object providerCacheKey;
  final int width;
  final int height;
  final SafeResizeFit fit;
  final bool allowUpscaling;
  final int? maxEdge;
  final int? maxPixels;

  @override
  bool operator ==(Object other) {
    return other is SafeResizeImageKey &&
        other.providerCacheKey == providerCacheKey &&
        other.width == width &&
        other.height == height &&
        other.fit == fit &&
        other.allowUpscaling == allowUpscaling &&
        other.maxEdge == maxEdge &&
        other.maxPixels == maxPixels;
  }

  @override
  int get hashCode => Object.hash(
    providerCacheKey,
    width,
    height,
    fit,
    allowUpscaling,
    maxEdge,
    maxPixels,
  );
}
