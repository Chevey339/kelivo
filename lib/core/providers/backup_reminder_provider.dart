import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupReminderProvider extends ChangeNotifier {
  BackupReminderProvider({bool autoLoad = true}) {
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

  bool _loaded = false;
  bool _enabled = false;
  int _intervalDays = 7;
  int? _reminderMinutesOfDay;
  DateTime? _enabledAt;
  DateTime? _lastBackupAt;
  bool _snoozedForSession = false;
  bool _shouldShowReminder = false;
  Timer? _timer;

  bool get loaded => _loaded;
  bool get enabled => _enabled;
  int get intervalDays => _intervalDays;
  int? get reminderMinutesOfDay => _reminderMinutesOfDay;
  DateTime? get enabledAt => _enabledAt;
  DateTime? get lastBackupAt => _lastBackupAt;
  bool get shouldShowReminder => _shouldShowReminder;

  DateTime? get nextReminderAt {
    if (!_enabled || _reminderMinutesOfDay == null) return null;
    final anchor = _lastBackupAt ?? _enabledAt;
    if (anchor == null) return null;
    return _dateWithReminderTime(
      DateTime(anchor.year, anchor.month, anchor.day + _intervalDays),
    );
  }

  Future<void> load({bool startTimer = true}) async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _intervalDays = _normalizeIntervalDays(prefs.getInt(_intervalDaysKey) ?? 7);
    _reminderMinutesOfDay = _normalizeMinutesOfDay(
      prefs.getInt(_minutesOfDayKey),
    );
    _enabledAt = _parseDate(prefs.getString(_enabledAtKey));
    _lastBackupAt = _parseDate(prefs.getString(_lastBackupAtKey));
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

  void evaluateDue(DateTime now, {bool notify = true}) {
    final next = nextReminderAt;
    final nextShouldShow =
        _enabled && !_snoozedForSession && next != null && !now.isBefore(next);
    if (_shouldShowReminder == nextShouldShow) return;
    _shouldShowReminder = nextShouldShow;
    if (notify) notifyListeners();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _enabled);
    await prefs.setInt(_intervalDaysKey, _intervalDays);
    if (_reminderMinutesOfDay == null) {
      await prefs.remove(_minutesOfDayKey);
    } else {
      await prefs.setInt(_minutesOfDayKey, _reminderMinutesOfDay!);
    }
    await _setDate(prefs, _enabledAtKey, _enabledAt);
    await _setDate(prefs, _lastBackupAtKey, _lastBackupAt);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      evaluateDue(DateTime.now());
    });
  }

  DateTime _dateWithReminderTime(DateTime date) {
    final minutes = _reminderMinutesOfDay!;
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
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

  static Future<void> _setDate(
    SharedPreferences prefs,
    String key,
    DateTime? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value.toIso8601String());
    }
  }
}
