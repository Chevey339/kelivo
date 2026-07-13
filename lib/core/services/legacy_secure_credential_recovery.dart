import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup/backup_settings_sanitizer.dart';

/// Recovers credentials moved out of SharedPreferences by an unreleased
/// secure-storage experiment.
///
/// Current builds keep these values in SharedPreferences so they participate
/// in backup and restore. This bridge only reads the old overlay, persists the
/// recovered values, and then removes the obsolete secure-storage entries.
final class LegacySecureCredentialRecovery {
  const LegacySecureCredentialRecovery({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(
              accessibility: null,
              usesDataProtectionKeychain: false,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _prefix = 'kelivo.credentials.v1.';
  static const _protectedJsonKeys = <String>[
    'provider_configs_v1',
    'search_services_v1',
    'tts_services_v1',
    'webdav_config_v1',
    's3_config_v1',
  ];
  static const _secretValueKeys = <String>['global_proxy_password_v1'];

  Future<bool> recover(SharedPreferences preferences) async {
    final recovered = <String, String>{};
    final obsoleteSecureKeys = <String>[];

    for (final preferenceKey in _protectedJsonKeys) {
      final secureKey = '${_prefix}json.$preferenceKey';
      final overlayRaw = await _read(secureKey);
      if (overlayRaw == null || overlayRaw.isEmpty) continue;
      obsoleteSecureKeys.add(secureKey);

      final raw = preferences.getString(preferenceKey);
      if (raw == null || raw.isEmpty) continue;
      recovered[preferenceKey] = _applyOverlayWithoutOverwritingNewSecrets(
        preferenceKey: preferenceKey,
        raw: raw,
        overlayRaw: overlayRaw,
      );
    }

    for (final preferenceKey in _secretValueKeys) {
      final secureKey = '${_prefix}value.$preferenceKey';
      final value = await _read(secureKey);
      if (value == null) continue;
      obsoleteSecureKeys.add(secureKey);
      final current = preferences.getString(preferenceKey) ?? '';
      if (current.isEmpty) recovered[preferenceKey] = value;
    }

    for (final entry in recovered.entries) {
      if (!await preferences.setString(entry.key, entry.value)) {
        throw StateError('legacy_credential_recovery:${entry.key}');
      }
    }
    for (final secureKey in obsoleteSecureKeys) {
      await _delete(secureKey);
    }
    return recovered.isNotEmpty;
  }

  static String _applyOverlayWithoutOverwritingNewSecrets({
    required String preferenceKey,
    required String raw,
    required String overlayRaw,
  }) {
    final value = jsonDecode(raw);
    final sanitizedRaw = BackupSettingsSanitizer.sanitize({
      preferenceKey: raw,
    })[preferenceKey];
    if (sanitizedRaw is! String) throw FormatException(preferenceKey);
    final sanitized = jsonDecode(sanitizedRaw);
    final overlay = jsonDecode(overlayRaw);
    if (overlay is! List) throw const FormatException('credential_overlay');

    for (final entry in overlay) {
      if (entry is! Map || entry['path'] is! List) {
        throw const FormatException('credential_overlay');
      }
      final path = (entry['path'] as List).toList(growable: false);
      final currentLeaf = _readPath(value, path);
      final sanitizedLeaf = _readPath(sanitized, path);
      // A value that differs from its sanitized form was entered after the
      // experiment was removed and is newer than the old overlay.
      if (jsonEncode(currentLeaf) != jsonEncode(sanitizedLeaf)) continue;
      _setPath(value, path, entry['value']);
    }
    return jsonEncode(value);
  }

  static Object? _readPath(Object? root, List<dynamic> path) {
    Object? cursor = root;
    for (final segment in path) {
      cursor = switch ((cursor, segment)) {
        (Map map, String key) when map.containsKey(key) => map[key],
        (List list, int index) when index >= 0 && index < list.length =>
          list[index],
        _ => throw const FormatException('credential_overlay_path'),
      };
    }
    return cursor;
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
    switch ((cursor, path.last)) {
      case (Map map, String key):
        map[key] = value;
      case (List list, int item) when item >= 0 && item < list.length:
        list[item] = value;
      default:
        throw const FormatException('credential_overlay_path');
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      if (_requiresMacOsLoginKeychainFallback(error)) {
        return _MacOsLoginKeychain.read(key);
      }
      rethrow;
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      if (_requiresMacOsLoginKeychainFallback(error)) {
        await _MacOsLoginKeychain.delete(key);
        return;
      }
      rethrow;
    }
  }

  static bool _requiresMacOsLoginKeychainFallback(PlatformException error) =>
      Platform.isMacOS &&
      (error.details == -34018 ||
          error.message?.contains('-34018') == true ||
          error.message?.contains('entitlement') == true);
}

abstract final class _MacOsLoginKeychain {
  static const _service = 'psyche.kelivo.credentials.v1';
  static const _executable = '/usr/bin/security';

  static Future<String?> read(String key) async {
    final result = await Process.run(_executable, [
      'find-generic-password',
      '-a',
      key,
      '-s',
      _service,
      '-w',
    ]);
    if (result.exitCode == 44) return null;
    if (result.exitCode != 0) throw StateError('macos_keychain_read');
    final encoded = (result.stdout as String).trim();
    try {
      return utf8.decode(base64Decode(encoded));
    } on FormatException {
      throw StateError('macos_keychain_value');
    }
  }

  static Future<void> delete(String key) async {
    final result = await Process.run(_executable, [
      'delete-generic-password',
      '-a',
      key,
      '-s',
      _service,
    ]);
    if (result.exitCode != 0 && result.exitCode != 44) {
      throw StateError('macos_keychain_delete');
    }
  }
}
