import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SyncMetadata {
  static const String _deviceIdKey = 'sync_device_id_v1';
  static const String _deviceNameKey = 'sync_device_name_v1';
  static const String _lastSyncAtKey = 'sync_last_sync_at_v1';
  static const String _enabledKey = 'sync_enabled_v1';
  static const String _backendChoiceKey = 'sync_backend_v1'; // 'webdav' or 's3'
  static const String _pullIntervalKey = 'sync_pull_interval_seconds_v1';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    return _prefs!;
  }

  String get deviceId {
    final existing = _p.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    _p.setString(_deviceIdKey, id);
    return id;
  }

  String get deviceName {
    final existing = _p.getString(_deviceNameKey);
    if (existing != null && existing.isNotEmpty) return existing;
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Unknown';
    }
  }

  set deviceName(String name) {
    if (name.trim().isEmpty) return;
    _p.setString(_deviceNameKey, name.trim());
  }

  int? get lastSyncAt {
    final val = _p.getInt(_lastSyncAtKey);
    return val != null && val > 0 ? val : null;
  }

  set lastSyncAt(int? millis) {
    if (millis != null) {
      _p.setInt(_lastSyncAtKey, millis);
    } else {
      _p.remove(_lastSyncAtKey);
    }
  }

  bool get enabled => _p.getBool(_enabledKey) ?? false;

  set enabled(bool value) {
    _p.setBool(_enabledKey, value);
  }

  String? get backendChoice => _p.getString(_backendChoiceKey);

  set backendChoice(String? value) {
    if (value != null) {
      _p.setString(_backendChoiceKey, value);
    } else {
      _p.remove(_backendChoiceKey);
    }
  }

  int get pullIntervalSeconds => _p.getInt(_pullIntervalKey) ?? 300;

  set pullIntervalSeconds(int seconds) {
    _p.setInt(_pullIntervalKey, seconds.clamp(60, 3600));
  }
}
