import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showReasoningLevelBadge defaults off and round-trips', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    expect(settings.showReasoningLevelBadge, isFalse);

    var notified = false;
    settings.addListener(() {
      notified = true;
    });
    await settings.setShowReasoningLevelBadge(true);
    expect(notified, isTrue);
    expect(settings.showReasoningLevelBadge, isTrue);
    expect(
      harness.preferences.getBool('display_show_reasoning_level_badge_v1'),
      isTrue,
    );

    final copied = settings.copyWith();
    addTearDown(copied.dispose);
    expect(copied.showReasoningLevelBadge, isTrue);

    final reloaded = SettingsProvider(harness.preferences);
    addTearDown(reloaded.dispose);
    await reloaded.loaded;
    expect(reloaded.showReasoningLevelBadge, isTrue);
  });

  test('showReasoningLevelBadge loads a persisted true value', () async {
    final harness = await createBusinessTestHarness(
      initial: const {'display_show_reasoning_level_badge_v1': true},
    );
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    expect(settings.showReasoningLevelBadge, isTrue);
  });
}
