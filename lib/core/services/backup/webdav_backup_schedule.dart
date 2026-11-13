import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local policy. Restoring someone else's backup must not turn this on.
final class WebDavBackupScheduleSettings {
  const WebDavBackupScheduleSettings({
    this.enabled = false,
    this.intervalHours = 24,
    this.wifiOnly = true,
    this.enabledAt,
  });

  static const intervalPresets = <int>[1, 6, 12, 24, 72, 168];

  final bool enabled;
  final int intervalHours;
  final bool wifiOnly;
  final DateTime? enabledAt;

  WebDavBackupScheduleSettings copyWith({
    bool? enabled,
    int? intervalHours,
    bool? wifiOnly,
    DateTime? enabledAt,
  }) => WebDavBackupScheduleSettings(
    enabled: enabled ?? this.enabled,
    intervalHours: intervalHours ?? this.intervalHours,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    enabledAt: enabledAt ?? this.enabledAt,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'intervalHours': intervalHours,
    'wifiOnly': wifiOnly,
    'enabledAt': enabledAt?.toUtc().toIso8601String(),
  };

  factory WebDavBackupScheduleSettings.fromJson(Map<String, dynamic> json) =>
      WebDavBackupScheduleSettings(
        enabled: json['enabled'] == true,
        intervalHours:
            json['intervalHours'] is int &&
                intervalPresets.contains(json['intervalHours'])
            ? json['intervalHours'] as int
            : 24,
        wifiOnly: json['wifiOnly'] != false,
        enabledAt: _date(json['enabledAt']),
      );
}

final class WebDavBackupScheduleState {
  const WebDavBackupScheduleState({
    this.lastAttempt,
    this.lastSuccess,
    this.lastError,
  });

  final DateTime? lastAttempt;
  final DateTime? lastSuccess;
  final String? lastError;

  Map<String, Object?> toJson() => {
    'lastAttempt': lastAttempt?.toUtc().toIso8601String(),
    'lastSuccess': lastSuccess?.toUtc().toIso8601String(),
    'lastError': lastError,
  };

  factory WebDavBackupScheduleState.fromJson(Map<String, dynamic> json) =>
      WebDavBackupScheduleState(
        lastAttempt: _date(json['lastAttempt']),
        lastSuccess: _date(json['lastSuccess']),
        lastError: json['lastError'] is String
            ? json['lastError'] as String
            : null,
      );
}

/// Uncached preferences are important: WorkManager has a different Dart engine.
/// Settings and outcomes have separate keys so a finishing worker cannot undo
/// a schedule the user has just changed or disabled.
class WebDavBackupScheduleStore {
  WebDavBackupScheduleStore({SharedPreferencesAsync? preferences})
    : _providedPreferences = preferences;

  final SharedPreferencesAsync? _providedPreferences;
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();
  static const settingsKey = 'webdav_backup_schedule_device_v1';
  static const stateKey = 'webdav_backup_schedule_state_device_v1';

  Future<WebDavBackupScheduleSettings> readSettings() async =>
      WebDavBackupScheduleSettings.fromJson(
        _decode(await _preferences.getString(settingsKey)),
      );

  Future<void> writeSettings(WebDavBackupScheduleSettings settings) =>
      _preferences.setString(settingsKey, jsonEncode(settings.toJson()));

  Future<WebDavBackupScheduleState> readState() async =>
      WebDavBackupScheduleState.fromJson(
        _decode(await _preferences.getString(stateKey)),
      );

  Future<void> writeState(WebDavBackupScheduleState state) =>
      _preferences.setString(stateKey, jsonEncode(state.toJson()));

  static Map<String, dynamic> _decode(String? value) {
    if (value == null) return const {};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}

final class WebDavBackupSchedule {
  WebDavBackupSchedule._();

  static const failureRetryDelay = Duration(minutes: 15);

  static DateTime? nextRunAt(
    WebDavBackupScheduleSettings settings,
    WebDavBackupScheduleState state,
  ) {
    if (!settings.enabled || settings.enabledAt == null) return null;
    var anchor = settings.enabledAt!;
    final success = state.lastSuccess;
    if (success != null && success.isAfter(anchor)) anchor = success;
    var due = anchor.add(Duration(hours: settings.intervalHours));
    final attempt = state.lastAttempt;
    if (state.lastError != null && attempt != null) {
      final retry = attempt.add(failureRetryDelay);
      if (retry.isAfter(due)) due = retry;
    }
    return due;
  }

  static bool isDue(
    WebDavBackupScheduleSettings settings,
    WebDavBackupScheduleState state,
    DateTime now,
  ) {
    final due = nextRunAt(settings, state);
    return due != null && !now.isBefore(due);
  }

  static Future<bool> networkAvailable(bool wifiOnly) async {
    final connections = await Connectivity().checkConnectivity();
    if (wifiOnly) {
      return connections.contains(ConnectivityResult.wifi) ||
          connections.contains(ConnectivityResult.ethernet);
    }
    return connections.any((value) => value != ConnectivityResult.none);
  }

  /// Keep provider credentials and remote URLs out of persistent error text.
  static String safeError(Object error) {
    if (error is FormatException &&
        error.message == 'backup_password_required') {
      return 'backup_password_required';
    }
    var message = error.toString().replaceAll(
      RegExp(r'https?://[^\s\x27\x22<>]+', caseSensitive: false),
      '[server]',
    );
    message = message.replaceAll(RegExp(r'Basic\s+[A-Za-z0-9+/=]+'), '[auth]');
    return message.length > 300 ? message.substring(0, 300) : message;
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
