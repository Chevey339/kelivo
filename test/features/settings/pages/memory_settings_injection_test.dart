import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/memory_entry.dart';
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
      'full injection types can be selected independently (desktop=$desktop)',
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
          expect(settings.memoryFullInjectionTypes, isEmpty);
          final voice = find.widgetWithText(
            MemorySelectChip,
            l10n.memoryEntryTypeVoice,
          );
          final instruction = find.widgetWithText(
            MemorySelectChip,
            l10n.memoryEntryTypeInstruction,
          );
          await tester.ensureVisible(voice);
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.memorySettingsFullInjectionTypesSubtitle),
            findsOneWidget,
          );
          expect(tester.widget<MemorySelectChip>(voice).selected, isFalse);
          await tester.tap(voice);
          await tester.pumpAndSettle();
          await tester.ensureVisible(instruction);
          await tester.tap(instruction);
          await tester.pumpAndSettle();
          expect(settings.memoryFullInjectionTypes, {
            MemoryType.voice,
            MemoryType.instruction,
          });
          expect(tester.widget<MemorySelectChip>(voice).selected, isTrue);
          expect(tester.widget<MemorySelectChip>(instruction).selected, isTrue);
          await tester.tap(voice);
          await tester.pumpAndSettle();
          expect(tester.widget<MemorySelectChip>(voice).selected, isFalse);
          expect(tester.widget<MemorySelectChip>(instruction).selected, isTrue);
          await tester.runAsync(storage.preferences.flushPendingWrites);
          expect(
            storage.preferences.getStringList('memory_full_injection_types_v1'),
            ['instruction'],
          );
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
          await tester.runAsync(storage.preferences.flushPendingWrites);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
