import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_settings_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'display_use_legacy_inline_code_style_v1';

  test(
    'legacy inline code defaults off and survives copying and restart',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.useLegacyInlineCodeStyle, isFalse);

      var notifications = 0;
      settings.addListener(() => notifications++);
      await settings.setUseLegacyInlineCodeStyle(true);
      await settings.setUseLegacyInlineCodeStyle(true);
      expect(notifications, 1);
      expect(harness.preferences.getBool(key), isTrue);

      final copied = settings.copyWith();
      addTearDown(copied.dispose);
      expect(copied.useLegacyInlineCodeStyle, isTrue);

      final reloaded = SettingsProvider(
        BusinessPreferences(harness.repository),
      );
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.useLegacyInlineCodeStyle, isTrue);
      await reloaded.setUseLegacyInlineCodeStyle(false);
      final restarted = SettingsProvider(
        BusinessPreferences(harness.repository),
      );
      addTearDown(restarted.dispose);
      await restarted.loaded;
      expect(restarted.useLegacyInlineCodeStyle, isFalse);
    },
  );

  for (final enabled in [false, true]) {
    test(
      'inline code preference round-trips through backup: $enabled',
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
        expect(settings.useLegacyInlineCodeStyle, enabled);
      },
    );
  }
}
