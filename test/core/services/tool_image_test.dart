import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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
