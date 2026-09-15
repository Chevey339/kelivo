import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/services/api/reasoning/reasoning_level_options.dart';

void main() {
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
}
