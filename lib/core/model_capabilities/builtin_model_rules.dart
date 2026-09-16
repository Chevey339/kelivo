import 'capability_cascade.dart';
import 'model_capabilities.dart';

/// Built-in capability rules.
///
/// Broad family rules come first so future SKUs (for example a hypothetical
/// `gpt-7`) inherit sane defaults, and narrower rules refine individual
/// fields. Pattern specificity — not table order — decides precedence.
///
/// This table is the single source of truth that replaces the legacy
/// `openai_model_compat.dart` dispatch and the `ModelRegistry` regexes.
const List<ModelRule> builtinModelRules = <ModelRule>[
  // Identity and grouping.
  ModelRule('gpt | chatgpt', group: 'GPT', icon: 'openai'),
  ModelRule('^o {1|3|4}', group: 'GPT', icon: 'openai'),

  // OpenAI families.
  ModelRule(
    '^gpt 4 o',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule(
    '^gpt 4.1',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule(
    '^gpt 5 chat',
    inputModalities: _text,
    toolCall: false,
    reasoning: false,
  ),
  ModelRule(
    '^gpt 5',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule('gpt oss', toolCall: true, reasoning: true),
  ModelRule(
    'o {0|1|2|3|4|5|6|7|8|9}',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),

  // Gemini and Gemma.
  ModelRule('gemini', inputModalities: _textImage, toolCall: true),
  ModelRule('gemini 2.5', reasoning: true),
  ModelRule('gemini 3', reasoning: true),
  ModelRule('gemini flash latest', reasoning: true),
  ModelRule('gemini pro latest', reasoning: true),
  ModelRule('gemma 4', reasoning: true),

  // Anthropic.
  ModelRule(
    'claude',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),

  // Kimi open platform and Kimi Code endpoint.
  ModelRule('kimi k 2', toolCall: true, reasoning: true),
  ModelRule('kimi k 2 {5|6|7}', inputModalities: _textImage),
  ModelRule(
    '^kimi k 3',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _lowHighMax,
    quirks: _alwaysOn,
  ),
  ModelRule(
    r'^kimi for coding highspeed $',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    quirks: <CapabilityQuirk>{CapabilityQuirk.effortParameterUnsupported},
  ),
  ModelRule(
    r'^kimi for coding $',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _kimiCodeEfforts,
    quirks: <CapabilityQuirk>{CapabilityQuirk.xhighEffortMapsToMax},
  ),
  ModelRule(
    r'^k 3 $',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _kimiCodeEfforts,
    quirks: <CapabilityQuirk>{CapabilityQuirk.xhighEffortMapsToMax},
  ),
  ModelRule(
    r'^k 3 256k $',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _kimiCodeEfforts,
    quirks: <CapabilityQuirk>{CapabilityQuirk.xhighEffortMapsToMax},
  ),
  ModelRule(
    '^kimi k 2 8',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _kimiCodeEfforts,
    quirks: <CapabilityQuirk>{CapabilityQuirk.xhighEffortMapsToMax},
  ),

  // DeepSeek.
  ModelRule('deepseek', reasoningOptions: _lowHighMax),
  ModelRule('deepseek v 3 1', toolCall: true, reasoning: true),
  ModelRule('deepseek v 3 2', toolCall: true, reasoning: true),
  ModelRule('deepseek v 3', toolCall: true),
  ModelRule(
    'deepseek v 4 flash',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule('deepseek v 4', toolCall: true, reasoning: true),
  ModelRule(
    'deepseek flash',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule('deepseek r 1', toolCall: true, reasoning: true),
  ModelRule('deepseek chat', toolCall: true),
  ModelRule('deepseek reasoner', toolCall: true, reasoning: true),

  // Qwen. Vision is deliberate: only the documented SKUs are multimodal.
  ModelRule('qwen 3', toolCall: true, reasoning: true),
  ModelRule('qwen 3 5', inputModalities: _textImage),
  ModelRule('qwen 3 7 plus', inputModalities: _textImage),
  ModelRule('qwen 3 7 flash', inputModalities: _textImage),
  ModelRule('qwen 3 7 max @snap>=2026-06-08', inputModalities: _textImage),
  ModelRule('qwen 3 8 max', inputModalities: _textImage),
  ModelRule('qwen 3 8 flash', inputModalities: _textImage),
  ModelRule('qwen 3 8 27b', inputModalities: _textImage),

  // GLM.
  ModelRule('glm 4 {5|6|7}', toolCall: true, reasoning: true),
  ModelRule('glm 5', toolCall: true, reasoning: true),
  ModelRule('glm 5.3 flash', inputModalities: _textImage),
  ModelRule('glm 5 2', reasoningOptions: _lowMediumHighXhighMax),
  ModelRule('glm 5 3', reasoningOptions: _lowHighMax, quirks: _alwaysOn),

  // MiniMax.
  ModelRule('minimax m 3', toolCall: true, reasoning: true),
  ModelRule(r'^minimax m 3 $', inputModalities: _textImage),
  ModelRule('minimax m 2', toolCall: true, reasoning: true),

  // Doubao / Ark.
  ModelRule(
    'doubao seed {v>=1.6}',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule(
    'doubao {v>=1.6}',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule(
    'doubao seed 2',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule(
    'doubao seed evolving',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),

  // Grok, MiMo and other compatible families.
  ModelRule(
    'grok 4',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule(
    '^grok 4 6',
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule('^grok 4 5', reasoningOptions: _lowMediumHigh, quirks: _alwaysOn),
  ModelRule(r'^mimo v 2 omni $', inputModalities: _textImage),
  ModelRule(r'^mimo v 2 5 $', inputModalities: _textImage),
  ModelRule(
    '^mimo v 2',
    toolCall: true,
    reasoning: true,
    reasoningOptions: _noneLowMediumHigh,
  ),
  ModelRule(
    'step 3',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule(
    'intern s 1',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),
  ModelRule('laguna', toolCall: true, reasoning: true),
  ModelRule(
    'sensenova 6.7 flash lite',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
  ),

  // Muse Spark.
  ModelRule(
    '^muse spark 1 3 contributor',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),
  ModelRule(
    '^muse spark 1 3',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _lowMediumHighXhighMax,
    quirks: _alwaysOn,
  ),
  ModelRule(
    '^muse spark 1',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _lowMediumHighXhigh,
    quirks: _alwaysOn,
  ),

  // GPT-6.
  ModelRule(
    '^gpt 6',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
    reasoningOptions: _lowMediumHighXhighMax,
    quirks: _alwaysOnNoSamplingNoAuto,
  ),

  // GPT-5.6.
  ModelRule(
    '^gpt 5.6',
    inputModalities: _textImage,
    toolCall: true,
    reasoning: true,
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
];

/// The shared cascade over [builtinModelRules].
final CapabilityCascade builtinCapabilityCascade = CapabilityCascade.builtin(
  builtinModelRules,
);

const List<CapabilityModality> _text = <CapabilityModality>[
  CapabilityModality.text,
];
const List<CapabilityModality> _textImage = <CapabilityModality>[
  CapabilityModality.text,
  CapabilityModality.image,
];

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
