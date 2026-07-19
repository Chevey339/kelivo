import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider chat suggestions', () {
    test('defaults suggestion model to disabled', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.suggestionModelProvider, isNull);
      expect(settings.suggestionModelId, isNull);
      expect(settings.suggestionModelKey, isNull);
      expect(
        settings.suggestionPrompt,
        SettingsProvider.defaultSuggestionPrompt,
      );
    });

    test('persists selected suggestion model and prompt', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setSuggestionModel('OpenAI', 'gpt-test');
      await settings.setSuggestionPrompt('Custom {content} {locale}');

      expect(settings.suggestionModelProvider, 'OpenAI');
      expect(settings.suggestionModelId, 'gpt-test');
      expect(settings.suggestionModelKey, 'OpenAI::gpt-test');
      expect(settings.suggestionPrompt, 'Custom {content} {locale}');

      final prefs = harness.preferences;
      expect(prefs.getString('suggestion_model_v1'), 'OpenAI::gpt-test');
      expect(
        prefs.getString('suggestion_prompt_v1'),
        'Custom {content} {locale}',
      );
    });

    test('defaults suggestion tap to auto-send', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.insertSuggestionOnTapOnly, isFalse);
    });

    test('loads and persists insert-only suggestion tap mode', () async {
      final harness = await createBusinessTestHarness(
        initial: {'suggestion_insert_on_tap_only_v1': true},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.insertSuggestionOnTapOnly, isTrue);

      await settings.setInsertSuggestionOnTapOnly(false);

      expect(settings.insertSuggestionOnTapOnly, isFalse);
      final prefs = harness.preferences;
      expect(prefs.getBool('suggestion_insert_on_tap_only_v1'), isFalse);
    });

    test(
      'clears suggestion model when provider selection is cleared',
      () async {
        final harness = await createBusinessTestHarness(
          initial: {'suggestion_model_v1': 'OpenAI::gpt-test'},
        );
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;
        await settings.clearSelectionsForProvider('OpenAI');

        expect(settings.suggestionModelProvider, isNull);
        expect(settings.suggestionModelId, isNull);
        final prefs = harness.preferences;
        expect(prefs.getString('suggestion_model_v1'), isNull);
      },
    );
  });
}
