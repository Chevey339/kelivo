import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_item.dart';

class FavoriteProvider extends ChangeNotifier {
  static const String _prefsKey = 'favorite_items_v1';

  List<FavoriteItem> _favorites = [];
  bool _initialized = false;

  List<FavoriteItem> get favorites => List.unmodifiable(_favorites);
  bool get initialized => _initialized;

  FavoriteProvider() {
    _init();
  }

  Future<void> _init() async {
    await _load();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;

      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      _favorites = list
          .map((item) => FavoriteItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load favorites: $e');
      _favorites = [];
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _favorites.map((item) => item.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Failed to save favorites: $e');
    }
  }

  /// 添加收藏
  Future<void> addFavorite({
    required String title,
    required String question,
    required String answer,
    String? conversationId,
    String? messageId,
    String? providerId,
    String? modelId,
    String? assistantId,
    String? assistantName,
    String? assistantAvatar,
  }) async {
    final item = FavoriteItem(
      title: title,
      question: question,
      answer: answer,
      conversationId: conversationId,
      messageId: messageId,
      providerId: providerId,
      modelId: modelId,
      assistantId: assistantId,
      assistantName: assistantName,
      assistantAvatar: assistantAvatar,
    );
    
    _favorites.insert(0, item); // 插入到最前面
    notifyListeners();
    await _save();
  }

  /// 删除收藏
  Future<void> deleteFavorite(String id) async {
    _favorites.removeWhere((item) => item.id == id);
    notifyListeners();
    await _save();
  }

  /// 检查消息是否已收藏
  bool isFavorited(String messageId) {
    return _favorites.any((item) => item.messageId == messageId);
  }

  /// 根据消息ID获取收藏项
  FavoriteItem? getFavoriteByMessageId(String messageId) {
    try {
      return _favorites.firstWhere((item) => item.messageId == messageId);
    } catch (_) {
      return null;
    }
  }
}
