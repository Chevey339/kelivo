import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/model_spec/model_defaults_guesser.dart';
import 'package:flutter_test/flutter_test.dart';

ModelGuess _guess(String id) => ModelDefaultsGuesser.guess(id);

void main() {
  group('ModelDefaultsGuesser Qwen / Doubao matrix', () {
    test('Qwen vision is precise for 3.7/3.8', () {
      final plus = _guess('qwen3.7-plus');
      final flash = _guess('qwen3.7-flash');
      final visionMax = _guess('qwen3.7-max-2026-06-08');
      final plainMax = _guess('qwen3.7-max');
      final earlyMax = _guess('qwen3.7-max-2026-05-20');
      final q38 = _guess('qwen3.8-max');
      final q38Flash = _guess('qwen3.8-flash');
      final q3827b = _guess('qwen3.8-27b');
      final q3824t = _guess('qwen3.8-2.4t-a95b');

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
      final flash = _guess('deepseek-flash');
      final namespaced = _guess('deepseek/deepseek-flash');
      final legacyFlash = _guess('deepseek-v4-flash');
      final legacyVision = _guess('deepseek-v4-flash-vision-exp');
      final pro = _guess('deepseek-v4-pro');

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
        final model = _guess(id);
        expect(model.input, contains(Modality.image), reason: id);
        expect(model.abilities, contains(ModelAbility.tool), reason: id);
        expect(model.abilities, contains(ModelAbility.reasoning), reason: id);
      }
    });

    test(
      'GPT-6 Astra, Muse 1.3 and GLM-5.3-Flash infer documented abilities',
      () {
        final astra = _guess('gpt-6-astra');
        final muse = _guess('muse-spark-1.3');
        final glmFlash = _guess('glm-5.3-flash');
        final glm53 = _guess('glm-5.3');

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
