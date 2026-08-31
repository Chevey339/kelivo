import '../../database/business_preferences.dart';
import 'local_snapshot_retention.dart';
import 'local_snapshot_schedule.dart';

/// What the user chose about automatic local copies.
final class LocalSnapshotSettings {
  const LocalSnapshotSettings({
    this.enabled = true,
    this.intervalDays = automaticInterval,
    this.keepRecent = 3,
    this.keepWeekly = true,
    this.keepMonthly = true,
    this.maximumTotalBytes = defaultMaximumTotalBytes,
    this.announceResult = false,
  });

  /// Let the interval follow the database size instead of a fixed number.
  static const automaticInterval = 0;

  static const intervalPresets = <int>[automaticInterval, 1, 3, 7, 14, 30];
  static const minimumKeepRecent = 1;
  static const maximumKeepRecent = 10;

  /// Generous on purpose: a heavy user's database is text-only but can still
  /// reach a gigabyte, and the retention slots already bound the count. This
  /// is the backstop, not the primary control.
  static const defaultMaximumTotalBytes = 10 * 1024 * 1024 * 1024;

  static const totalBytesPresets = <int>[
    0,
    1024 * 1024 * 1024,
    2 * 1024 * 1024 * 1024,
    5 * 1024 * 1024 * 1024,
    defaultMaximumTotalBytes,
    20 * 1024 * 1024 * 1024,
  ];

  final bool enabled;
  final int intervalDays;
  final int keepRecent;
  final bool keepWeekly;
  final bool keepMonthly;

  /// Zero means the retention slots alone bound the set.
  final int maximumTotalBytes;

  /// Whether a finished automatic copy says so. Off by default: a copy that
  /// worked is not news. Failures are reported either way.
  final bool announceResult;

  LocalSnapshotRetentionPolicy get retention => LocalSnapshotRetentionPolicy(
    keepRecent: keepRecent.clamp(minimumKeepRecent, maximumKeepRecent),
    keepWeekly: keepWeekly,
    keepMonthly: keepMonthly,
    maximumTotalBytes: maximumTotalBytes < 0 ? 0 : maximumTotalBytes,
  );

  Duration intervalFor(int databaseBytes) => intervalDays <= automaticInterval
      ? LocalSnapshotSchedule.defaultIntervalFor(databaseBytes)
      : Duration(days: intervalDays);

  LocalSnapshotSettings copyWith({
    bool? enabled,
    int? intervalDays,
    int? keepRecent,
    bool? keepWeekly,
    bool? keepMonthly,
    int? maximumTotalBytes,
    bool? announceResult,
  }) => LocalSnapshotSettings(
    enabled: enabled ?? this.enabled,
    intervalDays: intervalDays ?? this.intervalDays,
    keepRecent: keepRecent ?? this.keepRecent,
    keepWeekly: keepWeekly ?? this.keepWeekly,
    keepMonthly: keepMonthly ?? this.keepMonthly,
    maximumTotalBytes: maximumTotalBytes ?? this.maximumTotalBytes,
    announceResult: announceResult ?? this.announceResult,
  );
}

/// What happened last time, so the settings screen can say so.
final class LocalSnapshotState {
  const LocalSnapshotState({
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastFailureMessage,
    this.lastSkipReason,
    this.failureStreak = 0,
    this.fingerprint,
    this.firstObservedAt,
  });

  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final String? lastFailureMessage;
  final LocalSnapshotSkipReason? lastSkipReason;
  final int failureStreak;
  final DatabaseChangeFingerprint? fingerprint;

  /// When the schedule first ran on this install. Null until it has.
  final DateTime? firstObservedAt;

  /// Repeated failures back off well past the base window. A device that is
  /// simply full should be retried on the scale of hours, not minutes, and
  /// certainly not on every resume.
  Duration get failureBackoff {
    if (failureStreak <= 1) return LocalSnapshotSchedule.failureBackoff;
    final hours = 1 << (failureStreak - 1).clamp(0, 4);
    return Duration(hours: hours);
  }
}

/// Reads and writes both of the above through the app preference store.
final class LocalSnapshotPreferences {
  const LocalSnapshotPreferences(this._preferences);

  final BusinessPreferences _preferences;

  static const enabledKey = 'local_snapshot_enabled_v1';
  static const intervalDaysKey = 'local_snapshot_interval_days_v1';
  static const keepRecentKey = 'local_snapshot_keep_recent_v1';
  static const keepWeeklyKey = 'local_snapshot_keep_weekly_v1';
  static const keepMonthlyKey = 'local_snapshot_keep_monthly_v1';
  static const maximumTotalBytesKey = 'local_snapshot_max_total_bytes_v1';
  static const announceResultKey = 'local_snapshot_announce_v1';
  static const lastSuccessAtKey = 'local_snapshot_last_success_at_v1';
  static const lastFailureAtKey = 'local_snapshot_last_failure_at_v1';
  static const lastFailureMessageKey = 'local_snapshot_last_failure_v1';
  static const lastSkipReasonKey = 'local_snapshot_last_skip_v1';
  static const failureStreakKey = 'local_snapshot_failure_streak_v1';
  static const fingerprintKey = 'local_snapshot_fingerprint_v1';
  static const firstObservedAtKey = 'local_snapshot_first_observed_at_v1';

