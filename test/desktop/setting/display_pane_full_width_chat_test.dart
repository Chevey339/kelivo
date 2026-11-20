import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  testWidgets('desktop full-width chat switch saves both choices', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DesktopSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = find.text('Full-width chat');
    final toggle = find.descendant(
      of: find.ancestor(of: label, matching: find.byType(Row)).first,
      matching: find.byType(IosSwitch),
    );
    expect(tester.widget<IosSwitch>(toggle).value, isFalse);

    for (final value in [true, false]) {
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<IosSwitch>(toggle).value, value);

      await harness.preferences.flushPendingWrites();
      final reopened = SettingsProvider(
        BusinessPreferences(harness.repository),
      );
      addTearDown(reopened.dispose);
      await reopened.loaded;
      expect(reopened.desktopFullWidthChat, value);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.preferences.flushPendingWrites();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
