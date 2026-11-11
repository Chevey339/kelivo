part of 'chat_service.dart';

extension ChatCompressionSettings on ChatService {
  Future<Map<String, dynamic>?> compressionMetadataForExport(
    String id,
    Set<String> exportedGroups,
    CompressionConfig defaults, {
    String locale = 'en',
  }) async {
    final overrides = await compressionOverrides(id);
    final operations = (await loadContextOperations(id))
        .where(
          (op) =>
              exportedGroups.contains(op.appliedAfterGroupId) &&
              op.sourceGroups.every(exportedGroups.contains),
        )
        .toList();
    if (overrides.isEmpty && operations.isEmpty) return null;
    final config = defaults.withOverrides(overrides);
    Map<String, dynamic>? template;
    try {
      template = (await _repo.compression.template(
        config.templateId,
        locale: locale,
      )).toJson();
    } on StateError {
      /* Accepted operations also carry their template snapshots. */
    }
    return {
      'type': 'kelivo-conversation-context',
      'formatVersion': 1,
      'settings': {...config.toJson(includeMode: false), 'mode': 'off'},
      if (template != null) 'template': template,
      'operations': operations.map((op) => op.toJson()).toList(),
    };
  }

  void replaceTemporaryCompressionTemplate(String id, String replacement) {
    for (final entry in _temporaryCompressionSettings.entries.toList()) {
      if (entry.value['templateId'] == id) {
        _temporaryCompressionSettings[entry.key] = {
          ...entry.value,
          'templateId': replacement,
        };
      }
    }
  }

  Future<Map<String, dynamic>> compressionOverrides(String id) async {
    final local = _temporaryCompressionSettings[id];
    if (!_initialized ||
        isTemporaryConversation(id) ||
        _draftConversations.containsKey(id)) {
      return Map.of(local ?? const {});
    }
    if (local != null) {
      await _repo.compression.saveOverrides(id, local);
      _temporaryCompressionSettings.remove(id);
      return Map.of(local);
    }
    return _repo.compression.overrides(id);
  }

  Future<CompressionConfig> compressionConfig(
    String id,
    CompressionConfig defaults,
  ) async => defaults.withOverrides(await compressionOverrides(id));

  Future<void> setCompressionOverrides(
    String id,
    Map<String, dynamic> values,
  ) async {
    if (getConversation(id) == null) throw StateError('conversation_not_found');
    if (values['mode'] == 'off' &&
        contextCompression.taskFor(id)?.automatic == true) {
      await contextCompression.cancel(id);
    }
    if (!_initialized ||
        isTemporaryConversation(id) ||
        _draftConversations.containsKey(id)) {
      _temporaryCompressionSettings[id] = Map.of(values);
    } else {
      await _repo.compression.saveOverrides(id, values);
    }
    _notifyContextChanged(id);
  }

  Future<void> setAutoCompressionEnabled(String id, bool enabled) async {
    final overrides = await compressionOverrides(id);
    await setCompressionOverrides(id, {
      ...overrides,
      'mode': enabled ? 'auto' : 'off',
    });
  }
}
