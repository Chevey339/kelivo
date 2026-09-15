import '../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:Kelivo/features/chat/widgets/reasoning_level_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';

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

ProviderConfig _budgetConfig() {
  return ProviderConfig(
    id: 'Test',
    enabled: true,
    name: 'Test',
    apiKey: 'test-key',
    baseUrl: 'https://example.com/v1',
    providerType: ProviderKind.claude,
    models: const ['kelivo-test-budget'],
    modelOverrides: const {
      'kelivo-test-budget': {
        'type': 'chat',
        'abilities': ['reasoning'],
        'reasoning': {
          'levels': ['low', 'medium', 'high'],
          'canDisable': true,
          'defaultLevel': 'auto',
          'dialect': 'anthropicBudget',
          'budgets': {'low': 1024, 'medium': 4096, 'high': 8192},
        },
      },
    },
  );
}

Future<SettingsProvider> _settingsWith(
  WidgetTester tester,
  ProviderConfig config,
  String modelId,
) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider(createBusinessTestPreferences());
  await settings.loaded;
  await settings.setProviderConfig(config.id, config);
  await settings.setCurrentModel(config.id, modelId);
  return settings;
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required SettingsProvider settings,
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
}) async {
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
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const ValueKey('open-reasoning-sheet'),
                onPressed: () => showReasoningLevelSheet(
                  context,
                  config: config,
                  modelId: modelId,
                  assistant: assistant,
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-reasoning-sheet')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReasoningLevelSheet', () {
    testWidgets('hides off when canDisable is false', (tester) async {
      final config = _effortConfig();
      final spec = ModelSpecResolver.instance.spec(
        config,
        'kelivo-test-effort',
      );
      expect(spec.supportsReasoning, isTrue);
      expect(spec.reasoning.canDisable, isFalse);
      expect(spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
      ]);

      final settings = await _settingsWith(
        tester,
        config,
        'kelivo-test-effort',
      );
      await _pumpSheet(
        tester,
        settings: settings,
        config: config,
        modelId: 'kelivo-test-effort',
      );
      await _openSheet(tester);

      expect(find.byKey(CustomBottomSheet.panelKey), findsOneWidget);
      expect(find.byKey(const ValueKey('reasoning-row-auto')), findsOneWidget);
      expect(find.byKey(const ValueKey('reasoning-row-off')), findsNothing);
      expect(
        find.byKey(const ValueKey('reasoning-cannot-disable')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reasoning-row-low')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reasoning-row-medium')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reasoning-row-high')), findsOneWidget);
      expect(find.byKey(const ValueKey('reasoning-row-custom')), findsNothing);
      expect(find.text('1024'), findsNothing);
    });

    testWidgets('budget dialect shows budgets and a custom row', (
      tester,
    ) async {
      final config = _budgetConfig();
      final settings = await _settingsWith(
        tester,
        config,
        'kelivo-test-budget',
      );
      await _pumpSheet(
        tester,
        settings: settings,
        config: config,
        modelId: 'kelivo-test-budget',
      );
      await _openSheet(tester);

      expect(find.byKey(const ValueKey('reasoning-row-auto')), findsOneWidget);
      expect(find.byKey(const ValueKey('reasoning-row-off')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reasoning-cannot-disable')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('reasoning-row-custom')),
        findsOneWidget,
      );
      expect(find.text('1024'), findsOneWidget);
      expect(find.text('4096'), findsOneWidget);
      expect(find.text('8192'), findsOneWidget);
    });

    testWidgets('tapping a level row writes setReasoningChoice', (
      tester,
    ) async {
      final config = _effortConfig();
      final settings = await _settingsWith(
        tester,
        config,
        'kelivo-test-effort',
      );
      await _pumpSheet(
        tester,
        settings: settings,
        config: config,
        modelId: 'kelivo-test-effort',
      );
      await _openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('reasoning-row-high')));
      await tester.pumpAndSettle();

      expect(
        settings.reasoningChoiceFor('Test', 'kelivo-test-effort'),
        const ReasoningRequest(ReasoningLevel.high),
      );
    });

    testWidgets('reset clears per-model memory', (tester) async {
      final config = _effortConfig();
      final settings = await _settingsWith(
        tester,
        config,
        'kelivo-test-effort',
      );
      await settings.setReasoningChoice(
        'Test',
        'kelivo-test-effort',
        const ReasoningRequest(ReasoningLevel.low),
      );
      await _pumpSheet(
        tester,
        settings: settings,
        config: config,
        modelId: 'kelivo-test-effort',
      );
      await _openSheet(tester);

      expect(find.byKey(const ValueKey('reasoning-reset')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reasoning-reset')));
      await tester.pumpAndSettle();

      expect(settings.reasoningChoiceFor('Test', 'kelivo-test-effort'), isNull);
    });
  });
}
