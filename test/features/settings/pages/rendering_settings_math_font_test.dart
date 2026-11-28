import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  test('chat math font survives a restart and provider copies', () async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    expect(settings.chatMathFont, ChatMathFont.standard);
    for (final font in [ChatMathFont.stixTwo, ChatMathFont.standard]) {
      await settings.setChatMathFont(font);
      final copy = settings.copyWith();
      expect(copy.chatMathFont, font);
      copy.dispose();
      final reloaded = SettingsProvider(
        BusinessPreferences(harness.repository),
      );
      await reloaded.loaded;
      expect(reloaded.chatMathFont, font);
      reloaded.dispose();
    }
  });

  for (final desktop in [false, true]) {
    testWidgets(
      'the rendering settings picker saves the chat math font on ${desktop ? "desktop" : "mobile"}',
      (tester) async {
        tester.view.physicalSize = desktop
            ? const Size(1400, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = (await tester.runAsync(() async {
          final settings = SettingsProvider(createBusinessTestPreferences());
          await settings.loaded;
          return settings;
        }))!;
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
        final label = find.text('Math font');
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
        final trigger = desktop
            ? find.byType(DesktopSelectDropdown<ChatMathFont>)
            : label;
        expect(settings.chatMathFont, ChatMathFont.standard);
        for (final font in [ChatMathFont.stixTwo, ChatMathFont.standard]) {
          await tester.tap(trigger);
          await tester.pumpAndSettle();
          final option = font == ChatMathFont.stixTwo
              ? 'STIX Two Math'
              : 'Default';
          await tester.tap(find.text(option).last);
          await tester.pumpAndSettle();
          expect(settings.chatMathFont, font);
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        desktop ? TargetPlatform.macOS : TargetPlatform.iOS,
      ),
    );
  }
}
