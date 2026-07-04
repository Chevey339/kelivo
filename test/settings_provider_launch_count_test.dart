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

  group('SettingsProvider app launch count', () {
    test('defaults to zero', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.appLaunchCount, 0);
    });

    test('loads persisted count', () async {
      SharedPreferences.setMockInitialValues({'app_launch_count_v1': 7});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.appLaunchCount, 7);
    });

    test('increments and persists count once per explicit call', () async {
      SharedPreferences.setMockInitialValues({'app_launch_count_v1': 2});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.incrementAppLaunchCount();
      await settings.incrementAppLaunchCount();

      expect(settings.appLaunchCount, 4);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('app_launch_count_v1'), 4);
    });
  });
}
