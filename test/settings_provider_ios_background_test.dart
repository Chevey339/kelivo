import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider iOS background generation settings', () {
    test('defaults all iOS background options to disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.iosBackgroundGenerationEnabled, isFalse);
      expect(settings.iosBackgroundTaskRefreshEnabled, isFalse);
      expect(settings.iosLiveActivityEnabled, isFalse);
      expect(settings.iosBackgroundNotificationsEnabled, isFalse);
    });

    test('loads persisted enabled values', () async {
      SharedPreferences.setMockInitialValues({
        'ios_background_generation_enabled_v1': true,
        'ios_background_task_refresh_enabled_v1': true,
        'ios_live_activity_enabled_v1': true,
        'ios_background_notifications_enabled_v1': true,
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.iosBackgroundGenerationEnabled, isTrue);
      expect(settings.iosBackgroundTaskRefreshEnabled, isTrue);
      expect(settings.iosLiveActivityEnabled, isTrue);
      expect(settings.iosBackgroundNotificationsEnabled, isTrue);
    });

    test('persists mode changes to preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setIosBackgroundGenerationEnabled(true);
      await settings.setIosBackgroundTaskRefreshEnabled(true);
      await settings.setIosLiveActivityEnabled(true);
      await settings.setIosBackgroundNotificationsEnabled(true);

      final prefs = await SharedPreferences.getInstance();
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
