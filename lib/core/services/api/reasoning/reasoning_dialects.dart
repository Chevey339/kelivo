import 'package:flutter/foundation.dart';

import '../../../models/model_spec.dart';

enum ReasoningTransport {
  chatCompletions,
  responses,
  anthropicMessages,
  geminiGenerateContent,
}

@immutable
class ReasoningRequest {
  final ReasoningLevel level;
  final int? budgetTokens;

  const ReasoningRequest(this.level, {this.budgetTokens});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReasoningRequest &&
            runtimeType == other.runtimeType &&
            level == other.level &&
            budgetTokens == other.budgetTokens);
  }

  @override
  int get hashCode => Object.hash(level, budgetTokens);
}

@immutable
class ReasoningResolution {
  final ReasoningLevel requested;
  final ReasoningLevel effective;
  final int? budget;

  const ReasoningResolution({
    required this.requested,
    required this.effective,
    this.budget,
  });

  bool get thinkingEnabled => effective != ReasoningLevel.off;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReasoningResolution &&
            runtimeType == other.runtimeType &&
            requested == other.requested &&
            effective == other.effective &&
            budget == other.budget);
  }

  @override
  int get hashCode => Object.hash(requested, effective, budget);
}

const Map<ReasoningLevel, int> _fixedBudgets = {
  ReasoningLevel.minimal: 512,
  ReasoningLevel.low: 1024,
  ReasoningLevel.medium: 4096,
  ReasoningLevel.high: 8192,
  ReasoningLevel.xhigh: 16000,
  ReasoningLevel.max: 32000,
};

const List<String> _ownedTopLevelKeys = [
  'reasoning_effort',
  'reasoning',
  'thinking',
  'output_config',
  'enable_thinking',
  'thinking_budget',
  'thinking_mode',
];

const List<String> _chatSamplingKeys = [
  'temperature',
  'top_p',
  'top_k',
  'logprobs',
  'top_logprobs',
];

const List<String> _anthropicSamplingKeys = ['temperature', 'top_p', 'top_k'];

const List<String> _geminiSamplingKeys = ['temperature', 'topP', 'topK'];

ReasoningResolution resolveReasoning(ModelSpec spec, ReasoningRequest request) {
  final reasoning = spec.reasoning;
  final requested = request.level;
  late final ReasoningLevel effective;
  if (requested == ReasoningLevel.auto) {
    effective = ReasoningLevel.auto;
  } else if (requested == ReasoningLevel.off) {
    effective = reasoning.canDisable
        ? ReasoningLevel.off
        : _lowestExplicitLevel(reasoning);
  } else if (reasoning.levels.contains(requested) ||
      (reasoning.levels.isEmpty && _isBudgetDialect(reasoning.dialect))) {
    effective = requested;
  } else {
    effective = nearestLevel(requested, reasoning.levels);
  }

  final budget =
      _isBudgetDialect(reasoning.dialect) && _isExplicitLevel(effective)
      ? resolveBudget(
          spec,
          effective,
          explicit: _isExplicitLevel(requested) ? request.budgetTokens : null,
        )
      : null;

  return ReasoningResolution(
    requested: requested,
    effective: effective,
    budget: budget,
  );
}

/// Removes every key owned by the spec's dialect from [body] and writes the
/// shape for the effective level. Mutates and returns [body]. No-op when the
/// model has no reasoning ability or dialect == none.
Map<String, dynamic> applyReasoning(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningRequest request, {
  required ReasoningTransport transport,
}) {
  if (!spec.supportsReasoning ||
      spec.reasoning.dialect == ReasoningDialect.none) {
    return body;
  }
  final resolution = resolveReasoning(spec, request);
  _stripOwnedKeys(body);
  _writeDialect(body, spec, request, resolution, transport);
  return body;
}

/// Applies spec.sampling: `never` removes sampling keys always;
/// `onlyWhenReasoningOff` removes them unless resolution.effective == off;
/// `always` no-op. Keys per transport: chatCompletions/responses ->
/// temperature, top_p, top_k, logprobs, top_logprobs; anthropicMessages ->
/// temperature, top_p, top_k; geminiGenerateContent ->
/// generationConfig.temperature/topP/topK.
Map<String, dynamic> applySamplingPolicy(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningResolution resolution, {
  required ReasoningTransport transport,
}) {
  final strip = switch (spec.sampling) {
    SamplingPolicy.always => false,
    SamplingPolicy.never => true,
    SamplingPolicy.onlyWhenReasoningOff =>
      resolution.effective != ReasoningLevel.off,
  };
  if (!strip) return body;
  switch (transport) {
    case ReasoningTransport.chatCompletions:
    case ReasoningTransport.responses:
      for (final key in _chatSamplingKeys) {
        body.remove(key);
      }
    case ReasoningTransport.anthropicMessages:
      for (final key in _anthropicSamplingKeys) {
        body.remove(key);
      }
    case ReasoningTransport.geminiGenerateContent:
      _removeFromNested(body, 'generationConfig', _geminiSamplingKeys);
  }
  return body;
}

