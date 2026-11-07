import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/setting/default_model_pane.dart';
import 'package:Kelivo/features/model/pages/default_model_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  for (final desktop in [false, true]) {
    testWidgets('compression thinking remains editable desktop=$desktop', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = desktop
          ? const Size(1200, 900)
          : const Size(393, 852);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late SettingsProvider settings;
      await tester.runAsync(() async {
        settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await settings.setCompressGenerationThinkingEnabled(true);
      });
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: desktop
                ? const Scaffold(body: DesktopDefaultModelPane())
                : const DefaultModelPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      )!;
      final control = find.byWidgetPredicate(
        (w) =>
            w is IosSwitch && w.semanticLabel == l10n.titleModelThinkingTitle,
      );
      await tester.scrollUntilVisible(
        control,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(control, findsOneWidget);
      await tester.ensureVisible(control);
      await Scrollable.ensureVisible(tester.element(control), alignment: .5);
      await tester.pumpAndSettle();
      expect(tester.widget<IosSwitch>(control).value, isTrue);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(settings.compressGenerationThinkingEnabled, isFalse);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(settings.compressGenerationThinkingEnabled, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
