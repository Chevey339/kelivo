import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/desktop/search_provider_popover.dart';
import 'package:Kelivo/features/search/widgets/search_settings_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';

const _providerKey = 'Gemini';
const _modelId = 'gemini-test';

class _Fixture {
  const _Fixture({required this.settings, required this.assistants});

  final SettingsProvider settings;
  final AssistantProvider assistants;
}

Future<_Fixture> _createFixture() async {
  final harness = await createBusinessTestHarness();
  final settings = SettingsProvider(harness.preferences);
  final assistants = AssistantProvider(preferences: harness.preferences);
  await Future.wait([settings.loaded, assistants.loaded]);

  await settings.setProviderConfig(
    _providerKey,
    ProviderConfig(
      id: _providerKey,
      enabled: true,
      name: _providerKey,
      apiKey: '',
      baseUrl: '',
      providerType: ProviderKind.google,
      models: const [_modelId],
      modelOverrides: const {
        _modelId: {
          'builtInTools': [BuiltInToolNames.search],
        },
      },
    ),
  );
  await settings.setCurrentModel(_providerKey, _modelId);
  final assistantId = await assistants.addAssistant(name: 'Test');
  await assistants.setCurrentAssistant(assistantId);

  return _Fixture(settings: settings, assistants: assistants);
}

Widget _app({required _Fixture fixture, required Widget home}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: fixture.settings),
      ChangeNotifierProvider<AssistantProvider>.value(
        value: fixture.assistants,
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );
}

void _expectExternalSearchEnabled(_Fixture fixture) {
  expect(fixture.assistants.currentSearchEnabled, isTrue);
  expect(
    BuiltInToolsHelper.isBuiltInSearchEnabled(
      cfg: fixture.settings.getProviderConfig(_providerKey),
      modelId: _modelId,
    ),
    isFalse,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mobile sheet keeps external providers visible and switches modes',
    (tester) async {
      final fixture = await _createFixture();

      await tester.pumpWidget(
        _app(
          fixture: fixture,
          home: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showSearchSettingsSheet(
                  context,
                  chatModelProviderKey: _providerKey,
                  chatModelId: _modelId,
                ),
                child: const Text('Open mobile search'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open mobile search'));
      await tester.pumpAndSettle();

      expect(find.text('Built-in Search'), findsOneWidget);
      expect(find.text('Web Search'), findsOneWidget);
      expect(find.text('Bing (Local)'), findsOneWidget);

      await tester.tap(find.text('Bing (Local)'));
      await tester.pumpAndSettle();

      _expectExternalSearchEnabled(fixture);
    },
  );

  testWidgets(
    'desktop popover keeps external providers visible and switches modes',
    (tester) async {
      final fixture = await _createFixture();
      final anchorKey = GlobalKey();

      await tester.pumpWidget(
        _app(
          fixture: fixture,
          home: Align(
            alignment: Alignment.bottomCenter,
            child: Builder(
              builder: (context) => SizedBox(
                key: anchorKey,
                width: 500,
                height: 48,
                child: FilledButton(
                  onPressed: () => showDesktopSearchProviderPopover(
                    context,
                    anchorKey: anchorKey,
                    chatModelProviderKey: _providerKey,
                    chatModelId: _modelId,
                  ),
                  child: const Text('Open desktop search'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open desktop search'));
      await tester.pumpAndSettle();

      expect(find.text('Built-in Search'), findsOneWidget);
      expect(find.text('Bing (Local)'), findsOneWidget);

      await tester.tap(find.text('Bing (Local)'));
      await tester.pumpAndSettle();

      _expectExternalSearchEnabled(fixture);
    },
  );
}
