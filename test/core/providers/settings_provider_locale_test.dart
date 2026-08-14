import 'package:Kelivo/core/providers/settings_provider.dart';
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
