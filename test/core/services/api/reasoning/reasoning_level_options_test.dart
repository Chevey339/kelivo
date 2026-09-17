import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/reasoning/reasoning_level_options.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';

import '../../../../support/business_test_harness.dart';

void main() {
  test(
    'picker selection follows effective levels for inherited and saved choices',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      final config = ProviderConfig(
        id: 'Test',
        enabled: true,
        name: 'Test',
        apiKey: '',
        baseUrl: '',
        modelOverrides: const {
          'model': {
            'abilities': ['reasoning'],
            'reasoning': {
              'dialect': 'openaiReasoningEffort',
              'levels': ['low', 'high'],
              'canDisable': false,
            },
          },
        },
      );
      final spec = ModelSpecResolver.instance.spec(config, 'model');
      for (final saved in [false, true]) {
        for (final (requested, effective) in [
          (ReasoningLevel.max, ReasoningLevel.high),
          (ReasoningLevel.off, ReasoningLevel.low),
          (ReasoningLevel.auto, ReasoningLevel.auto),
        ]) {
          final request = ReasoningRequest(requested);
          await settings.setReasoningChoice(
            'Test',
            'model',
            saved ? request : null,
          );
          final snapshot = buildReasoningLevelPickerSnapshot(
            settings: settings,
            config: config,
            modelId: 'model',
            spec: spec,
            assistant: Assistant(id: 'a', name: 'A', reasoning: request),
          );
          expect(
            snapshot.rows.where(snapshot.isSelected).single.level,
            effective,
          );
          expect(snapshot.sliderStops[snapshot.sliderIndex].level, effective);
        }
      }
    },
  );

  test(
    'openrouter with levels is effort-style; empty levels is budget-style',
    () {
      expect(
        isBudgetStylePicker(
          const ReasoningSpec(
            dialect: ReasoningDialect.openrouterReasoning,
            levels: [ReasoningLevel.low, ReasoningLevel.high],
          ),
        ),
        isFalse,
      );
      expect(
        isBudgetStylePicker(
          const ReasoningSpec(dialect: ReasoningDialect.openrouterReasoning),
        ),
        isTrue,
      );
      expect(
        isBudgetStylePicker(
          const ReasoningSpec(dialect: ReasoningDialect.anthropicBudget),
        ),
        isTrue,
      );
      expect(
        isBudgetStylePicker(
          const ReasoningSpec(dialect: ReasoningDialect.openaiReasoningEffort),
        ),
        isFalse,
      );
    },
  );

  test('custom budget picks the nearest spec level', () {
    final spec = ModelSpec(
      id: 'm',
      displayName: 'm',
      abilities: const [ModelAbility.reasoning],
      reasoning: const ReasoningSpec(
        dialect: ReasoningDialect.anthropicBudget,
        levels: [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        budgets: {
          ReasoningLevel.low: 1024,
          ReasoningLevel.medium: 4096,
          ReasoningLevel.high: 8192,
        },
      ),
    );
    expect(levelForCustomBudget(spec, 2048), ReasoningLevel.low);
    expect(levelForCustomBudget(spec, 3000), ReasoningLevel.medium);
    expect(
      requestForCustomBudget(spec, 2048),
      const ReasoningRequest(ReasoningLevel.low, budgetTokens: 2048),
    );
  });

  test(
    'custom selection requires a budget that differs from the level default',
    () {
      final spec = ModelSpec(
        id: 'm',
        displayName: 'm',
        abilities: const [ModelAbility.reasoning],
        reasoning: const ReasoningSpec(
          dialect: ReasoningDialect.anthropicBudget,
          levels: [ReasoningLevel.low],
          budgets: {ReasoningLevel.low: 1024},
        ),
      );
      expect(
        isCustomBudgetSelection(
          spec,
          const ReasoningRequest(ReasoningLevel.low),
        ),
        isFalse,
      );
      expect(
        isCustomBudgetSelection(
          spec,
          const ReasoningRequest(ReasoningLevel.low, budgetTokens: 1024),
        ),
        isFalse,
      );
      expect(
        isCustomBudgetSelection(
          spec,
          const ReasoningRequest(ReasoningLevel.low, budgetTokens: 2048),
        ),
        isTrue,
      );
    },
  );

  test(
    'sliderStops omit custom and park a custom budget on the nearest level',
    () {
      final spec = ModelSpec(
        id: 'm',
        displayName: 'm',
        abilities: const [ModelAbility.reasoning],
        reasoning: const ReasoningSpec(
          dialect: ReasoningDialect.anthropicBudget,
          levels: [
            ReasoningLevel.low,
            ReasoningLevel.medium,
            ReasoningLevel.high,
          ],
          budgets: {
            ReasoningLevel.low: 1024,
            ReasoningLevel.medium: 4096,
            ReasoningLevel.high: 8192,
          },
        ),
      );
      const rows = [
        ReasoningLevelRow(
          kind: ReasoningLevelRowKind.auto,
          key: 'reasoning-row-auto',
          level: ReasoningLevel.auto,
          request: ReasoningRequest.auto,
        ),
        ReasoningLevelRow(
          kind: ReasoningLevelRowKind.off,
          key: 'reasoning-row-off',
          level: ReasoningLevel.off,
          request: ReasoningRequest.off,
        ),
        ReasoningLevelRow(
          kind: ReasoningLevelRowKind.level,
          key: 'reasoning-row-low',
          level: ReasoningLevel.low,
          request: ReasoningRequest(ReasoningLevel.low),
          budget: 1024,
        ),
        ReasoningLevelRow(
          kind: ReasoningLevelRowKind.level,
          key: 'reasoning-row-medium',
          level: ReasoningLevel.medium,
          request: ReasoningRequest(ReasoningLevel.medium),
          budget: 4096,
        ),
        ReasoningLevelRow(
          kind: ReasoningLevelRowKind.custom,
          key: 'reasoning-row-custom',
        ),
      ];
      final snapshot = ReasoningLevelPickerSnapshot(
        spec: spec,
        selected: const ReasoningRequest(
          ReasoningLevel.low,
          budgetTokens: 2048,
        ),
        source: ReasoningChoiceSource.perModel,
        hasPerModelMemory: true,
        isBudgetStyle: true,
        customSelected: true,
        rows: rows,
      );
      expect(snapshot.sliderStops.map((row) => row.kind), [
        ReasoningLevelRowKind.off,
        ReasoningLevelRowKind.auto,
        ReasoningLevelRowKind.level,
        ReasoningLevelRowKind.level,
      ]);
      expect(snapshot.sliderIndex, 2);
    },
  );

  test(
    'commitReasoningChoice clears memory when the request matches fallback',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      final config = ProviderConfig(
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
      await settings.setProviderConfig(config.id, config);
      await settings.setReasoningChoice(
        config.id,
        'kelivo-test-effort',
        const ReasoningRequest(ReasoningLevel.high),
      );

      await commitReasoningChoice(
        settings,
        config,
        'kelivo-test-effort',
        null,
        const ReasoningRequest(ReasoningLevel.medium),
      );
      expect(
        settings.reasoningChoiceFor(config.id, 'kelivo-test-effort'),
        isNull,
      );

      await commitReasoningChoice(
        settings,
        config,
        'kelivo-test-effort',
        null,
        const ReasoningRequest(ReasoningLevel.high),
      );
      expect(
        settings.reasoningChoiceFor(config.id, 'kelivo-test-effort'),
        const ReasoningRequest(ReasoningLevel.high),
      );

      const assistant = Assistant(
        id: 'a',
        name: 'A',
        reasoning: ReasoningRequest(ReasoningLevel.low),
      );
      await commitReasoningChoice(
        settings,
        config,
        'kelivo-test-effort',
        assistant,
        const ReasoningRequest(ReasoningLevel.low),
      );
      expect(
        settings.reasoningChoiceFor(config.id, 'kelivo-test-effort'),
        isNull,
      );
    },
  );
}
