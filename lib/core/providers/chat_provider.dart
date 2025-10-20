import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_item.dart';
import '../services/icloud_sync_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({List<ChatItem>? seed}) {
    _chats = List.of(seed ?? const <ChatItem>[]);
    _init();
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.addListener(_handleICloudUpdate);
    }
  }

  static const String _prefsPinnedKey = 'pinned_chat_ids';
  static const String _prefsTitlesKey = 'chat_titles_map';

  late List<ChatItem> _chats;
  final Set<String> _pinned = <String>{};
  bool _initialized = false;

  List<ChatItem> get chats => List.unmodifiable(_chats);
  Set<String> get pinnedIds => Set.unmodifiable(_pinned);
  bool get initialized => _initialized;

  Future<void> _init() async {
    await _loadPinned();
    await _loadTitles();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadPinned() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsPinnedKey) ?? const <String>[];
    _pinned
      ..clear()
      ..addAll(ids);
  }

  Future<void> _savePinned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsPinnedKey, _pinned.toList());
  }

  Future<void> _loadTitles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsTitlesKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      _chats = _chats
          .map((c) => map.containsKey(c.id)
              ? c.copyWith(title: (map[c.id] as String?)?.toString() ?? c.title)
              : c)
          .toList();
    } catch (_) {
      // ignore malformed
    }
  }

  Future<void> _saveTitles() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (final c in _chats) c.id: c.title};
    await prefs.setString(_prefsTitlesKey, jsonEncode(map));
  }

  Future<void> _reloadFromPrefs() async {
    await _loadPinned();
    await _loadTitles();
    if (_initialized == false) {
      _initialized = true;
    }
    notifyListeners();
  }

  void _handleICloudUpdate() {
    unawaited(_reloadFromPrefs());
  }

  void setChats(List<ChatItem> items) {
    _chats = List.of(items);
    notifyListeners();
  }

  Future<void> rename(String id, String newTitle) async {
    final idx = _chats.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    _chats[idx] = _chats[idx].copyWith(title: newTitle);
    notifyListeners();
    await _saveTitles();
  }

  Future<void> togglePin(String id) async {
    if (_pinned.contains(id)) {
      _pinned.remove(id);
    } else {
      _pinned.add(id);
    }
    notifyListeners();
    await _savePinned();
  }

  Future<void> deleteById(String id) async {
    _pinned.remove(id);
    _chats.removeWhere((c) => c.id == id);
    notifyListeners();
    await _savePinned();
    await _saveTitles();
  }

  @override
  void dispose() {
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.removeListener(_handleICloudUpdate);
    }
    super.dispose();
  }
}
