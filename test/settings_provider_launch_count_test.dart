import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider app launch count', () {
    test('defaults to zero', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.appLaunchCount, 0);
    });

    test('loads persisted count', () async {
      final harness = await createBusinessTestHarness(
        initial: {'app_launch_count_v1': 7},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.appLaunchCount, 7);
    });

    test('increments and persists count once per explicit call', () async {
      final harness = await createBusinessTestHarness(
        initial: {'app_launch_count_v1': 2},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.incrementAppLaunchCount();
      await settings.incrementAppLaunchCount();

      expect(settings.appLaunchCount, 4);
      final prefs = harness.preferences;
      expect(prefs.getInt('app_launch_count_v1'), 4);
    });
  });
}
