import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'business_data.dart';

enum BusinessKeyDisposition {
  entity,
  providerOrder,
  preference,
  localOnly,
  discarded,
  unknownPreference,
}

final class BusinessKeyRegistry {
  BusinessKeyRegistry._();

  static const localOnlyKeys = <String>{
    'window_width_v1',
    'window_height_v1',
    'window_pos_x_v1',
    'window_pos_y_v1',
    'window_maximized_v1',
    'desktop_hotkeys_commands_v1',
    'desktop_hotkeys_enabled_v1',
    'display_chat_font_scale_v1',
    'flutter_log_enabled_v1',
  };

  static const discardedKeys = <String>{
    'pinned_chat_ids',
    'chat_titles_map',
    'instruction_injections_active_id_v1',
    'instruction_injections_active_ids_v1',
    'migrations_version_v1',
    'provider_configs_backup_v1',
  };

  static const preferenceKeys = <String>{
    'current_assistant_id_v1',
    'selected_model_v1',
    'pinned_models_v1',
    'provider_group_map_v1',
    'provider_group_collapsed_v1',
    'provider_ungrouped_position_v1',
    'assistant_tag_map_v1',
    'assistant_tag_collapsed_v1',
    'instruction_injections_active_ids_by_assistant_v1',
    'instruction_injection_group_collapsed_v1',
    'world_books_active_ids_by_assistant_v1',
    'world_books_collapsed_v1',
    'search_common_v1',
    'search_selected_v1',
    'search_enabled_v1',
    'search_auto_test_on_launch_v1',
    'tts_selected_v1',
    'tts_auto_play_assistant_replies_v1',
    'tts_text_selection_mode_v1',
    'tts_speech_rate_v1',
    'tts_pitch_v1',
    'tts_engine_v1',
    'tts_language_v1',
    'webdav_config_v1',
    's3_config_v1',
    'backup_reminder_enabled_v1',
    'backup_reminder_interval_days_v1',
    'backup_reminder_minutes_of_day_v1',
    'backup_reminder_enabled_at_v1',
    'backup_reminder_last_backup_at_v1',
    'user_name',
    'avatar_type',
    'avatar_value',
    'theme_mode_v1',
    'theme_palette_v1',
    'use_dynamic_color_v1',
    'app_locale_v1',
    'title_model_v1',
    'title_prompt_v1',
    'title_generation_thinking_enabled_v1',
    'translate_model_v1',
    'translate_prompt_v1',
    'translate_target_lang_v1',
    'ocr_model_v1',
    'ocr_prompt_v1',
    'ocr_enabled_v1',
    'summary_model_v1',
    'summary_prompt_v1',
    'suggestion_model_v1',
    'suggestion_prompt_v1',
    'suggestion_insert_on_tap_only_v1',
    'compress_model_v1',
    'compress_prompt_v1',
    'thinking_budget_v1',
    'image_cropper_enabled_v1',
    'desktop_topic_position_v1',
    'desktop_right_sidebar_open_v1',
    'desktop_sidebar_width_v1',
    'desktop_sidebar_open_v1',
    'desktop_right_sidebar_width_v1',
    'desktop_send_shortcut_v1',
    'android_background_chat_mode_v1',
    'ios_background_generation_enabled_v1',
    'ios_background_task_refresh_enabled_v1',
    'ios_live_activity_enabled_v1',
    'ios_background_notifications_enabled_v1',
    'display_app_font_family_v1',
    'display_code_font_family_v1',
    'display_app_font_is_google_v1',
    'display_code_font_is_google_v1',
    'display_app_font_local_path_v1',
    'display_code_font_local_path_v1',
    'display_app_font_local_alias_v1',
    'display_code_font_local_alias_v1',
    'global_proxy_enabled_v1',
    'global_proxy_type_v1',
    'global_proxy_host_v1',
    'global_proxy_port_v1',
    'global_proxy_username_v1',
    'global_proxy_password_v1',
    'global_proxy_bypass_v1',
    'request_log_enabled_v1',
    'log_save_output_v1',
    'log_auto_delete_days_v1',
    'log_max_size_mb_v1',
    'app_launch_count_v1',
    'mcp_request_timeout_ms_v1',
    'learning_mode_enabled_v1',
    'learning_mode_prompt_v1',
    'mobile_assistant_edit_tab_order_v1',
    'mobile_assistant_edit_tab_hidden_v1',
    'mobile_assistant_detail_outline_enabled_v1',
  };

