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
import 'package:Kelivo/core/services/api/reasoning/reasoning_level_options.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:Kelivo/features/chat/widgets/reasoning_level_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/effort_slider.dart';

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
        locale: const Locale('en'),
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

Future<void> _tapStop(WidgetTester tester, String key) async {
  await tester.tapAt(tester.getCenter(find.byKey(ValueKey(key))));
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

      expect(find.byType(CustomBottomSheet), findsNothing);
      expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
      expect(find.byKey(ReasoningPickerSheet.panelKey), findsOneWidget);
      final sheetHeight = tester
          .getSize(find.byKey(ReasoningPickerSheet.panelKey))
          .height;
      final surfaceHeight = tester.getSize(find.byType(MaterialApp)).height;
      expect(sheetHeight, lessThan(surfaceHeight * 0.60));
      expect(find.text('Auto'), findsWidgets);
      expect(find.text('Low'), findsWidgets);
      expect(find.text('Medium'), findsWidgets);
      expect(find.text('High'), findsWidgets);
      expect(find.text('mid'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(EffortSlider),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
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
    });

    testWidgets('budget dialect shows a custom affordance', (tester) async {
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

      await _tapStop(tester, 'reasoning-row-low');
      expect(
        settings.reasoningChoiceFor('Test', 'kelivo-test-budget'),
        const ReasoningRequest(ReasoningLevel.low),
      );
      expect(find.text('Low'), findsWidgets);
      expect(
        find.text('${formatReasoningBudgetK(1024)} tokens'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a level stop writes setReasoningChoice', (
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

      await _tapStop(tester, 'reasoning-row-high');

      expect(
        settings.reasoningChoiceFor('Test', 'kelivo-test-effort'),
        const ReasoningRequest(ReasoningLevel.high),
      );
    });

    testWidgets('custom budget path writes requestForCustomBudget', (
      tester,
    ) async {
      final config = _budgetConfig();
      final spec = ModelSpecResolver.instance.spec(
        config,
        'kelivo-test-budget',
      );
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

      await tester.tap(find.byKey(const ValueKey('reasoning-row-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2048');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        settings.reasoningChoiceFor('Test', 'kelivo-test-budget'),
        requestForCustomBudget(spec, 2048),
      );
      expect(find.text('2048'), findsWidgets);
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
