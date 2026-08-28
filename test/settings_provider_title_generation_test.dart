import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider title generation', () {
    test('defaults title model to follow the current chat', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.titleModelProvider, isNull);
      expect(settings.titleModelId, isNull);
      expect(settings.isTitleGenerationEnabled, isTrue);
    });

    test('enables title generation after a model is selected', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setTitleModel('OpenAI', 'gpt-4o-mini');

      expect(settings.isTitleGenerationEnabled, isTrue);
      expect(settings.titleModelKey, 'OpenAI::gpt-4o-mini');
    });

    test('reset follows the current chat model', () async {
      final harness = await createBusinessTestHarness(
        initial: {'title_model_v1': 'OpenAI::gpt-4o-mini'},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      expect(settings.isTitleGenerationEnabled, isTrue);

      await settings.resetTitleModel();

      expect(settings.isTitleGenerationEnabled, isTrue);
      expect(settings.titleModelProvider, isNull);
      expect(settings.titleModelId, isNull);
      expect(harness.preferences.getString('title_model_v1'), isNull);
      expect(
        harness.preferences.getBool('title_generation_enabled_v1'),
        isTrue,
      );
    });

    test('can explicitly disable title generation', () async {
      final harness = await createBusinessTestHarness(
        initial: {'title_model_v1': 'OpenAI::gpt-4o-mini'},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.disableTitleGeneration();

      expect(settings.isTitleGenerationEnabled, isFalse);
      expect(settings.titleModelProvider, isNull);
      expect(settings.titleModelId, isNull);
      expect(
        harness.preferences.getBool('title_generation_enabled_v1'),
        isFalse,
      );
    });
  });
}
