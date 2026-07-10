import 'dart:convert';

/// Removes application-known authentication credentials from a regular
/// backup settings snapshot. Free-form user content is intentionally outside
/// this policy; migration disaster backups do not use this sanitizer.
final class BackupSettingsSanitizer {
  BackupSettingsSanitizer._();

  static const _credentialJsonBaseKeys = {
    'assistants',
    'mcp_servers',
    'provider_configs',
    's3_config',
    'search_services',
    'tts_services',
    'webdav_config',
  };
  static const _excludedBaseKeys = {'provider_configs_backup'};
  static const _knownSecretPlaceholders = {'global_proxy_password_v1': ''};
  static const _secretValueFields = {
    'accesskey',
    'accesskeyid',
    'accesstoken',
    'apikey',
    'auth',
    'authorization',
    'clientsecret',
    'cookie',
    'credential',
    'credentials',
    'passphrase',
    'password',
    'privatekey',
    'proxyauth',
    'proxyauthorization',
    'proxypassword',
    'refreshtoken',
    'secret',
    'secretaccesskey',
    'secretkey',
    'signature',
    'serviceaccountjson',
    'sessiontoken',
    'subscriptionkey',
    'token',
  };
  static const _credentialUriFields = {
    'balanceapipath',
    'baseurl',
    'chatpath',
    'endpoint',
    'url',
  };

