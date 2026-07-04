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

  group('SettingsProvider regeneration preferences', () {
    test('defaults preserve current regeneration behavior', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.regenerateDeleteTrailingMessages, isFalse);
      expect(settings.showRegenerateConfirmDialog, isTrue);
    });

    test('loads persisted regeneration behavior values', () async {
      SharedPreferences.setMockInitialValues({
        'display_regenerate_delete_trailing_messages_v1': true,
        'display_show_regenerate_confirm_dialog_v1': false,
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.regenerateDeleteTrailingMessages, isTrue);
      expect(settings.showRegenerateConfirmDialog, isFalse);
    });

    test('persists regeneration behavior changes', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setRegenerateDeleteTrailingMessages(true);
      await settings.setShowRegenerateConfirmDialog(false);

      expect(settings.regenerateDeleteTrailingMessages, isTrue);
      expect(settings.showRegenerateConfirmDialog, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('display_regenerate_delete_trailing_messages_v1'),
        isTrue,
      );
      expect(
        prefs.getBool('display_show_regenerate_confirm_dialog_v1'),
        isFalse,
      );
    });
  });
}
