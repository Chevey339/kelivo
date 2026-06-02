import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/home/widgets/image_generation_options.dart';

void main() {
  group('ImageGenerationOptionsController', () {
    test('toExtraBody omits unchanged quality and format defaults', () {
      final controller = ImageGenerationOptionsController()
        ..sizeTier = '4K'
        ..aspectRatio = '16:9'
        ..count = 2;

      expect(controller.toExtraBody(), {
        'size': '3840x2160',
        'n': 2,
      });
    });

    test('toExtraBody includes quality and format when customized', () {
      final controller = ImageGenerationOptionsController()
        ..quality = 'medium'
        ..outputFormat = 'webp'
        ..outputCompression = 80;

      expect(controller.toExtraBody(), {
        'quality': 'medium',
        'output_format': 'webp',
        'output_compression': 80,
      });
    });

    test('restoreFromBody resets stale values before applying partial body', () {
      final controller = ImageGenerationOptionsController()
        ..quality = 'medium'
        ..sizeTier = '4K'
        ..aspectRatio = '16:9'
        ..outputFormat = 'webp'
        ..outputCompression = 80
        ..count = 4;

      controller.restoreFromBody({'n': 2});

      expect(controller.quality, 'high');
      expect(controller.resolvedSize, 'auto');
      expect(controller.outputFormat, 'png');
      expect(controller.outputCompression, isNull);
      expect(controller.count, 2);
    });

    test('restoreFromBody with empty body restores defaults', () {
      final controller = ImageGenerationOptionsController()
        ..quality = 'low'
        ..sizeTier = '2K'
        ..aspectRatio = '1:1'
        ..outputFormat = 'jpeg'
        ..outputCompression = 60
        ..count = 3;

      controller.restoreFromBody(const <String, dynamic>{});

      expect(controller.customized, isFalse);
      expect(controller.toExtraBody(), isEmpty);
    });
  });
}
