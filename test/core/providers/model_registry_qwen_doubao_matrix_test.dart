import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelRegistry Qwen / Doubao matrix', () {
    test('Qwen vision is precise for 3.7/3.8', () {
      final plus = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.7-plus', displayName: 'qwen3.7-plus'),
      );
      final flash = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.7-flash', displayName: 'qwen3.7-flash'),
      );
      final visionMax = ModelRegistry.infer(
        ModelInfo(
          id: 'qwen3.7-max-2026-06-08',
          displayName: 'qwen3.7-max-2026-06-08',
        ),
      );
      final plainMax = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.7-max', displayName: 'qwen3.7-max'),
      );
      final earlyMax = ModelRegistry.infer(
        ModelInfo(
          id: 'qwen3.7-max-2026-05-20',
          displayName: 'qwen3.7-max-2026-05-20',
        ),
      );
      final q38 = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.8-max', displayName: 'qwen3.8-max'),
      );

      expect(plus.input, contains(Modality.image));
      expect(flash.input, contains(Modality.image));
      expect(visionMax.input, contains(Modality.image));
      expect(q38.input, contains(Modality.image));
      expect(plainMax.input, isNot(contains(Modality.image)));
      expect(earlyMax.input, isNot(contains(Modality.image)));
      expect(plus.abilities, contains(ModelAbility.tool));
      expect(plus.abilities, contains(ModelAbility.reasoning));
    });

    test('DeepSeek vision SKU is multimodal; text V4 stays text-only', () {
      final vision = ModelRegistry.infer(
        ModelInfo(
          id: 'deepseek-v4-flash-vision-exp',
          displayName: 'deepseek-v4-flash-vision-exp',
        ),
      );
      final namespaced = ModelRegistry.infer(
        ModelInfo(
          id: 'deepseek/deepseek-v4-flash-vision-exp',
          displayName: 'deepseek/deepseek-v4-flash-vision-exp',
        ),
      );
      final flash = ModelRegistry.infer(
        ModelInfo(id: 'deepseek-v4-flash', displayName: 'deepseek-v4-flash'),
      );
      final pro = ModelRegistry.infer(
        ModelInfo(id: 'deepseek-v4-pro', displayName: 'deepseek-v4-pro'),
      );

      expect(vision.input, contains(Modality.image));
      expect(namespaced.input, contains(Modality.image));
      expect(flash.input, isNot(contains(Modality.image)));
      expect(pro.input, isNot(contains(Modality.image)));
      expect(vision.output, isNot(contains(Modality.image)));
      expect(
        vision.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
    });

    test('Doubao seed 2.x / evolving get vision tool reasoning', () {
      for (final id in const [
        'doubao-seed-2.0-pro',
        'doubao-seed-2-1-pro-260628',
        'doubao-seed-2.1-turbo',
        'doubao-seed-evolving',
      ]) {
        final model = ModelRegistry.infer(ModelInfo(id: id, displayName: id));
        expect(model.input, contains(Modality.image), reason: id);
        expect(model.abilities, contains(ModelAbility.tool), reason: id);
        expect(model.abilities, contains(ModelAbility.reasoning), reason: id);
      }
    });
  });
}
