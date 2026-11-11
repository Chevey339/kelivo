import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exposes the persisted app locale before async settings load', () async {
    final harness = await createBusinessTestHarness(
      initial: const {'app_locale_v1': 'zh_CN'},
    );

    final settings = SettingsProvider(harness.preferences);

    expect(settings.appLocaleForMaterialApp, const Locale('zh', 'CN'));
    await settings.loaded;
  });

  for (final language in [
    AppLanguage.russian,
    AppLanguage.korean,
    AppLanguage.turkish,
  ]) {
    test('${language.tag} survives a settings reload', () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      await settings.setAppLocale(language.locale);
      expect(harness.preferences.get('app_locale_v1'), language.tag);

      final reloaded = SettingsProvider(harness.preferences);
      addTearDown(reloaded.dispose);
      expect(reloaded.appLocaleForMaterialApp, language.locale);
      await reloaded.loaded;
      expect(reloaded.appLocaleForMaterialApp, language.locale);
      await reloaded.setAppLocaleFollowSystem();
      expect(reloaded.appLocaleForMaterialApp, isNull);
      expect(harness.preferences.get('app_locale_v1'), 'system');
    });
  }

  test('resolves Chinese script and regional variants', () {
    expect(
      AppLanguage.fromLocale(const Locale('zh', 'TW')),
      AppLanguage.traditionalChinese,
    );
    expect(
      AppLanguage.fromLocale(const Locale('zh', 'HK')),
      AppLanguage.traditionalChinese,
    );
    expect(
      AppLanguage.fromLocale(
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'HK',
        ),
      ),
      AppLanguage.simplifiedChinese,
    );
  });

  for (final testCase in <({String name, Object value})>[
    (name: 'empty string', value: ''),
    (name: 'whitespace string', value: ' '),
    (name: 'unknown string', value: 'fr_FR'),
    (name: 'non-string value', value: 1),
  ]) {
    test('follows the system before loading for ${testCase.name}', () async {
      final harness = await createBusinessTestHarness(
        initial: {'app_locale_v1': testCase.value},
      );

      final settings = SettingsProvider(harness.preferences);

      expect(settings.appLocaleForMaterialApp, isNull);
      await settings.loaded;
      expect(settings.appLocaleForMaterialApp, isNull);
      expect(harness.preferences.get('app_locale_v1'), 'system');
    });
  }
}
