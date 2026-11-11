import 'package:Kelivo/desktop/widgets/desktop_labeled_control.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  for (final width in [1400.0, 360.0]) {
    testWidgets('desktop auto-follow dropdown at $width', (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DesktopSettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (width == 360) {
        await tester.tap(
          find
              .text(
                AppLocalizations.of(
                  tester.element(find.byType(DesktopSettingsPage)),
                )!.settingsPageDisplay,
              )
              .last,
        );
        await tester.pumpAndSettle();
      }
      final label = find.text('Auto-follow bottom');
      await tester.scrollUntilVisible(
        label,
        400,
        scrollable: find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final row = find
          .ancestor(of: label, matching: find.byType(DesktopLabeledControl))
          .first;
      final dropdown = find.descendant(
        of: row,
        matching: find.byType(DesktopSelectDropdown<bool>),
      );
      expect(dropdown, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byType(IosSwitch)),
        findsNothing,
      );
      expect(find.text('Auto-Scroll Back Delay'), findsNothing);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('Off').last);
      await tester.pumpAndSettle();
      expect(settings.autoScrollEnabled, isFalse);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('On').last);
      await tester.pumpAndSettle();
      expect(settings.autoScrollEnabled, isTrue);
    });
  }
}
