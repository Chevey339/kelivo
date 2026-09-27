import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'whole-turn token display defaults off and persists both settings',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.showTotalTokens, isFalse);
      for (final enabled in [true, false]) {
        await settings.setShowTotalTokens(enabled);
        final copied = settings.copyWith();
        addTearDown(copied.dispose);
        expect(copied.showTotalTokens, enabled);
        final reloaded = SettingsProvider(harness.preferences);
        addTearDown(reloaded.dispose);
        await reloaded.loaded;
        expect(reloaded.showTotalTokens, enabled);
        expect(reloaded.showTokenStats, isTrue);
      }
    },
  );
}
