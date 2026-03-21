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

  group('SettingsProvider assistant avatar UX toggle', () {
    test('defaults to legacy mode (disabled)', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.useNewAssistantAvatarUx, isFalse);
    });

    test('loads persisted enabled value', () async {
      SharedPreferences.setMockInitialValues({
        'display_use_new_assistant_avatar_ux_v1': true,
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.useNewAssistantAvatarUx, isTrue);
    });

    test('persists mode changes to preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setUseNewAssistantAvatarUx(true);

      expect(settings.useNewAssistantAvatarUx, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('display_use_new_assistant_avatar_ux_v1'), isTrue);
    });
  });
}
