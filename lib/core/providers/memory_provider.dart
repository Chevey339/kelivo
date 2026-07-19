import 'package:flutter/foundation.dart';
import '../database/business_preferences.dart';
import '../models/assistant_memory.dart';
import '../services/memory_store.dart';

class MemoryProvider extends ChangeNotifier {
  MemoryProvider({required BusinessPreferences preferences})
    : _store = MemoryStore(preferences);

  final MemoryStore _store;
  List<AssistantMemory> _memories = <AssistantMemory>[];
  bool _initialized = false;
  Future<void>? _initializationFuture;

  List<AssistantMemory> get memories => List.unmodifiable(_memories);

  List<AssistantMemory> getForAssistant(String assistantId) =>
      _memories.where((m) => m.assistantId == assistantId).toList();

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await loadAll();
      _initialized = true;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> loadAll() async {
    try {
      _memories = await _store.getAll();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load memories: $e');
      _memories = <AssistantMemory>[];
      notifyListeners();
    }
  }

  Future<AssistantMemory> add({
    required String assistantId,
    required String content,
  }) async {
    final mem = await _store.add(assistantId: assistantId, content: content);
    await loadAll();
    return mem;
  }

  Future<AssistantMemory?> update({
    required int id,
    required String content,
  }) async {
    final mem = await _store.update(id: id, content: content);
    await loadAll();
    return mem;
  }

  Future<bool> delete({required int id}) async {
    final ok = await _store.delete(id: id);
    await loadAll();
    return ok;
  }
}
