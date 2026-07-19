import 'dart:convert';

import '../database/business_preferences.dart';
import '../models/world_book.dart';

class WorldBookStore {
  WorldBookStore(this._preferences);

  static const String _itemsKey = 'world_books_v1';
  static const String _activeIdsByAssistantKey =
      'world_books_active_ids_by_assistant_v1';
  static const String _collapsedBooksKey = 'world_books_collapsed_v1';
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
    Map<String, List<String>> src,
  ) {
    return {for (final e in src.entries) e.key: List<String>.from(e.value)};
  }

  static Map<String, bool> _cloneCollapsedBooksMap(Map<String, bool> src) {
    return {for (final e in src.entries) e.key: e.value};
  }

  Future<List<WorldBook>> getAll() async {
    await _preferences.load();
    final raw = _preferences.getString(_itemsKey);
    if (raw == null || raw.isEmpty) return const <WorldBook>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => WorldBook.fromJson(e.cast<String, dynamic>()))
          .toList(growable: true);
    } catch (_) {
      return const <WorldBook>[];
    }
  }

  Future<void> save(List<WorldBook> items) async {
    await _preferences.setString(
      _itemsKey,
      jsonEncode(items.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Future<void> add(WorldBook item) async {
    final all = await getAll();
    all.add(item);
    await save(all);
  }

  Future<void> update(WorldBook item) async {
    final all = await getAll();
    final index = all.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      all[index] = item;
      await save(all);
    }
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((e) => e.id == id);
    await save(all);

    final activeMap = await _loadActiveIdsMap();
    var activeChanged = false;
    final nextActiveMap = <String, List<String>>{};
    for (final entry in activeMap.entries) {
      final filtered = entry.value
          .where((e) => e != id)
          .toList(growable: false);
      if (filtered.length != entry.value.length) activeChanged = true;
      nextActiveMap[entry.key] = filtered;
    }
    if (activeChanged) await _persistActiveIdsMap(nextActiveMap);

    final collapsed = await _loadCollapsedBooksMap();
    if (collapsed.remove(id) != null) {
      await _persistCollapsedBooksMap(collapsed);
    }
  }

  Future<void> clear() async {
    await save(const <WorldBook>[]);
    await _preferences.remove(_activeIdsByAssistantKey);
    await _preferences.remove(_collapsedBooksKey);
  }

  Future<void> reorder({required int oldIndex, required int newIndex}) async {
    final list = await getAll();
    if (list.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await save(list);
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

  Future<Map<String, bool>> getCollapsedBooksMap() async {
    return _cloneCollapsedBooksMap(await _loadCollapsedBooksMap());
  }

  Future<void> setCollapsed(String bookId, bool collapsed) async {
    final id = bookId.trim();
    if (id.isEmpty) return;
    final map = await _loadCollapsedBooksMap();
    map[id] = collapsed;
    await _persistCollapsedBooksMap(map);
  }

  Future<void> setCollapsedMap(Map<String, bool> map) async {
    final next = <String, bool>{};
    map.forEach((key, value) {
      final id = key.trim();
      if (id.isNotEmpty) next[id] = value;
    });
    await _persistCollapsedBooksMap(next);
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

  Future<Map<String, bool>> _loadCollapsedBooksMap() async {
    await _preferences.load();
    final raw = _preferences.getString(_collapsedBooksKey);
    if (raw == null || raw.isEmpty) return <String, bool>{};
    try {
      final decoded = jsonDecode(raw) as Map;
      final result = <String, bool>{};
      for (final entry in decoded.entries) {
        final id = entry.key.toString().trim();
        if (id.isEmpty) continue;
        result[id] = entry.value is bool
            ? entry.value as bool
            : entry.value.toString() == 'true';
      }
      return result;
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> _persistActiveIdsMap(Map<String, List<String>> map) {
    return _preferences.setString(_activeIdsByAssistantKey, jsonEncode(map));
  }

  Future<void> _persistCollapsedBooksMap(Map<String, bool> map) {
    return _preferences.setString(_collapsedBooksKey, jsonEncode(map));
  }
}
