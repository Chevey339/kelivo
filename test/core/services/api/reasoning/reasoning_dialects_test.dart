import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/api/reasoning/reasoning_dialects.dart';
import 'package:flutter_test/flutter_test.dart';

const _allExplicit = [
  ReasoningLevel.minimal,
  ReasoningLevel.low,
  ReasoningLevel.medium,
  ReasoningLevel.high,
  ReasoningLevel.xhigh,
  ReasoningLevel.max,
];

const _fixedBudgets = {
  ReasoningLevel.minimal: 512,
  ReasoningLevel.low: 1024,
  ReasoningLevel.medium: 4096,
  ReasoningLevel.high: 8192,
  ReasoningLevel.xhigh: 16000,
  ReasoningLevel.max: 32000,
};

const _customPatches = {
  ReasoningLevel.off: {'flag': 'off'},
  ReasoningLevel.minimal: {'flag': 'minimal'},
  ReasoningLevel.low: {'flag': 'low'},
  ReasoningLevel.medium: {'flag': 'medium'},
  ReasoningLevel.high: {'flag': 'high'},
  ReasoningLevel.xhigh: {'flag': 'xhigh'},
  ReasoningLevel.max: {'flag': 'max'},
};

ModelSpec _spec({
  required ReasoningDialect dialect,
  List<ReasoningLevel> levels = _allExplicit,
  bool canDisable = true,
  Map<ReasoningLevel, int> budgets = _fixedBudgets,
  Map<ReasoningLevel, Map<String, dynamic>> customPatches = const {},
  SamplingPolicy sampling = SamplingPolicy.always,
  List<ModelAbility> abilities = const [ModelAbility.reasoning],
}) {
  return ModelSpec(
    id: 'm',
    displayName: 'M',
    abilities: abilities,
    reasoning: ReasoningSpec(
      levels: levels,
      canDisable: canDisable,
      dialect: dialect,
      budgets: budgets,
      customPatches: customPatches,
    ),
    sampling: sampling,
  );
}

ReasoningTransport _nativeTransport(ReasoningDialect dialect) {
  switch (dialect) {
    case ReasoningDialect.openaiResponsesReasoning:
      return ReasoningTransport.responses;
    case ReasoningDialect.anthropicBudget:
    case ReasoningDialect.anthropicAdaptiveEffort:
    case ReasoningDialect.anthropicEffort:
      return ReasoningTransport.anthropicMessages;
    case ReasoningDialect.geminiThinkingBudget:
    case ReasoningDialect.geminiThinkingLevel:
      return ReasoningTransport.geminiGenerateContent;
    default:
      return ReasoningTransport.chatCompletions;
  }
}

bool _isBudgetDialect(ReasoningDialect dialect) {
  switch (dialect) {
    case ReasoningDialect.anthropicBudget:
    case ReasoningDialect.geminiThinkingBudget:
    case ReasoningDialect.qwenEnableThinking:
    case ReasoningDialect.siliconflowEnableThinking:
    case ReasoningDialect.openrouterReasoning:
      return true;
    default:
      return false;
  }
}

ReasoningLevel _lowest(List<ReasoningLevel> levels) {
  return levels.reduce((a, b) => a.index <= b.index ? a : b);
}

ReasoningLevel _effective({
  required ReasoningLevel requested,
  required bool canDisable,
  required List<ReasoningLevel> levels,
  required ReasoningDialect dialect,
}) {
  if (requested == ReasoningLevel.auto) return ReasoningLevel.auto;
  if (requested == ReasoningLevel.off) {
    return canDisable ? ReasoningLevel.off : _lowest(levels);
  }
  if (levels.contains(requested) ||
      (levels.isEmpty && _isBudgetDialect(dialect))) {
    return requested;
  }
  return nearestLevel(requested, levels);
}

Map<String, dynamic> _openaiBody({
  required ReasoningDialect dialect,
  required ReasoningLevel effective,
  required ReasoningTransport transport,
}) {
  final responses = switch (transport) {
    ReasoningTransport.responses => true,
    ReasoningTransport.chatCompletions => false,
    ReasoningTransport.anthropicMessages ||
    ReasoningTransport.geminiGenerateContent =>
      dialect == ReasoningDialect.openaiResponsesReasoning,
  };
  if (effective == ReasoningLevel.auto) {
    if (transport == ReasoningTransport.responses) {
      return {
        'reasoning': {'summary': 'auto'},
      };
    }
    return {};
  }
  final effort = effective == ReasoningLevel.off ? 'none' : effective.name;
  if (responses) {
    return {
      'reasoning': {'effort': effort, 'summary': 'auto'},
    };
  }
  return {'reasoning_effort': effort};
}

