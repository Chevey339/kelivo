import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/translation_language.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_translate_page.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/translate/pages/translate_page.dart';
import 'package:Kelivo/features/translate/pages/translation_languages_page.dart';
import 'package:Kelivo/features/translate/widgets/translation_languages_editor.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

Iterable<String> _visibleCodes(SettingsProvider settings) =>
    settings.visibleTranslationLanguages.map((language) => language.code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('visible translation languages persist in picker order', () async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    expect(settings.visibleTranslationLanguages, supportedLanguages);

    await settings.setVisibleTranslationLanguages(['ar', 'bn', 'ar', 'en']);
    await settings.setVisibleTranslationLanguages([]);
    final reloaded = SettingsProvider(BusinessPreferences(harness.repository));
    addTearDown(reloaded.dispose);
    await reloaded.loaded;
    expect(_visibleCodes(reloaded), ['ar', 'bn', 'en']);
  });

  testWidgets(
    'the translation toolbar opens the editor and the selector uses the saved order',
    (tester) async {
      final desktop = defaultTargetPlatform == TargetPlatform.macOS;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      final assistants = AssistantProvider(preferences: harness.preferences);
      addTearDown(settings.dispose);
      addTearDown(assistants.dispose);
      await Future.wait([settings.loaded, assistants.loaded]);
      await settings.setVisibleTranslationLanguages(['fr', 'bn', 'en', 'ar']);
      await settings.setTranslateTargetLang('fr');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: assistants),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: desktop
                ? const Scaffold(body: DesktopTranslatePage())
                : const TranslatePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('French'), findsOneWidget);

      final manage = find.byTooltip('Translation languages');
      final save = find.widgetWithText(IosTextButton, 'Save');
      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(find.byType(TranslationLanguagesEditor), findsOneWidget);
      expect(
        desktop
            ? find.byType(AppDialogHeader)
            : find.byType(TranslationLanguagesPage),
        findsOneWidget,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(TranslationLanguagesEditor), findsNothing);
      expect(_visibleCodes(settings), ['fr', 'bn', 'en', 'ar']);

      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(find.text('Shown in menus'), findsOneWidget);
      expect(find.text('Hidden'), findsOneWidget);
      final frenchRow = find.byKey(const ValueKey('fr'));
      final frenchSwitch = find.descendant(
        of: frenchRow,
        matching: find.byType(IosSwitch),
      );
      await tester.tap(frenchSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<IosSwitch>(frenchSwitch).value, isFalse);
      expect(_visibleCodes(settings), ['fr', 'bn', 'en', 'ar']);

      await tester.ensureVisible(frenchSwitch);
      await tester.pumpAndSettle();
      // Both controls can request the same change before the next build.
      await tester.tap(
        find.descendant(of: frenchRow, matching: find.text('French')),
      );
      await tester.tap(frenchSwitch);
      await tester.pumpAndSettle();
      final languageList = find.byType(ReorderableListView);
      expect(tester.widget<ReorderableListView>(languageList).itemCount, 4);
      final scrollable = find.descendant(
        of: languageList,
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(frenchSwitch);
      await tester.pumpAndSettle();

      final arabicHandle = find.descendant(
        of: find.byKey(const ValueKey('ar')),
        matching: find.byType(ReorderableDragStartListener),
      );
      final firstRowTop = tester
          .getTopLeft(find.byKey(const ValueKey('bn')))
          .dy;
      final handleCenter = tester.getCenter(arabicHandle);
      await tester.timedDrag(
        arabicHandle,
        Offset(0, firstRowTop - handleCenter.dy - 40),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(_visibleCodes(settings), ['ar', 'bn', 'en']);
      expect(find.byType(TranslationLanguagesEditor), findsNothing);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('French'), findsNothing);
      expect(find.text('🇸🇦'), findsOneWidget);
      expect(find.text('🇧🇩'), findsOneWidget);
      final arabic = find.text('Arabic');
      expect(
        tester.getTopLeft(arabic).dy,
        lessThan(tester.getTopLeft(find.text('Bangla')).dy),
      );
      await tester.tap(arabic);
      await tester.pumpAndSettle();
      expect(settings.translateTargetLang, 'ar');
      expect(arabic, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }),
  );
}