  static BusinessKeyDisposition classify(String key) {
    if (BusinessEntityKind.values.any((kind) => kind.sourceKey == key)) {
      return BusinessKeyDisposition.entity;
    }
    if (key == 'providers_order_v1') {
      return BusinessKeyDisposition.providerOrder;
    }
    if (localOnlyKeys.contains(key) || key.startsWith('restore_')) {
      return BusinessKeyDisposition.localOnly;
    }
    if (discardedKeys.contains(key)) {
      return BusinessKeyDisposition.discarded;
    }
    if (preferenceKeys.contains(key) || key.startsWith('display_')) {
      return BusinessKeyDisposition.preference;
    }
    return BusinessKeyDisposition.unknownPreference;
  }
}

final class BusinessSettingsRouter {
  BusinessSettingsRouter._();

  static const _providerOrderKey = 'providers_order_v1';
  static const _legacyPinnedModelsKey = 'pinned_models_v1';
  static const _instructionInjectionsKey = 'instruction_injections_v1';
  static const _legacyActiveIdKey = 'instruction_injections_active_id_v1';
  static const _legacyActiveIdsKey = 'instruction_injections_active_ids_v1';
  static const _activeIdsByAssistantKey =
      'instruction_injections_active_ids_by_assistant_v1';
  static const _searchEnabledKey = 'search_enabled_v1';
  static const _globalAssistantKey = '__global__';
  static const _embeddingTypes = <String>{'embedding', 'embeddings'};
  static const _embeddingChatOnlyFields = <String>{
    'abilities',
    'output',
    'builtInTools',
    'built_in_tools',
    'tools',
  };

  /// Preserve an empty instruction list only at legacy input boundaries.
  /// Canonical SQLite exports always contain every entity key, so their `[]`
  /// cannot by itself distinguish an uninitialized table from a user clear.
  static BusinessSnapshot normalizeAndRoute(
    Map<String, Object?> source, {
    bool preserveExplicitEmptyInstructionList = false,
  }) {
    final normalized = Map<String, Object?>.from(source);
    _normalizeStringList(normalized, _providerOrderKey);
    _normalizeStringList(normalized, _legacyPinnedModelsKey);
    _normalizeInstructionActivation(
      normalized,
      preserveExplicitEmptyList: preserveExplicitEmptyInstructionList,
    );

    final entities = <BusinessEntityKind, List<BusinessEntityValue>>{};
    for (final kind in BusinessEntityKind.values) {
      entities[kind] = kind == BusinessEntityKind.provider
          ? _routeProviders(normalized)
          : _routeList(kind, normalized);
    }

    final preferences = <String, Object>{};
    for (final entry in normalized.entries) {
      final disposition = BusinessKeyRegistry.classify(entry.key);
      if (disposition == BusinessKeyDisposition.entity ||
          disposition == BusinessKeyDisposition.localOnly ||
          disposition == BusinessKeyDisposition.discarded ||
          entry.key == _providerOrderKey) {
        continue;
      }
      final value = entry.value;
      if (value == null) continue;
      preferences[entry.key] = _validatePreferenceValue(entry.key, value);
    }
    return BusinessSnapshot(entities: entities, preferences: preferences);
  }

  static Map<String, Object> exportSnapshot(BusinessSnapshot snapshot) {
    final result = <String, Object>{};
    for (final kind in BusinessEntityKind.values) {
      final rows = List<BusinessEntityValue>.of(snapshot.entities[kind]!)
        ..sort(_compareRows);
      if (kind == BusinessEntityKind.provider) {
        final providers = <String, Object?>{};
        for (final row in rows) {
          providers[row.id] = _decodePayload(row.payload, kind.sourceKey);
        }
        result[kind.sourceKey] = jsonEncode(providers);
        result[_providerOrderKey] = rows.map((row) => row.id).toList();
      } else {
        result[kind.sourceKey] = jsonEncode(
          rows
              .map((row) => _decodePayload(row.payload, kind.sourceKey))
              .toList(growable: false),
        );
      }
    }
    result.addAll(snapshot.preferences);
    return result;
  }

