import 'package:flutter/foundation.dart';

import '../../models/model_spec.dart';

/// Model-id-derived defaults. Host/protocol defaults live in [VendorDefaults].
@immutable
class ModelGuess {
  final ModelType type;
  final List<Modality> input;
  final List<Modality> output;
  final List<ModelAbility> abilities;
  final ReasoningSpec? reasoning;
  final SamplingPolicy? sampling;
  final int? maxOutput;
  final ReasoningReplayPolicy? replay;
  final ReasoningReplayField? replayField;
  final bool dynamicWebSearch;
  final bool remoteImageUrls;
  final bool promptCacheControl;

  const ModelGuess({
    required this.type,
    required this.input,
    required this.output,
    required this.abilities,
    this.reasoning,
    this.sampling,
    this.maxOutput,
    this.replay,
    this.replayField,
    this.dynamicWebSearch = false,
    this.remoteImageUrls = true,
    this.promptCacheControl = false,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ModelGuess &&
            runtimeType == other.runtimeType &&
            type == other.type &&
            listEquals(input, other.input) &&
            listEquals(output, other.output) &&
            listEquals(abilities, other.abilities) &&
            reasoning == other.reasoning &&
            sampling == other.sampling &&
            maxOutput == other.maxOutput &&
            replay == other.replay &&
            replayField == other.replayField &&
            dynamicWebSearch == other.dynamicWebSearch &&
            remoteImageUrls == other.remoteImageUrls &&
            promptCacheControl == other.promptCacheControl);
  }

  @override
  int get hashCode => Object.hash(
    type,
    Object.hashAll(input),
    Object.hashAll(output),
    Object.hashAll(abilities),
    reasoning,
    sampling,
    maxOutput,
    replay,
    replayField,
    dynamicWebSearch,
    remoteImageUrls,
    promptCacheControl,
  );
}

class _CapDraft {
  ModelType type;
  final List<Modality> input;
  final List<Modality> output;
  final List<ModelAbility> abilities;

  _CapDraft({
    required this.type,
    required List<Modality> input,
    required List<Modality> output,
    required List<ModelAbility> abilities,
  }) : input = List<Modality>.from(input),
       output = List<Modality>.from(output),
       abilities = List<ModelAbility>.from(abilities);
}

class _CapRule {
  final bool Function(String id) matches;
  final void Function(_CapDraft draft) apply;
  final bool terminal;

  const _CapRule({
    required this.matches,
    required this.apply,
    this.terminal = false,
  });
}

class _ReasoningHit {
  final ReasoningSpec spec;
  final SamplingPolicy? sampling;
  final int? maxOutput;
  final ReasoningReplayPolicy? replay;
  final ReasoningReplayField? replayField;

  const _ReasoningHit({
    required this.spec,
    this.sampling,
    this.maxOutput,
    this.replay,
    this.replayField,
  });
}

class _ReasoningRule {
  final bool Function(String id) matches;
  final _ReasoningHit? Function(String id) apply;

  const _ReasoningRule({required this.matches, required this.apply});
}

/// Central guesser for model-id-derived capability and reasoning defaults.
class ModelDefaultsGuesser {
  static final RegExp _vision = RegExp(
    r'(gpt-4o|gpt-4\.1|gpt-5(?!-chat)|gpt-6|o\d|gemini|claude|kimi-k2([-.])(?:5|6|7)|kimi-k3(?:$|[/_:@.-])|muse-spark-1(?:$|[/_:@.-])|doubao.+(?:1([-.])(?:6|8)|seed-2|seed-evolving)|grok-4|step-3|intern-s1|minimax-m3(?:$|[/_:@])|mimo-v2(?:-omni(?:$|[/_:@])|\.5(?:$|[/_:@])|\.6(?:$|[/_:@.-]))|sensenova-6\.7-flash-lite)',
    caseSensitive: false,
  );

  static final RegExp _tool = RegExp(
    (r'(gpt-4o|gpt-4\.1|gpt-oss|gpt-5(?!-chat)|gpt-6|o\d|'
            r'gemini|claude|'
            r'qwen-?3|doubao.+(?:1([-.])(?:6|8)|seed-2|seed-evolving)|grok-4|kimi-k2|'
            r'kimi-k3(?:$|[/_:@.-])|muse-spark-1(?:$|[/_:@.-])|'
            r'step-3|intern-s1|glm-4([-.])(?:5|6|7)|glm-5|minimax-(?:m2|m3)|'
            r'deepseek-(?:r1|v3|chat|v3\.1|v3\.2|v4|flash)|'
            r'deepseek-reasoner|'
            r'mimo-v2|'
            r'sensenova-6\.7-flash-lite|'
            r'laguna'
            r')')
        .replaceAll(' ', ''),
    caseSensitive: false,
  );

