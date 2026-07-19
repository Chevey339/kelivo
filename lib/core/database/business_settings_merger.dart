import 'dart:convert';

import 'business_data.dart';
import 'business_settings_router.dart';

final class BusinessSettingsMerger {
  BusinessSettingsMerger._();

  static const _legacyActivationKeys = <String>{
    'instruction_injections_active_id_v1',
    'instruction_injections_active_ids_v1',
  };
  static const _activeIdsByAssistantKey =
      'instruction_injections_active_ids_by_assistant_v1';

  static Map<String, Object> merge(
    Map<String, Object?> existing,
    Map<String, Object?> incoming,
  ) {
    final existingSnapshot = BusinessSettingsRouter.normalizeAndRoute(existing);
    final incomingSnapshot = BusinessSettingsRouter.normalizeAndRoute(incoming);
    final current = BusinessSettingsRouter.exportSnapshot(existingSnapshot);
    final normalizedIncoming = BusinessSettingsRouter.exportSnapshot(
      incomingSnapshot,
    );
    final incomingKeys = <String>{...incoming.keys};
    if (incomingKeys.any(_legacyActivationKeys.contains)) {
      incomingKeys.add(_activeIdsByAssistantKey);
    }

    for (final key in incomingKeys) {
      final disposition = BusinessKeyRegistry.classify(key);
      if (disposition == BusinessKeyDisposition.localOnly ||
          disposition == BusinessKeyDisposition.discarded) {
        continue;
      }
      final imported = normalizedIncoming[key];
      if (imported == null) continue;
      switch (key) {
        case 'assistants_v1':
          current[key] = _mergeAssistants(
            _entityRows(existingSnapshot, key),
            _entityRows(incomingSnapshot, key),
          );
        case 'assistant_memories_v1':
          current[key] = _mergeAssistantMemories(
            current[key] as String,
            imported as String,
          );
        case 'provider_configs_v1':
          current[key] = _mergeProviderConfigs(
            current[key] as String,
            imported as String,
          );
        case 'pinned_models_v1':
          current[key] = _mergeStringLists(current[key], imported, key);
        case 'mcp_servers_v1':
        case 'provider_groups_v1':
        case 'assistant_tags_v1':
          current[key] = _mergeJsonListById(
            _entityRows(existingSnapshot, key),
            _entityRows(incomingSnapshot, key),
          );
        case 'provider_group_map_v1':
        case 'provider_group_collapsed_v1':
        case 'assistant_tag_map_v1':
        case 'assistant_tag_collapsed_v1':
          current[key] = _mergeJsonMapsPreferExisting(
            current[key] as String?,
            imported as String,
          );
        case 'providers_order_v1':
        case 'search_services_v1':
          current[key] = imported;
        default:
          current[key] = imported;
      }
    }

    return BusinessSettingsRouter.exportSnapshot(
      BusinessSettingsRouter.normalizeAndRoute(current),
    );
  }

  static String _mergeAssistants(
    List<BusinessEntityValue> existing,
    List<BusinessEntityValue> incoming,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    final order = <String>[];
    for (final row in existing) {
      final id = row.id;
      if (byId.containsKey(id)) continue;
      byId[id] = _jsonMap(row.payload, 'assistants_v1');
      order.add(id);
    }
    for (final row in incoming) {
      final id = row.id;
      final assistant = _jsonMap(row.payload, 'assistants_v1');
      final local = byId[id];
      if (local == null) {
        byId[id] = assistant;
        order.add(id);
        continue;
      }
      final merged = <String, dynamic>{...local, ...assistant};
      _preserveLocalAsset(local, assistant, merged, 'avatar');
      _preserveLocalAsset(local, assistant, merged, 'background');
      byId[id] = merged;
    }
    return jsonEncode([for (final id in order) byId[id]]);
  }

  static void _preserveLocalAsset(
    Map<String, dynamic> local,
    Map<String, dynamic> incoming,
    Map<String, dynamic> merged,
    String key,
  ) {
    final localValue = (local[key] ?? '').toString();
    if (localValue.trim().isNotEmpty) {
      merged[key] = localValue;
      return;
    }
    final incomingValue = incoming[key]?.toString();
    merged[key] = incomingValue == null || incomingValue.trim().isEmpty
        ? null
        : incomingValue;
  }

