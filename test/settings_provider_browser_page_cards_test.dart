import 'support/business_test_harness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('browser cards default on and can be persisted off', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    expect(settings.showBrowserPageCards, isTrue);
    await settings.setShowBrowserPageCards(false);
    final restored = SettingsProvider(harness.preferences);
    await restored.loaded;
    expect(restored.showBrowserPageCards, isFalse);
    expect(
      harness.preferences.getBool('display_show_browser_page_cards_v1'),
      isFalse,
    );
    settings.dispose();
    restored.dispose();
  });
}
