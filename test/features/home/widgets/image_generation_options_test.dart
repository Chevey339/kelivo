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

    test('restoreFromBody falls back to dynamic defaults', () {
      final controller = ImageGenerationOptionsController()
        ..applyDefaultsFromBody(const {
          'quality': 'medium',
          'output_format': 'webp',
        })
        ..quality = 'low'
        ..sizeTier = '4K'
        ..aspectRatio = '16:9'
        ..outputCompression = 90
        ..count = 4;

      controller.restoreFromBody({'n': 2});

      expect(controller.quality, 'medium');
      expect(controller.resolvedSize, 'auto');
      expect(controller.outputFormat, 'webp');
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

    test('applyDefaultsFromBody updates baseline without forcing overrides', () {
      final controller = ImageGenerationOptionsController();

      controller.applyDefaultsFromBody(const {
        'quality': 'medium',
        'output_format': 'webp',
      });

      expect(controller.quality, 'medium');
      expect(controller.outputFormat, 'webp');
      expect(controller.customized, isFalse);
      expect(controller.toExtraBody(), isEmpty);
    });

    test('applyDefaultsFromBody keeps user customizations intact', () {
      final controller = ImageGenerationOptionsController()
        ..quality = 'low'
        ..count = 3;

      controller.applyDefaultsFromBody(const {
        'quality': 'medium',
        'output_format': 'webp',
      });

      expect(controller.quality, 'low');
      expect(controller.count, 3);
      expect(controller.toExtraBody(), {
        'quality': 'low',
        'n': 3,
      });
    });

    test('toExtraBody can clear provider size defaults back to auto', () {
      final controller = ImageGenerationOptionsController()
        ..applyDefaultsFromBody(const {'size': '3840x2160'});

      controller.sizeTier = 'auto';
      controller.aspectRatio = 'auto';

      expect(controller.toExtraBody(), {
        'size': null,
      });
    });

    test('toExtraBody clears inherited compression when switching back to png', () {
      final controller = ImageGenerationOptionsController()
        ..applyDefaultsFromBody(const {
          'output_format': 'webp',
          'output_compression': 80,
        });

      controller.outputFormat = 'png';
      controller.outputCompression = null;

      expect(controller.toExtraBody(), {
        'output_format': 'png',
        'output_compression': null,
      });
    });
  });
}
