import 'package:flutter/foundation.dart';
import '../models/assistant_memory.dart';
import '../services/memory_store.dart';

class MemoryProvider extends ChangeNotifier {
  List<AssistantMemory> _memories = <AssistantMemory>[];
  bool _initialized = false;
  bool _loading = false;

  MemoryProvider() {
    // Start loading memories asynchronously on creation
    _loadAllSilent();
  }

  List<AssistantMemory> get memories => List.unmodifiable(_memories);

  List<AssistantMemory> getForAssistant(String assistantId) =>
      _memories.where((m) => m.assistantId == assistantId).toList();

  Future<void> initialize() async {
    if (_initialized) return;
    await _loadAllSilent();
  }

  Future<void> _loadAllSilent() async {
    if (_loading) return;
    _loading = true;
    try {
      _memories = await MemoryStore.getAll();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load memories: $e');
      _memories = <AssistantMemory>[];
      _initialized = true; // Still mark as initialized to prevent infinite retries
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  Future<void> loadAll() async {
    await _loadAllSilent();
    if (_loading) return;
  }
  Future<AssistantMemory> add({
    required String assistantId,
    required String content,
  }) async {
    final mem = await MemoryStore.add(
      assistantId: assistantId,
      content: content,
    );
    await loadAll();
    return mem;
  }

  Future<AssistantMemory?> update({
    required int id,
    required String content,
  }) async {
    final mem = await MemoryStore.update(id: id, content: content);
    await loadAll();
    return mem;
  }

  Future<bool> delete({required int id}) async {
    final ok = await MemoryStore.delete(id: id);
    await loadAll();
    return ok;
  }
}