int? resolveBudget(ModelSpec spec, ReasoningLevel level, {int? explicit}) {
  return explicit ?? spec.reasoning.budgets[level] ?? _fixedBudgets[level];
}

ReasoningLevel nearestLevel(
  ReasoningLevel wanted,
  List<ReasoningLevel> levels,
) {
  if (levels.isEmpty || levels.contains(wanted)) return wanted;
  var best = levels.first;
  var bestDist = (best.index - wanted.index).abs();
  for (final level in levels.skip(1)) {
    final dist = (level.index - wanted.index).abs();
    if (dist < bestDist || (dist == bestDist && level.index < best.index)) {
      best = level;
      bestDist = dist;
    }
  }
  return best;
}

ReasoningLevel levelForLegacyBudget(int? budget) {
  if (budget == null || budget == -1) return ReasoningLevel.auto;
  if (budget < 1024) return ReasoningLevel.off;
  if (budget <= 2000) return ReasoningLevel.low;
  if (budget <= 20000) return ReasoningLevel.medium;
  if (budget <= 32000) return ReasoningLevel.high;
  if (budget <= 64000) return ReasoningLevel.xhigh;
  return ReasoningLevel.max;
}

bool _isExplicitLevel(ReasoningLevel level) {
  return level != ReasoningLevel.auto && level != ReasoningLevel.off;
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

bool _isOpenAiDialect(ReasoningDialect dialect) {
  return dialect == ReasoningDialect.openaiReasoningEffort ||
      dialect == ReasoningDialect.openaiResponsesReasoning;
}

ReasoningLevel _lowestExplicitLevel(ReasoningSpec spec) {
  if (spec.levels.isNotEmpty) {
    return spec.levels.reduce((a, b) => a.index <= b.index ? a : b);
  }
  if (spec.budgets.isNotEmpty) {
    var best = spec.budgets.keys.first;
    var bestBudget = spec.budgets[best]!;
    for (final entry in spec.budgets.entries.skip(1)) {
      if (entry.value < bestBudget ||
          (entry.value == bestBudget && entry.key.index < best.index)) {
        best = entry.key;
        bestBudget = entry.value;
      }
    }
    return best;
  }
  return ReasoningLevel.minimal;
}

void _stripOwnedKeys(Map<String, dynamic> body) {
  for (final key in _ownedTopLevelKeys) {
    body.remove(key);
  }
  _removeFromNested(body, 'chat_template_kwargs', const ['enable_thinking']);
  _removeFromNested(body, 'generationConfig', const ['thinkingConfig']);
}

void _writeDialect(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningRequest request,
  ReasoningResolution resolution,
  ReasoningTransport transport,
) {
  final dialect = spec.reasoning.dialect;
  if (_isOpenAiDialect(dialect)) {
    _writeOpenAi(body, dialect, resolution, transport);
    return;
  }
  switch (dialect) {
    case ReasoningDialect.openrouterReasoning:
      _writeOpenRouter(body, spec, resolution);
    case ReasoningDialect.anthropicBudget:
      _writeAnthropicBudget(body, resolution);
    case ReasoningDialect.anthropicAdaptiveEffort:
      _writeAnthropicAdaptive(body, resolution);
    case ReasoningDialect.anthropicEffort:
      _writeAnthropicEffort(body, resolution);
    case ReasoningDialect.geminiThinkingBudget:
      _writeGeminiBudget(body, request, resolution);
    case ReasoningDialect.geminiThinkingLevel:
      _writeGeminiLevel(body, spec, resolution);
    case ReasoningDialect.qwenEnableThinking:
      _writeQwen(body, spec, request, resolution, transport);
    case ReasoningDialect.siliconflowEnableThinking:
      _writeSiliconFlow(body, resolution);
    case ReasoningDialect.thinkingType:
      _writeThinkingType(body, spec, resolution);
    case ReasoningDialect.kimiThinking:
      _writeKimiThinking(body, spec, resolution);
    case ReasoningDialect.internThinkingMode:
      _writeIntern(body, resolution);
    case ReasoningDialect.chatTemplateKwargs:
      _writeChatTemplateKwargs(body, resolution);
    case ReasoningDialect.custom:
      _writeCustom(body, spec, resolution);
    case ReasoningDialect.none:
    case ReasoningDialect.openaiReasoningEffort:
    case ReasoningDialect.openaiResponsesReasoning:
      break;
  }
}

void _writeOpenAi(
  Map<String, dynamic> body,
  ReasoningDialect dialect,
  ReasoningResolution resolution,
  ReasoningTransport transport,
) {
  final useResponsesEnvelope = switch (transport) {
    ReasoningTransport.responses => true,
    ReasoningTransport.chatCompletions => false,
    ReasoningTransport.anthropicMessages ||
    ReasoningTransport.geminiGenerateContent =>
      dialect == ReasoningDialect.openaiResponsesReasoning,
  };
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) {
    if (dialect == ReasoningDialect.openaiResponsesReasoning &&
        useResponsesEnvelope) {
      body['reasoning'] = <String, dynamic>{'summary': 'auto'};
    }
    return;
  }
  final effort = effective == ReasoningLevel.off ? 'none' : effective.name;
  if (useResponsesEnvelope) {
    body['reasoning'] = <String, dynamic>{'effort': effort, 'summary': 'auto'};
  } else {
    body['reasoning_effort'] = effort;
  }
}

