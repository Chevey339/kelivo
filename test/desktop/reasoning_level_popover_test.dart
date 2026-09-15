import '../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/reasoning_level_popover.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ProviderConfig _effortConfig() {
  return ProviderConfig(
    id: 'Test',
    enabled: true,
    name: 'Test',
    apiKey: 'test-key',
    baseUrl: 'https://example.com/v1',
    providerType: ProviderKind.openai,
    models: const ['kelivo-test-effort'],
    modelOverrides: const {
      'kelivo-test-effort': {
        'type': 'chat',
        'abilities': ['reasoning'],
        'reasoning': {
          'levels': ['low', 'medium', 'high'],
          'canDisable': false,
          'defaultLevel': 'medium',
          'dialect': 'openaiReasoningEffort',
        },
      },
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop popover lists spec levels and writes the choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final config = _effortConfig();
    await settings.setProviderConfig(config.id, config);
    final anchorKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AssistantProvider>(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                key: anchorKey,
                width: 320,
                height: 48,
                child: Builder(
                  builder: (context) {
                    return TextButton(
                      key: const ValueKey('open-reasoning-popover'),
                      onPressed: () => showDesktopReasoningLevelPopover(
                        context,
                        anchorKey: anchorKey,
                        config: config,
                        modelId: 'kelivo-test-effort',
                      ),
                      child: const Text('open'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-reasoning-popover')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reasoning-row-auto')), findsOneWidget);
    expect(find.byKey(const ValueKey('reasoning-row-off')), findsNothing);
    expect(find.byKey(const ValueKey('reasoning-row-custom')), findsNothing);
    expect(find.byKey(const ValueKey('reasoning-row-high')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reasoning-row-high')));
    await tester.pumpAndSettle();

    expect(
      settings.reasoningChoiceFor('Test', 'kelivo-test-effort'),
      const ReasoningRequest(ReasoningLevel.high),
    );
  });
}
