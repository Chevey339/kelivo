import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider iOS background generation settings', () {
    test('defaults all iOS background options to disabled', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.iosBackgroundGenerationEnabled, isFalse);
      expect(settings.iosBackgroundTaskRefreshEnabled, isFalse);
      expect(settings.iosLiveActivityEnabled, isFalse);
      expect(settings.iosBackgroundNotificationsEnabled, isFalse);
    });

    test('loads persisted enabled values', () async {
      final harness = await createBusinessTestHarness(
        initial: {
          'ios_background_generation_enabled_v1': true,
          'ios_background_task_refresh_enabled_v1': true,
          'ios_live_activity_enabled_v1': true,
          'ios_background_notifications_enabled_v1': true,
        },
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.iosBackgroundGenerationEnabled, isTrue);
      expect(settings.iosBackgroundTaskRefreshEnabled, isTrue);
      expect(settings.iosLiveActivityEnabled, isTrue);
      expect(settings.iosBackgroundNotificationsEnabled, isTrue);
    });

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setIosBackgroundGenerationEnabled(true);
      await settings.setIosBackgroundTaskRefreshEnabled(true);
      await settings.setIosLiveActivityEnabled(true);
      await settings.setIosBackgroundNotificationsEnabled(true);

      final prefs = harness.preferences;
      expect(settings.iosBackgroundGenerationEnabled, isTrue);
      expect(settings.iosBackgroundTaskRefreshEnabled, isTrue);
      expect(settings.iosLiveActivityEnabled, isTrue);
      expect(settings.iosBackgroundNotificationsEnabled, isTrue);
      expect(prefs.getBool('ios_background_generation_enabled_v1'), isTrue);
      expect(prefs.getBool('ios_background_task_refresh_enabled_v1'), isTrue);
      expect(prefs.getBool('ios_live_activity_enabled_v1'), isTrue);
      expect(prefs.getBool('ios_background_notifications_enabled_v1'), isTrue);
    });
  });
}