  /// Builds the legacy key-value-compatible view consumed by runtime
  /// providers. Stable row ids are projected into list payloads that came
  /// from legacy data without an id; assistant memories use deterministic
  /// negative ids so they stay outside the persisted positive-id space.
  /// [exportSnapshot] deliberately preserves the published payload byte shape
  /// used by backup validation.
  static Map<String, Object> exportRuntimeSnapshot(BusinessSnapshot snapshot) {
    final result = exportSnapshot(snapshot);
    for (final kind in BusinessEntityKind.values) {
      if (kind == BusinessEntityKind.provider) continue;
      final rows = List<BusinessEntityValue>.of(snapshot.entities[kind]!)
        ..sort(_compareRows);
      final projectedMemoryIds = kind == BusinessEntityKind.assistantMemory
          ? _projectMemoryIds(rows)
          : const <String, int>{};
      result[kind.sourceKey] = jsonEncode([
        for (final row in rows)
          () {
            final payload = Map<String, Object?>.from(
              (_decodePayload(row.payload, kind.sourceKey) as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            );
            final rawId = payload['id'];
            if (rawId == null || rawId.toString().trim().isEmpty) {
              payload['id'] = kind == BusinessEntityKind.assistantMemory
                  ? projectedMemoryIds[row.id]!
                  : row.id;
            }
            return payload;
          }(),
      ]);
    }
    return result;
  }

  static List<BusinessEntityValue> _routeProviders(
    Map<String, Object?> source,
  ) {
    final key = BusinessEntityKind.provider.sourceKey;
    final raw = source[key];
    if (raw == null) return const <BusinessEntityValue>[];
    final decoded = _decodeJson(raw, key);
    if (decoded is! Map) throw FormatException(key);
    final providers = <String, Map<String, dynamic>>{};
    for (final entry in decoded.entries) {
      if (entry.value is! Map) throw FormatException(key);
      final payload = (entry.value as Map).map(
        (field, value) => MapEntry(field.toString(), value),
      );
      _normalizeLegacyEmbeddingOverrides(payload);
      _validateEntityPayload(BusinessEntityKind.provider, payload);
      providers[entry.key.toString()] = payload;
    }
    final rawOrder = source[_providerOrderKey];
    final order = rawOrder == null
        ? const <String>[]
        : _stringList(rawOrder, _providerOrderKey);
    final orderedKeys = <String>[];
    final seen = <String>{};
    for (final providerKey in order) {
      if (providers.containsKey(providerKey) && seen.add(providerKey)) {
        orderedKeys.add(providerKey);
      }
    }
    for (final providerKey in providers.keys) {
      if (seen.add(providerKey)) orderedKeys.add(providerKey);
    }
    return [
      for (var index = 0; index < orderedKeys.length; index++)
        BusinessEntityValue(
          id: orderedKeys[index],
          sortOrder: index,
          payload: jsonEncode(providers[orderedKeys[index]]),
        ),
    ];
  }

  static List<BusinessEntityValue> _routeList(
    BusinessEntityKind kind,
    Map<String, Object?> source,
  ) {
    final raw = source[kind.sourceKey];
    if (raw == null) return const <BusinessEntityValue>[];
    final decoded = _decodeJson(raw, kind.sourceKey);
    if (decoded is! List) throw FormatException(kind.sourceKey);
    final legacySearchEnabled = source[_searchEnabledKey];
    if (legacySearchEnabled != null && legacySearchEnabled is! bool) {
      throw const FormatException(_searchEnabledKey);
    }
    return [
      for (var index = 0; index < decoded.length; index++)
        _routeListItem(
          kind,
          decoded[index],
          index,
          legacySearchEnabled: legacySearchEnabled as bool?,
        ),
    ];
  }

  static BusinessEntityValue _routeListItem(
    BusinessEntityKind kind,
    Object? raw,
    int index, {
    required bool? legacySearchEnabled,
  }) {
    if (raw is! Map) throw FormatException(kind.sourceKey);
    final payload = raw.map((key, value) => MapEntry(key.toString(), value));
    if (kind == BusinessEntityKind.assistant &&
        legacySearchEnabled != null &&
        !payload.containsKey('searchEnabled')) {
      payload['searchEnabled'] = legacySearchEnabled;
    }
    _validateEntityPayload(kind, payload);
    final rawId = payload['id'];
    final id = rawId == null || rawId.toString().trim().isEmpty
        ? _stableGeneratedId(kind.sourceKey, index, payload)
        : rawId.toString();
    String? assistantId;
    if (kind == BusinessEntityKind.assistantMemory) {
      final rawAssistantId = payload['assistantId'];
      if (rawAssistantId is! String || rawAssistantId.trim().isEmpty) {
        throw FormatException(kind.sourceKey);
      }
      assistantId = rawAssistantId;
    }
    return BusinessEntityValue(
      id: id,
      sortOrder: index,
      payload: jsonEncode(payload),
      assistantId: assistantId,
    );
  }

  // Mirror runtime decoder cast boundaries without canonicalizing payloads.
  // Fields whose published decoders intentionally coerce values stay lenient.
  static void _validateEntityPayload(
    BusinessEntityKind kind,
    Map<String, Object?> payload,
  ) {
    switch (kind) {
      case BusinessEntityKind.assistant:
        _validateKnownFields(
          kind,
          payload,
          strings: const {
            'id',
            'name',
            'avatar',
            'chatModelProvider',
            'chatModelId',
            'systemPrompt',
            'messageTemplate',
            'background',
          },
          booleans: const {
            'useAssistantAvatar',
            'useAssistantName',
            'limitContextMessages',
            'streamOutput',
            'searchEnabled',
            'enableMemory',
            'enableRecentChatsReference',
          },
          numbers: const {
            'temperature',
            'topP',
            'contextMessageSize',
            'thinkingBudget',
            'maxTokens',
            'recentChatsSummaryMessageCount',
          },
          lists: const {
            'customHeaders',
            'customBody',
            'presetMessages',
            'regexRules',
          },
          stringLists: const {'mcpServerIds', 'localToolIds'},
        );
        _validateAssistantChildren(kind, payload);
        return;
      case BusinessEntityKind.provider:
        _validateKnownFields(
          kind,
          payload,
          strings: const {
            'id',
            'name',
            'apiKey',
            'baseUrl',
            'chatPath',
            'location',
            'projectId',
            'serviceAccountJson',
            'proxyType',
            'proxyHost',
            'proxyPort',
            'proxyUsername',
            'proxyPassword',
            'avatarType',
            'avatarValue',
            'balanceApiPath',
            'balanceResultPath',
            'claudePromptCachingTtl',
          },
          booleans: const {
            'enabled',
            'useResponseApi',
            'vertexAI',
            'proxyEnabled',
            'multiKeyEnabled',
            'aihubmixAppCodeEnabled',
            'balanceEnabled',
            'claudePromptCachingEnabled',
          },
          lists: const {'models', 'apiKeys'},
          maps: const {'modelOverrides', 'keyManagement'},
        );
        _validateProviderChildren(kind, payload);
        return;
      case BusinessEntityKind.providerGroup:
        return;
      case BusinessEntityKind.mcpServer:
        _validateKnownFields(
          kind,
          payload,
          strings: const {'id', 'name', 'transport'},
          booleans: const {'enabled'},
          objectLists: const {'tools'},
        );
        _validateMcpChildren(kind, payload);
        final transport = payload['transport'];
        if (transport == 'stdio') {
          _validateKnownFields(
            kind,
            payload,
            strings: const {'command', 'workingDirectory'},
            lists: const {'args'},
            maps: const {'env'},
          );
        } else if (transport != 'inmemory') {
          _validateKnownFields(
            kind,
            payload,
            strings: const {'url'},
            maps: const {'headers'},
          );
        }
        return;
      case BusinessEntityKind.worldBook:
        _validateKnownFields(
          kind,
          payload,
          strings: const {'id', 'name', 'description'},
          booleans: const {'enabled'},
          lists: const {'entries'},
        );
        _validateWorldBookChildren(kind, payload);
        return;
      case BusinessEntityKind.assistantMemory:
        _validateKnownFields(kind, payload, numbers: const {'id'});
        return;
      case BusinessEntityKind.quickPhrase:
        _validateKnownFields(
          kind,
          payload,
          strings: const {'id', 'title', 'content', 'assistantId'},
          booleans: const {'isGlobal'},
        );
        return;
      case BusinessEntityKind.searchService:
        _validateSearchService(kind, payload);
        return;
      case BusinessEntityKind.ttsService:
        return;
      case BusinessEntityKind.instructionInjection:
        _validateKnownFields(
          kind,
          payload,
          strings: const {'id', 'title', 'prompt', 'group'},
        );
        return;
      case BusinessEntityKind.assistantTag:
        return;
    }
  }

  static void _validateKnownFields(
    BusinessEntityKind kind,
    Map<String, Object?> payload, {
    Set<String> requiredStrings = const {},
    Set<String> strings = const {},
    Set<String> booleans = const {},
    Set<String> numbers = const {},
    Set<String> integers = const {},
    Set<String> lists = const {},
    Set<String> stringLists = const {},
    Set<String> maps = const {},
    Set<String> objectLists = const {},
  }) {
    for (final field in requiredStrings) {
      if (payload[field] is! String) throw FormatException(kind.sourceKey);
    }
    _validateFields(kind, payload, strings, (value) => value is String);
    _validateFields(kind, payload, booleans, (value) => value is bool);
    _validateFields(kind, payload, numbers, (value) => value is num);
    _validateFields(kind, payload, integers, (value) => value is int);
    _validateFields(kind, payload, lists, (value) => value is List);
    _validateFields(
      kind,
      payload,
      stringLists,
      (value) => value is List && value.every((item) => item is String),
    );
    _validateFields(kind, payload, maps, (value) => value is Map);
    _validateFields(
      kind,
      payload,
      objectLists,
      (value) => value is List && value.every((item) => item is Map),
    );
  }

  static void _validateFields(
    BusinessEntityKind kind,
    Map<String, Object?> payload,
    Set<String> fields,
    bool Function(Object value) accepts,
  ) {
    for (final field in fields) {
      final value = payload[field];
      if (value != null && !accepts(value)) {
        throw FormatException(kind.sourceKey);
      }
    }
  }

  static void _validateAssistantChildren(
    BusinessEntityKind kind,
    Map<String, Object?> payload,
  ) {
    for (final child in _mappedObjects(payload['presetMessages'])) {
      _validateKnownFields(
        kind,
        child,
        strings: const {'id', 'role', 'content'},
      );
    }
    for (final child in _mappedObjects(payload['regexRules'])) {
      _validateKnownFields(
        kind,
        child,
        strings: const {'id', 'name', 'pattern', 'replacement'},
        booleans: const {'visualOnly', 'replaceOnly', 'enabled'},
      );
    }
  }

  static void _validateProviderChildren(
    BusinessEntityKind kind,
    Map<String, Object?> payload,
  ) {
    for (final child in _mappedObjects(payload['apiKeys'])) {
      _validateKnownFields(
        kind,
        child,
        strings: const {'id', 'key', 'name', 'status', 'lastError'},
        booleans: const {'isEnabled'},
        integers: const {
          'priority',
          'maxRequestsPerMinute',
          'createdAt',
          'updatedAt',
        },
        maps: const {'usage'},
      );
      final usage = child['usage'];
      if (usage is Map) {
        _validateKnownFields(
          kind,
          _stringKeyedMap(usage),
          integers: const {
            'totalRequests',
            'successfulRequests',
            'failedRequests',
            'consecutiveFailures',
            'lastUsed',
          },
        );
      }
    }
    final keyManagement = payload['keyManagement'];
    if (keyManagement is Map) {
      _validateKnownFields(
        kind,
        _stringKeyedMap(keyManagement),
        strings: const {'strategy'},
        booleans: const {'enableAutoRecovery'},
        integers: const {
          'maxFailuresBeforeDisable',
          'failureRecoveryTimeMinutes',
          'roundRobinIndex',
        },
      );
    }
  }

  static void _validateMcpChildren(
    BusinessEntityKind kind,
    Map<String, Object?> payload,
  ) {
    for (final tool in _objectList(payload['tools'])) {
      _validateKnownFields(
        kind,
        tool,
        strings: const {'name', 'description'},
        booleans: const {'enabled', 'needsApproval'},
        objectLists: const {'params'},
      );
      for (final parameter in _objectList(tool['params'])) {
        _validateKnownFields(
          kind,
          parameter,
          strings: const {'name', 'type'},
          booleans: const {'required'},
        );
      }
    }
  }

  static void _validateWorldBookChildren(
    BusinessEntityKind kind,
    Map<String, Object?> payload,
  ) {
    for (final entry in _mappedObjects(payload['entries'])) {
      _validateKnownFields(
        kind,
        entry,
        strings: const {'id', 'name', 'content'},
        booleans: const {
          'enabled',
          'useRegex',
          'caseSensitive',
          'constantActive',
        },
        integers: const {'priority', 'injectDepth', 'scanDepth'},
        lists: const {'keywords'},
      );
    }
  }

  static void _validateSearchService(
    BusinessEntityKind kind,
    Map<String, Object?> payload,
  ) {
    _validateKnownFields(
      kind,
      payload,
      requiredStrings: const {'type'},
      strings: const {'id'},
    );
    switch (payload['type']) {
      case 'bing_local':
        _validateKnownFields(kind, payload, strings: const {'acceptLanguage'});
      case 'tavily':
      case 'exa':
        _validateKnownFields(
          kind,
          payload,
          requiredStrings: const {'apiKey'},
          strings: const {'url'},
        );
      case 'zhipu':
      case 'linkup':
      case 'brave':
      case 'metaso':
      case 'ollama':
      case 'jina':
        _validateKnownFields(kind, payload, requiredStrings: const {'apiKey'});
      case 'searxng':
        _validateKnownFields(
          kind,
          payload,
          requiredStrings: const {'url'},
          strings: const {'engines', 'language', 'username', 'password'},
        );
      case 'duckduckgo':
        _validateKnownFields(kind, payload, strings: const {'region'});
      case 'perplexity':
        _validateKnownFields(
          kind,
          payload,
          requiredStrings: const {'apiKey'},
          strings: const {'country'},
          integers: const {'maxTokensPerPage'},
          lists: const {'searchDomainFilter'},
        );
      case 'bocha':
        _validateKnownFields(
          kind,
          payload,
          requiredStrings: const {'apiKey'},
          strings: const {'freshness', 'include', 'exclude'},
          booleans: const {'summary'},
        );
      case 'serper':
        _validateKnownFields(
          kind,
          payload,
          requiredStrings: const {'apiKey'},
          strings: const {'gl', 'hl', 'tbs'},
          integers: const {'page'},
        );
      case 'grok':
        _validateKnownFields(
          kind,
          payload,
          strings: const {'apiKey', 'model', 'customUrl', 'systemPrompt'},
        );
      case 'querit':
        _validateKnownFields(
          kind,
          payload,
          strings: const {
            'apiKey',
            'sitesInclude',
            'sitesExclude',
            'timeRange',
            'countries',
            'languages',
          },
        );
    }
  }

  static List<Map<String, Object?>> _objectList(Object? raw) {
    if (raw is! List) return const [];
    return [for (final value in raw) _stringKeyedMap(value as Map)];
  }

  static List<Map<String, Object?>> _mappedObjects(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        if (value is Map) _stringKeyedMap(value),
    ];
  }

