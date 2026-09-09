import 'support/business_test_harness.dart';
import 'package:Kelivo/core/models/mobile_background_settings.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all feature flags default off, with one-minute completion display',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      expect(
        settings.mobileBackground.toJson().values.whereType<bool>(),
        everyElement(isFalse),
      );
      expect(
        settings.mobileBackground.completionVisibility,
        BackgroundCompletionVisibility.oneMinute,
      );
      expect(
        harness.preferences.getString('mobile_background_settings_v1'),
        isNull,
      );
      settings.dispose();
    },
  );

  test(
    'feature switches persist independently without enabling companion features',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      await settings.setMobileBackground(
        settings.mobileBackground.copyWith(
          androidEnabled: true,
          locationEnabled: true,
          overlayIconKind: 'emoji',
          overlayIconValue: '🐱',
          completionVisibility: BackgroundCompletionVisibility.untilForeground,
          overlayAppearance: BackgroundOverlayAppearance.circle.copyWith(
            width: 88,
            height: 88,
            progressStrokeWidth: 4.5,
          ),
        ),
      );
      final reloaded = SettingsProvider(harness.preferences);
      await reloaded.loaded;
      expect(reloaded.mobileBackground.androidEnabled, isTrue);
      expect(reloaded.mobileBackground.locationEnabled, isTrue);
      expect(reloaded.mobileBackground.iosEnabled, isFalse);
      expect(reloaded.mobileBackground.notificationsEnabled, isFalse);
      expect(reloaded.mobileBackground.backgroundSpeechEnabled, isFalse);
      expect(reloaded.mobileBackground.overlayIconValue, '🐱');
      expect(reloaded.mobileBackground.completionVisibility.seconds, 900);
      expect(reloaded.mobileBackground.overlayAppearance.width, 88);
      expect(reloaded.mobileBackground.overlayAppearance.height, 88);
      expect(
        reloaded.mobileBackground.overlayAppearance.progressStrokeWidth,
        4.5,
      );
      expect(reloaded.mobileBackground.overlayAppearance.isIconOnly, isTrue);
      expect(
        reloaded.mobileBackground.overlayAppearance.showBackground,
        isFalse,
      );
      expect(reloaded.mobileBackground.overlayEnabled, isFalse);
      reloaded.dispose();
      settings.dispose();
    },
  );

  test(
    'invalid overlay dimensions are bounded without enabling the feature',
    () {
      final value = MobileBackgroundSettings.fromJson({
        'overlayAppearance': {
          'width': 9000,
          'height': -1,
          'iconSize': double.nan,
          'progressSize': 1,
          'progressStrokeWidth': double.infinity,
        },
      });
      expect(value.overlayEnabled, isFalse);
      expect(value.overlayAppearance.width, 400);
      expect(value.overlayAppearance.height, 48);
      expect(value.overlayAppearance.iconSize, 34);
      expect(value.overlayAppearance.progressSize, 20);
      expect(value.overlayAppearance.progressStrokeWidth, 2);
    },
  );

  test(
    'malformed or removed settings never opt the user into background execution',
    () async {
      final harness = await createBusinessTestHarness(
        initial: {
          'mobile_background_settings_v1': '{invalid',
          'android_background_chat_mode_v1': 'on_notify',
          'ios_background_task_refresh_enabled_v1': true,
        },
      );
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      expect(
        settings.mobileBackground.toJson().values.whereType<bool>(),
        everyElement(isFalse),
      );
      settings.dispose();
    },
  );
}
