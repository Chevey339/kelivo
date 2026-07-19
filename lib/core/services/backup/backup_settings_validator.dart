import 'dart:convert';

import '../../database/business_settings_router.dart';

/// Pure validation shared by backup preflight and business-data restoration.
final class BackupSettingsValidator {
  BackupSettingsValidator._();

  static const _jsonListKeys = {
    'assistants_v1',
    'assistant_memories_v1',
    'mcp_servers_v1',
    'provider_groups_v1',
    'world_books_v1',
    'quick_phrases_v1',
    'search_services_v1',
    'tts_services_v1',
    'instruction_injections_v1',
    'assistant_tags_v1',
  };
  static const _jsonMapKeys = {
    'provider_configs_v1',
    'provider_group_map_v1',
    'provider_group_collapsed_v1',
    'assistant_tag_map_v1',
    'assistant_tag_collapsed_v1',
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

  static bool isLocalOnly(String key) =>
      BusinessKeyRegistry.classify(key) == BusinessKeyDisposition.localOnly;

  static bool isDiscarded(String key) =>
      BusinessKeyRegistry.classify(key) == BusinessKeyDisposition.discarded;

  static bool shouldIgnore(String key) => isLocalOnly(key) || isDiscarded(key);

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
      if (shouldIgnore(entry.key)) continue;
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
    }
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
}
