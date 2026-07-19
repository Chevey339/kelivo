import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../database/business_preferences.dart';
import '../models/instruction_injection.dart';
import 'learning_mode_store.dart';

class InstructionInjectionStore {
  InstructionInjectionStore(this._preferences);

  static const String _itemsKey = 'instruction_injections_v1';
  static const String _activeIdsByAssistantKey =
      'instruction_injections_active_ids_by_assistant_v1';
  static const String _learningModeEnabledKey = 'learning_mode_enabled_v1';
  static const String _learningModePromptKey = 'learning_mode_prompt_v1';
  static const String _defaultAssistantKey = '__global__';

  final BusinessPreferences _preferences;

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

  Future<List<InstructionInjection>> getAll() async {
    await _preferences.load();
    final raw = _preferences.getString(_itemsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final values = jsonDecode(raw) as List;
        final items = values
            .map(
              (value) => InstructionInjection.fromJson(
                (value as Map).cast<String, dynamic>(),
              ),
            )
            .toList(growable: true);
        if (items.isNotEmpty) return items;
      } catch (_) {
        return const <InstructionInjection>[];
      }
    }
    return _seedDefaultFromLearningMode();
  }

  Future<List<InstructionInjection>> _seedDefaultFromLearningMode() async {
    final rawPrompt = _preferences.getString(_learningModePromptKey);
    final prompt = rawPrompt == null || rawPrompt.trim().isEmpty
        ? LearningModeStore.defaultPrompt
        : rawPrompt;
    final enabled = _preferences.getBool(_learningModeEnabledKey) ?? false;
    final item = InstructionInjection(
      id: const Uuid().v4(),
      title: '',
      prompt: prompt,
    );
    await save(<InstructionInjection>[item]);
    if (enabled) {
      await _persistActiveIdsMap(<String, List<String>>{
        _defaultAssistantKey: <String>[item.id],
      });
    }
    return <InstructionInjection>[item];
  }

  Future<void> save(List<InstructionInjection> items) {
    return _preferences.setString(
      _itemsKey,
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  Future<void> add(InstructionInjection item) async {
    final all = await getAll();
    all.add(item);
    await save(all);
  }

  Future<void> addMany(List<InstructionInjection> items) async {
    if (items.isEmpty) return;
    final all = await getAll();
    all.addAll(items);
    await save(all);
  }

  Future<void> update(InstructionInjection item) async {
    final all = await getAll();
    final index = all.indexWhere((existing) => existing.id == item.id);
    if (index == -1) return;
    all[index] = item;
    await save(all);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((item) => item.id == id);
    await save(all);

    final map = await _loadActiveIdsMap();
    var removed = false;
    final next = <String, List<String>>{};
    for (final entry in map.entries) {
      final filtered = entry.value.where((value) => value != id).toList();
      if (filtered.length != entry.value.length) removed = true;
      next[entry.key] = filtered;
    }
    if (removed) await _persistActiveIdsMap(next);
  }

  Future<void> clear() async {
    await save(const <InstructionInjection>[]);
    await _preferences.remove(_activeIdsByAssistantKey);
  }

  Future<void> reorder({required int oldIndex, required int newIndex}) async {
    final list = await getAll();
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await save(list);
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
    await _preferences.load();
    final raw = _preferences.getString(_activeIdsByAssistantKey);
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
    return _preferences.setString(_activeIdsByAssistantKey, jsonEncode(map));
  }
}
