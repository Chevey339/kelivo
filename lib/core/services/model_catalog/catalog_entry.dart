/// Trimmed models.dev catalog JSON.
///
/// Absent/null values are omitted. Boolean defaults (`temperature: true` and
/// the other flags `false`) are also omitted to keep the snapshot small.
///
/// Key mapping (trimmed JSON → field):
///
/// Top-level:
/// - `schemaVersion` → [ModelCatalogData.schemaVersion]
/// - `generatedAt` → [ModelCatalogData.generatedAt] (ISO-8601 UTC)
/// - `providers` → [ModelCatalogData.providers]
///
/// Provider:
/// - `id` → [CatalogProvider.id]
/// - `name` → [CatalogProvider.name]
/// - `api` → [CatalogProvider.api] (raw base URL)
/// - `models` → [CatalogProvider.models]
///
/// Model:
/// - `id` → [CatalogModel.id]
/// - `name` → [CatalogModel.name]
/// - `family` → [CatalogModel.family]
/// - `status` → [CatalogModel.status]
/// - `tool` → [CatalogModel.toolCall]
/// - `rsn` → [CatalogModel.reasoning]
/// - `so` → [CatalogModel.structuredOutput]
/// - `temp` → [CatalogModel.temperature]
/// - `att` → [CatalogModel.attachment]
/// - `ro` → [CatalogModel.reasoningOptions]
/// - `il` → interleaved flag: `true` or `{field: <interleavedField>}`
/// - `in` → [CatalogModel.inputModalities]
/// - `out` → [CatalogModel.outputModalities]
/// - `limit` → `{context, input, output}`
/// - `cost` → `{input, output, cache_read, cache_write}`
///
/// Reasoning option:
/// - `type` → [CatalogReasoningOption.type] (`effort` | `budget_tokens` | `toggle`)
/// - `values` → [CatalogReasoningOption.values]
/// - `min` / `max` → [CatalogReasoningOption.min] / [CatalogReasoningOption.max]
library;

class ModelCatalogData {
  const ModelCatalogData({
    required this.schemaVersion,
    required this.generatedAt,
    required this.providers,
  });

  final int schemaVersion;
  final DateTime generatedAt;
  final Map<String, CatalogProvider> providers;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'providers': <String, dynamic>{
        for (final entry in providers.entries) entry.key: entry.value.toJson(),
      },
    };
  }

  factory ModelCatalogData.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != 1) {
      throw FormatException('unsupported schemaVersion: $version');
    }
    final providersRaw = json['providers'];
    if (providersRaw is! Map) {
      throw const FormatException('missing providers map');
    }

    final providers = <String, CatalogProvider>{};
    for (final entry in providersRaw.entries) {
      final key = entry.key;
      if (key is! String) {
        continue;
      }
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final provider = CatalogProvider.fromJson(
        Map<String, dynamic>.from(value),
        fallbackId: key,
      );
      if (provider.id.isEmpty) {
        continue;
      }
      providers[provider.id] = provider;
    }

    return ModelCatalogData(
      schemaVersion: 1,
      generatedAt: _readGeneratedAt(json['generatedAt']),
      providers: providers,
    );
  }
}

class CatalogProvider {
  const CatalogProvider({
    required this.id,
    required this.name,
    this.api,
    this.models = const <String, CatalogModel>{},
  });

  final String id;
  final String name;
  final String? api;
  final Map<String, CatalogModel> models;

  /// Lowercase host of [api], or `null` when [api] is missing/unparseable.
  String? get apiHost {
    final raw = api;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final host = Uri.tryParse(raw)?.host;
    if (host == null || host.isEmpty) {
      return null;
    }
    return host.toLowerCase();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (api != null) 'api': api,
      'models': <String, dynamic>{
        for (final entry in models.entries) entry.key: entry.value.toJson(),
      },
    };
  }

  factory CatalogProvider.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) {
    final id = _readNonEmptyString(json['id']) ?? fallbackId ?? '';
    final models = <String, CatalogModel>{};
    final modelsRaw = json['models'];
    if (modelsRaw is Map) {
      for (final entry in modelsRaw.entries) {
        final value = entry.value;
        if (value is! Map) {
          continue;
        }
        final model = CatalogModel.fromJson(Map<String, dynamic>.from(value));
        if (model.id.isEmpty) {
          continue;
        }
        models[model.id] = model;
      }
    }
    return CatalogProvider(
      id: id,
      name: _readNonEmptyString(json['name']) ?? id,
      api: _readNonEmptyString(json['api']),
      models: models,
    );
  }
}

class CatalogReasoningOption {
  const CatalogReasoningOption({
    required this.type,
    this.values = const <String>[],
    this.min,
    this.max,
  });

  /// `effort` | `budget_tokens` | `toggle`
  final String type;
  final List<String> values;
  final int? min;
  final int? max;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      if (values.isNotEmpty) 'values': values,
      if (min != null) 'min': min,
      if (max != null) 'max': max,
    };
  }

  factory CatalogReasoningOption.fromJson(Map<String, dynamic> json) {
    return CatalogReasoningOption(
      type: _readNonEmptyString(json['type']) ?? '',
      values: _readStringList(json['values']),
      min: _readInt(json['min']),
      max: _readInt(json['max']),
    );
  }
}