void _writeOpenRouter(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningResolution resolution,
) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  if (effective == ReasoningLevel.off) {
    body['reasoning'] = <String, dynamic>{'enabled': false};
    return;
  }
  if (spec.reasoning.levels.isNotEmpty) {
    body['reasoning'] = <String, dynamic>{'effort': effective.name};
    return;
  }
  body['reasoning'] = <String, dynamic>{
    'enabled': true,
    if (resolution.budget != null) 'max_tokens': resolution.budget,
  };
}

void _writeAnthropicBudget(
  Map<String, dynamic> body,
  ReasoningResolution resolution,
) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  if (effective == ReasoningLevel.off) {
    body['thinking'] = <String, dynamic>{'type': 'disabled'};
    return;
  }
  body['thinking'] = <String, dynamic>{
    'type': 'enabled',
    'budget_tokens': resolution.budget,
  };
}

void _writeAnthropicAdaptive(
  Map<String, dynamic> body,
  ReasoningResolution resolution,
) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.off) {
    body['thinking'] = <String, dynamic>{'type': 'disabled'};
    return;
  }
  body['thinking'] = <String, dynamic>{
    'type': 'adaptive',
    'display': 'summarized',
  };
  if (_isExplicitLevel(effective)) {
    body['output_config'] = <String, dynamic>{'effort': effective.name};
  }
}

void _writeAnthropicEffort(
  Map<String, dynamic> body,
  ReasoningResolution resolution,
) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  if (effective == ReasoningLevel.off) {
    body['thinking'] = <String, dynamic>{'type': 'disabled'};
    return;
  }
  body['thinking'] = <String, dynamic>{'type': 'enabled'};
  body['output_config'] = <String, dynamic>{'effort': effective.name};
}

void _writeGeminiBudget(
  Map<String, dynamic> body,
  ReasoningRequest request,
  ReasoningResolution resolution,
) {
  final hideThoughts = request.level == ReasoningLevel.off;
  if (resolution.effective == ReasoningLevel.auto) {
    _setThinkingConfig(body, <String, dynamic>{'includeThoughts': true});
    return;
  }
  if (resolution.effective == ReasoningLevel.off) {
    _setThinkingConfig(body, <String, dynamic>{
      'includeThoughts': false,
      'thinkingBudget': 0,
    });
    return;
  }
  _setThinkingConfig(body, <String, dynamic>{
    'includeThoughts': !hideThoughts,
    'thinkingBudget': resolution.budget,
  });
}

void _writeGeminiLevel(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningResolution resolution,
) {
  if (resolution.effective == ReasoningLevel.auto) {
    _setThinkingConfig(body, <String, dynamic>{'includeThoughts': true});
    return;
  }
  final hideThoughts =
      resolution.requested == ReasoningLevel.off ||
      resolution.effective == ReasoningLevel.off;
  final level = hideThoughts
      ? _lowestExplicitLevel(spec.reasoning)
      : resolution.effective;
  _setThinkingConfig(body, <String, dynamic>{
    'includeThoughts': !hideThoughts,
    'thinkingLevel': level.name.toUpperCase(),
  });
}

void _writeQwen(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningRequest request,
  ReasoningResolution resolution,
  ReasoningTransport transport,
) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  if (effective == ReasoningLevel.off) {
    body['enable_thinking'] = false;
    return;
  }
  body['enable_thinking'] = true;
  if (transport == ReasoningTransport.responses) return;
  final budget = _qwenBudget(spec, request, resolution);
  if (budget != null) {
    body['thinking_budget'] = budget;
  }
}

int? _qwenBudget(
  ModelSpec spec,
  ReasoningRequest request,
  ReasoningResolution resolution,
) {
  if (_isExplicitLevel(request.level) && request.budgetTokens != null) {
    return request.budgetTokens;
  }
  if (spec.reasoning.budgets.isNotEmpty) return resolution.budget;
  return null;
}

