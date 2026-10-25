import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

import '../../../support/business_test_harness.dart';

void main() {
  testWidgets('auto-follow stays a navigation row and saves on/off choices', (
    tester,
  ) async {
    final preferences = createBusinessTestPreferences();
    final settings = SettingsProvider(preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DisplaySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = find.text('Auto-follow bottom');
    await tester.scrollUntilVisible(label, 240);
    await tester.pumpAndSettle();
    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
    expect(find.descendant(of: row, matching: find.text('On')), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byType(IosSwitch)),
      findsNothing,
    );
    expect(find.text('Auto-Scroll Back Delay'), findsNothing);

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.byType(SfSlider), findsNothing);
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('Off')),
    );
    await tester.pumpAndSettle();
    expect(settings.autoScrollEnabled, isFalse);
    expect(preferences.getBool('display_auto_scroll_enabled_v1'), isFalse);
    expect(
      find.descendant(of: row, matching: find.text('Off')),
      findsOneWidget,
    );

    await tester.tap(label);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('On')),
    );
    await tester.pumpAndSettle();
    expect(settings.autoScrollEnabled, isTrue);
    expect(preferences.getBool('display_auto_scroll_enabled_v1'), isTrue);
    expect(find.descendant(of: row, matching: find.text('On')), findsOneWidget);
  });
}
