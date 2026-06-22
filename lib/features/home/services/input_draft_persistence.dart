import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/chat_input_data.dart';

class InputDraftPersistence {
  // 全局草稿，不按 conversationId 隔离（有意为之）
  static const String _draftKey = 'chat_draft_v1';
  static const Duration _debounceDuration = Duration(milliseconds: 800);

  Timer? _debounceTimer;
  ChatInputData? _pending;
  bool _disposed = false;

  void scheduleSave(ChatInputData data) {
    if (_disposed) return;
    _pending = data;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _flush);
  }

  Future<void> saveImmediately() async {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _flush();
  }

  Future<ChatInputData?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_draftKey);
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final text = map['text'] as String? ?? '';
      final images =
          (map['images'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [];
      final docs =
          (map['documents'] as List<dynamic>?)
              ?.map(
                (d) => DocumentAttachment(
                  path: d['path'] as String? ?? '',
                  fileName: d['fileName'] as String? ?? '',
                  mime: d['mime'] as String? ?? '',
                ),
              )
              .toList() ??
          [];
      if (text.isEmpty && images.isEmpty && docs.isEmpty) return null;
      return ChatInputData(text: text, imagePaths: images, documents: docs);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete() async {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pending = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_pending != null) {
      _write(_pending!);
      _pending = null;
    }
  }

  Future<void> _flush() async {
    if (_disposed) return;
    final data = _pending;
    if (data == null) return;
    _pending = null;
    if (data.text.isEmpty &&
        data.imagePaths.isEmpty &&
        data.documents.isEmpty) {
      await delete();
      return;
    }
    await _write(data);
  }

  Future<void> _write(ChatInputData data) async {
    final map = <String, dynamic>{
      'text': data.text,
      'images': data.imagePaths,
      'documents': data.documents
          .map(
            (d) => <String, String>{
              'path': d.path,
              'fileName': d.fileName,
              'mime': d.mime,
            },
          )
          .toList(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(map));
  }
}
