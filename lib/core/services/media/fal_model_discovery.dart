import 'dart:convert';

import 'package:flutter/foundation.dart' show compute, Uint8List;
import 'package:http/http.dart' as http;

import '../../models/model_spec.dart';
import '../../providers/settings_provider.dart';
import '../api_key_manager.dart';

import 'fal_model_catalog.dart';

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

  static FalCatalogEntry? fromRow(Object? raw) {
    if (raw case {
      'endpoint_id': final String id,
      'metadata': {
        'category': final String category,
        'display_name': final String name,
        'status': 'active',
      },
    } when isFalEndpointId(id) && falCreationCategories.contains(category)) {
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

  final http.Client client;
  final String apiKey;

  Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    final response = await client.get(
      Uri.https('api.fal.ai', '/v1/models', query),
      headers: {if (apiKey.isNotEmpty) 'Authorization': 'Key $apiKey'},
    );
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

  Future<Map<String, dynamic>> describe(FalCatalogEntry model) async {
    final data = await _get({'endpoint_id': model.id, 'expand': 'openapi-3.0'});
    for (final row in (data['models'] as List).whereType<Map>()) {
      if (FalCatalogEntry.fromRow(row)?.id == model.id) {
        return {
          'id': model.id,
          'name': model.name,
          'category': model.category,
          'fields': _inputFields(row['openapi']),
        };
      }
    }
    throw const FormatException('fal endpoint unavailable');
  }

  static Map<String, dynamic> _inputFields(Object? api) {
    if (api is! Map || api['paths'] is! Map) return {};
    // Aliases may point at a different canonical path in their OpenAPI schema.
    final routes = (api['paths'] as Map).values.whereType<Map>();
    final components = api['components'];
    final schemas = components is Map ? components['schemas'] : null;
    Map resolve(Object? raw) {
      if (raw is! Map) return const {};
      final ref = raw[r'$ref'];
      if (ref is String &&
          ref.startsWith('#/components/schemas/') &&
          schemas is Map) {
        final resolved = schemas[ref.split('/').last];
        if (resolved is Map) return resolved;
      }
      return raw;
    }

    for (final route in routes) {
      final post = route['post'];
      if (post case {
        'requestBody': {'content': {'application/json': {'schema': final raw}}},
      }) {
        final schema = resolve(raw);
        final props = schema['properties'];
        if (props is! Map) continue;
        final required = schema['required'];
        final fields = <String, dynamic>{};
        for (final key in falInputFields) {
          if (props[key] is! Map) continue;
          final field = resolve(props[key]);
          final union = field['anyOf'] ?? field['oneOf'];
          final variants = [field, if (union is List) ...union.map(resolve)];
          final choices = <Object>{
            for (final v in variants)
              if (v['enum'] case final List values)
                for (final e in values)
                  if (e is String || e is int) e as Object,
          };
          fields[key] = {
            if (choices.isNotEmpty) 'choices': choices.toList(),
            if (variants.any((v) => v['type'] == 'string')) 'string': true,
            if (variants.any((v) => v['type'] == 'object')) 'object': true,
            if (required is List && required.contains(key)) 'required': true,
            if (field['minimum'] case final int min) 'min': min,
            if (field['maximum'] case final int max) 'max': max,
            if (field['maxItems'] case final int maxItems) 'maxItems': maxItems,
          };
        }
        return fields;
      }
    }
    return {};
  }
}
