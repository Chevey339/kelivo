import 'dart:convert';

import '../database/business_preferences.dart';
import '../models/assistant_memory.dart';

class MemoryStore {
  MemoryStore(this._preferences);

  static const String _memoriesKey = 'assistant_memories_v1';

  final BusinessPreferences _preferences;

  Future<List<AssistantMemory>> getAll() async {
    await _preferences.load();
    final raw = _preferences.getString(_memoriesKey);
    if (raw == null || raw.isEmpty) return <AssistantMemory>[];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return [
        for (final value in values)
          AssistantMemory.fromJson((value as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return <AssistantMemory>[];
    }
  }

  Future<void> _saveAll(List<AssistantMemory> memories) {
    return _preferences.setString(
      _memoriesKey,
      jsonEncode(memories.map((memory) => memory.toJson()).toList()),
    );
  }

  Future<List<AssistantMemory>> getForAssistant(String assistantId) async {
    final all = await getAll();
    return all.where((memory) => memory.assistantId == assistantId).toList();
  }

  static int _nextId(List<AssistantMemory> memories) {
    var maxId = 0;
    for (final memory in memories) {
      if (memory.id > maxId) maxId = memory.id;
    }
    return maxId + 1;
  }

  Future<AssistantMemory> add({
    required String assistantId,
    required String content,
  }) async {
    final all = await getAll();
    final memory = AssistantMemory(
      id: _nextId(all),
      assistantId: assistantId,
      content: content,
    );
    all.add(memory);
    await _saveAll(all);
    return memory;
  }

  Future<AssistantMemory?> update({
    required int id,
    required String content,
  }) async {
    final all = await getAll();
    final index = all.indexWhere((memory) => memory.id == id);
    if (index == -1) return null;
    final updated = all[index].copyWith(content: content);
    all[index] = updated;
    await _saveAll(all);
    return updated;
  }

  Future<bool> delete({required int id}) async {
    final all = await getAll();
    final before = all.length;
    all.removeWhere((memory) => memory.id == id);
    if (all.length == before) return false;
    await _saveAll(all);
    return true;
  }

  Future<void> deleteForAssistant(String assistantId) async {
    final all = await getAll();
    all.removeWhere((memory) => memory.assistantId == assistantId);
    await _saveAll(all);
  }
}
