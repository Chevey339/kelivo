import 'dart:convert';
import 'dart:math';

import 'business_data.dart';
import 'business_repository.dart';
import 'business_settings_router.dart';

final class BusinessSettingsMerger {
  BusinessSettingsMerger._();

  static const _activeIdsByAssistantKey =
      'instruction_injections_active_ids_by_assistant_v1';
  static const _asrServicesKey = 'asr_services_v1';
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
        BusinessEntityKind.memoryEntry => _mergeMemoryEntries(
          localRows,
          importedRows,
        ),
        BusinessEntityKind.userProfileField => _mergeProfileFields(
          localRows,
          importedRows,
        ),
        _ => _mergeEntityRowsById(localRows, importedRows),
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
      } else if (key == _asrServicesKey || key == 'environment_variables_v1') {
        preferences[key] = _mergeJsonObjectListsByIdPreferExisting(
          preferences[key] as String?,
          imported as String,
          key,
          identityKey: key == 'environment_variables_v1' ? 'name' : 'id',
        );
      } else if (_relationshipMapKeys.contains(key)) {
        preferences[key] = _mergeJsonMapsPreferExisting(
          preferences[key] as String?,
          imported as String,
        );
      } else {
        preferences.putIfAbsent(key, () => imported);
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
    };
    for (final row in importedRows) {
      final local = selected[row.id];
      if (BusinessSettingsRouter.isProviderOrderOnlyRow(row) &&
          local != null &&
          !BusinessSettingsRouter.isProviderOrderOnlyRow(local)) {
        continue;
      }
      selected[row.id] = row;
    }
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

  static String _mergeJsonObjectListsByIdPreferExisting(
    String? existingRaw,
    String incomingRaw,
    String key, {
    String identityKey = 'id',
  }) {
    List<Map<String, dynamic>> decode(String raw) {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.any((entry) => entry is! Map)) {
        throw FormatException(key);
      }
      return [
        for (final entry in decoded) Map<String, dynamic>.from(entry as Map),
      ];
    }

    final existing = existingRaw == null || existingRaw.isEmpty
        ? <Map<String, dynamic>>[]
        : decode(existingRaw);
    final incoming = decode(incomingRaw);
    final seenIds = <String>{
      for (final service in existing)
        if (service[identityKey] case final String id) id,
    };
    return jsonEncode([
      ...existing,
      for (final service in incoming)
        if (service[identityKey] is! String ||
            seenIds.add(service[identityKey] as String))
          service,
    ]);
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

  static List<BusinessEntityValue> _mergeMemoryEntries(
    List<BusinessEntityValue> existing,
    List<BusinessEntityValue> incoming,
  ) {
    final out = <BusinessEntityValue>[];
    final indexByKey = <String, int>{};
    final seenIds = <String>{};
    final idRemap = <String, String>{};

    for (final row in _orderedRows(existing)) {
      final item = _jsonMap(row.payload, 'memory_entries_v1');
      final key = _memoryEntryDedupeKey(item);
      if (key != null) indexByKey.putIfAbsent(key, () => out.length);
      seenIds.add(row.id);
      out.add(row);
    }
    final localCount = out.length;

    for (final row in _orderedRows(incoming)) {
      final item = _jsonMap(row.payload, 'memory_entries_v1');
      final key = _memoryEntryDedupeKey(item);
      final duplicateIndex = key == null ? null : indexByKey[key];
      if (duplicateIndex != null) {
        out[duplicateIndex] = _mergeMigrationIds(out[duplicateIndex], item);
        continue;
      }

      var selected = row;
      var id = row.id;
      if (seenIds.contains(id)) {
        final newId = _newMemoryEntryId(seenIds);
        idRemap[id] = newId;
        item['id'] = newId;
        id = newId;
        selected = row.copyWith(id: newId, payload: jsonEncode(item));
      }

      if (key != null) indexByKey[key] = out.length;
      out.add(selected);
      seenIds.add(id);
    }

    // Rewrite relatedIds that pointed at remapped incoming ids. Only touch
    // rows that came from the incoming side so local payloads stay identical.
    if (idRemap.isNotEmpty) {
      for (var index = localCount; index < out.length; index++) {
        final row = out[index];
        final item = _jsonMap(row.payload, 'memory_entries_v1');
        final related = item['relatedIds'];
        if (related is! List) continue;
        final rewritten = <String>[
          for (final entry in related)
            if (entry is String) idRemap[entry] ?? entry,
        ];
        if (!_sameStringList(related, rewritten)) {
          item['relatedIds'] = rewritten;
          out[index] = row.copyWith(payload: jsonEncode(item));
        }
      }
    }

    // Drop dangling relatedIds that point at ids absent from the merge result.
    final knownIds = <String>{for (final row in out) row.id};
    for (var index = 0; index < out.length; index++) {
      final row = out[index];
      final item = _jsonMap(row.payload, 'memory_entries_v1');
      final related = item['relatedIds'];
      if (related is! List) continue;
      final filtered = <String>[
        for (final entry in related)
          if (entry is String && knownIds.contains(entry)) entry,
      ];
      if (_sameStringList(related, filtered)) continue;
      item['relatedIds'] = filtered;
      out[index] = row.copyWith(payload: jsonEncode(item));
    }

    return _assignSortOrders(out);
  }

  static BusinessEntityValue _mergeMigrationIds(
    BusinessEntityValue kept,
    Map<String, dynamic> incoming,
  ) {
    final incomingIds = incoming['migrationIds'];
    if (incomingIds is! List) return kept;

    final keptItem = _jsonMap(kept.payload, 'memory_entries_v1');
    final mergedIds = <String>[];
    final seen = <String>{};
    final keptIds = keptItem['migrationIds'];
    if (keptIds is List) {
      for (final id in keptIds) {
        if (id is String && seen.add(id)) mergedIds.add(id);
      }
    }
    var changed = false;
    for (final id in incomingIds) {
      if (id is String && seen.add(id)) {
        mergedIds.add(id);
        changed = true;
      }
    }
    if (!changed) return kept;
    keptItem['migrationIds'] = mergedIds;
    return kept.copyWith(payload: jsonEncode(keptItem));
  }

  static bool _sameStringList(List<dynamic> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < right.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  static List<BusinessEntityValue> _mergeProfileFields(
    List<BusinessEntityValue> existing,
    List<BusinessEntityValue> incoming,
  ) {
    // Local field wins by id (field key); incoming only fills gaps.
    return _mergeEntityRowsById(existing, incoming);
  }

  static String? _memoryEntryDedupeKey(Map<String, dynamic> item) {
    final scope = (item['scope'] ?? '').toString();
    final type = (item['type'] ?? '').toString();
    final content = item['content'];
    if (scope.isEmpty || type.isEmpty || content is! String) return null;
    final assistantId = (item['assistantId'] ?? '').toString();
    return '$scope\u0000$assistantId\u0000$type\u0000'
        '${BusinessRepository.normalizeMemoryContent(content)}';
  }

  static String _newMemoryEntryId(Set<String> seenIds) {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    while (true) {
      final id =
          'mem_${List.generate(8, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
      if (seenIds.add(id)) return id;
    }
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
