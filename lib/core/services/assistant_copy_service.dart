import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../database/business_data.dart';
import '../database/business_preferences.dart';
import '../models/assistant_copy_options.dart';
import '../models/assistant_memory.dart';
import '../models/memory_entry.dart';
import '../models/quick_phrase.dart';

class AssistantCopyMemories {
  const AssistantCopyMemories({required this.entries, required this.legacy});

  final List<MemoryEntry> entries;
  final List<AssistantMemory> legacy;
}

/// Builds only the selected data for the caller's atomic assistant write.
/// All callers that write hold BusinessPreferences.runExclusiveMutation.
class AssistantCopyService {
  AssistantCopyService(this.preferences);

  final BusinessPreferences preferences;

  List<T> _read<T>(
    BusinessEntityKind kind,
    T Function(Map<String, dynamic>) decode,
  ) {
    final raw = preferences.getString(kind.sourceKey);
    if (raw == null || raw.isEmpty) return <T>[];
    return (jsonDecode(raw) as List)
        .map((item) => decode((item as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<AssistantCopyMemories> loadMemories(String assistantId) async {
    await preferences.load();
    return AssistantCopyMemories(
      entries: _read(BusinessEntityKind.memoryEntry, MemoryEntry.fromPayload)
          .where(
            (e) =>
                e.scope == MemoryScope.assistant &&
                e.assistantId == assistantId,
          )
          .toList(),
      legacy: _read(
        BusinessEntityKind.assistantMemory,
        AssistantMemory.fromJson,
      ).where((e) => e.assistantId == assistantId).toList(),
    );
  }

  Map<String, Object> relatedUpdates({
    required String sourceId,
    required String targetId,
    required AssistantCopyOptions options,
  }) {
    final updates = <String, Object>{};
    if (options.memories) {
      final entries = _read(
        BusinessEntityKind.memoryEntry,
        MemoryEntry.fromPayload,
      );
      final selected = entries
          .where(
            (e) =>
                e.scope == MemoryScope.assistant &&
                e.assistantId == sourceId &&
                (options.memoryIds == null ||
                    options.memoryIds!.contains(e.id)),
          )
          .toList();
      final takenIds = entries.map((e) => e.id).toSet();
      final globalIds = {
        for (final entry in entries)
          if (entry.scope == MemoryScope.global) entry.id,
      };
      final ids = <String, String>{};
      for (final entry in selected) {
        var id = MemoryEntry.newId();
        while (!takenIds.add(id)) {
          id = MemoryEntry.newId();
        }
        ids[entry.id] = id;
      }
      entries.addAll(
        selected.map(
          (e) => e.copyWith(
            id: ids[e.id]!,
            assistantId: targetId,
            // Private references follow the copied subset; global memories
            // remain shared. Never retain another assistant's private IDs.
            relatedIds: [
              for (final id in e.relatedIds)
                if (ids.containsKey(id))
                  ids[id]!
                else if (globalIds.contains(id))
                  id,
            ],
            migrationIds: const [],
          ),
        ),
      );
      if (selected.isNotEmpty) {
        updates[BusinessEntityKind.memoryEntry.sourceKey] = jsonEncode(
          entries.map((e) => e.toPayload()).toList(),
        );
      }

      final legacy = _read(
        BusinessEntityKind.assistantMemory,
        AssistantMemory.fromJson,
      );
      var nextId = legacy.fold<int>(0, (max, e) => e.id > max ? e.id : max);
      final copied = legacy
          .where(
            (e) =>
                e.assistantId == sourceId &&
                (options.legacyMemoryIds == null ||
                    options.legacyMemoryIds!.contains(e.id)),
          )
          .map((e) => e.copyWith(id: ++nextId, assistantId: targetId))
          .toList();
      if (copied.isNotEmpty) {
        updates[BusinessEntityKind.assistantMemory.sourceKey] = jsonEncode(
          [...legacy, ...copied].map((e) => e.toJson()).toList(),
        );
      }
    }
    if (options.quickPhrases) {
      final phrases = _read(
        BusinessEntityKind.quickPhrase,
        QuickPhrase.fromJson,
      );
      final copied = phrases
          .where((e) => !e.isGlobal && e.assistantId == sourceId)
          .map((e) => e.copyWith(id: const Uuid().v4(), assistantId: targetId))
          .toList();
      if (copied.isNotEmpty) {
        updates[BusinessEntityKind.quickPhrase.sourceKey] = jsonEncode(
          [...phrases, ...copied].map((e) => e.toJson()).toList(),
        );
      }
    }
    for (final key in [
      if (options.worldBooks) 'world_books_active_ids_by_assistant_v1',
      if (options.instructionInjections)
        'instruction_injections_active_ids_by_assistant_v1',
    ]) {
      final raw = preferences.getString(key);
      final map = raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(raw) as Map).cast<String, dynamic>();
      // Preserve explicit emptiness; snapshot the effective global binding
      // when the source has no override of its own.
      map[targetId] = List<String>.from(
        (map[sourceId] ?? map['__global__'] ?? const <String>[]) as List,
      );
      updates[key] = jsonEncode(map);
    }
    return updates;
  }
}
