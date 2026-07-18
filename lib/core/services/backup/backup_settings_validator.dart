import 'dart:convert';

/// Pure validation shared by backup preflight and preference restoration.
final class BackupSettingsValidator {
  BackupSettingsValidator._();

  static const _localOnlyKeys = {
    'window_width_v1',
    'window_height_v1',
    'window_pos_x_v1',
    'window_pos_y_v1',
    'window_maximized_v1',
    'display_chat_font_scale_v1',
    'desktop_hotkeys_commands_v1',
    'desktop_hotkeys_enabled_v1',
  };
  static const _jsonListKeys = {
    'assistants_v1',
    'assistant_memories_v1',
    'mcp_servers_v1',
    'provider_groups_v1',
    'search_services_v1',
    'assistant_tags_v1',
  };
  static const _jsonMapKeys = {
    'provider_configs_v1',
    'provider_group_map_v1',
    'provider_group_collapsed_v1',
    'assistant_tag_map_v1',
    'assistant_tag_collapsed_v1',
    'chat_model_selections_v1',
  };
  static const _jsonMapOfMapKeys = {'provider_configs_v1'};
  static const _jsonMapOfStringKeys = {
    'provider_group_map_v1',
    'assistant_tag_map_v1',
  };
  static const _jsonMapOfBoolKeys = {
    'provider_group_collapsed_v1',
    'assistant_tag_collapsed_v1',
  };
  static const _legacyStringListKeys = {
    'pinned_models_v1',
    'providers_order_v1',
  };

  static bool isLocalOnly(String key) => _localOnlyKeys.contains(key);

  static void normalizeAndValidate(Map<String, dynamic> data) {
    normalizeLegacyStringLists(data);
    validate(data);
  }

  static void normalizeLegacyStringLists(Map<String, dynamic> data) {
    for (final key in _legacyStringListKeys) {
      final value = data[key];
      if (value is! String) continue;
      try {
        final decoded = jsonDecode(value);
        if (decoded is! List || decoded.any((item) => item is! String)) {
          throw FormatException(key);
        }
        data[key] = decoded.cast<String>();
      } on FormatException {
        throw FormatException(key);
      }
    }
  }

  static void validate(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      if (isLocalOnly(entry.key)) continue;
      validateValue(entry.key, entry.value);
    }
  }

  static void validateValue(String key, dynamic value) {
    final supported =
        value is bool ||
        value is int ||
        value is double ||
        value is String ||
        (value is List && value.every((item) => item is String));
    if (!supported) throw FormatException(key);

    if (_jsonListKeys.contains(key)) {
      _validateJsonShape(key, value, expectList: true);
    } else if (_jsonMapKeys.contains(key)) {
      _validateJsonShape(key, value, expectList: false);
      if (key == 'chat_model_selections_v1') {
        _validateChatModelSelections(key, value);
      }
    }
  }

  /// Merges the preference-backed multi-model selection index during a backup
  /// merge. Only incoming conversation IDs are remapped: the database merge
  /// report describes imported IDs, not local conversation renames.
  static String mergeChatModelSelectionsForRestore({
    required String incomingValue,
    String? existingValue,
    Map<String, String> remappedConversationIds = const <String, String>{},
  }) {
    final incoming = _decodeChatModelSelections(incomingValue);
    final existing = existingValue == null || existingValue.isEmpty
        ? const <String, dynamic>{}
        : _decodeChatModelSelections(existingValue);

    Map<String, dynamic> mergeIndex(String key, {required bool remap}) {
      final imported = _selectionIndex(incoming[key]);
      final remapped = <String, dynamic>{};
      for (final entry in imported.entries) {
        final targetKey = remap
            ? (remappedConversationIds[entry.key] ?? entry.key)
            : entry.key;
        remapped.putIfAbsent(targetKey, () => entry.value);
      }
      // Local scope history wins when an imported identifier still collides.
      return <String, dynamic>{...remapped, ..._selectionIndex(existing[key])};
    }

    final merged = <String, dynamic>{
      ...incoming,
      ...existing,
      'version': existing['version'] ?? incoming['version'] ?? 1,
      'scope': existing['scope'] ?? incoming['scope'] ?? 'conversation',
      'assistants': mergeIndex('assistants', remap: false),
      'conversations': mergeIndex('conversations', remap: true),
      'nextMessages': mergeIndex('nextMessages', remap: true),
    };
    final encoded = jsonEncode(merged);
    _validateChatModelSelections('chat_model_selections_v1', encoded);
    return encoded;
  }

  static void _validateJsonShape(
    String key,
    dynamic value, {
    required bool expectList,
  }) {
    if (value is! String) throw FormatException(key);
    try {
      final decoded = jsonDecode(value);
      if (expectList) {
        if (decoded is! List || decoded.any((entry) => entry is! Map)) {
          throw FormatException(key);
        }
      } else if (decoded is! Map) {
        throw FormatException(key);
      } else if (_jsonMapOfMapKeys.contains(key) &&
          decoded.values.any((entry) => entry is! Map)) {
        throw FormatException(key);
      } else if (_jsonMapOfStringKeys.contains(key) &&
          decoded.values.any((entry) => entry is! String)) {
        throw FormatException(key);
      } else if (_jsonMapOfBoolKeys.contains(key) &&
          decoded.values.any((entry) => entry is! bool)) {
        throw FormatException(key);
      }
    } on FormatException {
      throw FormatException(key);
    }
  }

  static Map<String, dynamic> _decodeChatModelSelections(String value) {
    _validateChatModelSelections('chat_model_selections_v1', value);
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  static Map<String, dynamic> _selectionIndex(Object? value) {
    if (value == null) return const <String, dynamic>{};
    return Map<String, dynamic>.from(value as Map);
  }

  static void _validateChatModelSelections(String key, dynamic value) {
    if (value is! String) throw FormatException(key);
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) throw FormatException(key);
      final version = decoded['version'];
      if (version != null && version != 1) throw FormatException(key);
      final scope = decoded['scope'];
      if (scope != null &&
          scope != 'assistant' &&
          scope != 'conversation' &&
          scope != 'nextMessage') {
        throw FormatException(key);
      }
      for (final indexKey in const <String>[
        'assistants',
        'conversations',
        'nextMessages',
      ]) {
        final index = decoded[indexKey];
        if (index == null) continue;
        if (index is! Map) throw FormatException(key);
        for (final entry in index.entries) {
          if (entry.key is! String || (entry.key as String).isEmpty) {
            throw FormatException(key);
          }
          final targets = entry.value;
          if (targets is! List || targets.length < 2 || targets.length > 5) {
            throw FormatException(key);
          }
          final seen = <String>{};
          for (final target in targets) {
            if (target is! Map ||
                target['providerKey'] is! String ||
                target['modelId'] is! String) {
              throw FormatException(key);
            }
            final providerKey = (target['providerKey'] as String).trim();
            final modelId = (target['modelId'] as String).trim();
            if (providerKey.isEmpty ||
                modelId.isEmpty ||
                !seen.add('$providerKey\u0000$modelId')) {
              throw FormatException(key);
            }
          }
        }
      }
    } on FormatException {
      throw FormatException(key);
    } on Object {
      throw FormatException(key);
    }
  }
}
