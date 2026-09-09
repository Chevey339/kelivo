import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider show thinking and tool cards', () {
    test('defaults to visible', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.showThinkingCards, isTrue);
      expect(settings.showToolCards, isTrue);
    });

    test(
      'produced files visibility persists, notifies and survives copying',
      () async {
        final harness = await createBusinessTestHarness(initial: {});
        final settings = SettingsProvider(harness.preferences);
        addTearDown(settings.dispose);
        await settings.loaded;
        expect(settings.showProducedFiles, isTrue);
        var notified = false;
        settings.addListener(() {
          notified = true;
        });
        await settings.setShowProducedFiles(false);
        expect(notified, isTrue);
        expect(
          harness.preferences.getBool('display_show_produced_files_v1'),
          isFalse,
        );
        final copied = settings.copyWith();
        addTearDown(copied.dispose);
        expect(copied.showProducedFiles, isFalse);
        final reloaded = SettingsProvider(harness.preferences);
        addTearDown(reloaded.dispose);
        await reloaded.loaded;
        expect(reloaded.showProducedFiles, isFalse);
        expect(reloaded.showToolCards, isTrue);
      },
    );

    test('loads persisted hidden values', () async {
      final harness = await createBusinessTestHarness(
        initial: {
          'display_show_thinking_cards_v1': false,
          'display_show_tool_cards_v1': false,
        },
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.showThinkingCards, isFalse);
      expect(settings.showToolCards, isFalse);
    });

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setShowThinkingCards(false);
      await settings.setShowToolCards(false);

      expect(settings.showThinkingCards, isFalse);
      expect(settings.showToolCards, isFalse);
      final prefs = harness.preferences;
      expect(prefs.getBool('display_show_thinking_cards_v1'), isFalse);
      expect(prefs.getBool('display_show_tool_cards_v1'), isFalse);
    });
  });
}