  static final RegExp _reasoning = RegExp(
    (r'(gpt-oss|gpt-5(?!-chat)|gpt-6|o\d|'
            r'gemini-(?:2\.5|3).*|gemini-(?:flash-latest|pro-latest)|'
            r'gemini-3-pro-image-preview|'
            r'gemma[-_]?4|'
            r'claude|'
            r'qwen-?3|doubao.+(?:1([-.])(?:6|8)|seed-2|seed-evolving)|grok-4|kimi-k2|'
            r'kimi-k3(?:$|[/_:@.-])|muse-spark-1(?:$|[/_:@.-])|'
            r'step-3|intern-s1|glm-4([-.])(?:5|6|7)|glm-5|minimax-(?:m2|m3)|'
            r'deepseek-(?:r1|v3\.1|v3\.2|v4|flash)|'
            r'deepseek-reasoner|'
            r'mimo-v2|'
            r'laguna'
            r')')
        .replaceAll(' ', ''),
    caseSensitive: false,
  );

  static final List<_ReasoningRule> _reasoningRules = <_ReasoningRule>[
    _ReasoningRule(matches: _isKimiCodeHighSpeed, apply: _kimiHighSpeed),
    _ReasoningRule(matches: _isKimiCodeFamily, apply: _kimiCode),
    _ReasoningRule(matches: _isKimiK3, apply: _kimiK3),
    _ReasoningRule(matches: _isKimiHybrid, apply: _kimiHybrid),
    _ReasoningRule(matches: _isKimiForcedThinking, apply: _kimiForced),
    _ReasoningRule(matches: (id) => id.contains('deepseek'), apply: _deepSeek),
    _ReasoningRule(matches: _isMimoV2, apply: _mimo),
    _ReasoningRule(
      matches: (id) => _matches(id, r'(^|[/_:@])grok-4\.(?:6|7)(?:$|[-.])'),
      apply: _grok46,
    ),
    _ReasoningRule(
      matches: (id) => _matches(id, r'(^|[/_:@])grok-4\.5(?:$|[-.])'),
      apply: _grok45,
    ),
    _ReasoningRule(
      matches: (id) => _matches(id, r'(^|[/_:@])muse-spark-1\.3(?:$|[-.])'),
      apply: _museSpark13,
    ),
    _ReasoningRule(
      matches: (id) => _matches(id, r'(^|[/_:@])muse-spark-1(?:$|[-.])'),
      apply: _museSpark1,
    ),
    _ReasoningRule(matches: _isGlm53, apply: _glm53),
    _ReasoningRule(matches: _isGlm52, apply: _glm52),
    _ReasoningRule(matches: _isGlmOther, apply: _glmOther),
    _ReasoningRule(matches: _isGpt6, apply: _gpt6),
    _ReasoningRule(matches: _isGpt5, apply: _gpt5Family),
    _ReasoningRule(matches: _isOSeries, apply: _oSeries),
    _ReasoningRule(
      matches: (id) => id.contains('claude-'),
      apply: _claudeFamily,
    ),
    _ReasoningRule(matches: _isGemma4, apply: _gemma4),
    _ReasoningRule(matches: _isGemini3FlashImage, apply: _gemini3FlashImage),
    _ReasoningRule(matches: _isGemini3Pro, apply: _gemini3Pro),
    _ReasoningRule(matches: _isGemini3Flash, apply: _gemini3Flash),
    _ReasoningRule(matches: _isGemini3ReplayOnly, apply: _gemini3ReplayOnly),
    _ReasoningRule(matches: _isGeminiBudgetFamily, apply: _geminiBudget),
    _ReasoningRule(matches: _isQwen3Family, apply: _qwen3),
    _ReasoningRule(matches: _isLaguna, apply: _laguna),
    _ReasoningRule(matches: _isDoubaoSeed, apply: _doubaoSeed),
  ];

  static bool isLikelyEmbeddingId(String rawId) {
    final id = rawId.toLowerCase();
    return id.contains('embedding') ||
        RegExp(r'(^|[-_/])embed(?:dings?)?([-.]|$)').hasMatch(id);
  }

  static ModelGuess guess(String modelId, {ModelSpec? base}) {
    final spec = base ?? ModelSpec(id: modelId, displayName: modelId);
    final id = _normalizeGuesserId(modelId);
    final draft = _CapDraft(
      type: spec.type,
      input: spec.input,
      output: spec.output,
      abilities: spec.abilities,
    );

    final forceEmbedding =
        spec.type == ModelType.embedding || isLikelyEmbeddingId(id);
    for (final rule in _capabilityTable(forceEmbedding: forceEmbedding)) {
      if (!rule.matches(id)) continue;
      rule.apply(draft);
      if (rule.terminal) break;
    }

    if (_isImagesApiId(id)) {
      draft.type = ModelType.image;
      // dall-e-2 accepts reference images on the edits endpoint; the others
      // in this set are generation-only (agnes / SenseNova never allowed edits).
      if (id == 'dall-e-2') {
        if (!draft.input.contains(Modality.image)) {
          draft.input.add(Modality.image);
        }
      } else if (id == 'dall-e-3' ||
          id.startsWith('agnes-image-') ||
          id == 'sensenova-u1-fast') {
        draft.input.removeWhere((m) => m == Modality.image);
      }
    }

    final normalized = ModelSpec(
      id: spec.id,
      displayName: spec.displayName,
      type: draft.type,
      input: draft.input,
      output: draft.output,
      abilities: draft.abilities,
    );

    ReasoningSpec? reasoning;
    SamplingPolicy? sampling;
    int? maxOutput;
    ReasoningReplayPolicy? replay;
    ReasoningReplayField? replayField;

    if (normalized.type != ModelType.embedding) {
      for (final rule in _reasoningRules) {
        if (!rule.matches(id)) continue;
        final hit = rule.apply(id);
        if (hit != null) {
          reasoning = hit.spec;
          sampling = hit.sampling;
          maxOutput = hit.maxOutput;
          replay = hit.replay;
          replayField = hit.replayField;
        }
        break;
      }
    }

    if (maxOutput == null && _isKimiFamily(id)) {
      maxOutput = 32000;
    }

    return ModelGuess(
      type: normalized.type,
      input: normalized.input,
      output: normalized.output,
      abilities: normalized.abilities,
      reasoning: reasoning,
      sampling: sampling,
      maxOutput: maxOutput,
      replay: replay,
      replayField: replayField,
      dynamicWebSearch: _isClaudeDynamicSearchGeneration(id),
      remoteImageUrls: !_isKimiK3Wire(id),
      promptCacheControl: _isClaudeRoute(id),
    );
  }

