import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/scheduled_task.dart';
import 'desktop_power_state.dart';
import 'scheduled_task_schedule.dart';
import 'scheduled_task_store.dart';

/// Device-local schedules. No OS alarms, launch agents or startup registration.
/// Only an attached, running app can dispatch a future occurrence.
class DesktopScheduledTasks extends ChangeNotifier {
  DesktopScheduledTasks({
    required this._store,
    DateTime Function()? now,
    Future<DesktopPowerState> Function()? readPowerState,
  }) : _now = now ?? DateTime.now,
       _readPowerState = readPowerState ?? DesktopPowerState.read;

  static const _pollInterval = Duration(seconds: 1);
  final ScheduledTaskStore _store;
  final DateTime Function() _now;
  final Future<DesktopPowerState> Function() _readPowerState;
  Timer? _timer;
  DateTime? _lastTick;
  Duration? _lastTimeZoneOffset;
  void Function(String, ScheduledTask)? _onRun;
  List<ScheduledTask> tasks = const [];
  bool loaded = false;
  String? error;
  bool _disposed = false;
  int _attachment = 0;

  Future<void> load() => _store.runExclusive(() async {
    if (loaded || _disposed) return;
    final values = await _store.readAll();
    final now = _now();
    final restored = values.map((task) {
      final armed = _arm(task, now);
      return armed.withState(
        nextRunAt: armed.nextRunAt,
        runs: task.runs
            .map(
              (run) => run.status != 'running'
                  ? run
                  : ScheduledTaskRun(
                      id: run.id,
                      startedAt: run.startedAt,
                      status: 'interrupted',
                      conversationId: run.conversationId,
                      error: 'process_terminated',
                    ),
            )
            .toList(),
      );
    }).toList();
    if (_disposed) return;
    await _commit(restored);
    loaded = true;
    notifyListeners();
  });

  Future<void> start(void Function(String, ScheduledTask) onRun) async {
    stop();
    final attachment = _attachment;
    await load();
    await _store.runExclusive(() async {
      if (_disposed || attachment != _attachment) return;
      // Loading the UI or reopening the app never replays an old deadline.
      final now = _now();
      await _commit(tasks.map((task) => _arm(task, now)).toList());
      if (_disposed || attachment != _attachment) return;
      _onRun = onRun;
      _updateTimer();
    });
  }

  void stop() {
    _attachment++;
    _timer?.cancel();
    _timer = null;
    _onRun = null;
    _lastTick = null;
    _lastTimeZoneOffset = null;
  }

