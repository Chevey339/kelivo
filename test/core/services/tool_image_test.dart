import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/tool_image.dart';

void main() {
  for (final orientation in [2, 6]) {
    test(
      'JPEG orientation $orientation is baked into encoded pixels',
      () async {
        final original = img.Image(width: 30, height: 20);
        img.fill(original, color: img.ColorRgb8(255, 0, 0));
        original.exif.imageIfd.orientation = orientation;
        final bytes = img.encodeJpg(original);
        expect(img.decodeJpgExif(bytes)!.imageIfd.orientation, orientation);

        final image = await ToolImage.fromBytes(bytes);
        final decoder = img.findDecoderForData(image.bytes)!;
        final encodedInfo = decoder.startDecode(image.bytes)!;
        final expectedSize = orientation == 6 ? (20, 30) : (30, 20);
        expect((image.width, image.height), expectedSize);
        expect((encodedInfo.width, encodedInfo.height), expectedSize);
        if (image.mime == 'image/jpeg') {
          expect(
            img.decodeJpgExif(image.bytes)?.imageIfd.orientation,
            anyOf(isNull, 1),
          );
        }
        expect((await ToolImage.fromBytes(image.bytes)).bytes, image.bytes);
      },
    );
  }

  test('remote animated WebP resizes the first frame', () async {
    final bytes = base64Decode(
      'UklGRoQAAABXRUJQVlA4WAoAAAACAAAAlwgAAQAAQU5JTQYAAAAAAAAAAABBTk1G'
      'KAAAAAAAAAAAAJcIAAEAAGQAAAJWUDhMDwAAAC+XSAAABxD9j/4HIqL/AQBBTk1G'
      'KAAAAAAAAAAAAJcIAAEAAGQAAABWUDhMDwAAAC+XSAAABxDR//4HIqL/AQA=',
    );
    expect(img.WebPDecoder().startDecode(bytes)!.numFrames, 2);
    final image = await ToolImage.fromNetworkBytes(bytes);
    final decoded = img.decodePng(image.bytes)!;
    expect((decoded.width, decoded.height), (ToolImage.maxLongEdge, 2));
    expect(decoded.numFrames, 1);
    expect(decoded.getPixel(0, 0).r, 255);
  });

  test('remote image decoding observes generation cancellation', () async {
    final bytes = img.encodePng(img.Image(width: 2, height: 2));
    final stop = Completer<void>();
    final cancellation = ToolCallCancellation(
      isCancelled: () => stop.isCompleted,
      cancelled: stop.future,
    );
    final decode = cancellation.run(() => ToolImage.fromNetworkBytes(bytes));
    final rejected = expectLater(decode, throwsStateError);
    stop.complete();
    await rejected;
    expect(cancellation.listenerCount, 0);
  });

  testWidgets('iOS background state skips native image decoding', (
    tester,
  ) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    final previousState =
        tester.binding.lifecycleState ?? AppLifecycleState.resumed;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final bytes = img.encodePng(img.Image(width: 2, height: 2));
      await expectLater(
        ToolImage.fromNetworkBytes(bytes),
        throwsA(
          isA<ToolImageException>().having(
            (error) => error.message,
            'message',
            contains('Return to Kelivo'),
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
      tester.binding.handleAppLifecycleStateChanged(previousState);
    }
  });

  test(
    'detailed images fit the byte budget without losing later replay',
    () async {
      final original = img.Image(width: 2000, height: 2000, numChannels: 4);
      final random = Random(47);
      for (final pixel in original) {
        pixel.setRgba(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
          255,
        );
      }
      final bytes = img.encodePng(original);
      expect(bytes.length, greaterThan(ToolImage.maxEncodedBytes));
      expect(bytes.length, lessThan(ToolImage.maxFileBytes));
      final image = await ToolImage.fromBytes(bytes);
      expect(image.mime, 'image/jpeg');
      expect(image.bytes.length, lessThanOrEqualTo(ToolImage.maxEncodedBytes));
      final decoded = img.decodeJpg(image.bytes)!;
      expect((decoded.width, decoded.height), (2000, 2000));
      expect((await ToolImage.fromBytes(image.bytes)).bytes, image.bytes);
    },
  );
}
