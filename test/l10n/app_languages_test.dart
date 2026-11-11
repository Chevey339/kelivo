import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/l10n/app_language.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/business_test_harness.dart';

void main() {
  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} can switch all new languages',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = desktop
            ? const Size(1280, 800)
            : const Size(390, 600);
        addTearDown(tester.view.reset);
        final settings = SettingsProvider(createBusinessTestPreferences());
        addTearDown(settings.dispose);
        await settings.loaded;
        await settings.setAppLocale(AppLanguage.english.locale);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: Consumer<SettingsProvider>(
              builder: (context, value, child) => MaterialApp(
                locale: value.appLocaleForMaterialApp,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: desktop
                    ? const Scaffold(body: DesktopSettingsPage())
                    : const DisplaySettingsPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final language in [
          AppLanguage.russian,
          AppLanguage.korean,
          AppLanguage.turkish,
        ]) {
          final current = await AppLocalizations.delegate.load(
            settings.appLocale,
          );
          final trigger = desktop
              ? find.text(AppLanguage.fromLocale(settings.appLocale).nativeName)
              : find.text(current.displaySettingsPageLanguageTitle);
          await tester.ensureVisible(trigger.first);
          await tester.pumpAndSettle();
          await tester.tap(trigger.first);
          await tester.pumpAndSettle();
          final choice = find.text(language.nativeName).last;
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          await tester.tap(choice);
          await tester.pumpAndSettle();
          expect(settings.appLocale, language.locale);
          final localized = await AppLocalizations.delegate.load(
            language.locale,
          );
          expect(
            find.text(localized.displaySettingsPageLanguageTitle),
            findsOneWidget,
          );
          expect(localized.settingsPageTitle, isNot('Settings'));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('follow system resolves the three new locales', (tester) async {
    for (final language in [
      AppLanguage.russian,
      AppLanguage.korean,
      AppLanguage.turkish,
    ]) {
      tester.platformDispatcher.localesTestValue = [language.locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      late Locale resolved;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              resolved = Localizations.localeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(resolved.languageCode, language.locale.languageCode);
    }
  });

  test(
    'Russian plural output preserves quantities and uses distinct forms',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      for (final n in [0, 1, 2, 5, 11, 21, 22, 101]) {
        expect(l10n.settingsSearchResultCount(n), contains('$n'));
        expect(l10n.browserTabsCount(n), contains('$n'));
      }
      final one = l10n.settingsSearchResultCount(1).replaceAll('1', '');
      final few = l10n.settingsSearchResultCount(2).replaceAll('2', '');
      final many = l10n.settingsSearchResultCount(5).replaceAll('5', '');
      expect({one, few, many}, hasLength(3));
      expect(l10n.settingsSearchResultCount(21).replaceAll('21', ''), one);
      expect(l10n.settingsSearchResultCount(22).replaceAll('22', ''), few);
      expect(l10n.settingsSearchResultCount(11).replaceAll('11', ''), many);
    },
  );
}
