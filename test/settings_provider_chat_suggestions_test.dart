import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider chat suggestions', () {
    test('defaults suggestion model to disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.suggestionModelProvider, isNull);
      expect(settings.suggestionModelId, isNull);
      expect(settings.suggestionModelKey, isNull);
      expect(
        settings.suggestionPrompt,
        SettingsProvider.defaultSuggestionPrompt,
      );
    });

    test('persists selected suggestion model and prompt', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setSuggestionModel('OpenAI', 'gpt-test');
      await settings.setSuggestionPrompt('Custom {content} {locale}');

      expect(settings.suggestionModelProvider, 'OpenAI');
      expect(settings.suggestionModelId, 'gpt-test');
      expect(settings.suggestionModelKey, 'OpenAI::gpt-test');
      expect(settings.suggestionPrompt, 'Custom {content} {locale}');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('suggestion_model_v1'), 'OpenAI::gpt-test');
      expect(
        prefs.getString('suggestion_prompt_v1'),
        'Custom {content} {locale}',
      );
    });

    test(
      'clears suggestion model when provider selection is cleared',
      () async {
        SharedPreferences.setMockInitialValues({
          'suggestion_model_v1': 'OpenAI::gpt-test',
        });
        final settings = SettingsProvider();

        await _waitForSettingsLoad();
        await settings.clearSelectionsForProvider('OpenAI');

        expect(settings.suggestionModelProvider, isNull);
        expect(settings.suggestionModelId, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('suggestion_model_v1'), isNull);
      },
    );
  });
}
