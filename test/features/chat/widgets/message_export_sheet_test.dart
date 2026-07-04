import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

import 'package:Cuplivo/features/chat/widgets/message_export_sheet.dart';

Uint8List _solidPng({
  required int width,
  required int height,
  required image_lib.Color color,
}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(color);
  return image_lib.encodePng(image);
}

Uint8List _rowIndexPng({required int width, required int height}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      image.setPixelRgba(x, y, 0, y, 0, 255);
    }
  }
  return image_lib.encodePng(image);
}

Uint8List _blankPaddedPng({
  required int width,
  required int height,
  required image_lib.Color background,
  required image_lib.Color content,
  required int contentLeft,
  required int contentTop,
  required int contentWidth,
  required int contentHeight,
}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(background);
  for (var y = contentTop; y < contentTop + contentHeight; y += 1) {
    for (var x = contentLeft; x < contentLeft + contentWidth; x += 1) {
      image.setPixel(x, y, content);
    }
  }
  return image_lib.encodePng(image);
}

void main() {
  testWidgets('export capture root keeps the captured theme', (tester) async {
    final exportTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    Color? capturedSurface;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: buildExportCaptureRootForTesting(
          theme: exportTheme,
          child: Builder(
            builder: (context) {
              capturedSurface = Theme.of(context).colorScheme.surface;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(capturedSurface, exportTheme.colorScheme.surface);
  });

  testWidgets('export viewport root captures a shifted slice', (tester) async {
    final exportTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: buildExportCaptureViewportRootForTesting(
          theme: exportTheme,
          width: 80,
          viewportHeight: 40,
          contentHeight: 120,
          offsetY: 40,
          child: Column(
            children: const [
              SizedBox(
                width: 80,
                height: 40,
                child: ColoredBox(color: Colors.red),
              ),
              SizedBox(
                width: 80,
                height: 40,
                child: ColoredBox(color: Colors.green),
              ),
              SizedBox(
                width: 80,
                height: 40,
                child: ColoredBox(color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final overflowBox = tester.widget<OverflowBox>(find.byType(OverflowBox));
    final transform = tester.widget<Transform>(find.byType(Transform));

    expect(overflowBox.minHeight, 120);
    expect(overflowBox.maxHeight, 120);
    expect(transform.transform.getTranslation().y, -40);
  });

  test('desktop export image config keeps enough source pixels for text', () {
    final config = exportImageRenderConfigForTesting(isDesktop: true);

    expect(config.width * config.pixelRatio, greaterThanOrEqualTo(2160));
    expect(config.pixelRatio, greaterThanOrEqualTo(3.0));
  });

  test('export capture keeps medium-long images on the whole-capture path', () {
    expect(
      shouldUseFullExportCaptureForTesting(
        logicalSize: const Size(480, 2665),
        pixelRatio: 3,
      ),
      isTrue,
    );
    expect(
      exportFullCapturePixelRatioForTesting(
        logicalSize: const Size(480, 2665),
        requestedPixelRatio: 3,
      ),
      3,
    );
  });

  test('export capture downscales very long whole captures before slicing', () {
    final pixelRatio = exportFullCapturePixelRatioForTesting(
      logicalSize: const Size(480, 7537),
      requestedPixelRatio: 3,
    );

    expect(pixelRatio, isNotNull);
    expect(pixelRatio!, closeTo(15360 / 7537, 0.0001));
    expect(
      shouldUseFullExportCaptureForTesting(
        logicalSize: const Size(480, 8000),
        pixelRatio: 3,
      ),
      isFalse,
    );
  });

  test('export capture slice height stays on logical pixel boundaries', () {
    final logicalHeight = exportCaptureSliceLogicalHeightForTesting(
      pixelRatio: 3,
    );

    expect(logicalHeight, 1365);
    expect(logicalHeight * 3, lessThanOrEqualTo(4096));
  });

  test('export image stitching keeps bottom slice content', () {
    final pngBytes = stitchExportPngSlicesForTesting(
      outputWidth: 20,
      outputHeight: 4136,
      slices: [
        (
          bytes: _solidPng(
            width: 20,
            height: 4096,
            color: image_lib.ColorRgba8(255, 0, 0, 255),
          ),
          y: 0,
        ),
        (
          bytes: _solidPng(
            width: 20,
            height: 40,
            color: image_lib.ColorRgba8(0, 255, 0, 255),
          ),
          y: 4096,
        ),
      ],
    );

    final image = image_lib.decodePng(pngBytes);
    expect(image, isNotNull);
    expect(image!.width, 20);
    expect(image.height, 4136);

    final topPixel = image.getPixel(10, 20);
    expect(topPixel.r, greaterThan(topPixel.g));

    final bottomPixel = image.getPixel(10, 4116);
    expect(bottomPixel.g, greaterThan(bottomPixel.r));
  });

  test(
    'export image stitching crops slices that extend past output height',
    () {
      final pngBytes = stitchExportPngSlicesForTesting(
        outputWidth: 20,
        outputHeight: 100,
        slices: [
          (
            bytes: _solidPng(
              width: 20,
              height: 80,
              color: image_lib.ColorRgba8(255, 0, 0, 255),
            ),
            y: 0,
          ),
          (
            bytes: _solidPng(
              width: 20,
              height: 21,
              color: image_lib.ColorRgba8(0, 255, 0, 255),
            ),
            y: 80,
          ),
        ],
      );

      final image = image_lib.decodePng(pngBytes);
      expect(image, isNotNull);
      expect(image!.width, 20);
      expect(image.height, 100);

      final lastPixel = image.getPixel(10, 99);
      expect(lastPixel.g, greaterThan(lastPixel.r));
    },
  );

  test('export image stitching crops without vertical resampling', () {
    final pngBytes = stitchExportPngSlicesForTesting(
      outputWidth: 2,
      outputHeight: 20,
      slices: [(bytes: _rowIndexPng(width: 2, height: 21), y: 0)],
    );

    final image = image_lib.decodePng(pngBytes);
    expect(image, isNotNull);
    expect(image!.height, 20);
    for (var y = 0; y < 20; y += 1) {
      expect(image.getPixel(1, y).g, y);
    }
  });

  test('export image blank trim removes opaque outer padding', () {
    final pngBytes = _blankPaddedPng(
      width: 12,
      height: 24,
      background: image_lib.ColorRgba8(255, 255, 255, 255),
      content: image_lib.ColorRgba8(255, 0, 0, 255),
      contentLeft: 4,
      contentTop: 9,
      contentWidth: 3,
      contentHeight: 4,
    );

    final trimmed = trimExportPngBlankPaddingForTesting(
      pngBytes,
      preservePadding: 2,
    );

    final image = image_lib.decodePng(trimmed);
    expect(image, isNotNull);
    expect(image!.width, 7);
    expect(image.height, 8);
    final contentPixel = image.getPixel(3, 3);
    expect(contentPixel.r, greaterThan(contentPixel.g));
  });

  test('export image blank trim removes transparent outer padding', () {
    final pngBytes = _blankPaddedPng(
      width: 10,
      height: 18,
      background: image_lib.ColorRgba8(0, 0, 0, 0),
      content: image_lib.ColorRgba8(0, 255, 0, 255),
      contentLeft: 2,
      contentTop: 7,
      contentWidth: 5,
      contentHeight: 3,
    );

    final trimmed = trimExportPngBlankPaddingForTesting(
      pngBytes,
      preservePadding: 1,
    );

    final image = image_lib.decodePng(trimmed);
    expect(image, isNotNull);
    expect(image!.width, 7);
    expect(image.height, 5);
    final contentPixel = image.getPixel(2, 2);
    expect(contentPixel.g, greaterThan(contentPixel.r));
  });

  test(
    'captured export png processing trims a single capture asynchronously',
    () async {
      final pngBytes = _blankPaddedPng(
        width: 12,
        height: 24,
        background: image_lib.ColorRgba8(255, 255, 255, 255),
        content: image_lib.ColorRgba8(0, 0, 255, 255),
        contentLeft: 4,
        contentTop: 9,
        contentWidth: 3,
        contentHeight: 4,
      );

      final trimmed = await processCapturedExportPngForTesting(
        singlePngBytes: pngBytes,
        preservePadding: 2,
      );

      final image = image_lib.decodePng(trimmed);
      expect(image, isNotNull);
      expect(image!.width, 7);
      expect(image.height, 8);
      final contentPixel = image.getPixel(3, 3);
      expect(contentPixel.b, greaterThan(contentPixel.r));
    },
  );

  test(
    'captured export png processing stitches slices asynchronously',
    () async {
      final pngBytes = await processCapturedExportPngForTesting(
        outputWidth: 8,
        outputHeight: 14,
        slices: [
          (
            bytes: _blankPaddedPng(
              width: 8,
              height: 8,
              background: image_lib.ColorRgba8(0, 0, 0, 0),
              content: image_lib.ColorRgba8(255, 0, 0, 255),
              contentLeft: 2,
              contentTop: 2,
              contentWidth: 4,
              contentHeight: 4,
            ),
            y: 0,
          ),
          (
            bytes: _blankPaddedPng(
              width: 8,
              height: 6,
              background: image_lib.ColorRgba8(0, 0, 0, 0),
              content: image_lib.ColorRgba8(0, 255, 0, 255),
              contentLeft: 2,
              contentTop: 0,
              contentWidth: 4,
              contentHeight: 4,
            ),
            y: 8,
          ),
        ],
        preservePadding: 0,
      );

      final image = image_lib.decodePng(pngBytes);
      expect(image, isNotNull);
      expect(image!.width, 4);
      expect(image.height, 10);
      expect(image.getPixel(2, 0).r, greaterThan(image.getPixel(2, 0).g));
      expect(image.getPixel(2, 9).g, greaterThan(image.getPixel(2, 9).r));
    },
  );
}
