import 'capability_cascade.dart';
import 'model_capabilities.dart';

/// Built-in capability rules.
///
/// Broad family rules come first so future SKUs (for example a hypothetical
/// `gpt-7`) inherit sane defaults, and narrower rules refine individual
/// fields. Pattern specificity — not table order — decides precedence.
///
/// This table is the single source of truth that replaces the legacy
/// `openai_model_compat.dart` dispatch.
const List<ModelRule> builtinModelRules = <ModelRule>[
  // Identity and coarse abilities.
  ModelRule(
    'gpt | chatgpt',
    group: 'GPT',
    icon: 'openai',
    toolCall: true,
    reasoning: true,
  ),
  ModelRule(
    '^o {1|3|4}',
    group: 'GPT',
    icon: 'openai',
    toolCall: true,
    reasoning: true,
  ),

  // Kimi Code endpoint models (k3 aliases, kimi-for-coding, kimi-k2.8).
  ModelRule(
    r'^kimi for coding highspeed $',
    quirks: <CapabilityQuirk>{CapabilityQuirk.effortParameterUnsupported},
  ),
  ModelRule(
    r'^kimi for coding $',
    reasoningOptions: _kimiCodeEfforts,
    quirks: <CapabilityQuirk>{CapabilityQuirk.xhighEffortMapsToMax},
  ),
  ModelRule(
    r'^k 3 $',
    reasoningOptions: _kimiCodeEfforts,
    quirks: <CapabilityQuirk>{CapabilityQuirk.xhighEffortMapsToMax},
  ),
  ModelRule(
    r'^k 3 256k $',
    reasoningOptions: _kimiCodeEfforts,
    quirks: <CapabilityQuirk>{CapabilityQuirk.xhighEffortMapsToMax},
  ),
  ModelRule(
    '^kimi k 2 8',
    reasoningOptions: _kimiCodeEfforts,
    quirks: <CapabilityQuirk>{CapabilityQuirk.xhighEffortMapsToMax},
  ),

  // Kimi K3 open platform, DeepSeek and MiMo.
  ModelRule('^kimi k 3', reasoningOptions: _lowHighMax, quirks: _alwaysOn),
  ModelRule('deepseek', reasoningOptions: _lowHighMax),
  ModelRule('^mimo v 2', reasoningOptions: _noneLowMediumHigh),

  // Grok.
  ModelRule(
    '^grok 4 6',
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule('^grok 4 5', reasoningOptions: _lowMediumHigh, quirks: _alwaysOn),

  // Muse Spark.
  ModelRule(
    '^muse spark 1 3 contributor',
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule(
    '^muse spark 1 3',
    reasoningOptions: _lowMediumHighXhighMax,
    quirks: _alwaysOn,
  ),
  ModelRule(
    '^muse spark 1',
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),

  // GLM.
  ModelRule('^glm 5 3', reasoningOptions: _lowHighMax, quirks: _alwaysOn),
  ModelRule('^glm 5 2', reasoningOptions: _lowMediumHighXhighMax),

  // GPT-6.
  ModelRule(
    '^gpt 6',
    reasoningOptions: _lowMediumHighXhighMax,
    quirks: _alwaysOnNoSamplingNoAuto,
  ),

  // GPT-5.6.
  ModelRule(
    '^gpt 5.6',
    reasoningOptions: _noneLowMediumHighXhighMax,
    quirks: <CapabilityQuirk>{
      CapabilityQuirk.samplingRequiresNoThinking,
      CapabilityQuirk.autoDisallowsSampling,
      CapabilityQuirk.toolsForceEffortNone,
    },
  ),

  // GPT-5.5.
  ModelRule(
    '^gpt 5.5 pro',
    reasoningOptions: _mediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule('^gpt 5.5 codex', clear: _clearReasoning),
  ModelRule('^gpt 5.5 chat latest', clear: _clearReasoning),
  ModelRule(
    '^gpt 5.5',
    reasoningOptions: _noneLowMediumHighXhigh,
    quirks: _samplingRequiresNoThinking,
  ),

  // GPT-5.4.
  ModelRule(
    '^gpt 5.4 pro',
    reasoningOptions: _mediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule('^gpt 5.4 codex', clear: _clearReasoning),
  ModelRule('^gpt 5.4 chat latest', clear: _clearReasoning),
  ModelRule(
    '^gpt 5.4',
    reasoningOptions: _noneLowMediumHighXhigh,
    quirks: _samplingRequiresNoThinking,
  ),

  // GPT-5.3.
  ModelRule(
    '^gpt 5.3 codex',
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule('^gpt 5.3 chat latest', reasoningOptions: _noneLowMediumHighXhigh),
  ModelRule('^gpt 5.3 pro', clear: _clearReasoning),
  ModelRule('^gpt 5.3', clear: _clearReasoning),

  // GPT-5.2.
  ModelRule(
    '^gpt 5.2 pro',
    reasoningOptions: _mediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule(
    '^gpt 5.2 codex',
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule('^gpt 5.2 chat latest', reasoningOptions: _noneLowMediumHighXhigh),
  ModelRule(
    '^gpt 5.2',
    reasoningOptions: _noneLowMediumHighXhigh,
    quirks: _samplingRequiresNoThinking,
  ),

  // GPT-5.1.
  ModelRule('^gpt 5.1 chat latest', reasoningOptions: _noneLowMediumHigh),
  ModelRule(
    '^gpt 5.1 codex max',
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule(
    '^gpt 5.1 codex',
    reasoningOptions: _lowMediumHigh,
    quirks: _alwaysOn,
  ),
  ModelRule('^gpt 5.1 pro', clear: _clearReasoning),
  ModelRule('^gpt 5.1', reasoningOptions: _noneLowMediumHigh),

  // GPT-5.
  ModelRule('^gpt 5 pro', reasoningOptions: _highOnly, quirks: _alwaysOn),
  ModelRule(
    '^gpt 5 codex',
    reasoningOptions: _lowMediumHigh,
    quirks: _alwaysOn,
  ),
  ModelRule('^gpt 5 chat latest', clear: _clearReasoning),
  ModelRule('^gpt 5', reasoningOptions: _noneLowMediumHigh),
];

/// The shared cascade over [builtinModelRules].
final CapabilityCascade builtinCapabilityCascade = CapabilityCascade.builtin(
  builtinModelRules,
);

const List<ReasoningOption> _noneLowMediumHigh = <ReasoningOption>[
  ReasoningOption.effort(<String>['none', 'low', 'medium', 'high']),
];
const List<ReasoningOption> _noneLowMediumHighXhigh = <ReasoningOption>[
  ReasoningOption.effort(<String>['none', 'low', 'medium', 'high', 'xhigh']),
];
const List<ReasoningOption> _noneLowMediumHighXhighMax = <ReasoningOption>[
  ReasoningOption.effort(<String>[
    'none',
    'low',
    'medium',
    'high',
    'xhigh',
    'max',
  ]),
];
const List<ReasoningOption> _lowMediumHigh = <ReasoningOption>[
  ReasoningOption.effort(<String>['low', 'medium', 'high']),
];
const List<ReasoningOption> _lowMediumHighXhigh = <ReasoningOption>[
  ReasoningOption.effort(<String>['low', 'medium', 'high', 'xhigh']),
];
const List<ReasoningOption> _lowMediumHighXhighMax = <ReasoningOption>[
  ReasoningOption.effort(<String>['low', 'medium', 'high', 'xhigh', 'max']),
];
const List<ReasoningOption> _mediumHighXhigh = <ReasoningOption>[
  ReasoningOption.effort(<String>['medium', 'high', 'xhigh']),
];
const List<ReasoningOption> _lowHighMax = <ReasoningOption>[
  ReasoningOption.effort(<String>['low', 'high', 'max']),
];
const List<ReasoningOption> _highOnly = <ReasoningOption>[
  ReasoningOption.effort(<String>['high']),
];
const List<ReasoningOption> _kimiCodeEfforts = <ReasoningOption>[
  ReasoningOption.effort(<String>['none', 'low', 'high', 'max']),
];

const Set<CapabilityQuirk> _alwaysOn = <CapabilityQuirk>{
  CapabilityQuirk.reasoningAlwaysOn,
};
const Set<CapabilityQuirk> _samplingRequiresNoThinking = <CapabilityQuirk>{
  CapabilityQuirk.samplingRequiresNoThinking,
};
const Set<CapabilityQuirk> _alwaysOnNoSamplingNoAuto = <CapabilityQuirk>{
  CapabilityQuirk.reasoningAlwaysOn,
  CapabilityQuirk.samplingRequiresNoThinking,
  CapabilityQuirk.autoDisallowsSampling,
};
const Set<CapabilityField> _clearReasoning = <CapabilityField>{
  CapabilityField.reasoningOptions,
  CapabilityField.quirks,
};