  static Map<String, dynamic> sanitize(Map<String, dynamic> source) {
    final sanitized = <String, dynamic>{};
    for (final entry in source.entries) {
      final baseKey = _preferenceKeyBase(entry.key);
      if (_excludedBaseKeys.contains(baseKey)) continue;
      if (_isSecretPreferenceKey(entry.key)) {
        sanitized[entry.key] = _emptyPreferenceCredential(
          entry.key,
          entry.value,
        );
      } else if (_credentialJsonBaseKeys.contains(baseKey)) {
        sanitized[entry.key] = _sanitizeCredentialJson(
          preferenceKey: entry.key,
          baseKey: baseKey,
          value: entry.value,
        );
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    for (final entry in _knownSecretPlaceholders.entries) {
      sanitized.putIfAbsent(entry.key, () => entry.value);
    }
    return sanitized;
  }

  static bool shouldClearBeforeSecretFreeOverwrite(String key) {
    final baseKey = _preferenceKeyBase(key);
    return _credentialJsonBaseKeys.contains(baseKey) ||
        _excludedBaseKeys.contains(baseKey) ||
        _isSecretPreferenceKey(key);
  }

  static String _preferenceKeyBase(String key) =>
      key.toLowerCase().replaceFirst(RegExp(r'_v\d+$'), '');

  static bool _isSecretPreferenceKey(String key) {
    final parts = _preferenceKeyBase(key)
        .split(RegExp('[^a-z0-9]+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final compact = parts.join();
    const secretSuffixes = {
      'accesskey',
      'accesskeyid',
      'accesstoken',
      'apikey',
      'authorization',
      'authtoken',
      'bearertoken',
      'clientsecret',
      'cookie',
      'credentials',
      'oauthtoken',
      'passphrase',
      'password',
      'privatekey',
      'proxypassword',
      'refreshtoken',
      'secret',
      'secretaccesskey',
      'serviceaccountjson',
      'sessiontoken',
    };
    if (secretSuffixes.any(compact.endsWith)) return true;
    return parts.isNotEmpty && parts.last == 'token';
  }

  static String _sanitizeCredentialJson({
    required String preferenceKey,
    required String baseKey,
    required dynamic value,
  }) {
    if (value is! String) throw FormatException(preferenceKey);
    final dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw FormatException(preferenceKey);
    }
    switch (baseKey) {
      case 'provider_configs':
        _sanitizeProviderConfigs(decoded, preferenceKey);
        break;
      case 'assistants':
        _sanitizeAssistants(decoded, preferenceKey);
        break;
      case 'mcp_servers':
        _sanitizeMcpServers(decoded, preferenceKey);
        break;
      case 'search_services':
      case 'tts_services':
        for (final item in _objectList(decoded, preferenceKey)) {
          _sanitizeDirectFields(item);
        }
        break;
      case 'webdav_config':
      case 's3_config':
        _sanitizeDirectFields(_object(decoded, preferenceKey));
        break;
      default:
        throw StateError(preferenceKey);
    }
    return jsonEncode(decoded);
  }

  // Only walk known configuration object levels. Provider/model identifiers
  // and MCP tool schemas are arbitrary maps and must remain untouched.
  static void _sanitizeProviderConfigs(dynamic value, String preferenceKey) {
    final configs = _object(value, preferenceKey);
    for (final rawConfig in configs.values) {
      final config = _object(rawConfig, preferenceKey);
      _sanitizeDirectFields(config);
      final rawApiKeys = config['apiKeys'];
      if (rawApiKeys != null) {
        for (final apiKey in _objectList(rawApiKeys, preferenceKey)) {
          _sanitizeDirectFields(apiKey);
          if (apiKey.containsKey('key')) {
            apiKey['key'] = _emptyJsonCredential(preferenceKey, apiKey['key']);
          }
        }
      }
      final rawOverrides = config['modelOverrides'];
      if (rawOverrides == null) continue;
      final overrides = _object(rawOverrides, preferenceKey);
      for (final rawOverride in overrides.values) {
        final override = _object(rawOverride, preferenceKey);
        _sanitizeDirectFields(override);
        if (override.containsKey('headers')) {
          _sanitizeNamedEntries(
            override['headers'],
            preferenceKey,
            headerValues: true,
          );
        }
        if (override.containsKey('body')) {
          _sanitizeNamedEntries(
            override['body'],
            preferenceKey,
            headerValues: false,
          );
        }
      }
    }
  }

  static void _sanitizeAssistants(dynamic value, String preferenceKey) {
    for (final assistant in _objectList(value, preferenceKey)) {
      _sanitizeDirectFields(assistant);
      if (assistant.containsKey('customHeaders')) {
        _sanitizeNamedEntries(
          assistant['customHeaders'],
          preferenceKey,
          headerValues: true,
        );
      }
      if (assistant.containsKey('customBody')) {
        _sanitizeNamedEntries(
          assistant['customBody'],
          preferenceKey,
          headerValues: false,
        );
      }
    }
  }

  static void _sanitizeMcpServers(dynamic value, String preferenceKey) {
    for (final server in _objectList(value, preferenceKey)) {
      _sanitizeDirectFields(server);
      if (server.containsKey('headers')) {
        _sanitizeNamedMap(server['headers'], preferenceKey, headerValues: true);
      }
      if (server.containsKey('env')) {
        _sanitizeNamedMap(server['env'], preferenceKey, headerValues: false);
      }
      if (server.containsKey('args')) {
        server['args'] = _sanitizeCommandArgs(server['args'], preferenceKey);
      }
    }
  }

  static void _sanitizeDirectFields(Map<String, dynamic> value) {
    for (final entry in value.entries.toList(growable: false)) {
      final normalizedKey = _normalizeName(entry.key);
      if (_isCredentialValueField(normalizedKey)) {
        value[entry.key] = _emptyJsonCredential(entry.key, entry.value);
      } else if (entry.value is String &&
          (_credentialUriFields.contains(normalizedKey) ||
              normalizedKey.endsWith('url'))) {
        value[entry.key] = _sanitizeCredentialUri(entry.value as String);
      }
    }
  }

  static void _sanitizeNamedEntries(
    dynamic value,
    String preferenceKey, {
    required bool headerValues,
  }) {
    if (value == null) return;
    for (final item in _objectList(value, preferenceKey)) {
      _sanitizeDirectFields(item);
      if (!item.containsKey('value')) continue;
      final rawValue = item['value'];
      if (rawValue is! String) throw FormatException(preferenceKey);
      final label = (item['name'] ?? item['key'] ?? '').toString();
      if (_isCredentialEntryName(_normalizeName(label)) ||
          (headerValues && _looksLikeCredentialLiteral(rawValue))) {
        item['value'] = '';
      }
    }
  }

  static void _sanitizeNamedMap(
    dynamic value,
    String preferenceKey, {
    required bool headerValues,
  }) {
    if (value == null) return;
    final values = _object(value, preferenceKey);
    for (final entry in values.entries.toList(growable: false)) {
      if (entry.value is! String) throw FormatException(preferenceKey);
      final rawValue = entry.value as String;
      if (_isCredentialEntryName(_normalizeName(entry.key)) ||
          (headerValues && _looksLikeCredentialLiteral(rawValue))) {
        values[entry.key] = '';
      } else if (rawValue.contains('://')) {
        values[entry.key] = _sanitizeCredentialUri(rawValue);
      }
    }
  }

  static List<String> _sanitizeCommandArgs(
    dynamic value,
    String preferenceKey,
  ) {
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException(preferenceKey);
    }
    final sanitized = <String>[];
    String? pendingValueKind;
    for (final item in value.cast<String>()) {
      if (pendingValueKind != null) {
        sanitized.add(switch (pendingValueKind) {
          'header' => _sanitizeHeaderArgument(item),
          'env' => _sanitizeAssignmentArgument(item),
          _ => '',
        });
        pendingValueKind = null;
        continue;
      }

      final equalsIndex = item.indexOf('=');
      final flag = equalsIndex < 0 ? item : item.substring(0, equalsIndex);
      final normalizedFlag = _normalizeName(
        flag.replaceFirst(RegExp(r'^--?'), ''),
      );
      final isHeaderFlag = flag == '-H' || normalizedFlag == 'header';
      final isEnvFlag = flag == '-e' || normalizedFlag == 'env';
      if (isHeaderFlag || isEnvFlag || _isCredentialEntryName(normalizedFlag)) {
        if (equalsIndex < 0) {
          sanitized.add(item);
          pendingValueKind = isHeaderFlag
              ? 'header'
              : (isEnvFlag ? 'env' : 'secret');
        } else {
          final rawValue = item.substring(equalsIndex + 1);
          final nextValue = isHeaderFlag
              ? _sanitizeHeaderArgument(rawValue)
              : (isEnvFlag ? _sanitizeAssignmentArgument(rawValue) : '');
          sanitized.add('${item.substring(0, equalsIndex + 1)}$nextValue');
        }
      } else if (equalsIndex > 0 && !flag.startsWith('-')) {
        sanitized.add(_sanitizeAssignmentArgument(item));
      } else if (item.contains('://')) {
        sanitized.add(_sanitizeCredentialUri(item));
      } else {
        sanitized.add(_looksLikeCredentialLiteral(item) ? '' : item);
      }
    }
    return sanitized;
  }

  static String _sanitizeHeaderArgument(String value) {
    final separator = value.indexOf(':');
    if (separator < 0) {
      return _looksLikeCredentialLiteral(value) ? '' : value;
    }
    final name = value.substring(0, separator);
    final rawValue = value.substring(separator + 1).trimLeft();
    return _isCredentialEntryName(_normalizeName(name)) ||
            _looksLikeCredentialLiteral(rawValue)
        ? '$name:'
        : value;
  }

  static String _sanitizeAssignmentArgument(String value) {
    final separator = value.indexOf('=');
    if (separator < 0) {
      return _looksLikeCredentialLiteral(value) ? '' : value;
    }
    final name = value.substring(0, separator);
    if (_isCredentialEntryName(_normalizeName(name))) return '$name=';
    final rawValue = value.substring(separator + 1);
    return rawValue.contains('://')
        ? '$name=${_sanitizeCredentialUri(rawValue)}'
        : value;
  }

  static bool _isCredentialEntryName(String normalizedKey) {
    return normalizedKey == 'key' || _isCredentialQueryField(normalizedKey);
  }

  static bool _isCredentialValueField(String normalizedKey) {
    return _secretValueFields.any(normalizedKey.endsWith);
  }

  static bool _looksLikeCredentialLiteral(String value) {
    final trimmed = value.trim();
    final lower = trimmed.toLowerCase();
    return lower.startsWith('basic ') ||
        lower.startsWith('bearer ') ||
        trimmed.startsWith('AIza') ||
        trimmed.startsWith('sk-') ||
        RegExp(r'^AKIA[0-9A-Z]{12,}$').hasMatch(trimmed);
  }

  static String _sanitizeCredentialUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) throw const FormatException('credential_uri');
    var changed = uri.userInfo.isNotEmpty || uri.hasFragment;
    Map<String, dynamic>? queryParameters;
    if (uri.hasQuery) {
      queryParameters = <String, dynamic>{};
      for (final entry in uri.queryParametersAll.entries) {
        if (_isCredentialQueryField(_normalizeName(entry.key))) {
          queryParameters[entry.key] = entry.value.length <= 1
              ? ''
              : List<String>.filled(entry.value.length, '');
          changed = true;
        } else {
          queryParameters[entry.key] = entry.value;
        }
      }
    }
    if (!changed) return value;
    final sanitized = uri
        .replace(userInfo: '', queryParameters: queryParameters)
        .toString();
    final fragmentStart = sanitized.indexOf('#');
    return fragmentStart < 0
        ? sanitized
        : sanitized.substring(0, fragmentStart);
  }

