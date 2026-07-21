import 'dart:convert';

import '../../../core/providers/provider_kind.dart';

/// Pure (Flutter-free) JSON Schema sanitizer for tool parameter schemas.
///
/// Extracted from `ToolHandlerService` so this normalization logic can be unit
/// tested without pulling in Flutter/provider dependencies. Behavior is
/// unchanged; `ToolHandlerService.sanitizeToolParametersForProvider` now
/// delegates here.
///
/// Different providers (Google, OpenAI, Claude) accept different subsets of
/// JSON Schema for tool parameters, so schemas are normalized to a common
/// accepted form per provider.
class ToolSchemaSanitizer {
  const ToolSchemaSanitizer._();

  /// Sanitize/translate [schema] to the JSON Schema subset accepted by [kind].
  static Map<String, dynamic> sanitizeToolParametersForProvider(
    Map<String, dynamic> schema,
    ProviderKind kind,
  ) {
    Map<String, dynamic> clone = _deepCloneMap(schema);
    clone = sanitizeNode(clone, kind) as Map<String, dynamic>;
    return clone;
  }

  /// Recursively sanitize a single schema [node]. Public (not name-mangled) so
  /// it can be exercised directly in unit tests.
  static dynamic sanitizeNode(dynamic node, ProviderKind kind) {
    if (node is List) {
      return node.map((e) => sanitizeNode(e, kind)).toList();
    }
    if (node is! Map) return node;

    final m = Map<String, dynamic>.from(node);
    // Remove $schema as it's not needed for tool definitions
    m.remove(r'$schema');

    // Convert 'const' to 'enum' for compatibility
    if (m.containsKey('const')) {
      final v = m['const'];
      if (v is String || v is num || v is bool) {
        m['enum'] = [v];
      }
      m.remove('const');
    }

    // Flatten anyOf/oneOf/allOf to first variant for simplicity
    for (final key in [
      'anyOf',
      'oneOf',
      'allOf',
      'any_of',
      'one_of',
      'all_of',
    ]) {
      if (m[key] is List && (m[key] as List).isNotEmpty) {
        final first = (m[key] as List).first;
        final flattened = sanitizeNode(first, kind);
        m.remove(key);
        if (flattened is Map<String, dynamic>) {
          m
            ..remove('type')
            ..remove('properties')
            ..remove('items');
          m.addAll(flattened);
        }
      }
    }

    // Normalize type array to single type
    final t = m['type'];
    if (t is List && t.isNotEmpty) m['type'] = t.first.toString();

    // Normalize items array to single item
    final items = m['items'];
    if (items is List && items.isNotEmpty) m['items'] = items.first;
    if (m['items'] is Map) m['items'] = sanitizeNode(m['items'], kind);

    // Recursively sanitize properties
    if (m['properties'] is Map) {
      final props = Map<String, dynamic>.from(m['properties']);
      final norm = <String, dynamic>{};
      props.forEach((k, v) {
        norm[k] = sanitizeNode(v, kind);
      });
      m['properties'] = norm;
    }

    // additionalProperties may be a bool or a subschema (Map). When it is a
    // subschema, recurse so nested nodes are normalized like properties/items.
    if (m['additionalProperties'] is Map) {
      m['additionalProperties'] = sanitizeNode(m['additionalProperties'], kind);
    }

    // Keep only allowed keys based on provider
    Set<String> allowed;
    switch (kind) {
      case ProviderKind.google:
        allowed = {
          'type',
          'description',
          'properties',
          'required',
          'items',
          'enum',
        };
        break;
      case ProviderKind.openai:
      case ProviderKind.claude:
        allowed = {
          'type',
          'description',
          'properties',
          'required',
          'items',
          'enum',
          // Standard JSON Schema field. Must be preserved so MCP servers that
          // declare open/free-form object params (additionalProperties: true or
          // a subschema) are not silently narrowed to closed objects. Strict
          // models (e.g. GLM-5.1) otherwise refuse to fill undeclared params.
          // Gemini (ProviderKind.google) rejects this key, so it stays dropped
          // in that branch.
          'additionalProperties',
        };
        break;
    }
    m.removeWhere((k, v) => !allowed.contains(k));
    return m;
  }

  static Map<String, dynamic> _deepCloneMap(Map<String, dynamic> input) {
    return jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  }
}