  LocalSnapshotSettings readSettings() {
    const defaults = LocalSnapshotSettings();
    return LocalSnapshotSettings(
      enabled: _preferences.getBool(enabledKey) ?? defaults.enabled,
      intervalDays: _normalizeInterval(_preferences.getInt(intervalDaysKey)),
      keepRecent: (_preferences.getInt(keepRecentKey) ?? defaults.keepRecent)
          .clamp(
            LocalSnapshotSettings.minimumKeepRecent,
            LocalSnapshotSettings.maximumKeepRecent,
          ),
      keepWeekly: _preferences.getBool(keepWeeklyKey) ?? defaults.keepWeekly,
      keepMonthly: _preferences.getBool(keepMonthlyKey) ?? defaults.keepMonthly,
      maximumTotalBytes: _normalizeTotalBytes(
        _preferences.getInt(maximumTotalBytesKey),
      ),
      announceResult:
          _preferences.getBool(announceResultKey) ?? defaults.announceResult,
    );
  }

  Future<void> writeSettings(LocalSnapshotSettings settings) async {
    await _preferences.setBool(enabledKey, settings.enabled);
    await _preferences.setInt(
      intervalDaysKey,
      _normalizeInterval(settings.intervalDays),
    );
    await _preferences.setInt(
      keepRecentKey,
      settings.keepRecent.clamp(
        LocalSnapshotSettings.minimumKeepRecent,
        LocalSnapshotSettings.maximumKeepRecent,
      ),
    );
    await _preferences.setBool(keepWeeklyKey, settings.keepWeekly);
    await _preferences.setBool(keepMonthlyKey, settings.keepMonthly);
    await _preferences.setInt(
      maximumTotalBytesKey,
      _normalizeTotalBytes(settings.maximumTotalBytes),
    );
    await _preferences.setBool(announceResultKey, settings.announceResult);
  }

  LocalSnapshotState readState() => LocalSnapshotState(
    lastSuccessAt: _parseDate(_preferences.getString(lastSuccessAtKey)),
    lastFailureAt: _parseDate(_preferences.getString(lastFailureAtKey)),
    lastFailureMessage: _preferences.getString(lastFailureMessageKey),
    lastSkipReason: LocalSnapshotSkipReason.values
        .where(
          (value) => value.name == _preferences.getString(lastSkipReasonKey),
        )
        .firstOrNull,
    failureStreak: _preferences.getInt(failureStreakKey) ?? 0,
    fingerprint: DatabaseChangeFingerprint.decode(
      _preferences.getString(fingerprintKey),
    ),
    firstObservedAt: _parseDate(_preferences.getString(firstObservedAtKey)),
  );

  Future<void> recordFirstObserved(DateTime at) =>
      _preferences.setString(firstObservedAtKey, at.toUtc().toIso8601String());

  Future<void> recordSuccess({
    required DateTime at,
    required DatabaseChangeFingerprint fingerprint,
  }) async {
    await _preferences.setString(
      lastSuccessAtKey,
      at.toUtc().toIso8601String(),
    );
    await _preferences.setString(fingerprintKey, fingerprint.encode());
    await _preferences.setInt(failureStreakKey, 0);
    await _preferences.remove(lastFailureAtKey);
    await _preferences.remove(lastFailureMessageKey);
    await _preferences.remove(lastSkipReasonKey);
  }

  Future<void> recordFailure({
    required DateTime at,
    required String message,
    required int previousStreak,
  }) async {
    await _preferences.setString(
      lastFailureAtKey,
      at.toUtc().toIso8601String(),
    );
    await _preferences.setString(lastFailureMessageKey, message);
    await _preferences.setInt(failureStreakKey, previousStreak + 1);
    await _preferences.remove(lastSkipReasonKey);
  }

  Future<void> recordSkip(LocalSnapshotSkipReason reason) =>
      _preferences.setString(lastSkipReasonKey, reason.name);

  /// Advances the change fingerprint without claiming a copy was written.
  ///
  /// Used when nothing changed since the last copy: re-checking the same
  /// unchanged database on every resume is wasted work, but the timestamp of
  /// the newest actual copy must not move, or the next real change would wait
  /// a whole interval longer than the user asked for.
  Future<void> recordUnchanged(DatabaseChangeFingerprint fingerprint) async {
    await _preferences.setString(fingerprintKey, fingerprint.encode());
    await _preferences.setString(
      lastSkipReasonKey,
      LocalSnapshotSkipReason.unchanged.name,
    );
  }

  static int _normalizeInterval(int? value) {
    if (value == null) return LocalSnapshotSettings.automaticInterval;
    if (value <= 0) return LocalSnapshotSettings.automaticInterval;
    if (value > 365) return 365;
    return value;
  }

  static int _normalizeTotalBytes(int? value) {
    if (value == null) return LocalSnapshotSettings.defaultMaximumTotalBytes;
    if (value < 0) return 0;
    return value;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
