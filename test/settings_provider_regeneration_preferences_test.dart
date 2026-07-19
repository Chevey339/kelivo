import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider regeneration preferences', () {
    test('defaults preserve current regeneration behavior', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.regenerateDeleteTrailingMessages, isFalse);
      expect(settings.showRegenerateConfirmDialog, isTrue);
    });

    test('loads persisted regeneration behavior values', () async {
      final harness = await createBusinessTestHarness(
        initial: {
          'display_regenerate_delete_trailing_messages_v1': true,
          'display_show_regenerate_confirm_dialog_v1': false,
        },
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.regenerateDeleteTrailingMessages, isTrue);
      expect(settings.showRegenerateConfirmDialog, isFalse);
    });

    test('persists regeneration behavior changes', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setRegenerateDeleteTrailingMessages(true);
      await settings.setShowRegenerateConfirmDialog(false);

      expect(settings.regenerateDeleteTrailingMessages, isTrue);
      expect(settings.showRegenerateConfirmDialog, isFalse);

      final prefs = harness.preferences;
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
