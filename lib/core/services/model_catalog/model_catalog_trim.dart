import 'catalog_entry.dart';

/// Converts a raw models.dev payload into the trimmed catalog JSON.
///
/// [schemaVersion] is always `1`. A single malformed provider or model is
/// skipped; this function does not throw for bad entries.
Map<String, dynamic> trimModelsDevJson(
  Map<String, dynamic> raw, {
  DateTime? generatedAt,
}) {
  return ModelCatalogData(
    schemaVersion: 1,
    generatedAt: generatedAt ?? DateTime.now().toUtc(),
    providers: _providersFromRaw(raw),
  ).toJson();
}

/// Parses trimmed catalog JSON.
///
/// Throws [FormatException] when the top-level shape is invalid (missing
/// `providers` map or unsupported `schemaVersion`). Individual provider/model
/// entries are tolerated.
ModelCatalogData parseTrimmedCatalog(Map<String, dynamic> json) {
  return ModelCatalogData.fromJson(json);
}

Map<String, CatalogProvider> _providersFromRaw(Map<String, dynamic> raw) {
  final providers = <String, CatalogProvider>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! Map) {
      continue;
    }
    final providerJson = Map<String, dynamic>.from(value);
    final id =
        _readNonEmptyString(providerJson['id']) ??
        _readNonEmptyString(entry.key) ??
        '';
    if (id.isEmpty) {
      continue;
    }
    providers[id] = CatalogProvider(
      id: id,
      name: _readNonEmptyString(providerJson['name']) ?? id,
      api: _readNonEmptyString(providerJson['api']),
      models: _modelsFromRaw(providerJson['models']),
    );
  }
  return providers;
}

Map<String, CatalogModel> _modelsFromRaw(Object? raw) {
  if (raw is! Map) {
    return const <String, CatalogModel>{};
  }
  final models = <String, CatalogModel>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! Map) {
      continue;
    }
    final modelJson = Map<String, dynamic>.from(value);
    final id = _readNonEmptyString(modelJson['id']);
    if (id == null) {
      continue;
    }
    models[id] = _modelFromRaw(modelJson, id: id);
  }
  return models;
}

CatalogModel _modelFromRaw(Map<String, dynamic> json, {required String id}) {
  final interleaved = _readInterleaved(json['interleaved']);
  final modalities = json['modalities'] is Map
      ? Map<String, dynamic>.from(json['modalities'] as Map)
      : const <String, dynamic>{};
  final limit = json['limit'] is Map
      ? Map<String, dynamic>.from(json['limit'] as Map)
      : const <String, dynamic>{};
  final cost = json['cost'] is Map
      ? Map<String, dynamic>.from(json['cost'] as Map)
      : const <String, dynamic>{};
  return CatalogModel(
    id: id,
    name: _readNonEmptyString(json['name']) ?? id,
    family: _readNonEmptyString(json['family']),
    status: _readNonEmptyString(json['status']),
    toolCall: _readBool(json['tool_call'], fallback: false),
    reasoning: _readBool(json['reasoning'], fallback: false),
    structuredOutput: _readBool(json['structured_output'], fallback: false),
    temperature: _readBool(json['temperature'], fallback: true),
    attachment: _readBool(json['attachment'], fallback: false),
    reasoningOptions: _readReasoningOptions(json['reasoning_options']),
    interleaved: interleaved.interleaved,
    interleavedField: interleaved.field,
    inputModalities: _readStringList(modalities['input']),
    outputModalities: _readStringList(modalities['output']),
    contextLimit: _readInt(limit['context']),
    inputLimit: _readInt(limit['input']),
    outputLimit: _readInt(limit['output']),
    costInput: _readDouble(cost['input']),
    costOutput: _readDouble(cost['output']),
    costCacheRead: _readDouble(cost['cache_read']),
    costCacheWrite: _readDouble(cost['cache_write']),
  );
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
