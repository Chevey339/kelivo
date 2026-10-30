import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  for (final desktop in [false, true]) {
    testWidgets(
      'rendering settings opt in to legacy inline code: desktop=$desktop',
      (tester) async {
        tester.view.physicalSize = desktop
            ? const Size(1400, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final preferences = createBusinessTestPreferences();
        final settings = SettingsProvider(preferences);
        addTearDown(settings.dispose);
        await settings.loaded;
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
        final label = find.text('Legacy inline code style');
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
        expect(tester.widget<IosSwitch>(toggle).value, isFalse);
        for (final enabled in [true, false]) {
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(settings.useLegacyInlineCodeStyle, enabled);
          expect(tester.widget<IosSwitch>(toggle).value, enabled);
          expect(
            preferences.getBool('display_use_legacy_inline_code_style_v1'),
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
