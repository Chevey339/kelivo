import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider collapse thinking steps toggle', () {
    test('defaults to disabled', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.collapseThinkingSteps, isFalse);
    });

    test('loads persisted enabled value', () async {
      final harness = await createBusinessTestHarness(
        initial: {'display_collapse_thinking_steps_v1': true},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.collapseThinkingSteps, isTrue);
    });

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setCollapseThinkingSteps(true);

      expect(settings.collapseThinkingSteps, isTrue);
      final prefs = harness.preferences;
      expect(prefs.getBool('display_collapse_thinking_steps_v1'), isTrue);
    });
  });
}
