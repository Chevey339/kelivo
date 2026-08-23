import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider hide tool result images toggle', () {
    test('defaults to disabled', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.hideToolResultImages, isFalse);
    });

    test('loads persisted enabled value', () async {
      final harness = await createBusinessTestHarness(
        initial: {'display_hide_tool_result_images_v1': true},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.hideToolResultImages, isTrue);
    });

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setHideToolResultImages(true);

      expect(settings.hideToolResultImages, isTrue);
      final prefs = harness.preferences;
      expect(prefs.getBool('display_hide_tool_result_images_v1'), isTrue);
    });
  });
}
