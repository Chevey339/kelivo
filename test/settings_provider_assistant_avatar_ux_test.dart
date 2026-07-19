import "support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider assistant avatar UX toggle', () {
    test('defaults to legacy mode (disabled)', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.useNewAssistantAvatarUx, isFalse);
    });

    test('loads persisted enabled value', () async {
      final harness = await createBusinessTestHarness(
        initial: {'display_use_new_assistant_avatar_ux_v1': true},
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.useNewAssistantAvatarUx, isTrue);
    });

    test('persists mode changes to preferences', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setUseNewAssistantAvatarUx(true);

      expect(settings.useNewAssistantAvatarUx, isTrue);
      final prefs = harness.preferences;
      expect(prefs.getBool('display_use_new_assistant_avatar_ux_v1'), isTrue);
    });
  });
}
