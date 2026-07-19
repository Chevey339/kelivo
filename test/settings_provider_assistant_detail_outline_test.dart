import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider assistant detail outline toggle', () {
    test('defaults to disabled to preserve the current tab layout', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.mobileAssistantDetailOutlineEnabled, isFalse);
    });

    test('loads persisted enabled value', () async {
      final harness = await createBusinessTestHarness(
        initial: {'mobile_assistant_detail_outline_enabled_v1': true},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.mobileAssistantDetailOutlineEnabled, isTrue);
    });

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setMobileAssistantDetailOutlineEnabled(true);

      expect(settings.mobileAssistantDetailOutlineEnabled, isTrue);
      final prefs = harness.preferences;
      expect(
        prefs.getBool('mobile_assistant_detail_outline_enabled_v1'),
        isTrue,
      );
    });
  });
}
