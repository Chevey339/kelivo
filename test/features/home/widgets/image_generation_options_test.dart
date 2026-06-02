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
  });
}
