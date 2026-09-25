import 'package:flutter/foundation.dart';

enum ModelType { chat, embedding, image }

enum Modality { text, image, audio, video, pdf }

enum ModelAbility { tool, reasoning, structuredOutput }

enum ReasoningLevel { auto, off, minimal, low, medium, high, xhigh, max }

enum ReasoningDialect {
  none,
  openaiReasoningEffort,
  openaiResponsesReasoning,
  openrouterReasoning,
  anthropicBudget,
  anthropicAdaptiveEffort,
  anthropicEffort,
  geminiThinkingBudget,
  geminiThinkingLevel,
  qwenEnableThinking,
  thinkingType,
  siliconflowEnableThinking,
  internThinkingMode,
  chatTemplateKwargs,
  kimiThinking,
  custom,
}

enum ReasoningReplayPolicy { none, toolTurns, all }

enum ReasoningReplayField {
  reasoningContent,
  reasoning,
  reasoningDetails;

  String get wireName => switch (this) {
    ReasoningReplayField.reasoningContent => 'reasoning_content',
    ReasoningReplayField.reasoning => 'reasoning',
    ReasoningReplayField.reasoningDetails => 'reasoning_details',
  };
}

enum SamplingPolicy { always, onlyWhenReasoningOff, never }

const Set<Modality> _outputModalities = {
  Modality.text,
  Modality.image,
  Modality.audio,
};

List<T> _uniqueSortedByIndex<T extends Enum>(Iterable<T> values) {
  final set = <T>{...values};
  final list = set.toList()..sort((a, b) => a.index.compareTo(b.index));
  return List<T>.unmodifiable(list);
}

List<ReasoningLevel> _normalizeReasoningLevels(
  Iterable<ReasoningLevel> levels,
) {
  return _uniqueSortedByIndex(
    levels.where(
      (level) => level != ReasoningLevel.auto && level != ReasoningLevel.off,
    ),
  );
}

List<Modality> _normalizeInputModalities(Iterable<Modality> mods) {
  final list = _uniqueSortedByIndex(mods);
  return list.isEmpty ? const [Modality.text] : list;
}

List<Modality> _normalizeOutputModalities(
  Iterable<Modality> mods,
  ModelType type,
) {
  if (type == ModelType.embedding) return const [Modality.text];
  final list = _uniqueSortedByIndex(mods.where(_outputModalities.contains));
  return list.isEmpty ? const [Modality.text] : list;
}

List<ModelAbility> _normalizeAbilities(
  Iterable<ModelAbility> abilities,
  ModelType type,
) {
  if (type == ModelType.embedding) return const <ModelAbility>[];
  return _uniqueSortedByIndex(abilities);
}

List<Map<String, String>> _freezeRows(List<Map<String, String>> rows) {
  if (rows.isEmpty) return const [];
  return List<Map<String, String>>.unmodifiable([
    for (final row in rows) Map<String, String>.unmodifiable(row),
  ]);
}

List<String> _freezeStrings(List<String> values) {
  if (values.isEmpty) return const [];
  return List<String>.unmodifiable(values);
}

bool _rowsEqual(List<Map<String, String>> a, List<Map<String, String>> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!mapEquals(a[i], b[i])) return false;
  }
  return true;
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return Object.hashAll(
      entries.map((e) => Object.hash(_deepHash(e.key), _deepHash(e.value))),
    );
  }
  if (value is List) {
    return Object.hashAll(value.map(_deepHash));
  }
  return value.hashCode;
}

int _rowsHash(List<Map<String, String>> rows) {
  return Object.hashAll(
    rows.map(
      (row) =>
          Object.hashAll(row.entries.map((e) => Object.hash(e.key, e.value))),
    ),
  );
}

T? _enumByName<T extends Enum>(Iterable<T> values, dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  for (final value in values) {
    if (value.name == s) return value;
  }
  final lower = s.toLowerCase();
  for (final value in values) {
    if (value.name.toLowerCase() == lower) return value;
  }
  return null;
}

int? _asInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

double? _asDouble(dynamic raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}

bool? _asBool(dynamic raw) => raw is bool ? raw : null;

