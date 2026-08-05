import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../models/backup.dart';
import 'backup_provider.dart';

class BackupReminderProvider extends ChangeNotifier {
  BackupReminderProvider({
    required this.preferences,
    this.backupProvider,
    this.webDavConfig,
    bool autoLoad = true,
  }) {
    if (autoLoad) {
      unawaited(load());
    }
  }

  static const List<int> presetIntervals = [1, 3, 7, 14, 30];

  static const String _enabledKey = 'backup_reminder_enabled_v1';
  static const String _intervalDaysKey = 'backup_reminder_interval_days_v1';
  static const String _minutesOfDayKey = 'backup_reminder_minutes_of_day_v1';
  static const String _enabledAtKey = 'backup_reminder_enabled_at_v1';
  static const String _lastBackupAtKey = 'backup_reminder_last_backup_at_v1';
  static const String _autoEnabledKey = 'backup_auto_enabled_v1';
  static const String _autoIntervalDaysKey = 'backup_auto_interval_days_v1';
  static const String _autoMinutesOfDayKey = 'backup_auto_minutes_of_day_v1';
  static const String _autoEnabledAtKey = 'backup_auto_enabled_at_v1';
  static const String _autoLastBackupAtKey = 'backup_auto_last_backup_at_v1';

  final BusinessPreferences preferences;
  final BackupProvider? backupProvider;
  WebDavConfig? webDavConfig;
  bool _loaded = false;
  bool _enabled = false;
  int _intervalDays = 7;
  int? _reminderMinutesOfDay;
  DateTime? _enabledAt;
  DateTime? _lastBackupAt;
  bool _snoozedForSession = false;
  bool _shouldShowReminder = false;

  bool _autoEnabled = false;
  int _autoIntervalDays = 7;
  int? _autoMinutesOfDay;
  DateTime? _autoEnabledAt;
  DateTime? _autoLastBackupAt;
  bool _autoBackupInProgress = false;
  Timer? _timer;

  bool get loaded => _loaded;
  bool get enabled => _enabled;
  int get intervalDays => _intervalDays;
  int? get reminderMinutesOfDay => _reminderMinutesOfDay;
  DateTime? get enabledAt => _enabledAt;
  DateTime? get lastBackupAt => _lastBackupAt;
  bool get shouldShowReminder => _shouldShowReminder;

  bool get autoEnabled => _autoEnabled;
  int get autoIntervalDays => _autoIntervalDays;
  int? get autoMinutesOfDay => _autoMinutesOfDay;
  DateTime? get autoEnabledAt => _autoEnabledAt;
  DateTime? get autoLastBackupAt => _autoLastBackupAt;

  DateTime? get nextReminderAt {
    if (!_enabled || _reminderMinutesOfDay == null) return null;
    final anchor = _lastBackupAt ?? _enabledAt;
    if (anchor == null) return null;
    return _dateWithTime(
      DateTime(anchor.year, anchor.month, anchor.day + _intervalDays),
      _reminderMinutesOfDay!,
    );
  }

  DateTime? get nextAutoBackupAt {
    if (!_autoEnabled || _autoMinutesOfDay == null) return null;
    final anchor = _autoLastBackupAt ?? _autoEnabledAt;
    if (anchor == null) return null;
    return _dateWithTime(
      DateTime(anchor.year, anchor.month, anchor.day + _autoIntervalDays),
      _autoMinutesOfDay!,
    );
  }

  Future<void> load({bool startTimer = true}) async {
    await preferences.load();
    _enabled = preferences.getBool(_enabledKey) ?? false;
    _intervalDays = _normalizeIntervalDays(
      preferences.getInt(_intervalDaysKey) ?? 7,
    );
    _reminderMinutesOfDay = _normalizeMinutesOfDay(
      preferences.getInt(_minutesOfDayKey),
    );
    _enabledAt = _parseDate(preferences.getString(_enabledAtKey));
    _lastBackupAt = _parseDate(preferences.getString(_lastBackupAtKey));

    _autoEnabled = preferences.getBool(_autoEnabledKey) ?? false;
    _autoIntervalDays = _normalizeIntervalDays(
      preferences.getInt(_autoIntervalDaysKey) ?? 7,
    );
    _autoMinutesOfDay = _normalizeMinutesOfDay(
      preferences.getInt(_autoMinutesOfDayKey),
    );
    _autoEnabledAt = _parseDate(preferences.getString(_autoEnabledAtKey));
    _autoLastBackupAt = _parseDate(
      preferences.getString(_autoLastBackupAtKey),
    );

    _loaded = true;
    evaluateDue(DateTime.now(), notify: false);
    if (startTimer) _startTimer();
    notifyListeners();
  }

  Future<void> saveSchedule({
    required bool enabled,
    required int intervalDays,
    required int reminderMinutesOfDay,
    DateTime? now,
  }) async {
    final normalizedInterval = _validateIntervalDays(intervalDays);
    final normalizedMinutes = _validateMinutesOfDay(reminderMinutesOfDay);
    final currentTime = now ?? DateTime.now();
    final wasEnabled = _enabled;

    _enabled = enabled;
    _intervalDays = normalizedInterval;
    _reminderMinutesOfDay = normalizedMinutes;
    if (enabled && (!wasEnabled || _enabledAt == null)) {
      _enabledAt = currentTime;
    }
    if (!enabled) {
      _snoozedForSession = false;
      _shouldShowReminder = false;
    }

    await _persist();
    evaluateDue(currentTime, notify: false);
    notifyListeners();
  }

