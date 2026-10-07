import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/search/web_fetch_service.dart';
import 'package:Kelivo/features/search/pages/search_service_editor_page.dart';
import 'package:Kelivo/features/search/pages/search_services_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('selects a configured reader and follows search after removal', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;
    await settings.setSearchServices([
      const BingLocalOptions(id: 'bing'),
      TavilyOptions(id: 'tavily', apiKey: 'key'),
    ]);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchServicesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('web-fetch-mode-row'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('web-fetch-mode-bing')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('web-fetch-mode-tavily')));
    await tester.pumpAndSettle();
    expect(settings.webFetchMode, 'tavily');
    await settings.setSearchServices([const BingLocalOptions(id: 'bing')]);
    await tester.pumpAndSettle();
    expect(settings.webFetchMode, WebFetchMode.follow);
    expect(find.text('Follow search · Local'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a provider in the full-page editor', (tester) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchServicesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SearchServiceEditorPage), findsNothing);
    final providerRows = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return widget is Row &&
          key is ValueKey<String> &&
          key.value.startsWith('search-service-row-');
    });
    expect(providerRows, findsWidgets);
    for (final row in tester.widgetList<Row>(providerRows)) {
      expect(row.crossAxisAlignment, CrossAxisAlignment.center);
      expect(tester.getSize(find.byKey(row.key!)).height, 22);
    }

    await tester.tap(find.text('Bing (Local)'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchServiceEditorPage), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
