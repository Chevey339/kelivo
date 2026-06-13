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

  group('SettingsProvider title generation options', () {
    test('default values are correct', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await _waitForSettingsLoad();

      expect(settings.titleDisableThinking, false);
      expect(settings.titleUseSystemPrompt, true);
      expect(settings.titleUseEmoji, false);
    });

    test('titleDisableThinking can be set and persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await _waitForSettingsLoad();

      await settings.setTitleDisableThinking(true);
      expect(settings.titleDisableThinking, true);

      await settings.setTitleDisableThinking(false);
      expect(settings.titleDisableThinking, false);
    });

    test('titleUseSystemPrompt can be set and persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await _waitForSettingsLoad();

      await settings.setTitleUseSystemPrompt(false);
      expect(settings.titleUseSystemPrompt, false);

      await settings.setTitleUseSystemPrompt(true);
      expect(settings.titleUseSystemPrompt, true);
    });

    test('titleUseEmoji can be set and persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      await _waitForSettingsLoad();

      await settings.setTitleUseEmoji(true);
      expect(settings.titleUseEmoji, true);

      await settings.setTitleUseEmoji(false);
      expect(settings.titleUseEmoji, false);
    });

    test(
      'titleUseEmoji can be toggled independently of titleUseSystemPrompt',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider();
        await _waitForSettingsLoad();

        await settings.setTitleUseSystemPrompt(false);
        await settings.setTitleUseEmoji(true);
        expect(settings.titleUseEmoji, true);
        expect(settings.titleUseSystemPrompt, false);
      },
    );

    test('values survive SharedPreferences reload', () async {
      SharedPreferences.setMockInitialValues({});
      final s1 = SettingsProvider();
      await _waitForSettingsLoad();

      await s1.setTitleDisableThinking(true);
      await s1.setTitleUseSystemPrompt(false);
      await s1.setTitleUseEmoji(true);

      final s2 = SettingsProvider();
      await _waitForSettingsLoad();

      expect(s2.titleDisableThinking, true);
      expect(s2.titleUseSystemPrompt, false);
      expect(s2.titleUseEmoji, true);
    });
  });

  group('defaultTitlePromptWithEmoji', () {
    test('contains the emoji rule appended to defaultTitlePrompt', () {
      final withEmoji = SettingsProvider.defaultTitlePromptWithEmoji;
      expect(withEmoji, startsWith(SettingsProvider.defaultTitlePrompt));
      expect(withEmoji, contains('single appropriate emoji'));
      expect(withEmoji, contains('followed by a space'));
      expect(
        withEmoji.length,
        greaterThan(SettingsProvider.defaultTitlePrompt.length),
      );
    });
  });

  group('buildTitleGenerationConfig', () {
    const locale = 'en-US';
    const content = 'User: hello\n\nAssistant: hi there';

    test(
      'system default without emoji uses defaultTitlePrompt and keeps budget',
      () {
        final (prompt, budget) = SettingsProvider.buildTitleGenerationConfig(
          useSystemPrompt: true,
          useEmoji: false,
          disableThinking: false,
          customPrompt: 'custom',
          existingBudget: 2048,
          locale: locale,
          content: content,
        );

        expect(prompt, contains('summarize the conversation'));
        expect(prompt, contains(locale));
        expect(prompt, contains(content));
        expect(prompt, isNot(contains('single appropriate emoji')));
        expect(budget, 2048);
      },
    );

    test('system default with emoji uses defaultTitlePromptWithEmoji', () {
      final (prompt, budget) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: true,
        useEmoji: true,
        disableThinking: false,
        customPrompt: 'custom',
        existingBudget: 2048,
        locale: locale,
        content: content,
      );

      expect(prompt, contains('single appropriate emoji'));
      expect(prompt, contains(locale));
      expect(prompt, contains(content));
      expect(budget, 2048);
    });

    test('custom prompt uses the provided customPrompt', () {
      const custom = 'Custom title prompt for {locale}: {content}';
      final (prompt, budget) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: false,
        useEmoji: false,
        disableThinking: false,
        customPrompt: custom,
        existingBudget: 4096,
        locale: locale,
        content: content,
      );

      expect(prompt, 'Custom title prompt for $locale: $content');
      expect(budget, 4096);
    });

    test('custom prompt with emoji flag true still ignores emoji', () {
      const custom = 'My custom prompt {locale} {content}';
      final (prompt, _) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: false,
        useEmoji: true,
        disableThinking: false,
        customPrompt: custom,
        existingBudget: 2048,
        locale: locale,
        content: content,
      );

      expect(prompt, isNot(contains('single appropriate emoji')));
    });

    test('disableThinking true nullifies the budget', () {
      final (_, budget) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: true,
        useEmoji: false,
        disableThinking: true,
        customPrompt: 'custom',
        existingBudget: 2048,
        locale: locale,
        content: content,
      );

      expect(budget, 0);
    });

    test('disableThinking false preserves the existing budget', () {
      final (_, budget) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: true,
        useEmoji: false,
        disableThinking: false,
        customPrompt: 'custom',
        existingBudget: 8192,
        locale: locale,
        content: content,
      );

      expect(budget, 8192);
    });

    test('disableThinking true returns 0 regardless of existingBudget', () {
      final (_, budget) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: true,
        useEmoji: false,
        disableThinking: true,
        customPrompt: 'custom',
        existingBudget: null,
        locale: locale,
        content: content,
      );

      expect(budget, 0);
    });

    test('handles empty content gracefully', () {
      final (prompt, _) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: true,
        useEmoji: false,
        disableThinking: false,
        customPrompt: '',
        existingBudget: 2048,
        locale: locale,
        content: '',
      );

      expect(prompt, contains('summarize the conversation'));
      expect(prompt, contains(locale));
    });

    test('handles empty locale gracefully', () {
      final (prompt, _) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: true,
        useEmoji: false,
        disableThinking: false,
        customPrompt: '',
        existingBudget: 2048,
        locale: '',
        content: content,
      );

      expect(prompt, contains('summarize the conversation'));
      expect(prompt, contains(content));
    });

    test('empty custom prompt in custom mode still produces a prompt', () {
      final (prompt, _) = SettingsProvider.buildTitleGenerationConfig(
        useSystemPrompt: false,
        useEmoji: false,
        disableThinking: false,
        customPrompt: '',
        existingBudget: 2048,
        locale: locale,
        content: content,
      );

      expect(prompt, '');
    });
  });
}
