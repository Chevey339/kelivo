import '../../../support/business_test_harness.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/model_catalog/catalog_entry.dart';
import 'package:Kelivo/core/services/model_catalog/model_catalog_service.dart';
import 'package:Kelivo/features/provider/pages/model_catalog_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('model_catalog_page_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ModelCatalogService service() {
    return ModelCatalogService(
      loadBundledJson: () async => '{}',
      cacheDirectory: () async => tempDir,
      clientFactory: () => MockClient((_) async => http.Response('{}', 500)),
      prefs: SharedPreferences.getInstance,
    );
  }

  testWidgets('renders status and toggles auto-update via the service', (
    tester,
  ) async {
    final catalog = service()
      ..debugSetData(
        ModelCatalogData(
          schemaVersion: 1,
          generatedAt: DateTime.utc(2026, 9, 16),
          providers: {
            'openai': CatalogProvider(
              id: 'openai',
              name: 'OpenAI',
              models: {
                'gpt-4o': const CatalogModel(id: 'gpt-4o', name: 'GPT-4o'),
                'gpt-4o-mini': const CatalogModel(
                  id: 'gpt-4o-mini',
                  name: 'GPT-4o mini',
                ),
              },
            ),
          },
        ),
        bundled: true,
      );

    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ModelCatalogPage(catalog: catalog),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('model-catalog-page')), findsOneWidget);
    expect(find.text('Model catalog'), findsOneWidget);
    expect(find.text('models.dev'), findsOneWidget);
    expect(find.textContaining('Bundled snapshot'), findsOneWidget);
    expect(find.textContaining('2026-09-16'), findsOneWidget);
    expect(find.text('1 providers'), findsOneWidget);
    expect(find.text('2 models'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Auto-update every 24 hours'), findsOneWidget);

    expect(catalog.autoUpdate, isTrue);
    await tester.tap(find.byKey(const ValueKey('model-catalog-auto-update')));
    await tester.pump();
    expect(catalog.autoUpdate, isFalse);
    expect(tester.widget<IosSwitch>(find.byType(IosSwitch)).value, isFalse);
  });
}
