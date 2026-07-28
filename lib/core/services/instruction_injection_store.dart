import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/instruction_injection.dart';
import 'json_blob_store.dart';
import 'learning_mode_store.dart';

class InstructionInjectionStore extends JsonBlobStore<InstructionInjection> {
  InstructionInjectionStore(super._preferences);

  static const String _itemsKey = 'instruction_injections_v1';
  static const String _activeIdsByAssistantKey =
      'instruction_injections_active_ids_by_assistant_v1';
  static const String _learningModeEnabledKey = 'learning_mode_enabled_v1';
  static const String _learningModePromptKey = 'learning_mode_prompt_v1';
  static const String _defaultAssistantKey = '__global__';

  @override
  String get storageKey => _itemsKey;

  @override
  InstructionInjection decodeItem(Map<String, dynamic> json) =>
      InstructionInjection.fromJson(json);

  @override
  Map<String, dynamic> encodeItem(InstructionInjection item) => item.toJson();

  static String assistantKey(String? assistantId) {
    final id = (assistantId ?? '').trim();
    return id.isEmpty ? _defaultAssistantKey : id;
  }

  static List<String> _cleanIds(Iterable<dynamic> ids) {
    return ids
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static Map<String, List<String>> _cloneActiveIdsMap(
    Map<String, List<String>> source,
  ) {
    return {
      for (final entry in source.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  /// Reads may seed the default item, so they join the serialized queue
  /// alongside writes. A blob that fails to decode throws [StateError]
  /// instead of seeding over the surviving rows.
  Future<List<InstructionInjection>> getAll() {
    return runExclusive(_getAllDirect);
  }

  Future<List<InstructionInjection>> _getAllDirect() async {
    await preferences.load();
    final raw = preferences.getString(_itemsKey);
    if (raw != null && raw.isNotEmpty) {
      final items = decodeAll(raw);
      if (items.isNotEmpty) return items;
      final activeIds = await _loadActiveIdsMap();
      if (activeIds[_defaultAssistantKey]?.isEmpty ?? false) return items;
    }
    return _seedDefaultFromLearningMode();
  }

  Future<List<InstructionInjection>> _seedDefaultFromLearningMode() async {
    final rawPrompt = preferences.getString(_learningModePromptKey);
    final prompt = rawPrompt == null || rawPrompt.trim().isEmpty
        ? LearningModeStore.defaultPrompt
        : rawPrompt;
    final enabled = preferences.getBool(_learningModeEnabledKey) ?? false;
    final item = InstructionInjection(
      id: const Uuid().v4(),
      title: '',
      prompt: prompt,
    );
    await _writeItems(<InstructionInjection>[item]);
    if (enabled) {
      await _persistActiveIdsMap(<String, List<String>>{
        _defaultAssistantKey: <String>[item.id],
      });
    }
    return <InstructionInjection>[item];
  }

  Future<void> save(List<InstructionInjection> items) {
    return runExclusive(() => _writeItems(items));
  }

  Future<void> _writeItems(List<InstructionInjection> items) async {
    if (items.isEmpty) {
      final activeIds = await _loadActiveIdsMap();
      activeIds[_defaultAssistantKey] = const <String>[];
      await _persistActiveIdsMap(activeIds);
    }
    await writeAll(items);
  }

  Future<void> add(InstructionInjection item) {
    return runExclusive(() async {
      final all = await _getAllDirect();
      all.add(item);
      await _writeItems(all);
    });
  }

  Future<void> addMany(List<InstructionInjection> items) async {
    if (items.isEmpty) return;
    return runExclusive(() async {
      final all = await _getAllDirect();
      all.addAll(items);
      await _writeItems(all);
    });
  }

  Future<void> update(InstructionInjection item) {
    return runExclusive(() async {
      final all = await _getAllDirect();
      final index = all.indexWhere((existing) => existing.id == item.id);
      if (index == -1) return;
      all[index] = item;
      await _writeItems(all);
    });
  }

  Future<void> delete(String id) {
    return runExclusive(() async {
      final all = await _getAllDirect();
      all.removeWhere((item) => item.id == id);
      await _writeItems(all);

      final map = await _loadActiveIdsMap();
      var removed = false;
      final next = <String, List<String>>{};
      for (final entry in map.entries) {
        final filtered = entry.value.where((value) => value != id).toList();
        if (filtered.length != entry.value.length) removed = true;
        next[entry.key] = filtered;
      }
      if (removed) await _persistActiveIdsMap(next);
    });
  }

  Future<void> clear() {
    return runExclusive(() async {
      await _writeItems(const <InstructionInjection>[]);
      await _persistActiveIdsMap(const <String, List<String>>{
        _defaultAssistantKey: <String>[],
      });
    });
  }

  Future<void> reorder({required int oldIndex, required int newIndex}) {
    return runExclusive(() async {
      final list = await _getAllDirect();
      if (oldIndex < 0 || oldIndex >= list.length) return;
      if (newIndex < 0 || newIndex >= list.length) return;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      await _writeItems(list);
    });
  }

  Future<String?> getActiveId({String? assistantId}) async {
    final ids = await getActiveIds(assistantId: assistantId);
    return ids.isEmpty ? null : ids.first;
  }

  Future<void> setActiveId(String? id, {String? assistantId}) async {
    await setActiveIds(
      id == null || id.isEmpty ? const <String>[] : <String>[id],
      assistantId: assistantId,
    );
  }

  Future<List<String>> getActiveIds({String? assistantId}) async {
    final map = await _loadActiveIdsMap();
    final key = assistantKey(assistantId);
    if (map.containsKey(key)) return List<String>.from(map[key]!);
    final fallback = map[_defaultAssistantKey];
    return fallback == null ? const <String>[] : List<String>.from(fallback);
  }

  Future<Map<String, List<String>>> getActiveIdsByAssistant() async {
    return _cloneActiveIdsMap(await _loadActiveIdsMap());
  }

  Future<void> setActiveIds(List<String> ids, {String? assistantId}) async {
    final map = await _loadActiveIdsMap();
    map[assistantKey(assistantId)] = _cleanIds(ids);
    await _persistActiveIdsMap(map);
  }

  Future<void> setActiveIdsMap(Map<String, List<String>> map) async {
    final next = <String, List<String>>{};
    map.forEach((key, value) {
      next[key] = _cleanIds(value).toList(growable: false);
    });
    await _persistActiveIdsMap(next);
  }

  Future<InstructionInjection?> getActive({String? assistantId}) async {
    final list = await getActives(assistantId: assistantId);
    return list.isEmpty ? null : list.first;
  }

  Future<List<InstructionInjection>> getActives({String? assistantId}) async {
    final ids = await getActiveIds(assistantId: assistantId);
    if (ids.isEmpty) return const <InstructionInjection>[];
    final byId = <String, InstructionInjection>{
      for (final item in await getAll()) item.id: item,
    };
    return [
      for (final id in ids)
        if (byId[id] case final item?) item,
    ];
  }

  Future<Map<String, List<String>>> _loadActiveIdsMap() async {
    await preferences.load();
    final raw = preferences.getString(_activeIdsByAssistantKey);
    if (raw == null || raw.isEmpty) return <String, List<String>>{};
    try {
      final decoded = jsonDecode(raw) as Map;
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): _cleanIds(
            entry.value is List ? entry.value as List : const <dynamic>[],
          ),
      };
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  Future<void> _persistActiveIdsMap(Map<String, List<String>> map) {
    return preferences.setString(_activeIdsByAssistantKey, jsonEncode(map));
  }
}
