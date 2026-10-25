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
  testWidgets('desktop auto-follow uses an on/off dropdown without a delay', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;
    tester.view.physicalSize = const Size(1400, 900);
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
    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
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