  static Map<String, Object?> _stringKeyedMap(Map<dynamic, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  static void _normalizeStringList(Map<String, Object?> values, String key) {
    final raw = values[key];
    if (raw == null) return;
    if (raw is String) {
      values[key] = _stringList(_decodeJson(raw, key), key);
      return;
    }
    values[key] = _stringList(raw, key);
  }

  static void _normalizeInstructionActivation(
    Map<String, Object?> values, {
    required bool preserveExplicitEmptyList,
  }) {
    final rawItems = preserveExplicitEmptyList
        ? values[_instructionInjectionsKey]
        : null;
    var explicitlyEmptyItems = false;
    if (rawItems != null) {
      final decodedItems = _decodeJson(rawItems, _instructionInjectionsKey);
      explicitlyEmptyItems = decodedItems is List && decodedItems.isEmpty;
    }
    final finalRaw = values[_activeIdsByAssistantKey];
    Map<String, List<String>>? normalized;
    if (finalRaw != null) {
      final decoded = _decodeJson(finalRaw, _activeIdsByAssistantKey);
      if (decoded is! Map) {
        throw const FormatException(_activeIdsByAssistantKey);
      }
      normalized = <String, List<String>>{};
      for (final entry in decoded.entries) {
        normalized[entry.key.toString()] = _deduplicateStrings(
          _stringList(entry.value, _activeIdsByAssistantKey),
        );
      }
    } else {
      List<String> legacy = const <String>[];
      final legacyIdsRaw = values[_legacyActiveIdsKey];
      if (legacyIdsRaw != null) {
        legacy = _deduplicateStrings(
          _stringList(
            _decodeJson(legacyIdsRaw, _legacyActiveIdsKey),
            _legacyActiveIdsKey,
          ),
        );
      } else {
        final legacyId = values[_legacyActiveIdKey];
        if (legacyId != null) {
          if (legacyId is! String) {
            throw const FormatException(_legacyActiveIdKey);
          }
          if (legacyId.trim().isNotEmpty) legacy = <String>[legacyId.trim()];
        }
      }
      if (legacy.isNotEmpty) {
        normalized = <String, List<String>>{_globalAssistantKey: legacy};
      }
    }
    if (explicitlyEmptyItems) {
      (normalized ??= <String, List<String>>{})[_globalAssistantKey] =
          const <String>[];
    }
    if (normalized != null) {
      values[_activeIdsByAssistantKey] = jsonEncode(normalized);
    }
    values.remove(_legacyActiveIdKey);
    values.remove(_legacyActiveIdsKey);
  }

  static Object _validatePreferenceValue(String key, Object value) {
    if (value is bool || value is int || value is double || value is String) {
      return value;
    }
    if (value is List && value.every((item) => item is String)) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    throw FormatException(key);
  }

  static Object? _decodePayload(String payload, String key) {
    final decoded = _decodeJson(payload, key);
    if (decoded is! Map) throw FormatException(key);
    return decoded;
  }

  static Object? _decodeJson(Object raw, String key) {
    if (raw is! String) throw FormatException(key);
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw FormatException(key);
    }
  }

