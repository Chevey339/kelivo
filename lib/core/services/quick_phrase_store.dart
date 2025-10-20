import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/quick_phrase.dart';
import 'icloud_sync_service.dart';

class QuickPhraseStore {
  static const String _phrasesKey = 'quick_phrases_v1';
  static List<QuickPhrase>? _cache;
  static bool _listenerAttached = false;

  static void _ensureListener() {
    if (_listenerAttached) return;
    if (!ICloudSyncService.instance.isSupported) return;
    _listenerAttached = true;
    ICloudSyncService.instance.addListener(_handleICloudUpdate);
  }

  static void _handleICloudUpdate() {
    _cache = null;
  }

  static Future<List<QuickPhrase>> getAll() async {
    _ensureListener();
    if (_cache != null) return List.of(_cache!);
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_phrasesKey);
    if (json == null || json.isEmpty) {
      _cache = [];
      return [];
    }
    try {
      final list = jsonDecode(json) as List;
      _cache = list.map((e) => QuickPhrase.fromJson(e as Map<String, dynamic>)).toList();
      return List.of(_cache!);
    } catch (_) {
      _cache = [];
      return [];
    }
  }

  static Future<List<QuickPhrase>> getGlobal() async {
    final all = await getAll();
    return all.where((p) => p.isGlobal).toList();
  }

  static Future<List<QuickPhrase>> getForAssistant(String assistantId) async {
    final all = await getAll();
    return all.where((p) => !p.isGlobal && p.assistantId == assistantId).toList();
  }

  static Future<void> save(List<QuickPhrase> phrases) async {
    _ensureListener();
    _cache = phrases;
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(phrases.map((p) => p.toJson()).toList());
    await prefs.setString(_phrasesKey, json);
  }

  static Future<void> add(QuickPhrase phrase) async {
    _ensureListener();
    final all = await getAll();
    all.add(phrase);
    await save(all);
  }

  static Future<void> update(QuickPhrase phrase) async {
    _ensureListener();
    final all = await getAll();
    final index = all.indexWhere((p) => p.id == phrase.id);
    if (index != -1) {
      all[index] = phrase;
      await save(all);
    }
  }

  static Future<void> delete(String id) async {
    _ensureListener();
    final all = await getAll();
    all.removeWhere((p) => p.id == id);
    await save(all);
  }

  static Future<void> clear() async {
    _ensureListener();
    _cache = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phrasesKey);
  }
}
