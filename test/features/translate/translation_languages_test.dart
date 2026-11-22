import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/translation_language.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_translate_page.dart';
import 'package:Kelivo/features/translate/pages/translate_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
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
    'the toolbar manages languages and the selector uses the saved order',
    (tester) async {
      final desktop = defaultTargetPlatform == TargetPlatform.windows;
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

      final manage = find.byTooltip('Manage translation languages');
      await tester.tap(manage);
      await tester.pumpAndSettle();
      final frenchCheckbox = find.descendant(
        of: find.byKey(const ValueKey('fr')),
        matching: find.byType(IosCheckbox),
      );
      await tester.tap(frenchCheckbox);
      await tester.pumpAndSettle();
      expect(tester.widget<IosCheckbox>(frenchCheckbox).value, isFalse);

      final arabicHandle = find.descendant(
        of: find.byKey(const ValueKey('ar')),
        matching: find.byType(ReorderableDragStartListener),
      );
      await tester.drag(arabicHandle, const Offset(0, -144));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(_visibleCodes(settings), ['ar', 'bn', 'en']);

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
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );
}
