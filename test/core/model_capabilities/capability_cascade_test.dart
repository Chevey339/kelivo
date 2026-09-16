import 'package:Kelivo/core/model_capabilities/builtin_model_rules.dart';
import 'package:Kelivo/core/model_capabilities/capability_cascade.dart';
import 'package:Kelivo/core/model_capabilities/model_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

CapabilityResolution _resolve(
  List<ModelRule> rules,
  String modelId, {
  ProviderContext? provider,
}) {
  return CapabilityCascade.builtin(rules).resolve(modelId, provider: provider);
}

void main() {
  group('merge', () {
    final rules = <ModelRule>[
      const ModelRule(
        'gpt',
        group: 'GPT',
        icon: 'openai',
        toolCall: true,
        reasoning: true,
      ),
      const ModelRule(
        '^gpt 5 2',
        temperature: false,
        reasoningOptions: <ReasoningOption>[
          ReasoningOption.effort(<String>[
            'none',
            'low',
            'medium',
            'high',
            'xhigh',
          ]),
        ],
      ),
    ];

    test('narrow rules fill fields the broad rule left absent', () {
      final result = _resolve(rules, 'gpt-5.2');
      expect(result.capabilities.group, 'GPT');
      expect(result.capabilities.icon, 'openai');
      expect(result.capabilities.toolCall, isTrue);
      expect(result.capabilities.reasoning, isTrue);
      expect(result.capabilities.temperature, isFalse);
      expect(result.capabilities.reasoningOptions!.single.values, <String>[
        'none',
        'low',
        'medium',
        'high',
        'xhigh',
      ]);
      expect(
        result.provenance[CapabilityField.group],
        CapabilityOrigin.builtin,
      );
      expect(result.conflicts, isEmpty);
    });

    test('future SKUs inherit the broad family defaults', () {
      final result = _resolve(rules, 'gpt-7-ultra');
      expect(result.capabilities.group, 'GPT');
      expect(result.capabilities.toolCall, isTrue);
      expect(result.capabilities.reasoning, isTrue);
      expect(result.capabilities.temperature, isNull);
      expect(result.capabilities.reasoningOptions, isNull);
    });

    test('returns no match for unrelated ids', () {
      final result = _resolve(rules, 'llama-3.1-8b');
      expect(result.matched, isFalse);
      expect(result.capabilities.isEmpty, isTrue);
    });
  });

  group('clear and mask', () {
    test('clear unsets a field declared by a broader rule', () {
      final rules = <ModelRule>[
        const ModelRule(
          '^gpt 5',
          temperature: false,
          reasoningOptions: <ReasoningOption>[
            ReasoningOption.effort(<String>['none', 'low', 'medium', 'high']),
          ],
        ),
        const ModelRule(
          '^gpt 5 3',
          clear: <CapabilityField>{CapabilityField.reasoningOptions},
        ),
      ];
      final result = _resolve(rules, 'gpt-5.3');
      expect(result.capabilities.temperature, isFalse);
      expect(result.capabilities.reasoningOptions, isNull);
    });

    test('mask drops capabilities but keeps identity fields', () {
      final rules = <ModelRule>[
        const ModelRule('gpt', group: 'GPT', icon: 'openai', toolCall: true),
        const ModelRule('^gpt 5 3', mask: true),
      ];
      final result = _resolve(rules, 'gpt-5.3');
      expect(result.capabilities.group, 'GPT');
      expect(result.capabilities.icon, 'openai');
      expect(result.capabilities.toolCall, isNull);
    });
  });

  group('origin precedence', () {
    test('a broad user rule beats a specific builtin rule', () {
      final cascade = CapabilityCascade(<CapabilityRuleEntry>[
        const CapabilityRuleEntry(
          ModelRule('^gpt 5 2', temperature: false),
          origin: CapabilityOrigin.builtin,
          order: 0,
        ),
        const CapabilityRuleEntry(
          ModelRule('gpt 5 2', temperature: true),
          origin: CapabilityOrigin.user,
          order: 1,
        ),
      ]);
      final result = cascade.resolve('gpt-5.2');
      expect(result.capabilities.temperature, isTrue);
      expect(
        result.provenance[CapabilityField.temperature],
        CapabilityOrigin.user,
      );
    });
  });

  group('provider scope', () {
    final rules = <ModelRule>[
      const ModelRule(
        'kimi k 2 7 code',
        on: 'dashscope',
        quirks: <CapabilityQuirk>{CapabilityQuirk.reasoningAlwaysOn},
      ),
    ];

    test('scoped rules require a matching provider', () {
      expect(_resolve(rules, 'kimi-k2.7-code').matched, isFalse);
      expect(
        _resolve(
          rules,
          'kimi-k2.7-code',
          provider: const ProviderContext(
            providerId: 'openrouter',
            baseUrl: 'https://openrouter.ai/api/v1',
          ),
        ).matched,
        isFalse,
      );
    });

    test('scoped rules match host identities', () {
      final result = _resolve(
        rules,
        'kimi-k2.7-code',
        provider: const ProviderContext(
          providerId: 'custom',
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        ),
      );
      expect(result.matched, isTrue);
      expect(
        result.capabilities.quirks,
        contains(CapabilityQuirk.reasoningAlwaysOn),
      );
    });
  });

  group('conflicts', () {
    test('reports equal-specificity disagreements', () {
      final result = _resolve(const <ModelRule>[
        ModelRule('^gpt 5 2', temperature: false),
        ModelRule('^gpt 5 2', temperature: true),
      ], 'gpt-5.2');
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.single.field, CapabilityField.temperature);
      expect(result.capabilities.temperature, isFalse);
    });

    test('does not report agreement as a conflict', () {
      final result = _resolve(const <ModelRule>[
        ModelRule('^gpt 5 2', temperature: false),
        ModelRule('^gpt 5 2', temperature: false),
      ], 'gpt-5.2');
      expect(result.conflicts, isEmpty);
    });
  });

  group('builtin table', () {
    test('gpt-5.2 declares conditional sampling and the xhigh stop', () {
      final caps = builtinCapabilityCascade
          .resolve('openai/gpt-5.2-2028-01-01')
          .capabilities;
      expect(caps.temperature, isNull);
      expect(caps.reasoningOptions!.single.values, contains('xhigh'));
      expect(caps.quirks, contains(CapabilityQuirk.samplingRequiresNoThinking));
    });

    test('gpt-5.3 keeps identity but loses reasoning options', () {
      final caps = builtinCapabilityCascade.resolve('gpt-5.3').capabilities;
      expect(caps.group, 'GPT');
      expect(caps.toolCall, isTrue);
      expect(caps.reasoningOptions, isNull);
      expect(caps.quirks, isNull);
    });

    test('gpt-5.3-codex keeps its codex reasoning', () {
      final caps = builtinCapabilityCascade
          .resolve('gpt-5.3-codex')
          .capabilities;
      expect(caps.reasoningOptions!.single.values, <String>[
        'low',
        'medium',
        'high',
        'xhigh',
      ]);
      expect(caps.quirks, contains(CapabilityQuirk.reasoningAlwaysOn));
    });

    test('unknown gpt SKUs stay grouped and tool-capable', () {
      final caps = builtinCapabilityCascade.resolve('gpt-9-nova').capabilities;
      expect(caps.group, 'GPT');
      expect(caps.toolCall, isTrue);
      expect(caps.reasoningOptions, isNull);
    });

    test('o-series is grouped with GPT', () {
      final caps = builtinCapabilityCascade.resolve('o3-mini').capabilities;
      expect(caps.group, 'GPT');
      expect(caps.toolCall, isTrue);
    });

    test('gpt-5.6 forces sampling-none with tools', () {
      final caps = builtinCapabilityCascade.resolve('gpt-5.6-sol').capabilities;
      expect(caps.quirks, contains(CapabilityQuirk.toolsForceEffortNone));
      expect(caps.quirks, contains(CapabilityQuirk.autoDisallowsSampling));
    });

    test('kimi-k3 requires thinking', () {
      final caps = builtinCapabilityCascade
          .resolve('moonshotai/kimi-k3')
          .capabilities;
      expect(caps.reasoningOptions!.single.values, <String>[
        'low',
        'high',
        'max',
      ]);
      expect(caps.quirks, contains(CapabilityQuirk.reasoningAlwaysOn));
    });

    test('kimi code aliases and paths resolve distinctly', () {
      for (final id in <String>['k3', 'k3-256k', 'kimi-for-coding']) {
        final caps = builtinCapabilityCascade.resolve(id).capabilities;
        expect(caps.reasoningOptions!.single.values, <String>[
          'none',
          'low',
          'high',
          'max',
        ], reason: id);
        expect(
          caps.quirks,
          contains(CapabilityQuirk.xhighEffortMapsToMax),
          reason: id,
        );
      }
      expect(
        builtinCapabilityCascade
            .resolve('moonshotai/kimi-k2.8-preview')
            .capabilities
            .reasoningOptions,
        isNotNull,
      );
      expect(
        builtinCapabilityCascade
            .resolve('kimi-for-coding-highspeed')
            .capabilities
            .quirks,
        contains(CapabilityQuirk.effortParameterUnsupported),
      );
    });

    test('colon-qualified variants resolve, dash continuations do not', () {
      expect(
        builtinCapabilityCascade
            .resolve('moonshotai/kimi-for-coding:fast')
            .capabilities
            .quirks,
        contains(CapabilityQuirk.xhighEffortMapsToMax),
      );
      expect(
        builtinCapabilityCascade.resolve('kimi-for-coding-other').matched,
        isFalse,
      );
    });

    test('no builtin rule produces a conflict across a broad id corpus', () {
      const corpus = <String>[
        'gpt-5.2',
        'gpt-5.2-codex',
        'gpt-5.3',
        'gpt-5.3-chat-latest',
        'gpt-5.6-sol',
        'gpt-5.1-codex-max',
        'gpt-6-astra',
        'gpt-7-ultra',
        'chatgpt-4o-latest',
        'o1-preview',
        'o3-mini',
        'o4-mini',
        'k3',
        'k3-256k',
        'kimi-for-coding',
        'kimi-for-coding-highspeed',
        'moonshotai/kimi-for-coding:fast',
        'kimi-k2.8-preview',
        'kimi-k3',
        'moonshotai/kimi-k3-256k',
        'glm-5.2',
        'glm-5.3-flash',
        'deepseek/deepseek-v4-pro',
        'mimo-v2.5-pro',
        'xiaomi/mimo-v2.5',
        'grok-4.5',
        'x-ai/grok-4.6',
        'meta/muse-spark-1.1',
        'muse-spark-1.3',
        'muse-spark-1.3-contributor',
        'qwen3.7-max',
        'llama-3.1-8b',
      ];
      for (final id in corpus) {
        final result = builtinCapabilityCascade.resolve(id);
        expect(result.conflicts, isEmpty, reason: id);
      }
    });
  });
}