void _writeSiliconFlow(
  Map<String, dynamic> body,
  ReasoningResolution resolution,
) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  if (effective == ReasoningLevel.off) {
    body['enable_thinking'] = false;
    return;
  }
  if (resolution.budget != null) {
    body['thinking_budget'] = resolution.budget;
  }
}

void _writeThinkingType(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningResolution resolution,
) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  if (effective == ReasoningLevel.off) {
    body['thinking'] = <String, dynamic>{'type': 'disabled'};
    return;
  }
  body['thinking'] = <String, dynamic>{'type': 'enabled'};
  if (spec.reasoning.levels.isNotEmpty) {
    body['reasoning_effort'] = effective.name;
  }
}

void _writeKimiThinking(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningResolution resolution,
) {
  // Single dialect: official Kimi Code OpenAI (OAuth) already sends
  // thinking.type/effort. API-key Moonshot Code currently writes top-level
  // reasoning_effort, but that lives in the builders this module replaces;
  // K3 is already openaiReasoningEffort. No in-repo evidence that Moonshot
  // rejects thinking.effort, so this is not split into a second enum.
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  if (effective == ReasoningLevel.off) {
    body['thinking'] = <String, dynamic>{'type': 'disabled'};
    return;
  }
  body['thinking'] = <String, dynamic>{
    'type': 'enabled',
    if (spec.reasoning.levels.isNotEmpty) 'effort': effective.name,
  };
}

void _writeIntern(Map<String, dynamic> body, ReasoningResolution resolution) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  body['thinking_mode'] = effective != ReasoningLevel.off;
}

void _writeChatTemplateKwargs(
  Map<String, dynamic> body,
  ReasoningResolution resolution,
) {
  final effective = resolution.effective;
  if (effective == ReasoningLevel.auto) return;
  final kwargs = _mutableChild(body, 'chat_template_kwargs');
  kwargs['enable_thinking'] = effective != ReasoningLevel.off;
}

void _writeCustom(
  Map<String, dynamic> body,
  ModelSpec spec,
  ReasoningResolution resolution,
) {
  if (resolution.effective == ReasoningLevel.auto) return;
  final patch = spec.reasoning.customPatches[resolution.effective];
  if (patch == null) return;
  final remove = patch[r'$remove'];
  if (remove is List) {
    for (final raw in remove) {
      final path = raw.toString().trim();
      if (path.isEmpty) continue;
      _removeDotted(body, path);
    }
  }
  _deepMerge(body, patch, skipKeys: const {r'$remove'});
}

void _setThinkingConfig(
  Map<String, dynamic> body,
  Map<String, dynamic> config,
) {
  _mutableChild(body, 'generationConfig')['thinkingConfig'] = config;
}

Map<String, dynamic> _asMutableMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _mutableChild(Map<String, dynamic> parent, String key) {
  final child = _asMutableMap(parent[key]);
  parent[key] = child;
  return child;
}

void _removeFromNested(
  Map<String, dynamic> body,
  String parentKey,
  Iterable<String> keys,
) {
  final raw = body[parentKey];
  if (raw is! Map) return;
  final child = _asMutableMap(raw);
  for (final key in keys) {
    child.remove(key);
  }
  if (child.isEmpty) {
    body.remove(parentKey);
  } else {
    body[parentKey] = child;
  }
}

void _removeDotted(Map<String, dynamic> body, String path) {
  final parts = [
    for (final part in path.split('.'))
      if (part.isNotEmpty) part,
  ];
  if (parts.isEmpty) return;
  _removePath(body, parts);
}

void _removePath(Map<String, dynamic> body, List<String> path) {
  final key = path.first;
  if (path.length == 1) {
    body.remove(key);
    return;
  }
  final raw = body[key];
  if (raw is! Map) return;
  final child = _asMutableMap(raw);
  _removePath(child, path.sublist(1));
  if (child.isEmpty) {
    body.remove(key);
  } else {
    body[key] = child;
  }
}

void _deepMerge(
  Map<String, dynamic> target,
  Map<dynamic, dynamic> patch, {
  Set<String> skipKeys = const {},
}) {
  for (final entry in patch.entries) {
    final key = entry.key.toString();
    if (skipKeys.contains(key)) continue;
    final incoming = entry.value;
    final existing = target[key];
    if (existing is Map && incoming is Map) {
      final merged = _asMutableMap(existing);
      _deepMerge(merged, incoming);
      target[key] = merged;
    } else if (incoming is Map) {
      target[key] = _asMutableMap(incoming);
    } else {
      target[key] = incoming;
    }
  }
}
