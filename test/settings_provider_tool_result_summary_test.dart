import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider tool result summary toggle', () {
    test('defaults to disabled', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.showToolResultSummary, isFalse);
    });

    test('loads persisted enabled value', () async {
      final harness = await createBusinessTestHarness(
        initial: {'display_show_tool_result_summary_v1': true},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.showToolResultSummary, isTrue);
    });

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setShowToolResultSummary(true);

      expect(settings.showToolResultSummary, isTrue);
      final prefs = harness.preferences;
      expect(prefs.getBool('display_show_tool_result_summary_v1'), isTrue);
    });
  });
}