Map<String, dynamic> _geminiConfig(Map<String, dynamic> thinkingConfig) {
  return {
    'generationConfig': {'thinkingConfig': thinkingConfig},
  };
}

Map<String, dynamic> _expectedBody({
  required ReasoningDialect dialect,
  required ReasoningLevel requested,
  required bool canDisable,
  required ReasoningTransport transport,
  List<ReasoningLevel> levels = _allExplicit,
  Map<ReasoningLevel, int> budgets = _fixedBudgets,
  int? budgetTokens,
  Map<ReasoningLevel, Map<String, dynamic>> customPatches = const {},
}) {
  if (dialect == ReasoningDialect.none) return {};
  final effective = _effective(
    requested: requested,
    canDisable: canDisable,
    levels: levels,
    dialect: dialect,
  );
  final explicitBudget =
      requested != ReasoningLevel.auto && requested != ReasoningLevel.off
      ? budgetTokens
      : null;
  final budget =
      _isBudgetDialect(dialect) &&
          effective != ReasoningLevel.auto &&
          effective != ReasoningLevel.off
      ? explicitBudget ?? budgets[effective] ?? _fixedBudgets[effective]
      : null;

  switch (dialect) {
    case ReasoningDialect.none:
      return {};
    case ReasoningDialect.openaiReasoningEffort:
    case ReasoningDialect.openaiResponsesReasoning:
      return _openaiBody(
        dialect: dialect,
        effective: effective,
        transport: transport,
      );
    case ReasoningDialect.openrouterReasoning:
      if (effective == ReasoningLevel.auto) return {};
      if (effective == ReasoningLevel.off) {
        return {
          'reasoning': {'enabled': false},
        };
      }
      if (levels.isNotEmpty) {
        return {
          'reasoning': {'effort': effective.name},
        };
      }
      return {
        'reasoning': {'enabled': true, 'max_tokens': budget},
      };
    case ReasoningDialect.anthropicBudget:
      if (effective == ReasoningLevel.auto) return {};
      if (effective == ReasoningLevel.off) {
        return {
          'thinking': {'type': 'disabled'},
        };
      }
      return {
        'thinking': {
          'type': 'enabled',
          // Anthropic's minimum budget.
          'budget_tokens': budget == null || budget < 1024 ? 1024 : budget,
        },
      };
    case ReasoningDialect.anthropicAdaptiveEffort:
      if (effective == ReasoningLevel.off) {
        return {
          'thinking': {'type': 'disabled'},
        };
      }
      return {
        'thinking': {'type': 'adaptive', 'display': 'summarized'},
        if (effective != ReasoningLevel.auto)
          'output_config': {'effort': effective.name},
      };
    case ReasoningDialect.anthropicEffort:
      if (effective == ReasoningLevel.auto) return {};
      if (effective == ReasoningLevel.off) {
        return {
          'thinking': {'type': 'disabled'},
        };
      }
      return {
        'thinking': {'type': 'enabled'},
        'output_config': {'effort': effective.name},
      };
    case ReasoningDialect.geminiThinkingBudget:
      if (effective == ReasoningLevel.auto) {
        return _geminiConfig({'includeThoughts': true});
      }
      if (effective == ReasoningLevel.off) {
        return _geminiConfig({'includeThoughts': false, 'thinkingBudget': 0});
      }
      return _geminiConfig({
        'includeThoughts': requested != ReasoningLevel.off,
        'thinkingBudget': budget,
      });
    case ReasoningDialect.geminiThinkingLevel:
      if (effective == ReasoningLevel.auto) {
        return _geminiConfig({'includeThoughts': true});
      }
      final hide =
          requested == ReasoningLevel.off || effective == ReasoningLevel.off;
      final level = hide ? _lowest(levels) : effective;
      return _geminiConfig({
        'includeThoughts': !hide,
        'thinkingLevel': level.name.toUpperCase(),
      });
    case ReasoningDialect.qwenEnableThinking:
      if (effective == ReasoningLevel.auto) return {};
      if (!canDisable) {
        return {if (budget != null) 'thinking_budget': budget};
      }
      if (effective == ReasoningLevel.off) {
        return {'enable_thinking': false};
      }
      final writeBudget =
          transport != ReasoningTransport.responses &&
          (budgets.isNotEmpty ||
              (requested != ReasoningLevel.auto &&
                  requested != ReasoningLevel.off &&
                  budgetTokens != null));
      return {
        'enable_thinking': true,
        if (writeBudget) 'thinking_budget': budget,
      };
    case ReasoningDialect.siliconflowEnableThinking:
      if (effective == ReasoningLevel.auto) return {};
      if (effective == ReasoningLevel.off) {
        return {'enable_thinking': false};
      }
      return {'thinking_budget': budget};
    case ReasoningDialect.thinkingType:
      if (effective == ReasoningLevel.auto) return {};
      if (transport == ReasoningTransport.responses) {
        return {
          'reasoning': {
            'effort': effective == ReasoningLevel.off ? 'none' : effective.name,
          },
        };
      }
      if (effective == ReasoningLevel.off) {
        return {
          'thinking': {'type': 'disabled'},
        };
      }
      return {
        'thinking': {'type': 'enabled'},
        if (levels.isNotEmpty) 'reasoning_effort': effective.name,
      };
    case ReasoningDialect.kimiThinking:
      if (effective == ReasoningLevel.auto) return {};
      if (effective == ReasoningLevel.off) {
        return {
          'thinking': {'type': 'disabled'},
        };
      }
      return {
        'thinking': {
          'type': 'enabled',
          if (levels.isNotEmpty) 'effort': effective.name,
        },
      };
    case ReasoningDialect.internThinkingMode:
      if (effective == ReasoningLevel.auto) return {};
      return {'thinking_mode': effective != ReasoningLevel.off};
    case ReasoningDialect.chatTemplateKwargs:
      if (effective == ReasoningLevel.auto) return {};
      return {
        'chat_template_kwargs': {
          'enable_thinking': effective != ReasoningLevel.off,
        },
      };
    case ReasoningDialect.custom:
      if (effective == ReasoningLevel.auto) return {};
      final patch = customPatches[effective];
      if (patch == null) return {};
      return Map<String, dynamic>.from(patch);
  }
}