  static List<_CapRule> _capabilityTable({required bool forceEmbedding}) {
    return <_CapRule>[
      _CapRule(
        matches: (_) => forceEmbedding,
        apply: (draft) {
          draft.type = ModelType.embedding;
          if (!draft.input.contains(Modality.text)) {
            draft.input.add(Modality.text);
          }
          draft.output
            ..clear()
            ..add(Modality.text);
          draft.abilities.clear();
        },
        terminal: true,
      ),
      _CapRule(
        matches: _isGemini3FlashImage,
        apply: (draft) {
          if (!draft.input.contains(Modality.image)) {
            draft.input.add(Modality.image);
          }
          if (!draft.output.contains(Modality.image)) {
            draft.output.add(Modality.image);
          }
          draft.abilities.removeWhere((x) => x == ModelAbility.tool);
          if (!draft.abilities.contains(ModelAbility.reasoning)) {
            draft.abilities.add(ModelAbility.reasoning);
          }
        },
        terminal: true,
      ),
      _CapRule(
        matches: (id) =>
            id.contains('image') &&
            id.contains('gemini-3') &&
            !_isGemini3FlashImage(id),
        apply: (draft) {
          if (!draft.input.contains(Modality.image)) {
            draft.input.add(Modality.image);
          }
          if (!draft.output.contains(Modality.image)) {
            draft.output.add(Modality.image);
          }
          draft.abilities.removeWhere((x) => x == ModelAbility.tool);
          if (!draft.abilities.contains(ModelAbility.reasoning)) {
            draft.abilities.add(ModelAbility.reasoning);
          }
        },
        terminal: true,
      ),
      _CapRule(
        matches: (id) => id.contains('image'),
        apply: (draft) {
          if (!draft.input.contains(Modality.image)) {
            draft.input.add(Modality.image);
          }
          if (!draft.output.contains(Modality.image)) {
            draft.output.add(Modality.image);
          }
          draft.abilities.removeWhere(
            (x) => x == ModelAbility.tool || x == ModelAbility.reasoning,
          );
        },
        terminal: true,
      ),
      _CapRule(
        matches: _isGemini35Flash,
        apply: (draft) {
          if (!draft.input.contains(Modality.image)) {
            draft.input.add(Modality.image);
          }
          draft.output
            ..clear()
            ..add(Modality.text);
          if (!draft.abilities.contains(ModelAbility.tool)) {
            draft.abilities.add(ModelAbility.tool);
          }
          if (!draft.abilities.contains(ModelAbility.reasoning)) {
            draft.abilities.add(ModelAbility.reasoning);
          }
        },
        terminal: true,
      ),
      _CapRule(
        matches: (id) =>
            _vision.hasMatch(id) ||
            _isKimiCode(id) ||
            _isQwenVisionModel(id) ||
            _isGlmVisionModel(id) ||
            _isDeepSeekVisionModel(id),
        apply: (draft) {
          if (!draft.input.contains(Modality.image)) {
            draft.input.add(Modality.image);
          }
        },
      ),
      _CapRule(
        matches: (id) => _tool.hasMatch(id) || _isKimiCode(id),
        apply: (draft) {
          if (!draft.abilities.contains(ModelAbility.tool)) {
            draft.abilities.add(ModelAbility.tool);
          }
        },
      ),
      _CapRule(
        matches: (id) =>
            (_reasoning.hasMatch(id) || _isKimiCode(id)) &&
            !_isGemini25NonTextVariant(id),
        apply: (draft) {
          if (!draft.abilities.contains(ModelAbility.reasoning)) {
            draft.abilities.add(ModelAbility.reasoning);
          }
        },
      ),
    ];
  }
}

bool _isImagesApiId(String id) {
  return id.startsWith('gpt-image-') ||
      id.startsWith('chatgpt-image-') ||
      id.startsWith('agnes-image-') ||
      id == 'sensenova-u1-fast' ||
      id == 'dall-e-2' ||
      id == 'dall-e-3';
}

bool _matches(String id, String pattern) {
  return RegExp(pattern, caseSensitive: false).hasMatch(id);
}

