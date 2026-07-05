import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/assistant_memory_doc.dart';

/// Storage for long-form memory docs. Unlike [MemoryStore] entries, doc
/// contents are never injected wholesale; only a catalog (title + summary)
/// goes into the system prompt and the model fetches full text on demand
/// via the read_memory_doc tool.
class MemoryDocStore {
  static const String _docsKey = 'assistant_memory_docs_v1';

  static List<AssistantMemoryDoc>? _cache;

  static Future<List<AssistantMemoryDoc>> _loadAllInternal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_docsKey);
    if (raw == null || raw.isEmpty) return <AssistantMemoryDoc>[];
    try {
      final arr = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in arr)
          if (e is Map<String, dynamic>)
            AssistantMemoryDoc.fromJson(e)
          else
            AssistantMemoryDoc.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return <AssistantMemoryDoc>[];
    }
  }

  static Future<List<AssistantMemoryDoc>> getAll() async {
    _cache ??= await _loadAllInternal();
    return List<AssistantMemoryDoc>.of(_cache!);
  }

  static Future<void> _saveAll(List<AssistantMemoryDoc> list) async {
    _cache = List<AssistantMemoryDoc>.of(list);
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_docsKey, json);
  }

  static Future<List<AssistantMemoryDoc>> getForAssistant(
    String assistantId,
  ) async {
    final all = await getAll();
    return all.where((d) => d.assistantId == assistantId).toList();
  }

  static Future<AssistantMemoryDoc?> getById(int id) async {
    final all = await getAll();
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  static int _nextId(List<AssistantMemoryDoc> list) {
    int maxId = 0;
    for (final d in list) {
      if (d.id > maxId) maxId = d.id;
    }
    return maxId + 1;
  }

  static Future<AssistantMemoryDoc> add({
    required String assistantId,
    required String title,
    required String summary,
    required String content,
  }) async {
    final all = await getAll();
    final id = _nextId(all);
    final doc = AssistantMemoryDoc(
      id: id,
      assistantId: assistantId,
      title: title,
      summary: summary,
      content: content,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    all.add(doc);
    await _saveAll(all);
    return doc;
  }

  static Future<AssistantMemoryDoc?> update({
    required int id,
    String? title,
    String? summary,
    String? content,
  }) async {
    final all = await getAll();
    final idx = all.indexWhere((d) => d.id == id);
    if (idx == -1) return null;
    final updated = all[idx].copyWith(
      title: title,
      summary: summary,
      content: content,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    all[idx] = updated;
    await _saveAll(all);
    return updated;
  }

  static Future<bool> delete({required int id}) async {
    final all = await getAll();
    final before = all.length;
    all.removeWhere((d) => d.id == id);
    final changed = all.length != before;
    if (changed) await _saveAll(all);
    return changed;
  }
}
