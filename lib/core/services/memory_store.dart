import '../models/assistant_memory.dart';
import 'json_blob_store.dart';

class MemoryStore extends JsonBlobStore<AssistantMemory> {
  MemoryStore(super._preferences);

  static const String _memoriesKey = 'assistant_memories_v1';

  @override
  String get storageKey => _memoriesKey;

  @override
  AssistantMemory decodeItem(Map<String, dynamic> json) =>
      AssistantMemory.fromJson(json);

  @override
  Map<String, dynamic> encodeItem(AssistantMemory item) => item.toJson();

  Future<List<AssistantMemory>> getAll() => readAll();

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
  }) {
    return runExclusive(() async {
      final all = await readAll();
      final memory = AssistantMemory(
        id: _nextId(all),
        assistantId: assistantId,
        content: content,
      );
      all.add(memory);
      await writeAll(all);
      return memory;
    });
  }

  Future<AssistantMemory?> update({required int id, required String content}) {
    return runExclusive(() async {
      final all = await readAll();
      final index = all.indexWhere((memory) => memory.id == id);
      if (index == -1) return null;
      final updated = all[index].copyWith(content: content);
      all[index] = updated;
      await writeAll(all);
      return updated;
    });
  }

  Future<bool> delete({required int id}) {
    return runExclusive(() async {
      final all = await readAll();
      final before = all.length;
      all.removeWhere((memory) => memory.id == id);
      if (all.length == before) return false;
      await writeAll(all);
      return true;
    });
  }

  Future<void> deleteForAssistant(String assistantId) {
    return runExclusive(() async {
      final all = await readAll();
      all.removeWhere((memory) => memory.assistantId == assistantId);
      await writeAll(all);
    });
  }
}