/// Lowercase the id and strip a Vertex-style `@YYYYMMDD` (or any all-digit)
/// suffix so family tables match `claude-sonnet-4@20250514`.
String _normalizeGuesserId(String modelId) {
  var id = modelId.toLowerCase();
  final at = id.lastIndexOf('@');
  if (at <= 0) return id;
  final suffix = id.substring(at + 1);
  if (suffix.isEmpty) return id;
  for (var i = 0; i < suffix.length; i++) {
    final code = suffix.codeUnitAt(i);
    if (code < 48 || code > 57) return id;
  }
  return id.substring(0, at);
}

/// Anthropic dynamic-filtering search / fetch tool versions (2026-03-18).
bool _isClaudeDynamicSearchGeneration(String id) {
  if (id.contains('mythos') || id.contains('fable')) return true;
  return _isClaude5(id) ||
      _matches(id, r'claude-opus-4[-.][678](?:$|[._:@/-])') ||
      _matches(id, r'claude-sonnet-4[-.]6(?:$|[._:@/-])');
}

/// K3 rejects remote image URLs (local and data URLs still work). K2.x on the
/// same host accepts them, so this is a model rule, not a host rule.
bool _isKimiK3Wire(String id) =>
    _isKimiCodeK3Alias(id) || _matches(id, r'(^|[/_:@])kimi-k3(?:$|[-.:])');

/// OpenRouter accepts `cache_control` only on Claude / Anthropic routes.
bool _isClaudeRoute(String id) =>
    id.contains('claude') || id.contains('anthropic/');

bool _isKimiFamily(String id) => id.contains('kimi') || _isKimiCodeK3Alias(id);

bool _isKimiCodeK3Alias(String id) {
  final normalized = id.trim().toLowerCase();
  return normalized == 'k3' || normalized == 'k3-256k';
}

bool _isKimiK28(String id) => _matches(id, r'(^|[/_:@])kimi-k2\.8(?:$|[-.:])');

bool _isKimiForCoding(String id) =>
    _matches(id, r'(^|[/_:@])kimi-for-coding(?:-highspeed)?(?:$|[:])');

bool _isKimiCodeHighSpeed(String id) =>
    _matches(id, r'(^|[/_:@])kimi-for-coding-highspeed(?:$|[:])');

bool _isKimiCode(String id) =>
    _isKimiCodeK3Alias(id) || _isKimiForCoding(id) || _isKimiK28(id);

bool _isKimiCodeFamily(String id) =>
    !_isKimiCodeHighSpeed(id) && _isKimiCode(id);

bool _isKimiK3(String id) => _matches(id, r'(^|[/_:@])kimi-k3(?:$|[-.:])');

bool _isKimiHybrid(String id) =>
    id.contains('kimi-k2.5') || id.contains('kimi-k2.6');

bool _isKimiForcedThinking(String id) =>
    id.contains('kimi-k2-thinking') || id.contains('kimi-k2.7');

bool _isKimiK27Code(String id) =>
    _matches(id, r'(^|[/_:@])kimi-k2\.7-code(?:$|[-.:])');

bool _isQwenVisionModel(String id) {
  if (RegExp(r'qwen-?3([-.])5').hasMatch(id)) return true;
  if (RegExp(r'qwen-?3([-.])7-(?:plus|flash)').hasMatch(id)) return true;
  if (RegExp(r'qwen-?3([-.])8-(?:max|flash|27b)').hasMatch(id)) return true;
  final maxSnap = RegExp(
    r'qwen-?3([-.])7-max-(\d{4}-\d{2}-\d{2})',
  ).firstMatch(id);
  if (maxSnap == null) return false;
  final date = DateTime.tryParse(maxSnap.group(2)!);
  if (date == null) return false;
  return !date.isBefore(DateTime(2026, 6, 8));
}

bool _isGlmVisionModel(String id) =>
    _matches(id, r'(^|[/_:@])glm-5\.3-flash(?:$|[-.])');

bool _isDeepSeekVisionModel(String id) => _matches(
  id,
  r'(^|[/_:@])(?:deepseek-flash|deepseek-v4-flash)(?:$|[/_:@.-])',
);

bool _isGemini35Flash(String id) =>
    _matches(id, r'(^|[/:_-])gemini-3\.5-flash([._:@/-]|$)');

bool _isMimoV2(String id) => _matches(id, r'(^|[/_:@])mimo-v2(?:$|[-.])');

bool _isGlm53(String id) => _matches(id, r'(^|[/_:@])glm-5\.3(?:$|[-.])');

bool _isGlm52(String id) => _matches(id, r'(^|[/_:@])glm-5\.2(?:$|[-.])');

bool _isGlmOther(String id) =>
    _matches(id, r'(^|[/_:@])glm-(?:4([-.])(?:5|6|7)|5)(?:$|[-.])');

bool _isGpt5(String id) => _matches(id, r'gpt-5(?=$|[-.])');

bool _isGpt6(String id) => _matches(id, r'gpt-6(?=$|[-.])');

bool _isOSeries(String id) => _matches(id, r'(^|[/_:@])o[134](?:$|[-.])');

bool _isGemma4(String id) => _matches(id, r'(^|[/:_-])gemma[-_]?4([._-]|$)');

final _gemini3NonTextSuffix = RegExp(
  r'(^|[-_/])(image|tts|live)([-._:@/]|$)',
  caseSensitive: false,
);

