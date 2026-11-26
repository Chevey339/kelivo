import 'dart:convert';

import 'package:flutter/foundation.dart' show compute, Uint8List;
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' show CancelToken;

import '../../models/model_spec.dart';
import '../../providers/settings_provider.dart';
import '../api_key_manager.dart';
import '../network/provider_http_client.dart';

import 'fal_model_catalog.dart';
import 'media_request.dart' show MediaParameter;

/// A catalog endpoint whose required inputs or output cannot be used in Creation.
class FalUnsupportedEndpoint implements Exception {
  const FalUnsupportedEndpoint([this.input]);
  final String? input;

  @override
  String toString() => input == null
      ? 'This fal endpoint does not return a supported image or video file.'
      : 'Unsupported required fal input: $input';
}

/// Only models selected by the user keep their compact input description.
class FalCatalogEntry {
  FalCatalogEntry(this.id, this.name, this.category);

  final String id, name, category;
  bool get video => category.endsWith('-to-video');

  late final spec = ModelSpec(
    id: id,
    displayName: name,
    type: video ? ModelType.video : ModelType.image,
    input: [Modality.text, if (category.startsWith('image-')) Modality.image],
    output: [video ? Modality.video : Modality.image],
  );

  static FalCatalogEntry? fromRow(
    Object? raw, {
    bool includeDeprecated = false,
  }) {
    if (raw
        case {
          'endpoint_id': final String id,
          'metadata': {
            'category': final String category,
            'display_name': final String name,
            'status': final String status,
          },
        }
        when (status == 'active' ||
                includeDeprecated && status == 'deprecated') &&
            isFalEndpointId(id) &&
            falCreationCategories.contains(category)) {
      return FalCatalogEntry(id, name, category);
    }
    return null;
  }
}

typedef FalCatalogPage = ({List<FalCatalogEntry> models, String? nextCursor});

class FalModelDiscovery {
  const FalModelDiscovery(this.client, {this.apiKey = ''});

  factory FalModelDiscovery.forProvider(
    http.Client client,
    ProviderConfig config,
  ) {
    return FalModelDiscovery(
      client,
      apiKey: config.usesOfficialFalQueue
          ? ApiKeyManager().effectiveKeyForProvider(config)
          : '',
    );
  }

  static bool hasAdditionalSettings(String id, Object? overrides) {
    final saved = overrides is Map ? overrides['falEndpoint'] : null;
    return saved is Map &&
        saved['id'] == id &&
        saved['additionalSettings'] is Map &&
        saved['settingsVersion'] == 2;
  }

  static bool needsSchema(ProviderConfig config, String id, Object? overrides) {
    if (!config.usesOfficialFalQueue || falModels.containsKey(id)) return false;
    final saved = overrides is Map ? overrides['falEndpoint'] : null;
    if (saved is! Map || saved['id'] != id || saved['fields'] is! Map) {
      return true;
    }
    return switch (saved['category']) {
      'text-to-image' ||
      'image-to-image' => !const {'images', 'image'}.contains(saved['output']),
      'text-to-video' ||
      'image-to-video' => !const {'videos', 'video'}.contains(saved['output']),
      _ => true,
    };
  }

