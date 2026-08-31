import 'dart:convert';

import '../../models/tool_schema_override.dart';
import '../../../features/home/services/built_in_tool_names.dart';

/// A parameter whose description can be overridden, extracted from a default schema.
class ToolParamDescriptor {
  const ToolParamDescriptor({
    required this.path,
    this.type,
    this.enumValues,
    this.defaultDescription,
  });

  /// Flattened path such as `query` or `questions.items.id`.
  final String path;
  final String? type;
  final List<String>? enumValues;
  final String? defaultDescription;
}

/// Applies user description overrides onto built-in tool definitions.
///
/// Structure is never changed: only `function.description` and existing
/// `properties.<path>.description` values are written. Unknown tool names and
/// unknown parameter paths are ignored. MCP tools (names not in
/// [BuiltInToolNames.all]) are left untouched, including identity of the
/// original map instance.
abstract final class ToolSchemaOverrides {
  ToolSchemaOverrides._();

  static List<Map<String, dynamic>> apply(
    List<Map<String, dynamic>> defs,
    Map<String, ToolSchemaOverride> overrides,
  ) {
    if (overrides.isEmpty) return defs;
    var copied = false;
    List<Map<String, dynamic>>? out;
    for (var i = 0; i < defs.length; i++) {
      final def = defs[i];
      final applied = _applyOne(def, overrides);
      if (applied == null) continue;
      if (!copied) {
        out = List<Map<String, dynamic>>.from(defs);
        copied = true;
      }
      out![i] = applied;
    }
    return out ?? defs;
  }

  /// Walk a default schema and list every property that can have a description.
  static List<ToolParamDescriptor> describeParams(Map<String, dynamic> def) {
    final function = _asStringKeyMap(def['function']);
    if (function == null) return const [];
    final parameters = _asStringKeyMap(function['parameters']);
    if (parameters == null) return const [];
    final properties = _asStringKeyMap(parameters['properties']);
    if (properties == null) return const [];
    final out = <ToolParamDescriptor>[];
    _walkProperties(properties, '', out);
    return out;
  }

  static Map<String, dynamic>? _applyOne(
    Map<String, dynamic> def,
    Map<String, ToolSchemaOverride> overrides,
  ) {
    final function = _asStringKeyMap(def['function']);
    if (function == null) return null;
    final name = function['name'];
    if (name is! String) return null;
    if (!BuiltInToolNames.all.contains(name)) return null;
    final override = overrides[name];
    if (override == null) return null;

    final desc = override.description;
    final hasDesc = desc != null && desc.trim().isNotEmpty;
    final paramEntries = [
      for (final e in override.paramDescriptions.entries)
        if (e.value.trim().isNotEmpty) e,
    ];
    if (!hasDesc && paramEntries.isEmpty) return null;

    final copy = _deepCopyMap(def);
    final copyFn = _asStringKeyMap(copy['function']);
    if (copyFn == null) return null;

    var mutated = false;
    if (hasDesc) {
      copyFn['description'] = desc;
      mutated = true;
    }

    final parameters = _asStringKeyMap(copyFn['parameters']);
    if (parameters != null) {
      for (final entry in paramEntries) {
        if (_setParamDescription(parameters, entry.key, entry.value)) {
          mutated = true;
        }
      }
    }
    return mutated ? copy : null;
  }

  static void _walkProperties(
    Map<String, dynamic> properties,
    String prefix,
    List<ToolParamDescriptor> out,
  ) {
    for (final entry in properties.entries) {
      final schema = _asStringKeyMap(entry.value);
      if (schema == null) continue;
      final path = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final rawEnum = schema['enum'];
      List<String>? enumValues;
      if (rawEnum is List) {
        enumValues = [
          for (final v in rawEnum)
            if (v != null) v.toString(),
        ];
      }
      final rawType = schema['type'];
      final rawDesc = schema['description'];
      out.add(
        ToolParamDescriptor(
          path: path,
          type: rawType is String ? rawType : null,
          enumValues: enumValues,
          defaultDescription: rawDesc is String ? rawDesc : null,
        ),
      );
      final nested = _asStringKeyMap(schema['properties']);
      if (nested != null) {
        _walkProperties(nested, path, out);
      }
      final items = _asStringKeyMap(schema['items']);
      if (items != null) {
        final itemProps = _asStringKeyMap(items['properties']);
        if (itemProps != null) {
          _walkProperties(itemProps, '$path.items', out);
        } else if (items['description'] is String) {
          final itemEnum = items['enum'];
          List<String>? itemEnumValues;
          if (itemEnum is List) {
            itemEnumValues = [
              for (final v in itemEnum)
                if (v != null) v.toString(),
            ];
          }
          final itemType = items['type'];
          out.add(
            ToolParamDescriptor(
              path: '$path.items',
              type: itemType is String ? itemType : null,
              enumValues: itemEnumValues,
              defaultDescription: items['description'] as String,
            ),
          );
        }
      }
    }
  }

  static bool _setParamDescription(
    Map<String, dynamic> parameters,
    String path,
    String description,
  ) {
    final segments = path.split('.');
    if (segments.isEmpty || segments.any((s) => s.isEmpty)) return false;
    var node = parameters;
    for (final seg in segments) {
      if (seg == 'items') {
        final items = _asStringKeyMap(node['items']);
        if (items == null) return false;
        node['items'] = items;
        node = items;
        continue;
      }
      final props = _asStringKeyMap(node['properties']);
      if (props == null) return false;
      node['properties'] = props;
      final next = _asStringKeyMap(props[seg]);
      if (next == null) return false;
      props[seg] = next;
      node = next;
    }
    node['description'] = description;
    return true;
  }

  static Map<String, dynamic> _deepCopyMap(Map<String, dynamic> def) {
    return jsonDecode(jsonEncode(def)) as Map<String, dynamic>;
  }

  static Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