  static List<String> _stringList(Object? raw, String key) {
    if (raw is! List || raw.any((item) => item is! String)) {
      throw FormatException(key);
    }
    return raw.cast<String>();
  }

  static List<String> _deduplicateStrings(List<String> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (value.trim().isNotEmpty && seen.add(value.trim())) value.trim(),
    ];
  }

  static String _stableGeneratedId(
    String sourceKey,
    int index,
    Map<String, Object?> payload,
  ) {
    final digest = sha256.convert(
      utf8.encode('$sourceKey\u0000$index\u0000${jsonEncode(payload)}'),
    );
    return 'generated_${digest.toString().substring(0, 32)}';
  }

  static void _normalizeLegacyEmbeddingOverrides(
    Map<String, Object?> provider,
  ) {
    final rawOverrides = provider['modelOverrides'];
    if (rawOverrides is! Map) return;
    final normalized = <String, Object?>{};
    for (final entry in rawOverrides.entries) {
      final rawOverride = entry.value;
      if (rawOverride is! Map) {
        normalized[entry.key.toString()] = rawOverride;
        continue;
      }
      final override = rawOverride.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final type = (override['type'] ?? override['t'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (_embeddingTypes.contains(type)) {
        for (final field in _embeddingChatOnlyFields) {
          override.remove(field);
        }
      }
      normalized[entry.key.toString()] = override;
    }
    provider['modelOverrides'] = normalized;
  }

  static Map<String, int> _projectMemoryIds(List<BusinessEntityValue> rows) {
    final used = <int>{};
    final missing = <BusinessEntityValue>[];
    for (final row in rows) {
      final payload =
          _decodePayload(
                row.payload,
                BusinessEntityKind.assistantMemory.sourceKey,
              )!
              as Map;
      final rawId = payload['id'];
      if (rawId is num) {
        used.add(rawId.toInt());
      } else {
        missing.add(row);
      }
    }
    missing.sort((left, right) => left.id.compareTo(right.id));
    final projected = <String, int>{};
    for (final row in missing) {
      final digest = sha256.convert(utf8.encode(row.id)).toString();
      // Keep runtime-only identities outside MemoryStore's positive ID space.
      var candidate =
          -((int.parse(digest.substring(0, 8), radix: 16) & 0x3fffffff) + 1);
      while (!used.add(candidate)) {
        candidate = candidate == -0x40000000 ? -1 : candidate - 1;
      }
      projected[row.id] = candidate;
    }
    return projected;
  }

  static int _compareRows(BusinessEntityValue left, BusinessEntityValue right) {
    final byOrder = left.sortOrder.compareTo(right.sortOrder);
    return byOrder != 0 ? byOrder : left.id.compareTo(right.id);
  }
}