void main() {
  group('applyReasoning table', () {
    for (final dialect in ReasoningDialect.values) {
      for (final level in ReasoningLevel.values) {
        for (final canDisable in [true, false]) {
          test('$dialect $level canDisable=$canDisable', () {
            final patches = dialect == ReasoningDialect.custom
                ? _customPatches
                : const <ReasoningLevel, Map<String, dynamic>>{};
            final spec = _spec(
              dialect: dialect,
              canDisable: canDisable,
              customPatches: patches,
            );
            final transport = _nativeTransport(dialect);
            final body = applyReasoning(
              <String, dynamic>{},
              spec,
              ReasoningRequest(level),
              transport: transport,
            );
            expect(
              body,
              _expectedBody(
                dialect: dialect,
                requested: level,
                canDisable: canDisable,
                transport: transport,
                customPatches: patches,
              ),
            );
          });
        }
      }
    }
  });

  group('nearestLevel', () {
    test('identity when wanted is in the ladder', () {
      expect(
        nearestLevel(ReasoningLevel.medium, const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ]),
        ReasoningLevel.medium,
      );
    });

    test('xhigh on low/medium/high clamps to high', () {
      expect(
        nearestLevel(ReasoningLevel.xhigh, const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ]),
        ReasoningLevel.high,
      );
    });

    test('minimal on low/high clamps to the nearer low', () {
      expect(
        nearestLevel(ReasoningLevel.minimal, const [
          ReasoningLevel.low,
          ReasoningLevel.high,
        ]),
        ReasoningLevel.low,
      );
    });

    test('ties prefer the lower level', () {
      expect(
        nearestLevel(ReasoningLevel.medium, const [
          ReasoningLevel.low,
          ReasoningLevel.high,
        ]),
        ReasoningLevel.low,
      );
    });

    test('empty levels return wanted', () {
      expect(
        nearestLevel(ReasoningLevel.xhigh, const []),
        ReasoningLevel.xhigh,
      );
    });

    test('applyReasoning clamps an out-of-ladder request', () {
      final spec = _spec(
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        budgets: const {},
      );
      expect(
        resolveReasoning(spec, const ReasoningRequest(ReasoningLevel.xhigh)),
        const ReasoningResolution(
          requested: ReasoningLevel.xhigh,
          effective: ReasoningLevel.high,
        ),
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          spec,
          const ReasoningRequest(ReasoningLevel.minimal),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'reasoning_effort': 'low'},
      );
    });
  });

  group('OpenAI transport crossover', () {
    test(
      'openaiReasoningEffort over responses uses the Responses envelope',
      () {
        final spec = _spec(dialect: ReasoningDialect.openaiReasoningEffort);
        expect(
          applyReasoning(
            <String, dynamic>{},
            spec,
            const ReasoningRequest(ReasoningLevel.high),
            transport: ReasoningTransport.responses,
          ),
          {
            'reasoning': {'effort': 'high', 'summary': 'auto'},
          },
        );
        expect(
          applyReasoning(
            <String, dynamic>{},
            spec,
            const ReasoningRequest(ReasoningLevel.auto),
            transport: ReasoningTransport.responses,
          ),
          {
            'reasoning': {'summary': 'auto'},
          },
        );
        expect(
          applyReasoning(
            <String, dynamic>{},
            spec,
            const ReasoningRequest(ReasoningLevel.off),
            transport: ReasoningTransport.responses,
          ),
          {
            'reasoning': {'effort': 'none', 'summary': 'auto'},
          },
        );
      },
    );

    test(
      'openaiResponsesReasoning over chatCompletions writes reasoning_effort',
      () {
        final spec = _spec(dialect: ReasoningDialect.openaiResponsesReasoning);
        expect(
          applyReasoning(
            <String, dynamic>{},
            spec,
            const ReasoningRequest(ReasoningLevel.low),
            transport: ReasoningTransport.chatCompletions,
          ),
          {'reasoning_effort': 'low'},
        );
        expect(
          applyReasoning(
            <String, dynamic>{},
            spec,
            const ReasoningRequest(ReasoningLevel.auto),
            transport: ReasoningTransport.chatCompletions,
          ),
          isEmpty,
        );
        expect(
          applyReasoning(
            <String, dynamic>{},
            spec,
            const ReasoningRequest(ReasoningLevel.off),
            transport: ReasoningTransport.chatCompletions,
          ),
          {'reasoning_effort': 'none'},
        );
      },
    );
  });

  group('budget derivation', () {
    test('spec budgets win over the fixed table', () {
      final spec = _spec(
        dialect: ReasoningDialect.anthropicBudget,
        budgets: const {ReasoningLevel.high: 1234},
      );
      expect(resolveBudget(spec, ReasoningLevel.high), 1234);
      expect(
        resolveReasoning(spec, const ReasoningRequest(ReasoningLevel.high)),
        const ReasoningResolution(
          requested: ReasoningLevel.high,
          effective: ReasoningLevel.high,
          budget: 1234,
        ),
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          spec,
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.anthropicMessages,
        ),
        {
          'thinking': {'type': 'enabled', 'budget_tokens': 1234},
        },
      );
    });

    test('explicit budget wins over spec and table', () {
      final spec = _spec(
        dialect: ReasoningDialect.anthropicBudget,
        budgets: const {ReasoningLevel.low: 2048},
      );
      expect(resolveBudget(spec, ReasoningLevel.low, explicit: 777), 777);
      expect(
        resolveReasoning(
          spec,
          const ReasoningRequest(ReasoningLevel.low, budgetTokens: 777),
        ).budget,
        777,
      );
    });

    test('fixed table is the last resort', () {
      final spec = _spec(
        dialect: ReasoningDialect.anthropicBudget,
        budgets: const {},
      );
      expect(resolveBudget(spec, ReasoningLevel.minimal), 512);
      expect(resolveBudget(spec, ReasoningLevel.low), 1024);
      expect(resolveBudget(spec, ReasoningLevel.medium), 4096);
      expect(resolveBudget(spec, ReasoningLevel.high), 8192);
      expect(resolveBudget(spec, ReasoningLevel.xhigh), 16000);
      expect(resolveBudget(spec, ReasoningLevel.max), 32000);
      expect(resolveBudget(spec, ReasoningLevel.auto), isNull);
      expect(resolveBudget(spec, ReasoningLevel.off), isNull);
    });

    test('empty-level budget dialect keeps the requested explicit level', () {
      final spec = _spec(
        dialect: ReasoningDialect.openrouterReasoning,
        levels: const [],
      );
      expect(
        resolveReasoning(spec, const ReasoningRequest(ReasoningLevel.high)),
        const ReasoningResolution(
          requested: ReasoningLevel.high,
          effective: ReasoningLevel.high,
          budget: 8192,
        ),
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          spec,
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'reasoning': {'enabled': true, 'max_tokens': 8192},
        },
      );
    });

    test('qwen writes thinking_budget only when spec or request has one', () {
      final noBudgets = _spec(
        dialect: ReasoningDialect.qwenEnableThinking,
        budgets: const {},
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          noBudgets,
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'enable_thinking': true},
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          noBudgets,
          const ReasoningRequest(ReasoningLevel.high, budgetTokens: 2222),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'enable_thinking': true, 'thinking_budget': 2222},
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          noBudgets,
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.responses,
        ),
        {'enable_thinking': true},
      );
    });

    test('effort dialects do not expose a resolved budget', () {
      final spec = _spec(dialect: ReasoningDialect.openaiReasoningEffort);
      expect(
        resolveReasoning(spec, const ReasoningRequest(ReasoningLevel.high)),
        const ReasoningResolution(
          requested: ReasoningLevel.high,
          effective: ReasoningLevel.high,
        ),
      );
    });
  });

  group('stale-key removal', () {
    test('explicit level strips only the effective dialect keys', () {
      final dirty = <String, dynamic>{
        'model': 'kept',
        'reasoning_effort': 'high',
        'reasoning': {'effort': 'high', 'enabled': true, 'max_tokens': 9},
        'thinking': {'type': 'enabled', 'budget_tokens': 9, 'effort': 'high'},
        'output_config': {'effort': 'high'},
        'enable_thinking': true,
        'thinking_budget': 999,
        'thinking_mode': false,
        'chat_template_kwargs': {'enable_thinking': true, 'other': 1},
        'generationConfig': {
          'thinkingConfig': {'includeThoughts': true, 'thinkingBudget': 9},
          'temperature': 0.2,
        },
      };
      final body = applyReasoning(
        dirty,
        _spec(dialect: ReasoningDialect.internThinkingMode),
        const ReasoningRequest(ReasoningLevel.high),
        transport: ReasoningTransport.chatCompletions,
      );
      expect(body, {
        'model': 'kept',
        'reasoning_effort': 'high',
        'reasoning': {'effort': 'high', 'enabled': true, 'max_tokens': 9},
        'thinking': {'type': 'enabled', 'budget_tokens': 9, 'effort': 'high'},
        'output_config': {'effort': 'high'},
        'enable_thinking': true,
        'thinking_budget': 999,
        'thinking_mode': true,
        'chat_template_kwargs': {'enable_thinking': true, 'other': 1},
        'generationConfig': {
          'thinkingConfig': {'includeThoughts': true, 'thinkingBudget': 9},
          'temperature': 0.2,
        },
      });
    });
  });

  group('custom patches', () {
    test('\$remove deletes dotted paths before a nested merge', () {
      final spec = _spec(
        dialect: ReasoningDialect.custom,
        customPatches: {
          ReasoningLevel.high: {
            r'$remove': ['stale.path', 'top'],
            'keep': 'yes',
            'nested': {'b': 2},
          },
        },
      );
      final body = applyReasoning(
        <String, dynamic>{
          'top': 1,
          'stale': {'path': true, 'left': true},
          'nested': {'a': 1},
          'reasoning_effort': 'gone',
        },
        spec,
        const ReasoningRequest(ReasoningLevel.high),
        transport: ReasoningTransport.chatCompletions,
      );
      expect(body, {
        'stale': {'left': true},
        'keep': 'yes',
        'nested': {'a': 1, 'b': 2},
        'reasoning_effort': 'gone',
      });
    });

    test('auto applies no patch and does not strip', () {
      final spec = _spec(
        dialect: ReasoningDialect.custom,
        customPatches: _customPatches,
      );
      expect(
        applyReasoning(
          <String, dynamic>{'reasoning_effort': 'high', 'flag': 'old'},
          spec,
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'reasoning_effort': 'high', 'flag': 'old'},
      );
    });
  });

  group('applySamplingPolicy', () {
    Map<String, dynamic> seeded() => {
      'temperature': 0.5,
      'top_p': 0.9,
      'top_k': 20,
      'logprobs': true,
      'top_logprobs': 2,
      'generationConfig': {
        'temperature': 0.5,
        'topP': 0.9,
        'topK': 20,
        'extra': 1,
      },
    };

    const off = ReasoningResolution(
      requested: ReasoningLevel.off,
      effective: ReasoningLevel.off,
    );
    const auto = ReasoningResolution(
      requested: ReasoningLevel.auto,
      effective: ReasoningLevel.auto,
    );
    const high = ReasoningResolution(
      requested: ReasoningLevel.high,
      effective: ReasoningLevel.high,
    );

    test('always is a no-op on every transport', () {
      final spec = _spec(
        dialect: ReasoningDialect.openaiReasoningEffort,
        sampling: SamplingPolicy.always,
      );
      for (final transport in ReasoningTransport.values) {
        expect(
          applySamplingPolicy(seeded(), spec, high, transport: transport),
          seeded(),
        );
      }
    });

    test('never strips the keys for each transport', () {
      final spec = _spec(
        dialect: ReasoningDialect.openaiReasoningEffort,
        sampling: SamplingPolicy.never,
      );
      expect(
        applySamplingPolicy(
          seeded(),
          spec,
          off,
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'generationConfig': {
            'temperature': 0.5,
            'topP': 0.9,
            'topK': 20,
            'extra': 1,
          },
        },
      );
      expect(
        applySamplingPolicy(
          seeded(),
          spec,
          high,
          transport: ReasoningTransport.responses,
        ),
        {
          'generationConfig': {
            'temperature': 0.5,
            'topP': 0.9,
            'topK': 20,
            'extra': 1,
          },
        },
      );
      expect(
        applySamplingPolicy(
          seeded(),
          spec,
          off,
          transport: ReasoningTransport.anthropicMessages,
        ),
        {
          'logprobs': true,
          'top_logprobs': 2,
          'generationConfig': {
            'temperature': 0.5,
            'topP': 0.9,
            'topK': 20,
            'extra': 1,
          },
        },
      );
      expect(
        applySamplingPolicy(
          seeded(),
          spec,
          high,
          transport: ReasoningTransport.geminiGenerateContent,
        ),
        {
          'temperature': 0.5,
          'top_p': 0.9,
          'top_k': 20,
          'logprobs': true,
          'top_logprobs': 2,
          'generationConfig': {'extra': 1},
        },
      );
    });

    test('onlyWhenReasoningOff strips unless effective is off', () {
      final spec = _spec(
        dialect: ReasoningDialect.openaiReasoningEffort,
        sampling: SamplingPolicy.onlyWhenReasoningOff,
      );
      expect(
        applySamplingPolicy(
          seeded(),
          spec,
          off,
          transport: ReasoningTransport.chatCompletions,
        ),
        seeded(),
      );
      expect(
        applySamplingPolicy(
          seeded(),
          spec,
          auto,
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'generationConfig': {
            'temperature': 0.5,
            'topP': 0.9,
            'topK': 20,
            'extra': 1,
          },
        },
      );
      expect(
        applySamplingPolicy(
          seeded(),
          spec,
          high,
          transport: ReasoningTransport.anthropicMessages,
        ),
        {
          'logprobs': true,
          'top_logprobs': 2,
          'generationConfig': {
            'temperature': 0.5,
            'topP': 0.9,
            'topK': 20,
            'extra': 1,
          },
        },
      );
    });
  });

  group('no reasoning ability', () {
    test('leaves the body untouched', () {
      final dirty = <String, dynamic>{
        'reasoning_effort': 'high',
        'thinking': {'type': 'enabled'},
      };
      final spec = _spec(
        dialect: ReasoningDialect.openaiReasoningEffort,
        abilities: const [],
      );
      expect(spec.supportsReasoning, isFalse);
      expect(
        applyReasoning(
          dirty,
          spec,
          const ReasoningRequest(ReasoningLevel.off),
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'reasoning_effort': 'high',
          'thinking': {'type': 'enabled'},
        },
      );
    });

    test('auto does not write surface flags', () {
      final spec = _spec(
        dialect: ReasoningDialect.geminiThinkingBudget,
        abilities: const [],
      );
      expect(spec.supportsReasoning, isFalse);
      expect(
        applyReasoning(
          <String, dynamic>{},
          spec,
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.geminiGenerateContent,
        ),
        isEmpty,
      );
    });
  });

  group('resolveReasoning', () {
    test('auto stays auto and counts as thinkingEnabled', () {
      final resolution = resolveReasoning(
        _spec(dialect: ReasoningDialect.anthropicBudget),
        const ReasoningRequest(ReasoningLevel.auto),
      );
      expect(resolution.effective, ReasoningLevel.auto);
      expect(resolution.budget, isNull);
      expect(resolution.thinkingEnabled, isTrue);
    });

    test('off is kept only when canDisable', () {
      expect(
        resolveReasoning(
          _spec(dialect: ReasoningDialect.thinkingType, canDisable: true),
          const ReasoningRequest(ReasoningLevel.off),
        ).effective,
        ReasoningLevel.off,
      );
      expect(
        resolveReasoning(
          _spec(dialect: ReasoningDialect.thinkingType, canDisable: false),
          const ReasoningRequest(ReasoningLevel.off),
        ).effective,
        ReasoningLevel.minimal,
      );
    });

    test('off without canDisable uses the lowest advertised level', () {
      final spec = _spec(
        dialect: ReasoningDialect.thinkingType,
        canDisable: false,
        levels: const [ReasoningLevel.low, ReasoningLevel.high],
        budgets: const {},
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          spec,
          const ReasoningRequest(ReasoningLevel.off),
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'thinking': {'type': 'enabled'},
          'reasoning_effort': 'low',
        },
      );
    });
  });

  group('qwen thinking-only and thinkingType Responses', () {
    test('qwen !canDisable writes only thinking_budget', () {
      final spec = _spec(
        dialect: ReasoningDialect.qwenEnableThinking,
        canDisable: false,
      );
      expect(
        applyReasoning(
          <String, dynamic>{'enable_thinking': true},
          spec,
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'thinking_budget': 8192},
      );
    });

    test(
      'qwen !canDisable off uses the lowest budget and omits enable_thinking',
      () {
        final spec = _spec(
          dialect: ReasoningDialect.qwenEnableThinking,
          canDisable: false,
        );
        expect(
          applyReasoning(
            <String, dynamic>{'enable_thinking': false},
            spec,
            const ReasoningRequest(ReasoningLevel.off),
            transport: ReasoningTransport.chatCompletions,
          ),
          {'thinking_budget': 512},
        );
      },
    );

    test('thinkingType over responses writes reasoning.effort', () {
      final spec = _spec(dialect: ReasoningDialect.thinkingType);
      expect(
        applyReasoning(
          <String, dynamic>{
            'thinking': {'type': 'enabled'},
            'reasoning_effort': 'low',
          },
          spec,
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.responses,
        ),
        {
          'thinking': {'type': 'enabled'},
          'reasoning_effort': 'low',
          'reasoning': {'effort': 'high'},
        },
      );
    });

    test('thinkingType over responses off writes effort none', () {
      final spec = _spec(dialect: ReasoningDialect.thinkingType);
      expect(
        applyReasoning(
          <String, dynamic>{
            'thinking': {'type': 'enabled'},
          },
          spec,
          const ReasoningRequest(ReasoningLevel.off),
          transport: ReasoningTransport.responses,
        ),
        {
          'thinking': {'type': 'enabled'},
          'reasoning': {'effort': 'none'},
        },
      );
    });
  });

  group('empty-level effort dialects', () {
    test('thinkingType and kimiThinking omit effort when levels is empty', () {
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(
            dialect: ReasoningDialect.thinkingType,
            levels: const [],
            budgets: const {},
          ),
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'thinking': {'type': 'enabled'},
        },
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(
            dialect: ReasoningDialect.kimiThinking,
            levels: const [],
            budgets: const {},
          ),
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'thinking': {'type': 'enabled'},
        },
      );
    });
  });

  group('extraBody survival', () {
    test('user-provided reasoning_effort survives auto', () {
      expect(
        applyReasoning(
          <String, dynamic>{'reasoning_effort': 'high', 'keep': true},
          _spec(dialect: ReasoningDialect.openaiReasoningEffort),
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'reasoning_effort': 'high', 'keep': true},
      );
    });

    test('auto does not clobber a user thinking map on an OpenAI dialect', () {
      expect(
        applyReasoning(
          <String, dynamic>{
            'thinking': {'type': 'enabled', 'effort': 'low'},
          },
          _spec(dialect: ReasoningDialect.openaiReasoningEffort),
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'thinking': {'type': 'enabled', 'effort': 'low'},
        },
      );
    });

    test(
      'Gemini auto keeps a user thinkingBudget and adds includeThoughts',
      () {
        expect(
          applyReasoning(
            <String, dynamic>{
              'generationConfig': {
                'thinkingConfig': {'thinkingBudget': 2048},
              },
            },
            _spec(dialect: ReasoningDialect.geminiThinkingBudget),
            const ReasoningRequest(ReasoningLevel.auto),
            transport: ReasoningTransport.geminiGenerateContent,
          ),
          {
            'generationConfig': {
              'thinkingConfig': {
                'thinkingBudget': 2048,
                'includeThoughts': true,
              },
            },
          },
        );
      },
    );

    test('explicit level replaces the user value for the owned key', () {
      expect(
        applyReasoning(
          <String, dynamic>{'reasoning_effort': 'low'},
          _spec(dialect: ReasoningDialect.openaiReasoningEffort),
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'reasoning_effort': 'high'},
      );
    });

    test('explicit level leaves unrelated dialect keys alone', () {
      expect(
        applyReasoning(
          <String, dynamic>{
            'reasoning_effort': 'low',
            'thinking': {'type': 'enabled'},
            'enable_thinking': true,
          },
          _spec(dialect: ReasoningDialect.openaiReasoningEffort),
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'reasoning_effort': 'high',
          'thinking': {'type': 'enabled'},
          'enable_thinking': true,
        },
      );
    });

    test('Responses auto keeps a user effort and adds summary if absent', () {
      expect(
        applyReasoning(
          <String, dynamic>{
            'reasoning': {'effort': 'high'},
          },
          _spec(dialect: ReasoningDialect.openaiResponsesReasoning),
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.responses,
        ),
        {
          'reasoning': {'effort': 'high', 'summary': 'auto'},
        },
      );
    });

    test('adaptive auto does not replace a user thinking map', () {
      expect(
        applyReasoning(
          <String, dynamic>{
            'thinking': {'type': 'enabled'},
          },
          _spec(dialect: ReasoningDialect.anthropicAdaptiveEffort),
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.anthropicMessages,
        ),
        {
          'thinking': {'type': 'enabled'},
        },
      );
    });
  });

  group('literal dialect shapes', () {
    test('spot-checks a representative body per dialect', () {
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(dialect: ReasoningDialect.openaiReasoningEffort),
          const ReasoningRequest(ReasoningLevel.medium),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'reasoning_effort': 'medium'},
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(dialect: ReasoningDialect.openaiResponsesReasoning),
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.responses,
        ),
        {
          'reasoning': {'summary': 'auto'},
        },
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(dialect: ReasoningDialect.anthropicAdaptiveEffort),
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.anthropicMessages,
        ),
        {
          'thinking': {'type': 'adaptive', 'display': 'summarized'},
        },
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(dialect: ReasoningDialect.anthropicEffort),
          const ReasoningRequest(ReasoningLevel.max),
          transport: ReasoningTransport.anthropicMessages,
        ),
        {
          'thinking': {'type': 'enabled'},
          'output_config': {'effort': 'max'},
        },
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(
            dialect: ReasoningDialect.geminiThinkingBudget,
            canDisable: false,
          ),
          const ReasoningRequest(ReasoningLevel.off),
          transport: ReasoningTransport.geminiGenerateContent,
        ),
        {
          'generationConfig': {
            'thinkingConfig': {'includeThoughts': false, 'thinkingBudget': 512},
          },
        },
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(dialect: ReasoningDialect.geminiThinkingLevel),
          const ReasoningRequest(ReasoningLevel.high),
          transport: ReasoningTransport.geminiGenerateContent,
        ),
        {
          'generationConfig': {
            'thinkingConfig': {
              'includeThoughts': true,
              'thinkingLevel': 'HIGH',
            },
          },
        },
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          _spec(dialect: ReasoningDialect.siliconflowEnableThinking),
          const ReasoningRequest(ReasoningLevel.low),
          transport: ReasoningTransport.chatCompletions,
        ),
        {'thinking_budget': 1024},
      );
      expect(
        applyReasoning(
          <String, dynamic>{
            'chat_template_kwargs': {'foo': 'bar'},
          },
          _spec(dialect: ReasoningDialect.chatTemplateKwargs),
          const ReasoningRequest(ReasoningLevel.off),
          transport: ReasoningTransport.chatCompletions,
        ),
        {
          'chat_template_kwargs': {'foo': 'bar', 'enable_thinking': false},
        },
      );
    });
  });
}