String? _asNonEmptyString(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

@immutable
class ReasoningSpec {
  final List<ReasoningLevel> levels;
  final bool canDisable;
  final ReasoningLevel defaultLevel;
  final ReasoningDialect dialect;
  final Map<ReasoningLevel, int> budgets;
  final Map<ReasoningLevel, Map<String, dynamic>> customPatches;
  final ReasoningReplayPolicy replay;
  final ReasoningReplayField replayField;

  const ReasoningSpec({
    this.levels = const [],
    this.canDisable = false,
    this.defaultLevel = ReasoningLevel.auto,
    this.dialect = ReasoningDialect.none,
    this.budgets = const {},
    this.customPatches = const {},
    this.replay = ReasoningReplayPolicy.none,
    this.replayField = ReasoningReplayField.reasoningContent,
  });

  ReasoningSpec copyWith({
    List<ReasoningLevel>? levels,
    bool? canDisable,
    ReasoningLevel? defaultLevel,
    ReasoningDialect? dialect,
    Map<ReasoningLevel, int>? budgets,
    Map<ReasoningLevel, Map<String, dynamic>>? customPatches,
    ReasoningReplayPolicy? replay,
    ReasoningReplayField? replayField,
  }) {
    return ReasoningSpec(
      levels: _normalizeReasoningLevels(levels ?? this.levels),
      canDisable: canDisable ?? this.canDisable,
      defaultLevel: defaultLevel ?? this.defaultLevel,
      dialect: dialect ?? this.dialect,
      budgets: budgets ?? this.budgets,
      customPatches: customPatches ?? this.customPatches,
      replay: replay ?? this.replay,
      replayField: replayField ?? this.replayField,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'levels': [for (final level in levels) level.name],
      'canDisable': canDisable,
      'defaultLevel': defaultLevel.name,
      'dialect': dialect.name,
      'budgets': <String, int>{
        for (final e in budgets.entries) e.key.name: e.value,
      },
      'customPatches': <String, Map<String, dynamic>>{
        for (final e in customPatches.entries) e.key.name: e.value,
      },
      'replay': replay.name,
      'replayField': replayField.name,
    };
  }

  factory ReasoningSpec.fromJson(Map json) {
    final rawLevels = json['levels'];
    final levels = <ReasoningLevel>[];
    if (rawLevels is List) {
      for (final e in rawLevels) {
        final level = _enumByName(ReasoningLevel.values, e);
        if (level != null) levels.add(level);
      }
    }

    final budgets = <ReasoningLevel, int>{};
    final rawBudgets = json['budgets'];
    if (rawBudgets is Map) {
      for (final e in rawBudgets.entries) {
        final level = _enumByName(ReasoningLevel.values, e.key);
        final value = _asInt(e.value);
        if (level != null && value != null) {
          budgets[level] = value;
        }
      }
    }

    final patches = <ReasoningLevel, Map<String, dynamic>>{};
    final rawPatches = json['customPatches'];
    if (rawPatches is Map) {
      for (final e in rawPatches.entries) {
        final level = _enumByName(ReasoningLevel.values, e.key);
        final value = e.value;
        if (level == null || value is! Map) continue;
        patches[level] = <String, dynamic>{
          for (final entry in value.entries) entry.key.toString(): entry.value,
        };
      }
    }

    return ReasoningSpec(
      levels: _normalizeReasoningLevels(levels),
      canDisable: json['canDisable'] == true,
      defaultLevel:
          _enumByName(ReasoningLevel.values, json['defaultLevel']) ??
          ReasoningLevel.auto,
      dialect:
          _enumByName(ReasoningDialect.values, json['dialect']) ??
          ReasoningDialect.none,
      budgets: budgets,
      customPatches: patches,
      replay:
          _enumByName(ReasoningReplayPolicy.values, json['replay']) ??
          ReasoningReplayPolicy.none,
      replayField:
          _enumByName(ReasoningReplayField.values, json['replayField']) ??
          ReasoningReplayField.reasoningContent,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReasoningSpec &&
            runtimeType == other.runtimeType &&
            listEquals(levels, other.levels) &&
            canDisable == other.canDisable &&
            defaultLevel == other.defaultLevel &&
            dialect == other.dialect &&
            mapEquals(budgets, other.budgets) &&
            _deepEquals(customPatches, other.customPatches) &&
            replay == other.replay &&
            replayField == other.replayField);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(levels),
    canDisable,
    defaultLevel,
    dialect,
    _deepHash(budgets),
    _deepHash(customPatches),
    replay,
    replayField,
  );
}

@immutable
class ReasoningSpecOverride {
  final List<ReasoningLevel>? levels;
  final bool? canDisable;
  final ReasoningLevel? defaultLevel;
  final ReasoningDialect? dialect;
  final Map<ReasoningLevel, int>? budgets;
  final Map<ReasoningLevel, Map<String, dynamic>>? customPatches;
  final ReasoningReplayPolicy? replay;
  final ReasoningReplayField? replayField;

  const ReasoningSpecOverride({
    this.levels,
    this.canDisable,
    this.defaultLevel,
    this.dialect,
    this.budgets,
    this.customPatches,
    this.replay,
    this.replayField,
  });

  bool get isEmpty =>
      levels == null &&
      canDisable == null &&
      defaultLevel == null &&
      dialect == null &&
      budgets == null &&
      customPatches == null &&
      replay == null &&
      replayField == null;

  ReasoningSpecOverride copyWith({
    List<ReasoningLevel>? levels,
    bool clearLevels = false,
    bool? canDisable,
    bool clearCanDisable = false,
    ReasoningLevel? defaultLevel,
    bool clearDefaultLevel = false,
    ReasoningDialect? dialect,
    bool clearDialect = false,
    Map<ReasoningLevel, int>? budgets,
    bool clearBudgets = false,
    Map<ReasoningLevel, Map<String, dynamic>>? customPatches,
    bool clearCustomPatches = false,
    ReasoningReplayPolicy? replay,
    bool clearReplay = false,
    ReasoningReplayField? replayField,
    bool clearReplayField = false,
  }) {
    return ReasoningSpecOverride(
      levels: clearLevels
          ? null
          : (levels != null ? _normalizeReasoningLevels(levels) : this.levels),
      canDisable: clearCanDisable ? null : (canDisable ?? this.canDisable),
      defaultLevel: clearDefaultLevel
          ? null
          : (defaultLevel ?? this.defaultLevel),
      dialect: clearDialect ? null : (dialect ?? this.dialect),
      budgets: clearBudgets ? null : (budgets ?? this.budgets),
      customPatches: clearCustomPatches
          ? null
          : (customPatches ?? this.customPatches),
      replay: clearReplay ? null : (replay ?? this.replay),
      replayField: clearReplayField ? null : (replayField ?? this.replayField),
    );
  }

  factory ReasoningSpecOverride.fromJson(Map json) {
    List<ReasoningLevel>? levels;
    if (json.containsKey('levels')) {
      final rawLevels = json['levels'];
      if (rawLevels is List) {
        final parsed = <ReasoningLevel>[];
        for (final e in rawLevels) {
          final level = _enumByName(ReasoningLevel.values, e);
          if (level != null) parsed.add(level);
        }
        levels = _normalizeReasoningLevels(parsed);
      }
    }

    bool? canDisable;
    if (json.containsKey('canDisable')) {
      final raw = json['canDisable'];
      if (raw is bool) {
        canDisable = raw;
      }
    }

    Map<ReasoningLevel, int>? budgets;
    if (json.containsKey('budgets')) {
      final rawBudgets = json['budgets'];
      if (rawBudgets is Map) {
        budgets = <ReasoningLevel, int>{};
        for (final e in rawBudgets.entries) {
          final level = _enumByName(ReasoningLevel.values, e.key);
          final value = _asInt(e.value);
          if (level != null && value != null) {
            budgets[level] = value;
          }
        }
      }
    }

    Map<ReasoningLevel, Map<String, dynamic>>? customPatches;
    if (json.containsKey('customPatches')) {
      final rawPatches = json['customPatches'];
      if (rawPatches is Map) {
        customPatches = <ReasoningLevel, Map<String, dynamic>>{};
        for (final e in rawPatches.entries) {
          final level = _enumByName(ReasoningLevel.values, e.key);
          final value = e.value;
          if (level == null || value is! Map) continue;
          customPatches[level] = <String, dynamic>{
            for (final entry in value.entries)
              entry.key.toString(): entry.value,
          };
        }
      }
    }

    return ReasoningSpecOverride(
      levels: levels,
      canDisable: canDisable,
      defaultLevel: json.containsKey('defaultLevel')
          ? _enumByName(ReasoningLevel.values, json['defaultLevel'])
          : null,
      dialect: json.containsKey('dialect')
          ? _enumByName(ReasoningDialect.values, json['dialect'])
          : null,
      budgets: budgets,
      customPatches: customPatches,
      replay: json.containsKey('replay')
          ? _enumByName(ReasoningReplayPolicy.values, json['replay'])
          : null,
      replayField: json.containsKey('replayField')
          ? _enumByName(ReasoningReplayField.values, json['replayField'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (levels != null) 'levels': [for (final level in levels!) level.name],
      if (canDisable != null) 'canDisable': canDisable,
      if (defaultLevel != null) 'defaultLevel': defaultLevel!.name,
      if (dialect != null) 'dialect': dialect!.name,
      if (budgets != null)
        'budgets': <String, int>{
          for (final e in budgets!.entries) e.key.name: e.value,
        },
      if (customPatches != null)
        'customPatches': <String, Map<String, dynamic>>{
          for (final e in customPatches!.entries) e.key.name: e.value,
        },
      if (replay != null) 'replay': replay!.name,
      if (replayField != null) 'replayField': replayField!.name,
    };
  }

  ReasoningSpec applyTo(ReasoningSpec base) {
    if (isEmpty) return base;
    return base.copyWith(
      levels: levels ?? base.levels,
      canDisable: canDisable ?? base.canDisable,
      defaultLevel: defaultLevel ?? base.defaultLevel,
      dialect: dialect ?? base.dialect,
      budgets: budgets ?? base.budgets,
      customPatches: customPatches ?? base.customPatches,
      replay: replay ?? base.replay,
      replayField: replayField ?? base.replayField,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReasoningSpecOverride &&
            runtimeType == other.runtimeType &&
            listEquals(levels, other.levels) &&
            canDisable == other.canDisable &&
            defaultLevel == other.defaultLevel &&
            dialect == other.dialect &&
            mapEquals(budgets, other.budgets) &&
            _deepEquals(customPatches, other.customPatches) &&
            replay == other.replay &&
            replayField == other.replayField);
  }

  @override
  int get hashCode => Object.hash(
    levels == null ? null : Object.hashAll(levels!),
    canDisable,
    defaultLevel,
    dialect,
    budgets == null ? null : _deepHash(budgets),
    customPatches == null ? null : _deepHash(customPatches),
    replay,
    replayField,
  );
}

@immutable
class ModelPricing {
  final double? input;
  final double? output;
  final double? cacheRead;
  final double? cacheWrite;
  final String currency;

  const ModelPricing({
    this.input,
    this.output,
    this.cacheRead,
    this.cacheWrite,
    this.currency = 'USD',
  });

  ModelPricing copyWith({
    double? input,
    double? output,
    double? cacheRead,
    double? cacheWrite,
    String? currency,
  }) {
    return ModelPricing(
      input: input ?? this.input,
      output: output ?? this.output,
      cacheRead: cacheRead ?? this.cacheRead,
      cacheWrite: cacheWrite ?? this.cacheWrite,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (input != null) 'input': input,
      if (output != null) 'output': output,
      if (cacheRead != null) 'cacheRead': cacheRead,
      if (cacheWrite != null) 'cacheWrite': cacheWrite,
      'currency': currency,
    };
  }

  factory ModelPricing.fromJson(Map json) {
    return ModelPricing(
      input: _asDouble(json['input']),
      output: _asDouble(json['output']),
      cacheRead: _asDouble(json['cacheRead']),
      cacheWrite: _asDouble(json['cacheWrite']),
      currency: _asNonEmptyString(json['currency']) ?? 'USD',
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ModelPricing &&
            runtimeType == other.runtimeType &&
            input == other.input &&
            output == other.output &&
            cacheRead == other.cacheRead &&
            cacheWrite == other.cacheWrite &&
            currency == other.currency);
  }

  @override
  int get hashCode =>
      Object.hash(input, output, cacheRead, cacheWrite, currency);
}

@immutable
class ModelSpec {
  final String id;
  final String? apiModelId;
  final String displayName;
  final ModelType type;
  final List<Modality> input;
  final List<Modality> output;
  final List<ModelAbility> abilities;
  final ReasoningSpec reasoning;
  final SamplingPolicy sampling;
  final int? contextWindow;
  final int? maxOutput;
  final ModelPricing? pricing;
  final List<Map<String, String>> headers;
  final List<Map<String, String>> body;
  final List<String> builtInTools;

  /// Accepts Anthropic's dynamic-filtering web search / fetch tool versions.
  final bool dynamicWebSearch;

  /// Accepts `http(s)` image URLs; otherwise images must be inlined.
  final bool remoteImageUrls;

  /// Accepts Anthropic-style `cache_control` on an OpenAI-compatible route.
  final bool promptCacheControl;

  String get upstreamId => apiModelId ?? id;

  bool get supportsTool => abilities.contains(ModelAbility.tool);

  bool get supportsReasoning => abilities.contains(ModelAbility.reasoning);

  bool get supportsImageInput => input.contains(Modality.image);

  bool get supportsAudioInput => input.contains(Modality.audio);

  bool get supportsVideoInput => input.contains(Modality.video);

  bool get isEmbedding => type == ModelType.embedding;

  ModelSpec({
    required this.id,
    required this.displayName,
    this.type = ModelType.chat,
    List<Modality> input = const [Modality.text],
    List<Modality> output = const [Modality.text],
    List<ModelAbility> abilities = const [],
    this.apiModelId,
    this.reasoning = const ReasoningSpec(),
    this.sampling = SamplingPolicy.always,
    this.contextWindow,
    this.maxOutput,
    this.pricing,
    List<Map<String, String>> headers = const [],
    List<Map<String, String>> body = const [],
    List<String> builtInTools = const [],
    this.dynamicWebSearch = false,
    this.remoteImageUrls = true,
    this.promptCacheControl = false,
  }) : input = _normalizeInputModalities(input),
       output = _normalizeOutputModalities(output, type),
       abilities = _normalizeAbilities(abilities, type),
       headers = _freezeRows(headers),
       body = _freezeRows(body),
       builtInTools = _freezeStrings(builtInTools);

  ModelSpec copyWith({
    String? id,
    String? apiModelId,
    String? displayName,
    ModelType? type,
    List<Modality>? input,
    List<Modality>? output,
    List<ModelAbility>? abilities,
    ReasoningSpec? reasoning,
    SamplingPolicy? sampling,
    int? contextWindow,
    int? maxOutput,
    ModelPricing? pricing,
    List<Map<String, String>>? headers,
    List<Map<String, String>>? body,
    List<String>? builtInTools,
    bool? dynamicWebSearch,
    bool? remoteImageUrls,
    bool? promptCacheControl,
  }) {
    return ModelSpec(
      id: id ?? this.id,
      apiModelId: apiModelId ?? this.apiModelId,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      input: input ?? this.input,
      output: output ?? this.output,
      abilities: abilities ?? this.abilities,
      reasoning: reasoning ?? this.reasoning,
      sampling: sampling ?? this.sampling,
      contextWindow: contextWindow ?? this.contextWindow,
      maxOutput: maxOutput ?? this.maxOutput,
      pricing: pricing ?? this.pricing,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      builtInTools: builtInTools ?? this.builtInTools,
      dynamicWebSearch: dynamicWebSearch ?? this.dynamicWebSearch,
      remoteImageUrls: remoteImageUrls ?? this.remoteImageUrls,
      promptCacheControl: promptCacheControl ?? this.promptCacheControl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ModelSpec &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            apiModelId == other.apiModelId &&
            displayName == other.displayName &&
            type == other.type &&
            listEquals(input, other.input) &&
            listEquals(output, other.output) &&
            listEquals(abilities, other.abilities) &&
            reasoning == other.reasoning &&
            sampling == other.sampling &&
            contextWindow == other.contextWindow &&
            maxOutput == other.maxOutput &&
            pricing == other.pricing &&
            _rowsEqual(headers, other.headers) &&
            _rowsEqual(body, other.body) &&
            listEquals(builtInTools, other.builtInTools) &&
            dynamicWebSearch == other.dynamicWebSearch &&
            remoteImageUrls == other.remoteImageUrls &&
            promptCacheControl == other.promptCacheControl);
  }

  @override
  int get hashCode => Object.hash(
    id,
    apiModelId,
    displayName,
    type,
    Object.hashAll(input),
    Object.hashAll(output),
    Object.hashAll(abilities),
    reasoning,
    sampling,
    contextWindow,
    maxOutput,
    pricing,
    _rowsHash(headers),
    _rowsHash(body),
    Object.hashAll(builtInTools),
    dynamicWebSearch,
    remoteImageUrls,
    promptCacheControl,
  );
}

@immutable
class ModelSpecOverride {
  static const Set<String> _knownKeys = {
    'apiModelId',
    'api_model_id',
    'name',
    'type',
    't',
    'input',
    'output',
    'abilities',
    'headers',
    'body',
    'builtInTools',
    'built_in_tools',
    'reasoning',
    'sampling',
    'contextWindow',
    'maxOutput',
    'pricing',
    'dynamicWebSearch',
    'remoteImageUrls',
    'promptCacheControl',
  };

  final String? apiModelId;
  final String? displayName;
  final ModelType? type;
  final List<Modality>? input;
  final List<Modality>? output;
  final List<ModelAbility>? abilities;
  final ReasoningSpecOverride? reasoning;
  final SamplingPolicy? sampling;
  final int? contextWindow;
  final int? maxOutput;
  final ModelPricing? pricing;
  final List<Map<String, String>>? headers;
  final List<Map<String, String>>? body;
  final List<String>? builtInTools;
  final bool? dynamicWebSearch;
  final bool? remoteImageUrls;
  final bool? promptCacheControl;
  final Map<String, dynamic> extra;

  const ModelSpecOverride({
    this.apiModelId,
    this.displayName,
    this.type,
    this.input,
    this.output,
    this.abilities,
    this.reasoning,
    this.sampling,
    this.contextWindow,
    this.maxOutput,
    this.pricing,
    this.headers,
    this.body,
    this.builtInTools,
    this.dynamicWebSearch,
    this.remoteImageUrls,
    this.promptCacheControl,
    this.extra = const {},
  });

  bool get isEmpty =>
      apiModelId == null &&
      displayName == null &&
      type == null &&
      input == null &&
      output == null &&
      abilities == null &&
      (reasoning == null || reasoning!.isEmpty) &&
      sampling == null &&
      contextWindow == null &&
      maxOutput == null &&
      pricing == null &&
      headers == null &&
      body == null &&
      builtInTools == null &&
      dynamicWebSearch == null &&
      remoteImageUrls == null &&
      promptCacheControl == null &&
      extra.isEmpty;

  ModelSpecOverride copyWith({
    String? apiModelId,
    bool clearApiModelId = false,
    String? displayName,
    bool clearDisplayName = false,
    ModelType? type,
    bool clearType = false,
    List<Modality>? input,
    bool clearInput = false,
    List<Modality>? output,
    bool clearOutput = false,
    List<ModelAbility>? abilities,
    bool clearAbilities = false,
    ReasoningSpecOverride? reasoning,
    bool clearReasoning = false,
    SamplingPolicy? sampling,
    bool clearSampling = false,
    int? contextWindow,
    bool clearContextWindow = false,
    int? maxOutput,
    bool clearMaxOutput = false,
    ModelPricing? pricing,
    bool clearPricing = false,
    List<Map<String, String>>? headers,
    bool clearHeaders = false,
    List<Map<String, String>>? body,
    bool clearBody = false,
    List<String>? builtInTools,
    bool clearBuiltInTools = false,
    bool? dynamicWebSearch,
    bool clearDynamicWebSearch = false,
    bool? remoteImageUrls,
    bool clearRemoteImageUrls = false,
    bool? promptCacheControl,
    bool clearPromptCacheControl = false,
    Map<String, dynamic>? extra,
  }) {
    return ModelSpecOverride(
      apiModelId: clearApiModelId ? null : (apiModelId ?? this.apiModelId),
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      type: clearType ? null : (type ?? this.type),
      input: clearInput ? null : (input ?? this.input),
      output: clearOutput ? null : (output ?? this.output),
      abilities: clearAbilities ? null : (abilities ?? this.abilities),
      reasoning: clearReasoning ? null : (reasoning ?? this.reasoning),
      sampling: clearSampling ? null : (sampling ?? this.sampling),
      contextWindow: clearContextWindow
          ? null
          : (contextWindow ?? this.contextWindow),
      maxOutput: clearMaxOutput ? null : (maxOutput ?? this.maxOutput),
      pricing: clearPricing ? null : (pricing ?? this.pricing),
      headers: clearHeaders ? null : (headers ?? this.headers),
      body: clearBody ? null : (body ?? this.body),
      builtInTools: clearBuiltInTools
          ? null
          : (builtInTools ?? this.builtInTools),
      dynamicWebSearch: clearDynamicWebSearch
          ? null
          : (dynamicWebSearch ?? this.dynamicWebSearch),
      remoteImageUrls: clearRemoteImageUrls
          ? null
          : (remoteImageUrls ?? this.remoteImageUrls),
      promptCacheControl: clearPromptCacheControl
          ? null
          : (promptCacheControl ?? this.promptCacheControl),
      extra: extra ?? this.extra,
    );
  }

  factory ModelSpecOverride.fromJson(Map ov) {
    final map = <String, dynamic>{
      for (final e in ov.entries) e.key.toString(): e.value,
    };
    final extra = <String, dynamic>{
      for (final e in map.entries)
        if (!_knownKeys.contains(e.key)) e.key: e.value,
    };

    return ModelSpecOverride(
      apiModelId: _asNonEmptyString(map['apiModelId'] ?? map['api_model_id']),
      displayName: _asNonEmptyString(map['name']),
      type: _parseType(map['type'] ?? map['t']),
      input: _parseModalities(map['input']),
      output: _parseModalities(map['output']),
      abilities: _parseAbilities(map['abilities']),
      reasoning: _parseReasoning(map['reasoning']),
      sampling: _enumByName(SamplingPolicy.values, map['sampling']),
      contextWindow: _asInt(map['contextWindow']),
      maxOutput: _asInt(map['maxOutput']),
      pricing: _parsePricing(map['pricing']),
      headers: _parseRows(map['headers']),
      body: _parseRows(map['body']),
      builtInTools: _parseStringList(
        map['builtInTools'] ?? map['built_in_tools'],
      ),
      dynamicWebSearch: _asBool(map['dynamicWebSearch']),
      remoteImageUrls: _asBool(map['remoteImageUrls']),
      promptCacheControl: _asBool(map['promptCacheControl']),
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (apiModelId != null) 'apiModelId': apiModelId,
      if (displayName != null) 'name': displayName,
      if (type != null) 'type': type!.name,
      if (input != null) 'input': [for (final m in input!) m.name],
      if (output != null) 'output': [for (final m in output!) m.name],
      if (abilities != null) 'abilities': [for (final a in abilities!) a.name],
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      if (builtInTools != null) 'builtInTools': builtInTools,
      if (reasoning != null && !reasoning!.isEmpty)
        'reasoning': reasoning!.toJson(),
      if (sampling != null) 'sampling': sampling!.name,
      if (contextWindow != null) 'contextWindow': contextWindow,
      if (maxOutput != null) 'maxOutput': maxOutput,
      if (pricing != null) 'pricing': pricing!.toJson(),
      if (dynamicWebSearch != null) 'dynamicWebSearch': dynamicWebSearch,
      if (remoteImageUrls != null) 'remoteImageUrls': remoteImageUrls,
      if (promptCacheControl != null) 'promptCacheControl': promptCacheControl,
      ...extra,
    };
  }

  ModelSpec applyTo(ModelSpec base, {bool applyDisplayName = false}) {
    final effectiveType = type ?? base.type;
    final inputMods = _nonEmptyModalities(input ?? base.input);
    final outputMods = effectiveType == ModelType.embedding
        ? const [Modality.text]
        : _nonEmptyModalities(output ?? base.output);
    final nextAbilities = effectiveType == ModelType.embedding
        ? const <ModelAbility>[]
        : (abilities ?? base.abilities);
    final next = base.copyWith(
      apiModelId: apiModelId ?? base.apiModelId,
      displayName: (applyDisplayName ? displayName : null) ?? base.displayName,
      type: effectiveType,
      input: inputMods,
      output: outputMods,
      abilities: nextAbilities,
      reasoning: reasoning?.applyTo(base.reasoning) ?? base.reasoning,
      sampling: sampling ?? base.sampling,
      contextWindow: contextWindow ?? base.contextWindow,
      maxOutput: maxOutput ?? base.maxOutput,
      pricing: pricing ?? base.pricing,
      headers: headers ?? base.headers,
      body: body ?? base.body,
      builtInTools: builtInTools ?? base.builtInTools,
      dynamicWebSearch: dynamicWebSearch ?? base.dynamicWebSearch,
      remoteImageUrls: remoteImageUrls ?? base.remoteImageUrls,
      promptCacheControl: promptCacheControl ?? base.promptCacheControl,
    );
    return next == base ? base : next;
  }

  static ModelType? _parseType(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase() ?? '';
    if (s.isEmpty) return null;
    if (s == 'embedding' || s == 'embeddings') return ModelType.embedding;
    if (s == 'chat') return ModelType.chat;
    if (s == 'image') return ModelType.image;
    return null;
  }

  static List<Modality>? _parseModalities(dynamic raw) {
    if (raw is! List) return null;
    if (raw.isEmpty) return const <Modality>[];
    final out = <Modality>[];
    for (final e in raw) {
      final value = _enumByName(Modality.values, e);
      if (value != null) out.add(value);
    }
    if (out.isEmpty) return null;
    return _uniqueSortedByIndex(out);
  }

  static List<ModelAbility>? _parseAbilities(dynamic raw) {
    if (raw is! List) return null;
    if (raw.isEmpty) return const <ModelAbility>[];
    final out = <ModelAbility>[];
    for (final e in raw) {
      final value = _enumByName(ModelAbility.values, e);
      if (value != null) out.add(value);
    }
    if (out.isEmpty) return null;
    return _uniqueSortedByIndex(out);
  }

  static ReasoningSpecOverride? _parseReasoning(dynamic raw) {
    if (raw is! Map) return null;
    final override = ReasoningSpecOverride.fromJson(raw);
    return override.isEmpty ? null : override;
  }

  static ModelPricing? _parsePricing(dynamic raw) {
    if (raw is! Map) return null;
    return ModelPricing.fromJson(raw);
  }

  static List<Map<String, String>>? _parseRows(dynamic raw) {
    if (raw is! List) return null;
    return [
      for (final e in raw)
        if (e is Map)
          <String, String>{
            for (final entry in e.entries)
              entry.key.toString(): entry.value?.toString() ?? '',
          },
    ];
  }

  static List<String>? _parseStringList(dynamic raw) {
    if (raw is! List) return null;
    return [for (final e in raw) e.toString()];
  }

  static List<Modality> _nonEmptyModalities(List<Modality> mods) {
    return mods.isEmpty ? const [Modality.text] : mods;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ModelSpecOverride &&
            runtimeType == other.runtimeType &&
            apiModelId == other.apiModelId &&
            displayName == other.displayName &&
            type == other.type &&
            listEquals(input, other.input) &&
            listEquals(output, other.output) &&
            listEquals(abilities, other.abilities) &&
            reasoning == other.reasoning &&
            sampling == other.sampling &&
            contextWindow == other.contextWindow &&
            maxOutput == other.maxOutput &&
            pricing == other.pricing &&
            _nullableRowsEqual(headers, other.headers) &&
            _nullableRowsEqual(body, other.body) &&
            listEquals(builtInTools, other.builtInTools) &&
            dynamicWebSearch == other.dynamicWebSearch &&
            remoteImageUrls == other.remoteImageUrls &&
            promptCacheControl == other.promptCacheControl &&
            _deepEquals(extra, other.extra));
  }

  @override
  int get hashCode => Object.hash(
    apiModelId,
    displayName,
    type,
    input == null ? null : Object.hashAll(input!),
    output == null ? null : Object.hashAll(output!),
    abilities == null ? null : Object.hashAll(abilities!),
    reasoning,
    sampling,
    contextWindow,
    maxOutput,
    pricing,
    headers == null ? null : _rowsHash(headers!),
    body == null ? null : _rowsHash(body!),
    builtInTools == null ? null : Object.hashAll(builtInTools!),
    Object.hash(dynamicWebSearch, remoteImageUrls, promptCacheControl),
    _deepHash(extra),
  );

  static bool _nullableRowsEqual(
    List<Map<String, String>>? a,
    List<Map<String, String>>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return _rowsEqual(a, b);
  }
}
