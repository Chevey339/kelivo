import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/avatar_config.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/search/web_fetch_service.dart';
import 'package:Kelivo/features/provider/widgets/provider_icon_picker.dart';
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

  testWidgets('saves a search icon per instance and can discard or reset it', (
    tester,
  ) async {
    const first = BingLocalOptions(id: 'first');
    const second = BingLocalOptions(id: 'second');
    const brave = AvatarConfig(
      type: AvatarType.icon,
      value: 'assets/icons/brave-color.svg',
    );
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    await settings.setSearchServices([first, second]);
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

    final row = find.byKey(const ValueKey('search-service-row-second'));
    Future<void> openIconMenu() async {
      await tester.tap(
        find.descendant(of: row, matching: find.text('Bing (Local)')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Change icon'));
      await tester.pumpAndSettle();
    }

    await openIconMenu();
    await tester.tap(find.text('Choose Built-in Icon'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(ProviderIconPicker),
        matching: find.byType(TextField),
      ),
      'brave',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Brave'));
    await tester.pumpAndSettle();
    expect(settings.searchServiceAvatar(second.id), isNull);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(settings.searchServiceAvatar(first.id), isNull);
    expect(settings.searchServiceAvatar(second.id), brave);

    await openIconMenu();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(settings.searchServiceAvatar(second.id), brave);

    await settings.setSearchServices([second, first]);
    final reloaded = SettingsProvider(BusinessPreferences(harness.repository));
    addTearDown(reloaded.dispose);
    await reloaded.loaded;
    expect(reloaded.searchServices.map((service) => service.id), [
      second.id,
      first.id,
    ]);
    expect(reloaded.searchServiceAvatar(second.id), brave);

    await openIconMenu();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(settings.searchServiceAvatar(second.id), isNull);
    final restoredPrefs = BusinessPreferences(harness.repository);
    await restoredPrefs.load();
    expect(
      restoredPrefs.getString('search_services_v1'),
      isNot(contains('avatar')),
    );
  });
}
