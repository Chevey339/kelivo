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

  group('SettingsProvider assistant detail outline toggle', () {
    test('defaults to disabled to preserve the current tab layout', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.mobileAssistantDetailOutlineEnabled, isFalse);
    });

    test('loads persisted enabled value', () async {
      SharedPreferences.setMockInitialValues({
        'mobile_assistant_detail_outline_enabled_v1': true,
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.mobileAssistantDetailOutlineEnabled, isTrue);
    });

    test('persists mode changes to preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setMobileAssistantDetailOutlineEnabled(true);

      expect(settings.mobileAssistantDetailOutlineEnabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('mobile_assistant_detail_outline_enabled_v1'),
        isTrue,
      );
    });
  });
}
