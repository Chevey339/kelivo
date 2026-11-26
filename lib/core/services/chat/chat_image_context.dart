part of 'chat_service.dart';

extension ChatImageContext on ChatService {
  Future<ImageContextSettings> imageContextSettings(String id) async {
    final temporary = _temporaryImageSettings[id];
    if (!_initialized && _existingRepository == null) {
      return temporary ?? const ImageContextSettings();
    }
    if (isTemporaryConversation(id) || _draftConversations.containsKey(id)) {
      return temporary ?? const ImageContextSettings();
    }
    if (temporary != null) {
      return _updateStoredImageContextSettings(id, (settings) => settings);
    }
    return _repo.readImageContextSettings(id);
  }

  Future<void> setImageContextSettings(
    String id,
    ImageContextSettings settings,
  ) async {
    await updateImageContextSettings(id, (_) => settings);
  }

  Future<ImageContextSettings> updateImageContextSettings(
    String id,
    ImageContextSettings Function(ImageContextSettings) update,
  ) async {
    final ImageContextSettings settings;
    if (isTemporaryConversation(id) || _draftConversations.containsKey(id)) {
      settings = _temporaryImageSettings[id] = update(
        _temporaryImageSettings[id] ?? const ImageContextSettings(),
      );
    } else {
      settings = await _updateStoredImageContextSettings(id, update);
    }
    _notifyContextChanged(id);
    return settings;
  }

  Future<ImageContextSettings> _updateStoredImageContextSettings(
    String id,
    ImageContextSettings Function(ImageContextSettings) update,
  ) async {
    ImageContextSettings? pending;
    try {
      return await _repo.updateImageContextSettings(id, (stored) {
        pending = _temporaryImageSettings.remove(id);
        return update(pending ?? stored);
      });
    } catch (_) {
      if (pending case final settings?) {
        _temporaryImageSettings.putIfAbsent(id, () => settings);
      }
      rethrow;
    }
  }

  /// Original selected branch, bounded by clear and regeneration, but not by
  /// the sliding message window or compression. This ordering drives eviction.
  Future<List<ChatMessage>> imageContextHistory(
    String id, {
    String? throughMessageId,
  }) async {
    if (!_initialized && _existingRepository == null) return [];
    if (!isTemporaryConversation(id) && !_draftConversations.containsKey(id)) {
      return _repo.readImageContextHistory(
        id,
        throughMessageId: throughMessageId,
      );
    }
    final snapshot = await loadContextSnapshot(id);
    final cutoff = throughMessageId == null
        ? snapshot.messages.length - 1
        : snapshot.messages.indexWhere((m) => m.id == throughMessageId);
    if (cutoff < 0) return [];
    final allowed = snapshot.messages.take(cutoff + 1).map((m) => m.id).toSet();
    return ContextHistory.resolve(
      snapshot.messages,
      snapshot.operations.where((op) => !op.isCompression).toList(),
    ).where((m) => allowed.contains(m.id)).toList();
  }
}
