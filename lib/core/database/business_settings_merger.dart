import 'dart:convert';

import 'business_data.dart';
import 'business_settings_router.dart';

final class BusinessSettingsMerger {
  BusinessSettingsMerger._();

  static const _activeIdsByAssistantKey =
      'instruction_injections_active_ids_by_assistant_v1';
  static const _providerOrderKey = 'providers_order_v1';
  static const _pinnedModelsKey = 'pinned_models_v1';
  static const _relationshipMapKeys = <String>{
    'provider_group_map_v1',
    'provider_group_collapsed_v1',
    'assistant_tag_map_v1',
    'assistant_tag_collapsed_v1',
  };

  static Map<String, Object> merge(
    Map<String, Object?> existing,
    Map<String, Object?> incoming, {
    bool preserveExplicitEmptyInstructionList = false,
  }) {
    final existingSnapshot = BusinessSettingsRouter.normalizeAndRoute(existing);
    if (incoming.containsKey(_pinnedModelsKey) &&
        existing.containsKey(_pinnedModelsKey) &&
        !existingSnapshot.preferences.containsKey(_pinnedModelsKey)) {
      throw const FormatException(_pinnedModelsKey);
    }
    final incomingSnapshot = BusinessSettingsRouter.normalizeAndRoute(
      incoming,
      preserveExplicitEmptyInstructionList:
          preserveExplicitEmptyInstructionList,
    );
    return BusinessSettingsRouter.exportSnapshot(
      mergeSnapshots(
        existingSnapshot,
        incomingSnapshot,
        incomingKeys: incoming.keys.toSet(),
      ),
    );
  }

  static BusinessSnapshot mergeSnapshots(
    BusinessSnapshot existing,
    BusinessSnapshot incoming, {
    required Set<String> incomingKeys,
  }) {
    final effectiveIncomingKeys = <String>{...incomingKeys};
    if (incoming.preferences.containsKey(_activeIdsByAssistantKey)) {
      effectiveIncomingKeys.add(_activeIdsByAssistantKey);
    }

    final entities = <BusinessEntityKind, List<BusinessEntityValue>>{
      for (final kind in BusinessEntityKind.values)
        kind: existing.entities[kind]!,
    };
    for (final kind in BusinessEntityKind.values) {
      if (!effectiveIncomingKeys.contains(kind.sourceKey)) continue;
      final localRows = existing.entities[kind]!;
      final importedRows = incoming.entities[kind]!;
      entities[kind] = switch (kind) {
        BusinessEntityKind.assistant => _mergeAssistants(
          localRows,
          importedRows,
        ),
        BusinessEntityKind.provider => _mergeProviders(
          localRows,
          importedRows,
          preferIncomingOrder: effectiveIncomingKeys.contains(
            _providerOrderKey,
          ),
        ),
        BusinessEntityKind.providerGroup ||
        BusinessEntityKind.mcpServer ||
        BusinessEntityKind.assistantTag => _mergeEntityRowsById(
          localRows,
          importedRows,
        ),
        BusinessEntityKind.assistantMemory => _mergeAssistantMemories(
          localRows,
          importedRows,
        ),
        _ => _reorderRows(importedRows),
      };
    }
    if (effectiveIncomingKeys.contains(_providerOrderKey) &&
        !effectiveIncomingKeys.contains(
          BusinessEntityKind.provider.sourceKey,
        )) {
      entities[BusinessEntityKind.provider] = _mergeProviders(
        existing.entities[BusinessEntityKind.provider]!,
        incoming.entities[BusinessEntityKind.provider]!,
        preferIncomingOrder: true,
      );
    }

    final preferences = Map<String, Object>.from(existing.preferences);
    for (final key in effectiveIncomingKeys) {
      final disposition = BusinessKeyRegistry.classify(key);
      if (disposition == BusinessKeyDisposition.entity ||
          disposition == BusinessKeyDisposition.providerOrder ||
          disposition == BusinessKeyDisposition.localOnly ||
          disposition == BusinessKeyDisposition.discarded) {
        continue;
      }
      final imported = incoming.preferences[key];
      if (imported == null) {
        if (key == _pinnedModelsKey) throw FormatException(key);
        continue;
      }
      if (key == _pinnedModelsKey) {
        preferences[key] = _mergeStringLists(
          existing.preferences.containsKey(key)
              ? preferences[key]
              : const <String>[],
          imported,
          key,
        );
      } else if (_relationshipMapKeys.contains(key)) {
        preferences[key] = _mergeJsonMapsPreferExisting(
          preferences[key] as String?,
          imported as String,
        );
      } else {
        preferences[key] = imported;
      }
    }

    return BusinessSnapshot(entities: entities, preferences: preferences);
  }

