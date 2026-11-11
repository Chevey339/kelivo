import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/setting/memory_settings_pane.dart';
import 'package:Kelivo/features/settings/pages/memory_settings_page.dart';
import 'package:Kelivo/features/settings/widgets/memory_ui.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

import '../../../support/business_test_harness.dart';

void main() {
  for (final desktop in [false, true]) {
    testWidgets(
      'global memory settings retain only the shared item limit (desktop=$desktop)',
      (tester) async {
        debugDefaultTargetPlatformOverride = desktop
            ? TargetPlatform.linux
            : TargetPlatform.android;
        try {
          tester.view.physicalSize = desktop
              ? const Size(1100, 900)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final storage = await createBusinessTestHarness();
          final settings = SettingsProvider(storage.preferences);
          addTearDown(settings.dispose);
          await settings.loaded;
          final locale = desktop
              ? const Locale('en')
              : const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hant',
                );
          final l10n = await AppLocalizations.delegate.load(locale);
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: settings,
              child: MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: desktop
                      ? const DesktopMemorySettingsPane()
                      : const MemorySettingsContent(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final limit = find.text(l10n.memorySettingsInjectionMaxItemsTitle);
          await tester.ensureVisible(limit);
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.assistantEditMemoryFullInjectionTypesTitle),
            findsNothing,
          );
          expect(find.byType(MemorySelectChip), findsNothing);
          await tester.tap(limit);
          await tester.pumpAndSettle();
          await tester.tap(find.text('5').last);
          await tester.pumpAndSettle();
          expect(settings.memoryInjectionMaxItems, 5);
          final legacyMode = find.byWidgetPredicate(
            (widget) =>
                widget is IosSwitch &&
                widget.semanticLabel == l10n.legacyMemoryModeTitle,
          );
          await tester.scrollUntilVisible(legacyMode, -300);
          await tester.pumpAndSettle();
          await tester.tap(legacyMode);
          await tester.pumpAndSettle();
          expect(find.byType(MemorySelectChip), findsNothing);
          expect(tester.takeException(), isNull);
          await storage.preferences.flushPendingWrites();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
