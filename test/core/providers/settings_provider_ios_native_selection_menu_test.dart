import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'ios_native_selection_menu_enabled_v1';

  test(
    'native menus default on and the device preference survives reload',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.iosNativeSelectionMenuEnabled, isTrue);

      var notifications = 0;
      settings.addListener(() => notifications++);
      await settings.setIosNativeSelectionMenuEnabled(false);
      await settings.setIosNativeSelectionMenuEnabled(false);
      expect(notifications, 1);
      expect(settings.iosNativeSelectionMenuEnabled, isFalse);
      final localPreferences = await SharedPreferences.getInstance();
      expect(localPreferences.getBool(key), isFalse);
      expect(harness.preferences.containsKey(key), isFalse);
      expect(
        BusinessKeyRegistry.classify(key),
        BusinessKeyDisposition.localOnly,
      );

      final copied = settings.copyWith();
      addTearDown(copied.dispose);
      expect(copied.iosNativeSelectionMenuEnabled, isFalse);

      final reloaded = SettingsProvider(harness.preferences);
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.iosNativeSelectionMenuEnabled, isFalse);
      await reloaded.setIosNativeSelectionMenuEnabled(true);
      expect(localPreferences.getBool(key), isTrue);
    },
  );

  test(
    'imported settings cannot override the local rollback preference',
    () async {
      final harness = await createBusinessTestHarness(
        initial: const {key: true},
        localInitial: const {key: false},
      );
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.iosNativeSelectionMenuEnabled, isFalse);
      final snapshot = await harness.repository.readSnapshot();
      expect(snapshot.preferences.containsKey(key), isFalse);
    },
  );
}