  static String _mergeProviderConfigs(String existingRaw, String incomingRaw) {
    final existing = _jsonObjectMap(existingRaw, 'provider_configs_v1');
    final incoming = _jsonObjectMap(incomingRaw, 'provider_configs_v1');
    return jsonEncode(<String, dynamic>{...existing, ...incoming});
  }

  static List<String> _mergeStringLists(
    Object? existing,
    Object imported,
    String key,
  ) {
    if (existing is! List || existing.any((item) => item is! String)) {
      throw FormatException(key);
    }
    if (imported is! List || imported.any((item) => item is! String)) {
      throw FormatException(key);
    }
    final seen = <String>{};
    return [
      for (final value in <String>[
        ...existing.cast<String>(),
        ...imported.cast<String>(),
      ])
        if (seen.add(value)) value,
    ];
  }

  static String _mergeJsonListById(
    List<BusinessEntityValue> existing,
    List<BusinessEntityValue> incoming,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    final order = <String>[];
    for (final row in <BusinessEntityValue>[...existing, ...incoming]) {
      final id = row.id;
      if (byId.containsKey(id)) continue;
      byId[id] = _jsonMap(row.payload, 'json_list');
      order.add(id);
    }
    return jsonEncode([for (final id in order) byId[id]]);
  }

  static List<BusinessEntityValue> _entityRows(
    BusinessSnapshot snapshot,
    String key,
  ) {
    final kind = BusinessEntityKind.values.singleWhere(
      (candidate) => candidate.sourceKey == key,
    );
    return snapshot.entities[kind]!;
  }

  static String _mergeJsonMapsPreferExisting(
    String? existingRaw,
    String incomingRaw,
  ) {
    final existing = existingRaw == null || existingRaw.isEmpty
        ? <String, dynamic>{}
        : _jsonMap(existingRaw, 'relationship_map');
    final incoming = _jsonMap(incomingRaw, 'relationship_map');
    return jsonEncode(<String, dynamic>{...incoming, ...existing});
  }

  static String _mergeAssistantMemories(
    String existingRaw,
    String incomingRaw,
  ) {
    final existing = _jsonObjectList(existingRaw, 'assistant_memories_v1');
    final incoming = _jsonObjectList(incomingRaw, 'assistant_memories_v1');
    final merged = <Map<String, dynamic>>[];
    final contentKeys = <String>{};
    final usedIds = <int>{};
    var maxId = 0;

    for (final item in existing) {
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id > 0) usedIds.add(id);
      if (id > maxId) maxId = id;
      final key = _memoryContentKey(item);
      if (key != null) contentKeys.add(key);
      merged.add(item);
    }
    for (final original in incoming) {
      final item = Map<String, dynamic>.from(original);
      final contentKey = _memoryContentKey(item);
      if (contentKey != null && contentKeys.contains(contentKey)) continue;
      var id = (item['id'] as num?)?.toInt() ?? 0;
      if (id <= 0 || usedIds.contains(id)) {
        do {
          maxId++;
        } while (usedIds.contains(maxId));
        id = maxId;
        item['id'] = id;
      } else if (id > maxId) {
        maxId = id;
      }
      usedIds.add(id);
      if (contentKey != null) contentKeys.add(contentKey);
      merged.add(item);
    }
    return jsonEncode(merged);
  }

  static String? _memoryContentKey(Map<String, dynamic> memory) {
    final assistantId = (memory['assistantId'] ?? '').toString().trim();
    final content = (memory['content'] ?? '').toString().trim();
    if (assistantId.isEmpty || content.isEmpty) return null;
    return '$assistantId\n$content';
  }

  static List<Map<String, dynamic>> _jsonObjectList(String raw, String key) {
    final decoded = _decode(raw, key);
    if (decoded is! List || decoded.any((item) => item is! Map)) {
      throw FormatException(key);
    }
    return decoded
        .cast<Map>()
        .map(
          (item) =>
              item.map((field, value) => MapEntry(field.toString(), value)),
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> _jsonObjectMap(String raw, String key) {
    final decoded = _jsonMap(raw, key);
    if (decoded.values.any((value) => value is! Map)) {
      throw FormatException(key);
    }
    return decoded;
  }

  static Map<String, dynamic> _jsonMap(String raw, String key) {
    final decoded = _decode(raw, key);
    if (decoded is! Map) throw FormatException(key);
    return decoded.map((field, value) => MapEntry(field.toString(), value));
  }

  static Object? _decode(String raw, String key) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw FormatException(key);
    }
  }
}
