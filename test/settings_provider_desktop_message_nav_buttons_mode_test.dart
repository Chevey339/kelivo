import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider desktop message navigation buttons mode', () {
    test('defaults to scroll visibility', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(
        settings.desktopMessageNavButtonsMode,
        DesktopMessageNavButtonsMode.scroll,
      );
    });

    test('loads every persisted mode value', () async {
      const cases = <String, DesktopMessageNavButtonsMode>{
        'always': DesktopMessageNavButtonsMode.always,
        'scroll': DesktopMessageNavButtonsMode.scroll,
        'hover': DesktopMessageNavButtonsMode.hover,
        'scrollAndHover': DesktopMessageNavButtonsMode.scrollAndHover,
        'never': DesktopMessageNavButtonsMode.never,
      };

      for (final entry in cases.entries) {
        final harness = await createBusinessTestHarness(
          initial: {'display_desktop_message_nav_buttons_mode_v1': entry.key},
        );
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;

        expect(settings.desktopMessageNavButtonsMode, entry.value);
      }
    });

    test(
      'maps legacy disabled toggle to never when new key is absent',
      () async {
        final harness = await createBusinessTestHarness(
          initial: {'display_show_message_nav_v1': false},
        );
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;

        expect(
          settings.desktopMessageNavButtonsMode,
          DesktopMessageNavButtonsMode.never,
        );
      },
    );

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setDesktopMessageNavButtonsMode(
        DesktopMessageNavButtonsMode.scrollAndHover,
      );

      expect(
        settings.desktopMessageNavButtonsMode,
        DesktopMessageNavButtonsMode.scrollAndHover,
      );
      final prefs = harness.preferences;
      expect(
        prefs.getString('display_desktop_message_nav_buttons_mode_v1'),
        'scrollAndHover',
      );
    });
  });
}