class CatalogModel {
  const CatalogModel({
    required this.id,
    required this.name,
    this.family,
    this.status,
    this.toolCall = false,
    this.reasoning = false,
    this.structuredOutput = false,
    this.temperature = true,
    this.attachment = false,
    this.reasoningOptions = const <CatalogReasoningOption>[],
    this.interleaved = false,
    this.interleavedField,
    this.inputModalities = const <String>[],
    this.outputModalities = const <String>[],
    this.contextLimit,
    this.inputLimit,
    this.outputLimit,
    this.costInput,
    this.costOutput,
    this.costCacheRead,
    this.costCacheWrite,
  });

  final String id;
  final String name;
  final String? family;
  final String? status;
  final bool toolCall;
  final bool reasoning;
  final bool structuredOutput;
  final bool temperature;
  final bool attachment;
  final List<CatalogReasoningOption> reasoningOptions;
  final bool interleaved;
  final String? interleavedField;
  final List<String> inputModalities;
  final List<String> outputModalities;
  final int? contextLimit;
  final int? inputLimit;
  final int? outputLimit;
  final double? costInput;
  final double? costOutput;
  final double? costCacheRead;
  final double? costCacheWrite;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (family != null) 'family': family,
      if (status != null) 'status': status,
      if (toolCall) 'tool': true,
      if (reasoning) 'rsn': true,
      if (structuredOutput) 'so': true,
      if (!temperature) 'temp': false,
      if (attachment) 'att': true,
      if (reasoningOptions.isNotEmpty)
        'ro': <Map<String, dynamic>>[
          for (final option in reasoningOptions) option.toJson(),
        ],
      if (interleaved)
        'il': interleavedField == null
            ? true
            : <String, dynamic>{'field': interleavedField},
      if (inputModalities.isNotEmpty) 'in': inputModalities,
      if (outputModalities.isNotEmpty) 'out': outputModalities,
      if (contextLimit != null || inputLimit != null || outputLimit != null)
        'limit': <String, dynamic>{
          if (contextLimit != null) 'context': contextLimit,
          if (inputLimit != null) 'input': inputLimit,
          if (outputLimit != null) 'output': outputLimit,
        },
      if (costInput != null ||
          costOutput != null ||
          costCacheRead != null ||
          costCacheWrite != null)
        'cost': <String, dynamic>{
          if (costInput != null) 'input': costInput,
          if (costOutput != null) 'output': costOutput,
          if (costCacheRead != null) 'cache_read': costCacheRead,
          if (costCacheWrite != null) 'cache_write': costCacheWrite,
        },
    };
  }

  factory CatalogModel.fromJson(Map<String, dynamic> json) {
    final interleaved = _readInterleaved(json['il']);
    final limit = json['limit'] is Map
        ? Map<String, dynamic>.from(json['limit'] as Map)
        : const <String, dynamic>{};
    final cost = json['cost'] is Map
        ? Map<String, dynamic>.from(json['cost'] as Map)
        : const <String, dynamic>{};
    return CatalogModel(
      id: _readNonEmptyString(json['id']) ?? '',
      name: _readNonEmptyString(json['name']) ?? '',
      family: _readNonEmptyString(json['family']),
      status: _readNonEmptyString(json['status']),
      toolCall: _readBool(json['tool'], fallback: false),
      reasoning: _readBool(json['rsn'], fallback: false),
      structuredOutput: _readBool(json['so'], fallback: false),
      temperature: _readBool(json['temp'], fallback: true),
      attachment: _readBool(json['att'], fallback: false),
      reasoningOptions: _readReasoningOptions(json['ro']),
      interleaved: interleaved.interleaved,
      interleavedField: interleaved.field,
      inputModalities: _readStringList(json['in']),
      outputModalities: _readStringList(json['out']),
      contextLimit: _readInt(limit['context']),
      inputLimit: _readInt(limit['input']),
      outputLimit: _readInt(limit['output']),
      costInput: _readDouble(cost['input']),
      costOutput: _readDouble(cost['output']),
      costCacheRead: _readDouble(cost['cache_read']),
      costCacheWrite: _readDouble(cost['cache_write']),
    );
  }
}

DateTime _readGeneratedAt(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

String? _readNonEmptyString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

bool _readBool(Object? value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  return fallback;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return <String>[
    for (final item in value)
      if (item is String) item,
  ];
}

List<CatalogReasoningOption> _readReasoningOptions(Object? value) {
  if (value is! List) {
    return const <CatalogReasoningOption>[];
  }
  final options = <CatalogReasoningOption>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final option = CatalogReasoningOption.fromJson(
      Map<String, dynamic>.from(item),
    );
    if (option.type.isEmpty) {
      continue;
    }
    options.add(option);
  }
  return options;
}

({bool interleaved, String? field}) _readInterleaved(Object? value) {
  if (value == true) {
    return (interleaved: true, field: null);
  }
  if (value is Map) {
    final field = value['field'];
    return (
      interleaved: true,
      field: field is String && field.isNotEmpty ? field : null,
    );
  }
  return (interleaved: false, field: null);
}
