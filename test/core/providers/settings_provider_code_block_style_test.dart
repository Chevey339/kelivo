import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_settings_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'display_use_legacy_code_block_style_v1';

  test(
    'legacy code block defaults on and explicit choices survive restart',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      expect(settings.useLegacyCodeBlockStyle, isTrue);
      await settings.loaded;
      expect(settings.useLegacyCodeBlockStyle, isTrue);
      expect(settings.useLegacyInlineCodeStyle, isFalse);
      await settings.setUseLegacyInlineCodeStyle(true);

      var notifications = 0;
      settings.addListener(() => notifications++);
      await settings.setUseLegacyCodeBlockStyle(false);
      await settings.setUseLegacyCodeBlockStyle(false);
      expect(notifications, 1);
      expect(harness.preferences.getBool(key), isFalse);

      final copied = settings.copyWith();
      addTearDown(copied.dispose);
      expect(copied.useLegacyCodeBlockStyle, isFalse);
      expect(copied.useLegacyInlineCodeStyle, isTrue);

      final reloaded = SettingsProvider(
        BusinessPreferences(harness.repository),
      );
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.useLegacyCodeBlockStyle, isFalse);
      await reloaded.setUseLegacyCodeBlockStyle(true);
      final restarted = SettingsProvider(
        BusinessPreferences(harness.repository),
      );
      addTearDown(restarted.dispose);
      await restarted.loaded;
      expect(restarted.useLegacyCodeBlockStyle, isTrue);
      expect(restarted.useLegacyInlineCodeStyle, isTrue);
    },
  );

  for (final enabled in [false, true]) {
    test(
      'code block preference round-trips through backup: $enabled',
      () async {
        final harness = await createBusinessTestHarness();
        await harness.preferences.setBool(key, enabled);
        final exported = BusinessSettingsRouter.exportSnapshot(
          await harness.repository.readSnapshot(),
        );
        BackupSettingsValidator.validate(exported);
        expect(exported[key], enabled);
        final restored = await createBusinessTestHarness(initial: exported);
        final settings = SettingsProvider(restored.preferences);
        addTearDown(settings.dispose);
        await settings.loaded;
        expect(settings.useLegacyCodeBlockStyle, enabled);
      },
    );
  }
}