  static List<BusinessEntityValue> _mergeAssistants(
    List<BusinessEntityValue> existing,
    List<BusinessEntityValue> incoming,
  ) {
    final mergedRows = <BusinessEntityValue>[];
    final indexById = <String, int>{};
    for (final row in _orderedRows(existing)) {
      if (indexById.containsKey(row.id)) continue;
      indexById[row.id] = mergedRows.length;
      mergedRows.add(row);
    }
    for (final row in _orderedRows(incoming)) {
      final localIndex = indexById[row.id];
      if (localIndex == null) {
        indexById[row.id] = mergedRows.length;
        mergedRows.add(row);
        continue;
      }
      final localRow = mergedRows[localIndex];
      final local = _jsonMap(localRow.payload, 'assistants_v1');
      final assistant = _jsonMap(row.payload, 'assistants_v1');
      final merged = <String, dynamic>{...local, ...assistant};
      _preserveLocalAsset(local, assistant, merged, 'avatar');
      _preserveLocalAsset(local, assistant, merged, 'background');
      mergedRows[localIndex] = localRow.copyWith(payload: jsonEncode(merged));
    }
    return _assignSortOrders(mergedRows);
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

  static List<BusinessEntityValue> _mergeProviders(
    List<BusinessEntityValue> existing,
    List<BusinessEntityValue> incoming, {
    required bool preferIncomingOrder,
  }) {
    final localRows = _orderedRows(existing);
    final importedRows = _orderedRows(incoming);
    final selected = <String, BusinessEntityValue>{
      for (final row in localRows) row.id: row,
      for (final row in importedRows) row.id: row,
    };
    final orderedIds = <String>[];
    final seen = <String>{};
    final primary = preferIncomingOrder ? importedRows : localRows;
    final secondary = preferIncomingOrder ? localRows : importedRows;
    for (final row in <BusinessEntityValue>[...primary, ...secondary]) {
      if (seen.add(row.id)) orderedIds.add(row.id);
    }
    return _assignSortOrders([for (final id in orderedIds) selected[id]!]);
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

  static List<BusinessEntityValue> _mergeEntityRowsById(
    List<BusinessEntityValue> existing,
    List<BusinessEntityValue> incoming,
  ) {
    final merged = <BusinessEntityValue>[];
    final seen = <String>{};
    for (final row in <BusinessEntityValue>[
      ..._orderedRows(existing),
      ..._orderedRows(incoming),
    ]) {
      if (seen.add(row.id)) merged.add(row);
    }
    return _assignSortOrders(merged);
  }

  static List<BusinessEntityValue> _reorderRows(
    List<BusinessEntityValue> rows,
  ) => _assignSortOrders(_orderedRows(rows));

  static List<BusinessEntityValue> _orderedRows(
    List<BusinessEntityValue> rows,
  ) => List<BusinessEntityValue>.of(rows)
    ..sort((left, right) {
      final byOrder = left.sortOrder.compareTo(right.sortOrder);
      return byOrder != 0 ? byOrder : left.id.compareTo(right.id);
    });

  static List<BusinessEntityValue> _assignSortOrders(
    List<BusinessEntityValue> rows,
  ) => [
    for (var index = 0; index < rows.length; index++)
      rows[index].sortOrder == index
          ? rows[index]
          : rows[index].copyWith(sortOrder: index),
  ];

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

  static List<BusinessEntityValue> _mergeAssistantMemories(
    List<BusinessEntityValue> existing,
    List<BusinessEntityValue> incoming,
  ) {
    final merged = <BusinessEntityValue>[];
    final contentKeys = <String>{};
    final usedIds = <int>{};
    var maxId = 0;

    for (final row in _orderedRows(existing)) {
      final item = _jsonMap(row.payload, 'assistant_memories_v1');
      final id = (item['id'] as num?)?.toInt() ?? 0;
      if (id > 0) usedIds.add(id);
      if (id > maxId) maxId = id;
      final key = _memoryContentKey(item);
      if (key != null) contentKeys.add(key);
      merged.add(row);
    }
    for (final row in _orderedRows(incoming)) {
      final item = _jsonMap(row.payload, 'assistant_memories_v1');
      final contentKey = _memoryContentKey(item);
      if (contentKey != null && contentKeys.contains(contentKey)) continue;
      var id = (item['id'] as num?)?.toInt() ?? 0;
      var selected = row;
      if (id <= 0 || usedIds.contains(id)) {
        do {
          maxId++;
        } while (usedIds.contains(maxId));
        id = maxId;
        item['id'] = id;
        selected = row.copyWith(id: '$id', payload: jsonEncode(item));
      } else if (id > maxId) {
        maxId = id;
      }
      usedIds.add(id);
      if (contentKey != null) contentKeys.add(contentKey);
      merged.add(selected);
    }
    return _assignSortOrders(merged);
  }

  static String? _memoryContentKey(Map<String, dynamic> memory) {
    final assistantId = (memory['assistantId'] ?? '').toString().trim();
    final content = (memory['content'] ?? '').toString().trim();
    if (assistantId.isEmpty || content.isEmpty) return null;
    return '$assistantId\n$content';
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
