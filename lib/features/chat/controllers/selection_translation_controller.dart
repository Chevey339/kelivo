import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum SelectionTranslationStatus { loading, streaming, complete, failed }

typedef SelectionTranslateRequest =
    Stream<String> Function(String text, String language, String requestId);

class SelectionTranslationController extends ChangeNotifier {
  SelectionTranslationController({
    required this.text,
    required this.request,
    required this.cancel,
  });
  final String text;
  final SelectionTranslateRequest request;
  final void Function(String requestId) cancel;
  SelectionTranslationStatus status = SelectionTranslationStatus.loading;
  String result = '';
  String? error;
  String? _requestId;
  bool _disposed = false;

  Future<void> translate(String language) async {
    if (_disposed) return;
    if (_requestId case final id?) cancel(id);
    final id = 'selection-translate-${const Uuid().v4()}';
    _requestId = id;
    result = '';
    error = null;
    status = SelectionTranslationStatus.loading;
    notifyListeners();
    try {
      await for (final chunk in request(text, language, id)) {
        if (_disposed || _requestId != id) return;
        if (chunk.isEmpty) continue;
        result += chunk;
        status = SelectionTranslationStatus.streaming;
        notifyListeners();
      }
      if (_disposed || _requestId != id) return;
      if (result.trim().isEmpty) throw StateError('Empty translation');
      status = SelectionTranslationStatus.complete;
    } catch (failure) {
      if (_disposed || _requestId != id) return;
      error = failure.toString();
      status = SelectionTranslationStatus.failed;
    }
    if (!_disposed && _requestId == id) {
      _requestId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_requestId case final id?) cancel(id);
    _requestId = null;
    super.dispose();
  }
}