  static Future<Map<String, dynamic>> fetchEndpoint(
    ProviderConfig config,
    String id,
    CancelToken cancelToken,
  ) async {
    final client = providerHttpClient(
      config,
      logMode: HttpLogMode.media,
      cancelToken: cancelToken,
      timeout: const Duration(seconds: 12),
    );
    try {
      return await FalModelDiscovery.forProvider(client, config).endpoint(id);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> endpoint(String id) async =>
      await lookup(id) ?? {'id': id, 'unlisted': true};

  final http.Client client;
  final String apiKey;

  Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    final response = await client.get(
      Uri.https('api.fal.ai', '/v1/models', query),
      headers: {if (apiKey.isNotEmpty) 'Authorization': 'Key $apiKey'},
    );
    if (response.statusCode == 404 && query.containsKey('endpoint_id')) {
      return {'models': const []};
    }
    if (response.statusCode != 200) {
      throw http.ClientException('fal HTTP ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    final data = bytes.length < 64 * 1024
        ? _decode(bytes)
        : await compute(_decode, bytes);
    if (data is! Map<String, dynamic> || data['models'] is! List) {
      throw const FormatException('Invalid fal catalog');
    }
    return data;
  }

  static dynamic _decode(Uint8List bytes) => jsonDecode(utf8.decode(bytes));

  Future<List<ModelSpec>> listModels() async {
    final models = <String, ModelSpec>{};
    final cursors = <String>{};
    String? cursor;
    do {
      final page = await search('', cursor: cursor);
      for (final entry in page.models) {
        models[entry.id] = entry.spec;
      }
      cursor = page.nextCursor;
    } while (cursor != null && cursors.add(cursor));
    return models.values.toList(growable: false);
  }

  Future<FalCatalogPage> search(String query, {String? cursor}) async {
    final data = await _get({
      'status': 'active',
      'limit': '50',
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (cursor != null) 'cursor': cursor,
    });
    final next = data['next_cursor'];
    return (
      models: [
        for (final raw in data['models'] as List)
          if (FalCatalogEntry.fromRow(raw) case final model?) model,
      ],
      nextCursor:
          data['has_more'] == true &&
              next is String &&
              next.isNotEmpty &&
              next != cursor
          ? next
          : null,
    );
  }

  Future<Map<String, dynamic>> describe(FalCatalogEntry model) async =>
      await lookup(model.id) ??
      (throw const FormatException('fal endpoint unavailable'));

  Future<Map<String, dynamic>?> lookup(String id) async {
    final data = await _get({'endpoint_id': id, 'expand': 'openapi-3.0'});
    for (final row in (data['models'] as List).whereType<Map>()) {
      if (row['endpoint_id'] != id) continue;
      final model = FalCatalogEntry.fromRow(row, includeDeprecated: true);
      final api = row['openapi'];
      if (model == null) throw const FalUnsupportedEndpoint();
      if (api is! Map || api['paths'] is! Map) {
        throw const FormatException('Missing fal endpoint schema');
      }
      final schema = _FalSchema(api);
      final output = schema.output(model.video);
      final inputs = schema.inputs(falModels[id]);
      return {
        'id': id,
        'name': model.name,
        'category': model.category,
        'output': output,
        'fields': inputs.fields,
        'additionalSettings': inputs.settings,
        'settingsVersion': 2,
      };
    }
    // An unlisted endpoint can still be added by its owner.
    return null;
  }
}

class _FalSchema {
  _FalSchema(this.api);
  final Map api;

  Map _resolve(Object? raw) {
    if (raw is! Map) return const {};
    final all = raw['allOf'];
    final ref =
        raw[r'$ref'] ??
        (all is List && all.length == 1 && all.first is Map
            ? all.first[r'$ref']
            : null);
    if (ref is String && ref.startsWith('#/components/schemas/')) {
      final value = api['components']?['schemas']?[ref.split('/').last];
      if (value is Map) return {...value, ...raw};
    }
    return raw;
  }

  Iterable<Map> _variants(Object? raw) sync* {
    final field = _resolve(raw);
    yield field;
    final union = field['anyOf'] ?? field['oneOf'];
    if (union is List) yield* union.map(_resolve);
  }

  /// The POST response describes the queue job. The GET result describes the file.
  String output(bool video) {
    final names = video ? const ['videos', 'video'] : const ['images', 'image'];
    for (final route in (api['paths'] as Map).entries) {
      if (!route.key.toString().endsWith('/requests/{request_id}')) continue;
      final result = _resolve(
        route
            .value['get']?['responses']?['200']?['content']?['application/json']?['schema'],
      );
      final props = result['properties'];
      if (props is! Map) continue;
      for (final name in names) {
        for (final field in _variants(props[name])) {
          final file = name.endsWith('s') ? _resolve(field['items']) : field;
          if (file['properties']?['url'] == null) continue;
          if (!video &&
              (_vectorOutput(field) || _vectorOutput(_resolve(props[name])))) {
            continue;
          }
          return name;
        }
      }
    }
    throw const FalUnsupportedEndpoint();
  }

  static bool _vectorOutput(Map field) {
    final description = '${field['title'] ?? ''} ${field['description'] ?? ''}'
        .toLowerCase();
    if (!RegExp(r'\b(?:png|jpeg|webp|gif|raster)\b').hasMatch(description) &&
        RegExp(
          r'\bsvg\s+(?:files?|images?|vectors?|outputs?)\b|\b(?:as|in)\s+(?:an?\s+)?svg\b|image/svg\+xml',
        ).hasMatch(description)) {
      return true;
    }
    final examples = field['examples'];
    if (examples is! List || examples.isEmpty) return false;
    final files = examples
        .expand((item) => item is List ? item : [item])
        .whereType<Map>();
    return files.isNotEmpty &&
        files.every(
          (file) =>
              file['content_type'] == 'image/svg+xml' ||
              [file['file_name'], file['url']].whereType<String>().any(
                (name) =>
                    Uri.tryParse(name)?.path.toLowerCase().endsWith('.svg') ==
                    true,
              ),
        );
  }

  // Some fal models publish an explicit array limit only in the field description.
  static final _documentedImageMax = RegExp(
    r'\b(?:up to|(?:a )?maximum(?: of)?|max\.?)\s+(\d{1,3})\s+(?:(?:input|reference)\s+)*images?\b',
    caseSensitive: false,
  );

  // Store only the validation keywords and definitions reachable from this input.
  // Examples and unrelated model schemas can contain large media payloads.
  Map<String, dynamic> _validation(Map root) {
    final definitions = <String, dynamic>{};
    Object compact(Object? raw) {
      if (raw is! Map) return raw is bool ? raw : true;
      final ref = raw[r'$ref'];
      final combined = <Object>[];
      if (ref is String && ref.startsWith('#/components/schemas/')) {
        final name = ref.substring('#/components/schemas/'.length);
        final source = api['components']?['schemas']?[name];
        if (source is Map) {
          if (!definitions.containsKey(name)) {
            definitions[name] = true;
            definitions[name] = compact(source);
          }
          combined.add({r'$ref': '#/definitions/$name'});
        }
      }
      if (raw['allOf'] case final List list) combined.addAll(list.map(compact));
      return <String, dynamic>{
        for (final k in const [
          'type',
          'const',
          'enum',
          'required',
          'minimum',
          'maximum',
          'exclusiveMinimum',
          'exclusiveMaximum',
          'multipleOf',
          'minItems',
          'maxItems',
          'uniqueItems',
          'minLength',
          'maxLength',
        ])
          if (raw.containsKey(k)) k: raw[k],
        if (raw['properties'] case final Map properties)
          'properties': {
            for (final e in properties.entries)
              e.key.toString(): compact(e.value),
          },
        for (final k in const ['items', 'additionalProperties', 'not'])
          if (raw[k] is Map || raw[k] is bool) k: compact(raw[k]),
        for (final k in const ['anyOf', 'oneOf'])
          if (raw[k] case final List list) k: list.map(compact).toList(),
        if (combined.isNotEmpty) 'allOf': combined,
      };
    }

    final result = compact(root) as Map<String, dynamic>;
    return {...result, if (definitions.isNotEmpty) 'definitions': definitions};
  }

  Map<String, dynamic> _setting(Map field, List<Map> variants) {
    final types = {
      for (final v in variants)
        for (final type in v['type'] is List ? v['type'] as List : [v['type']])
          if (type is String && type != 'null') type,
    };
    final alternatives = variants.where(
      (v) =>
          v['type'] != 'null' &&
          (v.containsKey('type') ||
              v.containsKey('enum') ||
              v.containsKey('const')),
    );
    final choices = <Object>{
      for (final v in alternatives)
        for (final value in v['enum'] as List? ?? [v['const']])
          if (value is String || value is num || value is bool) value as Object,
    };
    final enumerated =
        choices.isNotEmpty &&
        alternatives.every(
          (v) => v.containsKey('enum') || v.containsKey('const'),
        );
    final type = enumerated
        ? 'enumeration'
        : types.length == 1
        ? types.single
        : 'json';
    final fixed = field.containsKey('const');
    final defaultValue = fixed ? field['const'] : field['default'];
    Object? constraint(String name) =>
        variants.map((v) => v[name]).whereType<num>().firstOrNull;
    return {
      'type': type,
      if (choices.isNotEmpty) 'choices': choices.toList(),
      if (const {'array', 'object', 'json'}.contains(type))
        'schema': _validation(field),
      if (fixed) 'constant': true,
      if (field['title'] is String) 'title': field['title'],
      if (field['description'] is String) 'description': field['description'],
      if (defaultValue != null || fixed) 'default': defaultValue,
      if (field['readOnly'] == true) 'readOnly': true,
      for (final key in [
        'minimum',
        'maximum',
        'multipleOf',
        'exclusiveMinimum',
        'exclusiveMaximum',
      ])
        if (constraint(key) case final bound?) key: bound,
    };
  }

  ({Map<String, dynamic> fields, Map<String, dynamic> settings}) inputs(
    FalModel? model,
  ) {
    final nativeOptions = {
      for (final option
          in model?.capabilities.platformOptions ?? const <MediaParameter>[])
        option.key,
    };
    for (final route in (api['paths'] as Map).values.whereType<Map>()) {
      final raw =
          route['post']?['requestBody']?['content']?['application/json']?['schema'];
      final schema = _resolve(raw);
      final props = schema['properties'];
      if (props is! Map) continue;
      final required = (schema['required'] as List? ?? const [])
          .whereType<String>()
          .toSet();
      final fields = <String, dynamic>{};
      final settings = <String, dynamic>{};
      final order = {
        if (schema['x-fal-order-properties'] case final List keys)
          ...keys.whereType<String>(),
        ...props.keys.whereType<String>(),
      };
      for (final key in order) {
        if (props[key] is! Map) continue;
        final field = _resolve(props[key]);
        final variants = _variants(field).toList();
        final string = variants.any((v) => v['type'] == 'string');
        final array = variants.any((v) => v['type'] == 'array');
        final extraImage =
            !falInputFields.contains(key) &&
            string &&
            RegExp(r'(?:^|_)(?:image|frame)(?:_url)?$').hasMatch(key);
        if (!falInputFields.contains(key) &&
            !extraImage &&
            key != model?.ratioField) {
          final setting = _setting(field, variants);
          final requiredInput =
              required.contains(key) && setting['readOnly'] != true;
          if (requiredInput &&
              !nativeOptions.contains(key) &&
              !const {
                'string',
                'boolean',
                'number',
                'integer',
                'enumeration',
              }.contains(setting['type']) &&
              !field.containsKey('const') &&
              !field.containsKey('default')) {
            throw FalUnsupportedEndpoint(key);
          }
          if (key == 'max_images') {
            final combined = RegExp(
              r'image inputs\s*\+\s*image outputs\)?\s*must not exceed\s+(\d+)',
              caseSensitive: false,
            ).firstMatch(field['description'].toString());
            if (combined != null) {
              setting['combinedImageLimit'] = int.tryParse(combined.group(1)!);
            }
          }
          settings[key] = setting;
          if (requiredInput) {
            fields[key] = {
              'required': true,
              'setting': true,
              if (field['nullable'] == true ||
                  field.containsKey('const') && field['const'] == null ||
                  variants.any(
                    (v) =>
                        v['type'] == 'null' ||
                        v['type'] is List &&
                            (v['type'] as List).contains('null'),
                  ))
                'nullable': true,
            };
          }
          continue;
        }
        // Audio is an ordinary fal switch. Size enums without a custom-dimensions
        // variant have no equivalent in the aspect-ratio control.
        if (key == 'generate_audio' ||
            (key == 'image_size' &&
                (model != null && model.ratioField == null ||
                    !variants.any((v) => v['type'] == 'object')))) {
          settings[key] = _setting(field, variants);
        }
        final choices = <Object>{
          for (final v in variants)
            for (final e in [
              if (v.containsKey('const')) v['const'],
              ...(v['enum'] as List? ?? const []),
            ])
              if (e is String || e is int) e as Object,
        };
        int? bound(String name) =>
            variants.map((v) => v[name]).whereType<int>().firstOrNull;
        if (array && (bound('minItems') ?? 0) > 16 && required.contains(key)) {
          throw FalUnsupportedEndpoint(key);
        }
        fields[key] = {
          if (choices.isNotEmpty) 'choices': choices.toList(),
          if (string) 'string': true,
          if (key == 'prompt' &&
              props.containsKey('multi_prompt') &&
              RegExp(
                r'either\s+prompt\s+or\s+multi_prompt\s+must\s+be\s+provided',
                caseSensitive: false,
              ).hasMatch(field['description'].toString())) ...{
            'alternative': 'multi_prompt',
            'exclusive': field['description'].toString().toLowerCase().contains(
              'but not both',
            ),
          },
          if (array) 'array': true,
          if (extraImage) 'imageInput': true,
          if (variants.any((v) => v['type'] == 'object')) 'object': true,
          if (required.contains(key)) 'required': true,
          if (bound('minimum') case final min?) 'min': min,
          if (bound('maximum') case final max?) 'max': max,
          if (bound('minItems') case final min?) 'minItems': min,
          if ((bound('maxItems') ??
                  (array
                      ? int.tryParse(
                          _documentedImageMax
                                  .firstMatch(
                                    field['description']?.toString() ?? '',
                                  )
                                  ?.group(1) ??
                              '',
                        )
                      : null))
              case final max?)
            'maxItems': max,
        };
      }
      return (fields: fields, settings: settings);
    }
    throw const FormatException('Missing fal input schema');
  }
}
