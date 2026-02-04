import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/world_book.dart';

class WorldBookStore {
  static const String _itemsKey = 'world_books_v1';
  static const String _activeIdsByAssistantKey =
      'world_books_active_ids_by_assistant_v1';
  static const String _defaultAssistantKey = '__global__';

  static List<WorldBook>? _cache;
  static Map<String, List<String>>? _activeIdsByAssistantCache;

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

  static Future<List<WorldBook>> getAll() async {
    if (_cache != null) return List<WorldBook>.from(_cache!);
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_itemsKey);
    if (json == null || json.isEmpty) {
      _cache = const <WorldBook>[];
      return const <WorldBook>[];
    }
    try {
      final list = jsonDecode(json) as List;
      _cache = list
          .whereType<Map>()
          .map((e) => WorldBook.fromJson(e.cast<String, dynamic>()))
          .toList(growable: true);
      return List<WorldBook>.from(_cache!);
    } catch (_) {
      _cache = const <WorldBook>[];
      return const <WorldBook>[];
    }
  }

  static Future<void> save(List<WorldBook> items) async {
    _cache = List<WorldBook>.from(items);
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(
      items.map((e) => e.toJson()).toList(growable: false),
    );
    await prefs.setString(_itemsKey, json);
  }

  static Future<void> add(WorldBook item) async {
    final all = await getAll();
    all.add(item);
    await save(all);
  }

  static Future<void> update(WorldBook item) async {
    final all = await getAll();
    final index = all.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      all[index] = item;
      await save(all);
    }
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((e) => e.id == id);
    await save(all);

    // Remove from active map
    try {
      final map = await _loadActiveIdsMap();
      bool removed = false;
      final next = <String, List<String>>{};
      for (final entry in map.entries) {
        final filtered = entry.value
            .where((e) => e != id)
            .toList(growable: false);
        if (filtered.length != entry.value.length) removed = true;
        next[entry.key] = filtered;
      }
      if (removed) await _persistActiveIdsMap(next);
    } catch (_) {}
  }

  static Future<void> clear() async {
    _cache = const <WorldBook>[];
    _activeIdsByAssistantCache = const <String, List<String>>{};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_itemsKey);
    await prefs.remove(_activeIdsByAssistantKey);
  }

  static Future<void> reorder({
    required int oldIndex,
    required int newIndex,
  }) async {
    final list = await getAll();
    if (list.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await save(list);
  }

  static Future<List<String>> getActiveIds({String? assistantId}) async {
    final map = await _loadActiveIdsMap();
    final key = assistantKey(assistantId);
    if (map.containsKey(key)) {
      return List<String>.from(map[key]!);
    }
    final fallback = map[_defaultAssistantKey];
    if (fallback != null) return List<String>.from(fallback);
    return const <String>[];
  }

  static Future<Map<String, List<String>>> getActiveIdsByAssistant() async {
    final map = await _loadActiveIdsMap();
    return _cloneActiveIdsMap(map);
  }

  static Future<void> setActiveIds(
    List<String> ids, {
    String? assistantId,
  }) async {
    final key = assistantKey(assistantId);
    final clean = _cleanIds(ids);
    final map = await _loadActiveIdsMap();
    map[key] = clean;
    await _persistActiveIdsMap(map);
  }

  static Future<void> setActiveIdsMap(Map<String, List<String>> map) async {
    final next = <String, List<String>>{};
    map.forEach((key, value) {
      next[key] = _cleanIds(value).toList(growable: false);
    });
    await _persistActiveIdsMap(next);
  }

  static Future<Map<String, List<String>>> _loadActiveIdsMap() async {
    if (_activeIdsByAssistantCache != null) {
      return _cloneActiveIdsMap(_activeIdsByAssistantCache!);
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeIdsByAssistantKey);
    Map<String, List<String>> map = <String, List<String>>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map;
        decoded.forEach((key, value) {
          final list = (value is List) ? value : const [];
          map[key.toString()] = _cleanIds(list);
        });
      } catch (_) {
        map = <String, List<String>>{};
      }
    }
    _activeIdsByAssistantCache = map;
    return _cloneActiveIdsMap(map);
  }

  static Future<void> _persistActiveIdsMap(
    Map<String, List<String>> map,
  ) async {
    _activeIdsByAssistantCache = _cloneActiveIdsMap(map);
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(_activeIdsByAssistantKey, jsonEncode(map));
    } catch (_) {}
  }
}
