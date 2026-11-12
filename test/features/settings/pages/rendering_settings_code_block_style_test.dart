import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const startupChannel = MethodChannel('app.desktop_startup');
  const hapticsChannel = MethodChannel('haptic_feedback');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          startupChannel,
          (_) async => {'supported': false, 'enabled': false},
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(hapticsChannel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(startupChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(hapticsChannel, null);
  });
  for (final desktop in [false, true]) {
    testWidgets(
      'rendering settings retain legacy code blocks by default: desktop=$desktop',
      (tester) async {
        tester.view.physicalSize = desktop
            ? const Size(1400, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = (await tester.runAsync(() async {
          final preferences = createBusinessTestPreferences();
          final settings = SettingsProvider(preferences);
          await settings.loaded;
          return (preferences: preferences, settings: settings);
        }))!;
        final preferences = harness.preferences;
        final settings = harness.settings;
        addTearDown(settings.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: desktop
                  ? const Scaffold(body: DesktopSettingsPage())
                  : const RenderingSettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = find.text('Legacy code block style');
        await tester.scrollUntilVisible(
          label,
          300,
          scrollable: desktop
              ? find
                    .descendant(
                      of: find.byType(SingleChildScrollView),
                      matching: find.byType(Scrollable),
                    )
                    .first
              : find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final toggle = find.descendant(
          of: find.ancestor(
            of: label,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Row &&
                  widget.children.any((child) => child is IosSwitch),
            ),
          ),
          matching: find.byType(IosSwitch),
        );
        expect(tester.widget<IosSwitch>(toggle).value, isTrue);
        for (final enabled in [false, true]) {
          await tester.runAsync(() async {
            await tester.tap(toggle);
            await preferences.flushPendingWrites();
          });
          await tester.pumpAndSettle();
          expect(settings.useLegacyCodeBlockStyle, enabled);
          expect(settings.useLegacyInlineCodeStyle, isFalse);
          expect(tester.widget<IosSwitch>(toggle).value, enabled);
          expect(
            preferences.getBool('display_use_legacy_code_block_style_v1'),
            enabled,
          );
        }
        expect(tester.takeException(), isNull);
      },
      variant: desktop
          ? TargetPlatformVariant.desktop()
          : TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}),
    );
  }
}
