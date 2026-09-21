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
      final q38Flash = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.8-flash', displayName: 'qwen3.8-flash'),
      );
      final q3827b = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.8-27b', displayName: 'qwen3.8-27b'),
      );
      final q3824t = ModelRegistry.infer(
        ModelInfo(id: 'qwen3.8-2.4t-a95b', displayName: 'qwen3.8-2.4t-a95b'),
      );

      expect(plus.input, contains(Modality.image));
      expect(flash.input, contains(Modality.image));
      expect(visionMax.input, contains(Modality.image));
      expect(q38.input, contains(Modality.image));
      expect(q38Flash.input, contains(Modality.image));
      expect(q3827b.input, contains(Modality.image));
      expect(q3824t.input, isNot(contains(Modality.image)));
      expect(plainMax.input, isNot(contains(Modality.image)));
      expect(earlyMax.input, isNot(contains(Modality.image)));
      expect(plus.abilities, contains(ModelAbility.tool));
      expect(plus.abilities, contains(ModelAbility.reasoning));
    });

    test('DeepSeek Flash is multimodal; V4 Pro stays text-only', () {
      final flash = ModelRegistry.infer(
        ModelInfo(id: 'deepseek-flash', displayName: 'deepseek-flash'),
      );
      final namespaced = ModelRegistry.infer(
        ModelInfo(
          id: 'deepseek/deepseek-flash',
          displayName: 'deepseek/deepseek-flash',
        ),
      );
      final legacyFlash = ModelRegistry.infer(
        ModelInfo(id: 'deepseek-v4-flash', displayName: 'deepseek-v4-flash'),
      );
      final legacyVision = ModelRegistry.infer(
        ModelInfo(
          id: 'deepseek-v4-flash-vision-exp',
          displayName: 'deepseek-v4-flash-vision-exp',
        ),
      );
      final pro = ModelRegistry.infer(
        ModelInfo(id: 'deepseek-v4-pro', displayName: 'deepseek-v4-pro'),
      );

      expect(flash.input, contains(Modality.image));
      expect(namespaced.input, contains(Modality.image));
      expect(legacyFlash.input, contains(Modality.image));
      expect(legacyVision.input, contains(Modality.image));
      expect(pro.input, isNot(contains(Modality.image)));
      expect(flash.output, isNot(contains(Modality.image)));
      expect(
        flash.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
      expect(
        pro.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
    });

    test('Doubao seed 2.x / evolving get vision tool reasoning', () {
      for (final id in const [
        'doubao-seed-2.0-pro',
        'doubao-seed-2.0-code',
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

    test(
      'GPT-6 Astra, Muse 1.3 and GLM-5.3-Flash infer documented abilities',
      () {
        final astra = ModelRegistry.infer(
          ModelInfo(id: 'gpt-6-astra', displayName: 'gpt-6-astra'),
        );
        final muse = ModelRegistry.infer(
          ModelInfo(id: 'muse-spark-1.3', displayName: 'muse-spark-1.3'),
        );
        final glmFlash = ModelRegistry.infer(
          ModelInfo(id: 'glm-5.3-flash', displayName: 'glm-5.3-flash'),
        );
        final glm53 = ModelRegistry.infer(
          ModelInfo(id: 'glm-5.3', displayName: 'glm-5.3'),
        );

        expect(astra.input, contains(Modality.image));
        expect(
          astra.abilities,
          containsAll([ModelAbility.tool, ModelAbility.reasoning]),
        );
        expect(muse.input, contains(Modality.image));
        expect(
          muse.abilities,
          containsAll([ModelAbility.tool, ModelAbility.reasoning]),
        );
        expect(glmFlash.input, contains(Modality.image));
        expect(
          glmFlash.abilities,
          containsAll([ModelAbility.tool, ModelAbility.reasoning]),
        );
        expect(glm53.input, isNot(contains(Modality.image)));
        expect(
          glm53.abilities,
          containsAll([ModelAbility.tool, ModelAbility.reasoning]),
        );
      },
    );
  });
}
