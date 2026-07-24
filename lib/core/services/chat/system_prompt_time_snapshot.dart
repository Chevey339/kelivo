import 'dart:async';

/// The local time values used by system-prompt placeholders.
///
/// Both the date/time and timezone are captured together so every time-related
/// placeholder remains stable for the lifetime of the snapshot.
class SystemPromptTimeSnapshot {
  const SystemPromptTimeSnapshot({
    required this.localDateTime,
    required this.timezone,
  });

  final DateTime localDateTime;
  final String timezone;
}

typedef SystemPromptClock = DateTime Function();
typedef SystemPromptTimerScheduler = Timer Function(
  Duration delay,
  void Function() callback,
);
typedef SystemPromptTimezoneName = String Function(DateTime localDateTime);

/// Maintains an application-level time snapshot for system prompts.
///
/// A snapshot is stable within a local half-day and refreshes at local noon or
/// midnight. [current] also checks the boundary lazily, which covers suspended
/// applications and delayed timers.
class SystemPromptTimeSnapshotService {
  SystemPromptTimeSnapshotService({
    SystemPromptClock? clock,
    SystemPromptTimerScheduler? timerScheduler,
    SystemPromptTimezoneName? timezoneName,
  }) : _clock = clock ?? DateTime.now,
       _timerScheduler = timerScheduler ?? Timer.new,
       _timezoneName = timezoneName ?? ((value) => value.timeZoneName) {
    _snapshot = _capture(_clock());
  }

  static final SystemPromptTimeSnapshotService instance =
      SystemPromptTimeSnapshotService();

  final SystemPromptClock _clock;
  final SystemPromptTimerScheduler _timerScheduler;
  final SystemPromptTimezoneName _timezoneName;

  late SystemPromptTimeSnapshot _snapshot;
  Timer? _boundaryTimer;
  bool _initialized = false;

  /// Starts automatic noon/midnight refreshes.
  ///
  /// Calling this more than once is harmless.
  void initialize() {
    if (_initialized) {
      _refreshIfNeeded();
      return;
    }
    _initialized = true;
    _snapshot = _capture(_clock());
    _scheduleNextBoundary();
  }

  /// Returns the stable snapshot, refreshing first if a boundary was missed.
  SystemPromptTimeSnapshot get current {
    _refreshIfNeeded();
    return _snapshot;
  }

  void _refreshIfNeeded() {
    final now = _clock();
    if (_halfDayKey(now) == _halfDayKey(_snapshot.localDateTime)) return;

    _snapshot = _capture(now);
    if (_initialized) _scheduleNextBoundary();
  }

  SystemPromptTimeSnapshot _capture(DateTime now) {
    return SystemPromptTimeSnapshot(
      localDateTime: now,
      timezone: _timezoneName(now),
    );
  }

  void _scheduleNextBoundary() {
    _boundaryTimer?.cancel();

    final now = _clock();
    final nextBoundary = now.hour < 12
        ? DateTime(now.year, now.month, now.day, 12)
        : DateTime(now.year, now.month, now.day + 1);
    final delay = nextBoundary.difference(now);

    _boundaryTimer = _timerScheduler(delay, _handleBoundaryTimer);
  }

  void _handleBoundaryTimer() {
    _boundaryTimer = null;
    _refreshIfNeeded();
    if (_boundaryTimer == null && _initialized) _scheduleNextBoundary();
  }

  String _halfDayKey(DateTime value) {
    final half = value.hour < 12 ? 0 : 1;
    return '${value.year}-${value.month}-${value.day}-$half';
  }

  /// Stops the timer. Intended for tests and process teardown.
  void dispose() {
    _initialized = false;
    _boundaryTimer?.cancel();
    _boundaryTimer = null;
  }
}
