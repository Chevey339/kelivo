import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider edit-assistant keep cards toggle', () {
    test('defaults to disabled so edits drop thinking and tool cards', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.keepThinkingAndToolCardsWhenEditingAssistant, isFalse);
    });

    test('loads persisted enabled value', () async {
      final harness = await createBusinessTestHarness(
        initial: {'chat_edit_assistant_keep_thinking_tool_cards_v1': true},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.keepThinkingAndToolCardsWhenEditingAssistant, isTrue);
    });

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setKeepThinkingAndToolCardsWhenEditingAssistant(true);

      expect(settings.keepThinkingAndToolCardsWhenEditingAssistant, isTrue);
      final prefs = harness.preferences;
      expect(
        prefs.getBool('chat_edit_assistant_keep_thinking_tool_cards_v1'),
        isTrue,
      );
    });
  });
}