final _gemini3FlashImageId = RegExp(
  r'gemini-3(?:\.\d+)?-flash(-lite)?-image([._:@/-]|$)',
  caseSensitive: false,
);

final _gemini3FlashId = RegExp(
  r'gemini-3(?:\.(?<minor>\d+))?-flash([._:@/-]|$)',
  caseSensitive: false,
);

final _gemini3ProId = RegExp(
  r'gemini-3(?:\.(?<minor>\d+))?-pro(-preview)?([._:@/-]|$)',
  caseSensitive: false,
);

int? _gemini3Minor(String id, RegExp family) {
  if (_gemini3NonTextSuffix.hasMatch(id)) return null;
  final match = family.firstMatch(id);
  if (match == null) return null;
  return int.tryParse(match.namedGroup('minor') ?? '0') ?? 0;
}

bool _isGemini3FlashImage(String id) => _gemini3FlashImageId.hasMatch(id);

bool _isGemini3Pro(String id) => _gemini3Minor(id, _gemini3ProId) != null;

bool _isGemini3Flash(String id) => _gemini3Minor(id, _gemini3FlashId) != null;

bool _isGemini3TextModel(String id) {
  return id.contains(
    RegExp(r'gemini-3(?:\.\d+)?-(?!pro-image)', caseSensitive: false),
  );
}

bool _isGemini25Pro(String id) =>
    _matches(id, r'(^|[/_:@])gemini-2\.5-pro(?:$|[-.])');

bool _isGeminiNonTextVariant(String id) {
  if (!id.contains('gemini')) return false;
  if (_isGemini3FlashImage(id)) return false;
  return _gemini3NonTextSuffix.hasMatch(id);
}

bool _isGemini3ReplayOnly(String id) =>
    id.contains('gemini-3') && _isGeminiNonTextVariant(id);

bool _isGemini25NonTextVariant(String id) =>
    _isGeminiNonTextVariant(id) && !id.contains('gemini-3');

bool _isGeminiBudgetFamily(String id) {
  return id.contains('gemini') &&
      !_isGemini3FlashImage(id) &&
      !_isGemini3Pro(id) &&
      !_isGemini3Flash(id) &&
      !_isGeminiNonTextVariant(id);
}

bool _isDashScopeThinkingOnlyModel(String id) {
  if (id.contains('qwen3.7-max-preview') ||
      id.contains('qwen3.7-max-2026-05-17')) {
    return true;
  }
  if (_matches(id, r'(^|[/_:@])qwq(?:$|[-.])')) return true;
  if (_matches(id, r'(^|[/_:@])deepseek-r1(?:$|[-.])')) return true;
  if (id.contains('kimi-k2.7-code') || id.contains('kimi-k2-thinking')) {
    return true;
  }
  if (_matches(id, r'(^|[/_:@])minimax-m2\.(?:1|5)(?:$|[-.])')) return true;
  return id.contains('-thinking');
}

bool _isQwen3Family(String id) {
  return RegExp(r'qwen-?3', caseSensitive: false).hasMatch(id) ||
      _matches(id, r'(^|[/_:@])qwq(?:$|[-.])');
}

bool _isLaguna(String id) =>
    id.startsWith('laguna-') || id.contains('/laguna-');

bool _isDoubaoSeed(String id) {
  return RegExp(
        r'doubao.+(?:1([-.])(?:6|8)|seed-2|seed-evolving)',
        caseSensitive: false,
      ).hasMatch(id) ||
      _matches(id, r'(^|[/_:@])seed-(?:1|2|evolving)(?:$|[-.])');
}

ReasoningLevel? _levelByName(String raw) {
  for (final level in ReasoningLevel.values) {
    if (level.name == raw) return level;
  }
  return null;
}

_ReasoningHit _ladder({
  required List<String> efforts,
  required ReasoningDialect dialect,
  bool samplingRequiresNone = false,
  SamplingPolicy? sampling,
  ReasoningLevel defaultLevel = ReasoningLevel.auto,
  int? maxOutput,
  ReasoningReplayPolicy? replay,
  ReasoningReplayField? replayField,
  bool? canDisable,
}) {
  final levels = <ReasoningLevel>[];
  var disable = false;
  for (final effort in efforts) {
    if (effort == 'none') {
      disable = true;
      continue;
    }
    final level = _levelByName(effort);
    if (level != null &&
        level != ReasoningLevel.auto &&
        level != ReasoningLevel.off) {
      levels.add(level);
    }
  }
  return _ReasoningHit(
    spec: ReasoningSpec(
      levels: List<ReasoningLevel>.unmodifiable(levels),
      canDisable: canDisable ?? disable,
      defaultLevel: defaultLevel,
      dialect: dialect,
      replay: replay ?? ReasoningReplayPolicy.none,
      replayField: replayField ?? ReasoningReplayField.reasoningContent,
    ),
    sampling:
        sampling ??
        (samplingRequiresNone ? SamplingPolicy.onlyWhenReasoningOff : null),
    maxOutput: maxOutput,
    replay: replay,
    replayField: replayField,
  );
}

