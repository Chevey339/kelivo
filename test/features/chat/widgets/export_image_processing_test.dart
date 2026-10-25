import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:Kelivo/features/chat/utils/export_image_processor.dart';

Uint8List png(img.Format format, List<List<int>> pixels) {
  final image = img.Image(
    width: pixels.length,
    height: 1,
    format: format,
    numChannels: 4,
  );
  for (var x = 0; x < pixels.length; x++) {
    final p = pixels[x];
    image.setPixelRgba(x, 0, p[0], p[1], p[2], p[3]);
  }
  return img.encodePng(image);
}

void main() {
  test('16-bit iOS capture keeps color, antialiasing and alpha exactly', () {
    final pixels = [
      [32768, 32768, 32768, 65535],
      [10000, 40000, 60000, 65535],
      [1000, 2000, 3000, 32768],
      [65535, 0, 12345, 1],
    ];
    final slice = png(img.Format.uint16, pixels);
    final result = processExportImage(
      ExportImageProcessingRequest(
        outputWidth: 4,
        outputHeight: 2,
        slices: [(bytes: slice, y: 0), (bytes: slice, y: 1)],
        preparePreview: true,
      ),
    );
    final decoded = img.decodePng(result.pngBytes)!;
    expect(decoded.format, img.Format.uint16);
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < pixels.length; x++) {
        expect(decoded.getPixel(x, y).toList(), pixels[x]);
      }
    }
    expect(result.preview!.tiles.length, 2);
    expect(identical(result.preview!.tiles.first.bytes, slice), isTrue);
  });

  test(
    'mixed PNG depths promote 8-bit colors instead of truncating 16-bit',
    () {
      final a = png(img.Format.uint8, [
        [20, 40, 60, 128],
      ]);
      final b = png(img.Format.uint16, [
        [10000, 40000, 60000, 32768],
      ]);
      final result = stitchExportImage(1, 2, [
        (bytes: a, y: 0),
        (bytes: b, y: 1),
      ]);
      expect(result.getPixel(0, 0).toList(), [
        20 * 257,
        40 * 257,
        60 * 257,
        128 * 257,
      ]);
      expect(result.getPixel(0, 1).toList(), [10000, 40000, 60000, 32768]);
    },
  );

  test('16-bit blank trim applies the same alpha tolerance as 8-bit', () {
    final image = img.Image(
      width: 12,
      height: 16,
      format: img.Format.uint16,
      numChannels: 4,
    );
    image.clear(img.ColorUint16.rgba(10000, 20000, 30000, 1000));
    for (var y = 5; y < 10; y++) {
      for (var x = 4; x < 8; x++) {
        image.setPixelRgba(x, y, 40000, 50000, 60000, 65535);
      }
    }
    final result = processExportImage(
      ExportImageProcessingRequest(
        singlePngBytes: img.encodePng(image),
        preservePadding: 0,
        preparePreview: true,
      ),
    );
    final decoded = img.decodePng(result.pngBytes)!;
    expect((decoded.width, decoded.height), (4, 5));
    expect(decoded.getPixel(0, 0).toList(), [40000, 50000, 60000, 65535]);
    final preview = img.decodePng(result.preview!.tiles.single.bytes)!;
    expect(preview.toUint8List(), decoded.toUint8List());
  });

  test('clipped slices use row strides without resampling or seam loss', () {
    final src = img.Image(
      width: 5,
      height: 8,
      format: img.Format.uint16,
      numChannels: 4,
    );
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 5; x++) {
        src.setPixelRgba(x, y, x * 1000, y * 3000, 40000, 65535);
      }
    }
    final result = stitchExportImage(3, 5, [
      (bytes: img.encodePng(src), y: -2),
    ]);
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 3; x++) {
        expect(result.getPixel(x, y).toList(), src.getPixel(x, y + 2).toList());
      }
    }
  });

  test(
    'a broken slice fails the export instead of silently losing content',
    () {
      expect(
        () => stitchExportImage(2, 2, [(bytes: Uint8List(3), y: 0)]),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