  void _updateTimer() {
    if (_onRun == null ||
        !tasks.any((task) => task.enabled && task.nextRunAt != null)) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null || _disposed) return;
    final now = _now();
    _lastTick = now;
    _lastTimeZoneOffset = now.timeZoneOffset;
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_tick()));
  }

  ScheduledTask _arm(ScheduledTask task, DateTime after) {
    final next = nextScheduledTaskRun(task, after);
    return task.withState(
      nextRunAt: task.enabled ? next : null,
      enabled: task.enabled && next != null,
      exhausted: next == null,
    );
  }

  Future<void> _commit(List<ScheduledTask> next) async {
    if (_disposed) return;
    await _store.writeAll(next);
    if (_disposed) return;
    tasks = List.unmodifiable(next..sort((a, b) => a.name.compareTo(b.name)));
    error = null;
    _updateTimer();
    notifyListeners();
  }

  Future<void> _tick() async {
    try {
      await _store.runExclusive(() async {
        if (_disposed || _onRun == null) return;
        final attachment = _attachment;
        final power = await _readPowerState();
        if (_disposed || _onRun == null || attachment != _attachment) return;
        if (power.sleeping) return;
        final now = _now();
        final previous = _lastTick!;
        final previousOffset = _lastTimeZoneOffset;
        _lastTick = now;
        _lastTimeZoneOffset = now.timeZoneOffset;
        if (now.isBefore(previous) || now.timeZoneOffset != previousOffset) {
          await _commit(tasks.map((task) => _arm(task, now)).toList());
          return;
        }
        final dispatch = <(String, ScheduledTask)>[];
        final next = tasks.map((task) {
          final due = task.nextRunAt;
          if (!task.enabled || due == null || due.isAfter(now)) return task;
          final armed = _arm(task, now);
          // Only native wake evidence skips a missed occurrence. An overdue
          // callback while the computer stays awake still runs exactly once.
          if (task.running ||
              power.lastWakeAt != null &&
                  !power.lastWakeAt!.isAfter(now) &&
                  !due.isAfter(power.lastWakeAt!)) {
            return armed;
          }
          final started = _beginRun(armed, now);
          dispatch.add((started.runs.first.id, started));
          return started;
        }).toList();
        if (!listEquals(tasks, next)) await _commit(next);
        if (_disposed) return;
        for (final (id, task) in dispatch) {
          _onRun?.call(id, task);
        }
      });
    } catch (e) {
      if (_disposed) return;
      error = e.toString();
      notifyListeners();
    }
  }

  ScheduledTask _beginRun(ScheduledTask task, DateTime now) => task.withState(
    nextRunAt: task.nextRunAt,
    runs: [
      ScheduledTaskRun(
        id: const Uuid().v4(),
        startedAt: now,
        status: 'running',
      ),
      ...task.runs.take(19),
    ],
  );

  Future<void> save(ScheduledTask task, {bool? enabled}) async {
    await load();
    await _store.runExclusive(() async {
      _checkEditable(task.id);
      if (task.id.isEmpty ||
          task.id.length > 128 ||
          task.name.trim().isEmpty ||
          task.name.trim().length > 200 ||
          task.assistantId.trim().isEmpty ||
          task.prompt.trim().length > 32000 ||
          task.mode != ScheduledTaskMode.regenerate &&
              task.prompt.trim().isEmpty ||
          task.mode != ScheduledTaskMode.newChat &&
              (task.conversationId ?? '').trim().isEmpty ||
          task.mode == ScheduledTaskMode.regenerate &&
              (task.messageId ?? '').trim().isEmpty ||
          (task.modelProvider == null) != (task.modelId == null) ||
          task.modelId != null &&
              ((task.modelId!.trim().isEmpty) ||
                  task.modelProvider!.trim().isEmpty)) {
        throw ArgumentError('invalid_task');
      }
      final requested = task.withState(nextRunAt: null, enabled: enabled);
      final armed = _arm(requested, _now());
      if (requested.enabled && armed.exhausted) {
        throw StateError('schedule_ended');
      }
      final previous = tasks.where((value) => value.id == task.id).firstOrNull;
      await _commit([
        ...tasks.where((value) => value.id != task.id),
        armed.withState(
          nextRunAt: armed.nextRunAt,
          runs: previous?.runs ?? const [],
        ),
      ]);
    });
  }

  void _checkEditable(String id) {
    if (_disposed) throw StateError('scheduled_tasks_disposed');
    if (tasks.any((task) => task.id == id && task.running)) {
      throw StateError('task_running');
    }
  }

  Future<void> delete(String id) async {
    await load();
    await _store.runExclusive(() async {
      _checkEditable(id);
      await _commit(tasks.where((task) => task.id != id).toList());
    });
  }

  Future<void> runNow(String id) async {
    await load();
    await _store.runExclusive(() async {
      _checkEditable(id);
      if (_onRun == null) throw StateError('runner_not_ready');
      final task = tasks.where((task) => task.id == id).firstOrNull;
      if (task == null) throw StateError('task_missing');
      final started = _beginRun(task, _now());
      await _commit([
        for (final value in tasks) value.id == id ? started : value,
      ]);
      _onRun?.call(started.runs.first.id, started);
    });
  }

  Future<void> updateRun(String id, Map<String, Object?> result) =>
      _store.runExclusive(() async {
        if (_disposed) return;
        final next = tasks.map((task) {
          if (!task.runs.any(
            (run) => run.id == id && run.status == 'running',
          )) {
            return task;
          }
          return task.withState(
            nextRunAt: task.nextRunAt,
            runs: task.runs
                .map(
                  (run) => run.id != id
                      ? run
                      : ScheduledTaskRun.fromJson({...run.toJson(), ...result}),
                )
                .toList(),
          );
        }).toList();
        if (!listEquals(tasks, next)) await _commit(next);
      });

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }
}