_ReasoningHit _fixed({
  required ReasoningDialect dialect,
  List<ReasoningLevel> levels = const [],
  required bool canDisable,
  ReasoningLevel defaultLevel = ReasoningLevel.auto,
  SamplingPolicy? sampling,
  int? maxOutput,
  ReasoningReplayPolicy? replay,
  ReasoningReplayField? replayField,
}) {
  return _ReasoningHit(
    spec: ReasoningSpec(
      levels: levels,
      canDisable: canDisable,
      defaultLevel: defaultLevel,
      dialect: dialect,
      replay: replay ?? ReasoningReplayPolicy.none,
      replayField: replayField ?? ReasoningReplayField.reasoningContent,
    ),
    sampling: sampling,
    maxOutput: maxOutput,
    replay: replay,
    replayField: replayField,
  );
}

_ReasoningHit _kimiHighSpeed(String id) {
  return _fixed(
    dialect: ReasoningDialect.kimiThinking,
    levels: const [],
    canDisable: true,
    replay: ReasoningReplayPolicy.all,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _kimiCode(String id) {
  return _ladder(
    efforts: const ['none', 'low', 'high', 'max'],
    dialect: ReasoningDialect.kimiThinking,
    replay: ReasoningReplayPolicy.all,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _kimiK3(String id) {
  return _ladder(
    efforts: const ['low', 'high', 'max'],
    dialect: ReasoningDialect.openaiReasoningEffort,
    sampling: SamplingPolicy.never,
    replay: ReasoningReplayPolicy.all,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _kimiHybrid(String id) {
  return _fixed(
    dialect: ReasoningDialect.kimiThinking,
    canDisable: true,
    sampling: id.contains('kimi-k2.5') ? SamplingPolicy.never : null,
    replay: ReasoningReplayPolicy.toolTurns,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _kimiForced(String id) {
  final preserved = _isKimiK27Code(id);
  return _fixed(
    dialect: ReasoningDialect.kimiThinking,
    canDisable: false,
    sampling: id.contains('kimi-k2.7') ? SamplingPolicy.never : null,
    replay: preserved
        ? ReasoningReplayPolicy.all
        : ReasoningReplayPolicy.toolTurns,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _deepSeek(String id) {
  return _ladder(
    efforts: const ['low', 'high', 'max'],
    dialect: ReasoningDialect.thinkingType,
    canDisable: true,
    replay: ReasoningReplayPolicy.toolTurns,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _mimo(String id) {
  return _ladder(
    efforts: const ['none', 'low', 'medium', 'high'],
    dialect: ReasoningDialect.thinkingType,
    replay: ReasoningReplayPolicy.toolTurns,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _grok46(String id) {
  return _ladder(
    efforts: const ['low', 'medium', 'high', 'xhigh'],
    dialect: ReasoningDialect.openaiReasoningEffort,
  );
}

_ReasoningHit _grok45(String id) {
  return _ladder(
    efforts: const ['low', 'medium', 'high'],
    dialect: ReasoningDialect.openaiReasoningEffort,
  );
}

_ReasoningHit _museSpark13(String id) {
  return _ladder(
    efforts: id.contains('contributor')
        ? const ['low', 'medium', 'high', 'xhigh']
        : const ['low', 'medium', 'high', 'xhigh', 'max'],
    dialect: ReasoningDialect.openaiReasoningEffort,
  );
}

_ReasoningHit _museSpark1(String id) {
  return _ladder(
    efforts: const ['low', 'medium', 'high', 'xhigh'],
    dialect: ReasoningDialect.openaiReasoningEffort,
  );
}

_ReasoningHit _glm53(String id) {
  return _ladder(
    efforts: const ['low', 'high', 'max'],
    dialect: ReasoningDialect.thinkingType,
    replay: ReasoningReplayPolicy.toolTurns,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _glm52(String id) {
  return _ladder(
    efforts: const ['low', 'medium', 'high', 'xhigh', 'max'],
    dialect: ReasoningDialect.thinkingType,
    canDisable: true,
    replay: ReasoningReplayPolicy.toolTurns,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _glmOther(String id) {
  return _fixed(
    dialect: ReasoningDialect.thinkingType,
    canDisable: true,
    replay: ReasoningReplayPolicy.toolTurns,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _gpt6(String id) {
  return _ladder(
    efforts: const ['low', 'medium', 'high', 'xhigh', 'max'],
    dialect: ReasoningDialect.openaiReasoningEffort,
    samplingRequiresNone: true,
  );
}

_ReasoningHit _oSeries(String id) {
  return _ladder(
    efforts: const ['low', 'medium', 'high'],
    dialect: ReasoningDialect.openaiReasoningEffort,
  );
}

_ReasoningHit _qwen3(String id) {
  return _fixed(
    dialect: ReasoningDialect.qwenEnableThinking,
    canDisable: !_isDashScopeThinkingOnlyModel(id),
  );
}

_ReasoningHit _laguna(String id) {
  return _fixed(
    dialect: ReasoningDialect.chatTemplateKwargs,
    canDisable: true,
    replay: ReasoningReplayPolicy.all,
    replayField: ReasoningReplayField.reasoningContent,
  );
}

_ReasoningHit _doubaoSeed(String id) {
  return _fixed(dialect: ReasoningDialect.thinkingType, canDisable: true);
}

_ReasoningHit _gemma4(String id) {
  return _fixed(
    dialect: ReasoningDialect.geminiThinkingLevel,
    levels: const [ReasoningLevel.minimal, ReasoningLevel.high],
    canDisable: false,
    defaultLevel: ReasoningLevel.high,
  );
}

_ReasoningHit _gemini3ReplayOnly(String _) {
  return _fixed(
    dialect: ReasoningDialect.none,
    canDisable: true,
    replay: ReasoningReplayPolicy.all,
  );
}

_ReasoningHit _gemini3FlashImage(String id) {
  return _fixed(
    dialect: ReasoningDialect.geminiThinkingLevel,
    levels: const [ReasoningLevel.minimal, ReasoningLevel.high],
    canDisable: false,
    defaultLevel: ReasoningLevel.minimal,
    sampling: _isGemini3TextModel(id) ? SamplingPolicy.never : null,
    replay: ReasoningReplayPolicy.all,
  );
}

_ReasoningHit _gemini3Pro(String id) {
  final minor = _gemini3Minor(id, _gemini3ProId) ?? 0;
  final levels = minor >= 1
      ? const [ReasoningLevel.low, ReasoningLevel.medium, ReasoningLevel.high]
      : const [ReasoningLevel.low, ReasoningLevel.high];
  return _fixed(
    dialect: ReasoningDialect.geminiThinkingLevel,
    levels: levels,
    canDisable: false,
    defaultLevel: ReasoningLevel.high,
    sampling: SamplingPolicy.never,
    replay: ReasoningReplayPolicy.all,
  );
}

_ReasoningHit _gemini3Flash(String id) {
  final minor = _gemini3Minor(id, _gemini3FlashId) ?? 0;
  final noMinimal = minor >= 7;
  final levels = noMinimal
      ? const [ReasoningLevel.low, ReasoningLevel.medium, ReasoningLevel.high]
      : const [
          ReasoningLevel.minimal,
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ];
  final isLite = RegExp(
    r'gemini-3(?:\.\d+)?-flash-lite([._:@/-]|$)',
    caseSensitive: false,
  ).hasMatch(id);
  final defaultLevel = isLite
      ? (noMinimal ? ReasoningLevel.low : ReasoningLevel.minimal)
      : (minor >= 5 ? ReasoningLevel.medium : ReasoningLevel.high);
  return _fixed(
    dialect: ReasoningDialect.geminiThinkingLevel,
    levels: levels,
    canDisable: false,
    defaultLevel: defaultLevel,
    sampling: SamplingPolicy.never,
    maxOutput: minor >= 5 ? 65536 : null,
    replay: ReasoningReplayPolicy.all,
  );
}

_ReasoningHit _geminiBudget(String id) {
  return _fixed(
    dialect: ReasoningDialect.geminiThinkingBudget,
    canDisable: !_isGemini25Pro(id),
    sampling: _isGemini3TextModel(id) ? SamplingPolicy.never : null,
    replay: id.contains('gemini-3') ? ReasoningReplayPolicy.all : null,
  );
}

bool _isClaude5(String id) =>
    _matches(id, r'claude-(?:opus|sonnet)-5(?:$|[._:@/-])');

bool _isClaudeAlwaysOn(String id) =>
    id.contains('claude-fable') || id.contains('claude-mythos');

bool _supportsClaudeAdaptive(String id) {
  if (!id.contains('claude-')) return false;
  if (id.contains('fable') || id.contains('mythos')) return true;
  if (_isClaude5(id)) return true;
  final m = RegExp(
    r'claude-(opus|sonnet)-(\d+)[-.](\d+)',
    caseSensitive: false,
  ).firstMatch(id);
  if (m != null) {
    final major = int.tryParse(m.group(2) ?? '');
    final minor = int.tryParse(m.group(3) ?? '');
    if (major != null && minor != null) {
      return major > 4 || (major == 4 && minor >= 6);
    }
  }
  return id.contains('4-6') || id.contains('4.6');
}

bool _isClaudeAdaptiveOnly(String id) {
  if (!id.contains('claude-')) return false;
  if (id.contains('fable') || id.contains('mythos')) return true;
  if (_isClaude5(id)) return true;
  final m = RegExp(
    r'claude-(opus|sonnet)-(\d+)[-.](\d+)',
    caseSensitive: false,
  ).firstMatch(id);
  if (m == null) {
    return id.contains('4-7') ||
        id.contains('4.7') ||
        id.contains('4-8') ||
        id.contains('4.8');
  }
  final family = (m.group(1) ?? '').toLowerCase();
  final major = int.tryParse(m.group(2) ?? '');
  final minor = int.tryParse(m.group(3) ?? '');
  if (major == null || minor == null) return false;
  if (major > 4) return true;
  if (major < 4) return false;
  if (family == 'opus' && minor >= 7) return true;
  return false;
}

bool _claudeSupportsXhigh(String id) {
  return _isClaude5(id) ||
      id.contains('claude-opus-4-7') ||
      id.contains('claude-opus-4.7') ||
      id.contains('claude-opus-4-8') ||
      id.contains('claude-opus-4.8') ||
      id.contains('claude-fable') ||
      id.contains('claude-mythos');
}

bool _claudeSupportsMax(String id) {
  return _claudeSupportsXhigh(id) ||
      id.contains('claude-opus-4-6') ||
      id.contains('claude-opus-4.6') ||
      id.contains('claude-sonnet-4-6') ||
      id.contains('claude-sonnet-4.6') ||
      id.contains('mythos');
}

int _claudeMaxOutput(String id) {
  if (_matches(
    id,
    r'claude-(?:fable-5|mythos-5|opus-(?:5|4-[678])|sonnet-(?:5|4-6))(?:$|[._:/-])',
  )) {
    return 128000;
  }
  if (_matches(id, r'claude-3-haiku(?:$|[._:/])')) return 8000;
  if (id.contains('claude-3-5-sonnet') || id.contains('claude-3.5-sonnet')) {
    return 8192;
  }
  if (_matches(id, r'claude-opus-4-1(?:$|[._:/])') ||
      _matches(id, r'claude-opus-4(?:$|[._:/])')) {
    return 32000;
  }
  return 64000;
}

SamplingPolicy? _claudeSampling(String id) {
  if (_isClaudeAlwaysOn(id)) return SamplingPolicy.never;
  if (_isClaude5(id) ||
      id.contains('claude-opus-4-8') ||
      id.contains('claude-opus-4.8')) {
    return SamplingPolicy.never;
  }
  if (_isClaudeAdaptiveOnly(id)) return SamplingPolicy.onlyWhenReasoningOff;
  return null;
}

List<ReasoningLevel> _claudeAdaptiveLevels(String id) {
  final levels = <ReasoningLevel>[
    ReasoningLevel.low,
    ReasoningLevel.medium,
    ReasoningLevel.high,
  ];
  if (_claudeSupportsXhigh(id)) levels.add(ReasoningLevel.xhigh);
  if (_claudeSupportsMax(id)) levels.add(ReasoningLevel.max);
  return List<ReasoningLevel>.unmodifiable(levels);
}

_ReasoningHit _claudeFamily(String id) {
  final maxOutput = _claudeMaxOutput(id);
  final sampling = _claudeSampling(id);
  if (_isClaudeAlwaysOn(id) || _supportsClaudeAdaptive(id)) {
    return _fixed(
      dialect: ReasoningDialect.anthropicAdaptiveEffort,
      levels: _claudeAdaptiveLevels(id),
      canDisable: !_isClaudeAlwaysOn(id),
      sampling: sampling,
      maxOutput: maxOutput,
    );
  }
  return _fixed(
    dialect: ReasoningDialect.anthropicBudget,
    levels: const [
      ReasoningLevel.low,
      ReasoningLevel.medium,
      ReasoningLevel.high,
    ],
    canDisable: true,
    sampling: sampling,
    maxOutput: maxOutput,
  );
}

_ReasoningHit? _gpt5Family(String id) => _gpt5Support(id);

_ReasoningHit? _gpt5Support(String id) {
  if (_matches(id, r'(^|[/_:@])gpt-5\.6(?:-(?:sol|terra|luna))?(?:$|[.@])')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high', 'xhigh', 'max'],
      dialect: ReasoningDialect.openaiReasoningEffort,
      samplingRequiresNone: true,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.5-pro(?:$|[-.])')) {
    return _ladder(
      efforts: const ['medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.5-(?:codex|chat-latest)(?:$|[-.])')) {
    return null;
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.5(?:$|[-.])')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
      samplingRequiresNone: true,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.4-pro(?:$|[-.])')) {
    return _ladder(
      efforts: const ['medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.4-(?:codex|chat-latest)(?:$|[-.])')) {
    return null;
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.4(?:$|[-.])')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
      samplingRequiresNone: true,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.3-codex(?:$|[-.])')) {
    return _ladder(
      efforts: const ['low', 'medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.3-chat-latest(?:$|[-.])')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.3-(?:pro|chat-latest)(?:$|[-.])')) {
    return null;
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.3(?:$|[-.])')) {
    return null;
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.2-pro(?:$|[-.])')) {
    return _ladder(
      efforts: const ['medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.2-codex(?:$|[-.])')) {
    return _ladder(
      efforts: const ['low', 'medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.2-chat-latest(?:$|[-.])')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.2(?:$|[-.])')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
      samplingRequiresNone: true,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.1-chat-latest(?:$|[-.])')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.1-codex-max(?:$|[-.])')) {
    return _ladder(
      efforts: const ['low', 'medium', 'high', 'xhigh'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.1-codex(?:$|[-.])')) {
    return _ladder(
      efforts: const ['low', 'medium', 'high'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.1-pro(?:$|[-.])')) {
    return null;
  }
  if (_matches(id, r'(^|[/_:@])gpt-5\.1(?:$|[-.])')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5-pro(?:$|[-.])')) {
    return _ladder(
      efforts: const ['high'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5-codex(?:$|[-.])')) {
    return _ladder(
      efforts: const ['low', 'medium', 'high'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  if (_matches(id, r'(^|[/_:@])gpt-5-chat-latest(?:$|[-.])')) {
    return null;
  }
  if (_matches(id, r'(^|[/_:@])gpt-5(?:$|-)')) {
    return _ladder(
      efforts: const ['none', 'low', 'medium', 'high'],
      dialect: ReasoningDialect.openaiReasoningEffort,
    );
  }
  return null;
}
