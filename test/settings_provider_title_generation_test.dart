import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider title generation', () {
    test('defaults title model to disabled', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.titleModelProvider, isNull);
      expect(settings.titleModelId, isNull);
      expect(settings.isTitleGenerationEnabled, isFalse);
    });

    test('enables title generation after a model is selected', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setTitleModel('OpenAI', 'gpt-4o-mini');

      expect(settings.isTitleGenerationEnabled, isTrue);
      expect(settings.titleModelKey, 'OpenAI::gpt-4o-mini');
    });

    test('disables title generation when the model is reset', () async {
      final harness = await createBusinessTestHarness(
        initial: {'title_model_v1': 'OpenAI::gpt-4o-mini'},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      expect(settings.isTitleGenerationEnabled, isTrue);

      await settings.resetTitleModel();

      expect(settings.isTitleGenerationEnabled, isFalse);
      expect(harness.preferences.getString('title_model_v1'), isNull);
    });
  });
}