  static bool _isCredentialQueryField(String normalizedKey) {
    const additionalCredentialFields = {
      'accesskey',
      'auth',
      'credential',
      'googleaccessid',
      'key',
      'policy',
      'sig',
      'signature',
      'subscriptionkey',
    };
    return additionalCredentialFields.contains(normalizedKey) ||
        normalizedKey.endsWith('credential') ||
        normalizedKey.endsWith('signature') ||
        _isCredentialValueField(normalizedKey);
  }

  static Map<String, dynamic> _object(dynamic value, String preferenceKey) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException(preferenceKey);
    }
    return value.cast<String, dynamic>();
  }

  static List<Map<String, dynamic>> _objectList(
    dynamic value,
    String preferenceKey,
  ) {
    if (value is! List) throw FormatException(preferenceKey);
    return [for (final item in value) _object(item, preferenceKey)];
  }

  static dynamic _emptyPreferenceCredential(String key, dynamic value) {
    if (value is String) return '';
    if (value is List && value.every((item) => item is String)) {
      return <String>[];
    }
    if (value is bool) return false;
    if (value is int) return 0;
    if (value is double) return 0.0;
    throw FormatException(key);
  }

  static dynamic _emptyJsonCredential(String key, dynamic value) {
    if (value == null) return null;
    if (value is String) return '';
    if (value is List) return <dynamic>[];
    if (value is Map) return <String, dynamic>{};
    throw FormatException(key);
  }

  static String _normalizeName(String value) =>
      value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
}
