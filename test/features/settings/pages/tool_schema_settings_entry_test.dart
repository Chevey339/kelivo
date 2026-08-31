import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/features/settings/pages/settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  testWidgets(
    'mobile settings lists Tool Descriptions below Logs and above Sponsor',
    (tester) async {
      tester.view.physicalSize = const Size(400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;
      await settings.setRequestLogEnabled(true);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labels = _listTexts(tester);
      expect(
        labels.indexOf('Tool Descriptions'),
        greaterThan(labels.indexOf('Logs')),
      );
      expect(
        labels.indexOf('Sponsor'),
        greaterThan(labels.indexOf('Tool Descriptions')),
      );
      expect(
        labels.indexOf('Tool Descriptions'),
        greaterThan(labels.indexOf('Search')),
      );
    },
  );

  testWidgets(
    'desktop settings lists Tool Descriptions below Statistics and above About',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(body: DesktopSettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labels = _listTexts(tester);
      expect(
        labels.indexOf('Tool Descriptions'),
        greaterThan(labels.indexOf('Statistics')),
      );
      expect(
        labels.indexOf('About'),
        greaterThan(labels.indexOf('Tool Descriptions')),
      );
      expect(
        labels.indexOf('Tool Descriptions'),
        greaterThan(labels.indexOf('Search')),
      );
    },
  );
}

List<String> _listTexts(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data)
      .whereType<String>()
      .toList();
}
