import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup/backup_settings_sanitizer.dart';

/// Stores only credential leaves in platform secure storage while keeping the
/// non-secret configuration shape in SharedPreferences.
final class SecureCredentialStore {
  const SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _prefix = 'kelivo.credentials.v1.';
  static final Map<String, String> _missingPluginFallback = {};

  Future<String?> readProtectedJson(
    SharedPreferences preferences,
    String preferenceKey,
  ) async {
    final raw = preferences.getString(preferenceKey);
    if (raw == null || raw.isEmpty) return raw;
    final secureKey = '${_prefix}json.$preferenceKey';
    var overlayRaw = await _read(secureKey);
    if (overlayRaw == null) {
      await writeProtectedJson(preferences, preferenceKey, raw);
      overlayRaw = await _read(secureKey);
    }
    if (overlayRaw == null || overlayRaw.isEmpty) {
      return preferences.getString(preferenceKey);
    }
    final sanitizedRaw = preferences.getString(preferenceKey) ?? raw;
    final value = jsonDecode(sanitizedRaw);
    final overlay = jsonDecode(overlayRaw);
    if (overlay is! List) throw const FormatException('credential_overlay');
    for (final entry in overlay) {
      if (entry is! Map || entry['path'] is! List) {
        throw const FormatException('credential_overlay');
      }
      _setPath(
        value,
        (entry['path'] as List).toList(growable: false),
        entry['value'],
      );
    }
    return jsonEncode(value);
  }

  Future<void> writeProtectedJson(
    SharedPreferences preferences,
    String preferenceKey,
    String rawJson,
  ) async {
    final original = jsonDecode(rawJson);
    final sanitizedRaw = BackupSettingsSanitizer.sanitize({
      preferenceKey: rawJson,
    })[preferenceKey];
    if (sanitizedRaw is! String) {
      throw const FormatException('credential_json');
    }
    final sanitized = jsonDecode(sanitizedRaw);
    final overlay = <Map<String, Object?>>[];
    _collectDifferences(original, sanitized, const [], overlay);
    final secureKey = '${_prefix}json.$preferenceKey';
    if (overlay.isEmpty) {
      await _delete(secureKey);
    } else {
      await _write(secureKey, jsonEncode(overlay));
    }
    final persisted = await preferences.setString(preferenceKey, sanitizedRaw);
    if (!persisted) throw StateError(preferenceKey);
  }

  Future<String> readSecret(
    SharedPreferences preferences,
    String preferenceKey,
  ) async {
    final secureKey = '${_prefix}value.$preferenceKey';
    final secured = await _read(secureKey);
    if (secured != null) return secured;
    final legacy = preferences.getString(preferenceKey) ?? '';
    if (legacy.isNotEmpty) {
      await _write(secureKey, legacy);
    }
    await preferences.remove(preferenceKey);
    return legacy;
  }

  Future<void> writeSecret(
    SharedPreferences preferences,
    String preferenceKey,
    String value,
  ) async {
    final secureKey = '${_prefix}value.$preferenceKey';
    if (value.isEmpty) {
      await _delete(secureKey);
    } else {
      await _write(secureKey, value);
    }
    await preferences.remove(preferenceKey);
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return _missingPluginFallback[key];
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      // Unit-test and unsupported-runner fallback remains memory-only. Never
      // fall back to plaintext preferences.
      _missingPluginFallback[key] = value;
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      _missingPluginFallback.remove(key);
    }
  }

  static void _collectDifferences(
    Object? original,
    Object? sanitized,
    List<Object> path,
    List<Map<String, Object?>> out,
  ) {
    if (original is Map && sanitized is Map) {
      for (final entry in original.entries) {
        _collectDifferences(entry.value, sanitized[entry.key], [
          ...path,
          entry.key.toString(),
        ], out);
      }
      return;
    }
    if (original is List && sanitized is List) {
      for (var index = 0; index < original.length; index++) {
        _collectDifferences(
          original[index],
          index < sanitized.length ? sanitized[index] : null,
          [...path, index],
          out,
        );
      }
      return;
    }
    if (jsonEncode(original) != jsonEncode(sanitized)) {
      out.add({'path': path, 'value': original});
    }
  }

  static void _setPath(Object? root, List<dynamic> path, Object? value) {
    if (path.isEmpty) throw const FormatException('credential_overlay_path');
    Object? cursor = root;
    for (var index = 0; index < path.length - 1; index++) {
      final segment = path[index];
      cursor = switch ((cursor, segment)) {
        (Map map, String key) => map[key],
        (List list, int item) when item >= 0 && item < list.length =>
          list[item],
        _ => throw const FormatException('credential_overlay_path'),
      };
    }
    final last = path.last;
    switch ((cursor, last)) {
      case (Map map, String key):
        map[key] = value;
      case (List list, int item) when item >= 0 && item < list.length:
        list[item] = value;
      default:
        throw const FormatException('credential_overlay_path');
    }
  }
}