  Future<void> setEnabled(bool value, {DateTime? now}) async {
    if (value) {
      final minutes = _reminderMinutesOfDay;
      if (minutes == null) {
        throw StateError('Reminder time must be selected before enabling.');
      }
      await saveSchedule(
        enabled: true,
        intervalDays: _intervalDays,
        reminderMinutesOfDay: minutes,
        now: now,
      );
      return;
    }

    _enabled = false;
    _snoozedForSession = false;
    _shouldShowReminder = false;
    await _persist();
    notifyListeners();
  }

  Future<void> recordBackupCompleted({DateTime? now}) async {
    _lastBackupAt = now ?? DateTime.now();
    _snoozedForSession = false;
    await _persist();
    evaluateDue(_lastBackupAt!, notify: false);
    notifyListeners();
  }

  Future<void> saveAutoBackupSchedule({
    required bool enabled,
    required int intervalDays,
    required int reminderMinutesOfDay,
    DateTime? now,
  }) async {
    final normalizedInterval = _validateIntervalDays(intervalDays);
    final normalizedMinutes = _validateMinutesOfDay(reminderMinutesOfDay);
    final currentTime = now ?? DateTime.now();
    final wasEnabled = _autoEnabled;

    _autoEnabled = enabled;
    _autoIntervalDays = normalizedInterval;
    _autoMinutesOfDay = normalizedMinutes;
    if (enabled && !wasEnabled) {
      _autoEnabledAt = currentTime;
    }

    await _persistAuto();
    notifyListeners();
  }

  Future<void> setAutoEnabled(bool value, {DateTime? now}) async {
    if (value) {
      final minutes = _autoMinutesOfDay;
      if (minutes == null) {
        throw StateError('Auto backup time must be selected before enabling.');
      }
      await saveAutoBackupSchedule(
        enabled: true,
        intervalDays: _autoIntervalDays,
        reminderMinutesOfDay: minutes,
        now: now,
      );
      return;
    }

    _autoEnabled = false;
    await _persistAuto();
    notifyListeners();
  }

  Future<void> recordAutoBackupCompleted({DateTime? now}) async {
    _autoLastBackupAt = now ?? DateTime.now();
    await _persistAuto();
    notifyListeners();
  }

  void evaluateDue(DateTime now, {bool notify = true}) {
    final next = nextReminderAt;
    final nextShouldShow =
        _enabled && !_snoozedForSession && next != null && !now.isBefore(next);
    if (_shouldShowReminder != nextShouldShow) {
      _shouldShowReminder = nextShouldShow;
      if (notify) notifyListeners();
    }

    _triggerAutoBackupIfDue(now);
  }

  void _triggerAutoBackupIfDue(DateTime now) {
    if (!_autoEnabled || _autoMinutesOfDay == null) return;
    if (_autoBackupInProgress) return;
    final bp = backupProvider;
    final cfg = webDavConfig;
    if (bp == null || cfg == null) return;
    if (cfg.url.trim().isEmpty) return;

    final next = nextAutoBackupAt;
    if (next == null) return;
    if (now.isBefore(next)) return;

    _autoBackupInProgress = true;
    unawaited(() async {
      try {
        final success = await bp.silentBackup();
        if (success) {
          await recordAutoBackupCompleted(now: DateTime.now());
        }
      } finally {
        _autoBackupInProgress = false;
      }
    }());
  }

  void snoozeForSession() {
    if (!_shouldShowReminder && _snoozedForSession) return;
    _snoozedForSession = true;
    _shouldShowReminder = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _persist() async {
    await preferences.setBool(_enabledKey, _enabled);
    await preferences.setInt(_intervalDaysKey, _intervalDays);
    if (_reminderMinutesOfDay == null) {
      await preferences.remove(_minutesOfDayKey);
    } else {
      await preferences.setInt(_minutesOfDayKey, _reminderMinutesOfDay!);
    }
    await _setDate(_enabledAtKey, _enabledAt);
    await _setDate(_lastBackupAtKey, _lastBackupAt);
  }

  Future<void> _persistAuto() async {
    await preferences.setBool(_autoEnabledKey, _autoEnabled);
    await preferences.setInt(_autoIntervalDaysKey, _autoIntervalDays);
    if (_autoMinutesOfDay == null) {
      await preferences.remove(_autoMinutesOfDayKey);
    } else {
      await preferences.setInt(_autoMinutesOfDayKey, _autoMinutesOfDay!);
    }
    await _setDate(_autoEnabledAtKey, _autoEnabledAt);
    await _setDate(_autoLastBackupAtKey, _autoLastBackupAt);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      evaluateDue(DateTime.now());
    });
  }

  DateTime _dateWithTime(DateTime date, int minutesOfDay) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
  }

  static int _validateIntervalDays(int value) {
    if (value < 1 || value > 365) {
      throw ArgumentError.value(value, 'intervalDays', 'Must be 1-365.');
    }
    return value;
  }

  static int _normalizeIntervalDays(int value) {
    if (value < 1) return 1;
    if (value > 365) return 365;
    return value;
  }

  static int _validateMinutesOfDay(int value) {
    if (value < 0 || value >= 24 * 60) {
      throw ArgumentError.value(
        value,
        'reminderMinutesOfDay',
        'Must be in a day.',
      );
    }
    return value;
  }

  static int? _normalizeMinutesOfDay(int? value) {
    if (value == null) return null;
    if (value < 0 || value >= 24 * 60) return null;
    return value;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _setDate(String key, DateTime? value) async {
    if (value == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, value.toIso8601String());
    }
  }
}
