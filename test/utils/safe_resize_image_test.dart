import 'dart:typed_data';

import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeSafeResizeTarget contain', () {
    test('keeps both axes at least 1 for extreme ratios', () {
      final wide = computeSafeResizeTarget(
        intrinsicWidth: 10000,
        intrinsicHeight: 1,
        boxWidth: 720,
        boxHeight: 720,
        fit: SafeResizeFit.contain,
      );
      expect(wide.width, greaterThanOrEqualTo(1));
      expect(wide.height, greaterThanOrEqualTo(1));
      expect(wide.width, 720);
      expect(wide.height, 1);

      final tall = computeSafeResizeTarget(
        intrinsicWidth: 1,
        intrinsicHeight: 10000,
        boxWidth: 720,
        boxHeight: 720,
        fit: SafeResizeFit.contain,
      );
      expect(tall.width, 1);
      expect(tall.height, 720);
    });

    test('never returns the uncapped original for a 17k source', () {
      final target = computeSafeResizeTarget(
        intrinsicWidth: 17277,
        intrinsicHeight: 11457,
        boxWidth: 720,
        boxHeight: 360,
        fit: SafeResizeFit.contain,
        maxEdge: 4096,
        maxPixels: 12 * 1024 * 1024,
      );
      expect(target.width, lessThan(17277));
      expect(target.height, lessThan(11457));
      expect(target.width * target.height, lessThanOrEqualTo(12 * 1024 * 1024));
    });
  });

  group('computeSafeResizeTarget cover', () {
    test('4:1 panorama decodes a crop at least as large as the box', () {
      final target = computeSafeResizeTarget(
        intrinsicWidth: 4000,
        intrinsicHeight: 1000,
        boxWidth: 336,
        boxHeight: 336,
        fit: SafeResizeFit.cover,
      );
      expect(target.height, 336);
      expect(target.width, 1344);
    });

    test('1:4 portrait decodes a crop at least as large as the box', () {
      final target = computeSafeResizeTarget(
        intrinsicWidth: 1000,
        intrinsicHeight: 4000,
        boxWidth: 336,
        boxHeight: 336,
        fit: SafeResizeFit.cover,
      );
      expect(target.width, 336);
      expect(target.height, 1344);
    });

    test('square source matches the box', () {
      final target = computeSafeResizeTarget(
        intrinsicWidth: 2000,
        intrinsicHeight: 2000,
        boxWidth: 336,
        boxHeight: 336,
        fit: SafeResizeFit.cover,
      );
      expect(target.width, 336);
      expect(target.height, 336);
    });

    test('image smaller than the box is not upscaled', () {
      final target = computeSafeResizeTarget(
        intrinsicWidth: 80,
        intrinsicHeight: 80,
        boxWidth: 336,
        boxHeight: 336,
        fit: SafeResizeFit.cover,
        allowUpscaling: false,
      );
      expect(target.width, 80);
      expect(target.height, 80);
    });

    test('extreme cover still respects the pixel budget', () {
      final target = computeSafeResizeTarget(
        intrinsicWidth: 20000,
        intrinsicHeight: 10,
        boxWidth: 336,
        boxHeight: 336,
        fit: SafeResizeFit.cover,
        maxPixels: 2097152,
      );
      expect(target.width, greaterThanOrEqualTo(1));
      expect(target.height, greaterThanOrEqualTo(1));
      expect(target.width * target.height, lessThanOrEqualTo(2097152));
    });
  });

  test('cache key includes provider, size, policy, and allowUpscaling', () {
    final inner = MemoryImage(Uint8List.fromList([1, 2, 3]));
    final a = SafeResizeImage(
      inner,
      width: 100,
      height: 80,
      fit: SafeResizeFit.contain,
      allowUpscaling: false,
    );
    final same = SafeResizeImage(
      inner,
      width: 100,
      height: 80,
      fit: SafeResizeFit.contain,
      allowUpscaling: false,
    );
    final otherFit = SafeResizeImage(
      inner,
      width: 100,
      height: 80,
      fit: SafeResizeFit.cover,
      allowUpscaling: false,
    );
    final otherScale = SafeResizeImage(
      inner,
      width: 100,
      height: 80,
      fit: SafeResizeFit.contain,
      allowUpscaling: true,
    );
    final otherSize = SafeResizeImage(
      inner,
      width: 120,
      height: 80,
      fit: SafeResizeFit.contain,
      allowUpscaling: false,
    );

    expect(a, same);
    expect(a, isNot(otherFit));
    expect(a, isNot(otherScale));
    expect(a, isNot(otherSize));
  });

  test('clampDecodedPixelSize floors then stays under the pixel budget', () {
    const maxPixels = 12 * 1024 * 1024;
    final overIfRounded = clampDecodedPixelSize(
      width: 3546.6,
      height: 3546.6,
      maxPixels: maxPixels,
    );
    expect(overIfRounded.width, greaterThanOrEqualTo(1));
    expect(overIfRounded.height, greaterThanOrEqualTo(1));
    expect(
      overIfRounded.width * overIfRounded.height,
      lessThanOrEqualTo(maxPixels),
    );
  });

  testWidgets('async obtainKey failure reaches errorBuilder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Image(
          image: SafeResizeImage(
            _AsyncFailingKeyProvider(),
            width: 32,
            height: 32,
          ),
          errorBuilder: (_, __, ___) => const Text('decode-error'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('decode-error'), findsOneWidget);
  });

  test('wrap rejects non Network/File/Memory providers in all modes', () {
    expect(
      () => SafeResizeImage.wrap(
        _AsyncFailingKeyProvider(),
        width: 16,
        height: 16,
      ),
      throwsA(isA<FlutterError>()),
    );
    expect(
      () => SafeResizeImage.wrap(
        ResizeImage(MemoryImage(Uint8List.fromList([1, 2, 3])), width: 8),
        width: 16,
        height: 16,
      ),
      throwsA(isA<FlutterError>()),
    );
    expect(
      SafeResizeImage.wrap(
        MemoryImage(Uint8List.fromList([1, 2, 3])),
        width: 16,
        height: 16,
      ),
      isA<SafeResizeImage>(),
    );
  });

  test('core constructor still accepts a custom provider for tests', () {
    final wrapped = SafeResizeImage(
      _AsyncFailingKeyProvider(),
      width: 16,
      height: 16,
    );
    expect(wrapped.imageProvider, isA<_AsyncFailingKeyProvider>());
  });

  test('wrapping ResizeImage is rejected in debug', () {
    expect(
      () {
        final wrapped = SafeResizeImage(
          ResizeImage(MemoryImage(Uint8List.fromList([1, 2, 3])), width: 8),
          width: 16,
          height: 16,
        );
        wrapped.loadImage(
          const SafeResizeImageKey(
            providerCacheKey: 'k',
            width: 16,
            height: 16,
            fit: SafeResizeFit.contain,
            allowUpscaling: false,
            maxEdge: null,
            maxPixels: null,
          ),
          (buffer, {getTargetSize}) {
            throw StateError('unused');
          },
        );
      },
      throwsA(isA<FlutterError>()),
    );
  });
}

class _AsyncFailingKeyProvider extends ImageProvider<_AsyncFailingKeyProvider> {
  @override
  Future<_AsyncFailingKeyProvider> obtainKey(ImageConfiguration configuration) {
    return Future<_AsyncFailingKeyProvider>.delayed(
      Duration.zero,
      () => throw StateError('key-failed'),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    _AsyncFailingKeyProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError('should-not-load')),
    );
  }
}
