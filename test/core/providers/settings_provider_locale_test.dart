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
}
