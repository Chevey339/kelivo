import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../models/scheduled_task.dart';
import '../models/scheduled_task_payload.dart';
import 'scheduled_task_notifications.dart';
import 'scheduled_task_preparation.dart';
import 'scheduled_task_schedule.dart';
import 'scheduled_task_store.dart';
import 'scheduled_tasks_service.dart';

/// One occurrence, one durable run, regardless of how many preparation attempts
/// it takes. All state transitions are serialized; model I/O never holds the lock.
class PreparedScheduledTasks extends ChangeNotifier {
  PreparedScheduledTasks({
    required this._store,
    required this.notifications,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (notifications case final IosScheduledTaskNotifications native) {
      native.onExpiration = () async {
        await _cancellation?.cancel();
      };
    }
  }

  final ScheduledTaskStore _store;
  final ScheduledTaskNotifications notifications;
  final DateTime Function() _now;
  ScheduledTaskPreparation? preparation;
  void Function(String, ScheduledTask)? _onRun;
  List<ScheduledTask> tasks = const [];
  List<ScheduledTask> _persistedTasks = const [];
  Map<String, dynamic> _results = {};
  Set<String> _pendingNotifications = {};
  bool loaded = false, foreground = true, _disposed = false;
  String? error;
  Timer? _timer;
  DateTime? _lastActivity;
  Duration? _offset;
  String? _preparingId;
  ScheduledRunCancellation? _cancellation;
  final _pendingNotificationTaps = <String, Completer<String?>>{};

  Future<void> load() => _store.runExclusive(() async {
    if (loaded || _disposed) return;
    tasks = await _store.readAll();
    _persistedTasks = tasks;
    _results = await _store.readResults();
    _pendingNotifications = await notifications.pending();
    final owned = {
      for (final task in tasks)
        for (final run in task.runs) run.id,
    };
    for (final id in _pendingNotifications.difference(owned)) {
      await notifications.cancel(id);
    }
    tasks = [
      for (final task in tasks)
        task.withState(
          nextRunAt: task.nextRunAt,
          runs: [
            for (final run in task.runs)
              if (run.status == 'preparing')
                run.update({'status': 'pending', 'error': 'process_terminated'})
              else if (run.status == 'running')
                run.update({
                  'status': 'interrupted',
                  'error': 'process_terminated',
                })
              else
                run,
          ],
        ),
    ];
    final payloads = Map<String, dynamic>.from(
      _results['payloads'] as Map? ?? {},
    );
    final referenced = {
      for (final task in tasks)
        for (final run in task.runs)
          if (run.awaitingPublication && run.payloadId != null) run.payloadId!,
    };
    payloads.removeWhere((id, _) => !referenced.contains(id));
    _results = {..._results, 'payloads': payloads};
    await _store.writeResults(_results);
    _offset = Duration(
      minutes:
          _results['timeZoneOffsetMinutes'] as int? ??
          _now().timeZoneOffset.inMinutes,
    );
    _results = {..._results, 'timeZoneOffsetMinutes': _offset!.inMinutes};
    await _store.writeResults(_results);
    await _commit();
    loaded = true;
    notifyListeners();
  });

  Future<void> start(void Function(String, ScheduledTask) onRun) async {
    await load();
    if (_disposed) return;
    _onRun = onRun;
    await check(prepare: true, executeDue: false);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(
        check(
          prepare:
              foreground &&
              (_lastActivity == null ||
                  _now().difference(_lastActivity!) >=
                      const Duration(seconds: 45)),
          executeDue: foreground,
          validateContext: false,
        ).catchError(_recordError),
      );
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _onRun = null;
    unawaited(_cancellation?.cancel());
    for (final pending in _pendingNotificationTaps.values) {
      pending.complete(null);
    }
    _pendingNotificationTaps.clear();
  }

  Future<void> activityChanged() async {
    _lastActivity = _now();
    await check();
  }

  Future<void> lifecycle(bool active) async {
    foreground = active;
    if (active) _pendingNotifications = await notifications.pending();
    await check(prepare: true, executeDue: false, retryNotifications: active);
  }

  ScheduledTask? _task(String id) => tasks.where((t) => t.id == id).firstOrNull;
  ScheduledTaskRun? _run(String id) =>
      tasks.expand((t) => t.runs).where((r) => r.id == id).firstOrNull;
  ScheduledTaskPayload? _payload(String id) =>
      _run(id)?.payloadId == id ? _store.payload(_results, id) : null;

  Future<void> _commit() async {
    try {
      await _store.writeAll(tasks);
    } catch (_) {
      tasks = _persistedTasks;
      rethrow;
    }
    tasks = List.unmodifiable(tasks);
    _persistedTasks = tasks;
    error = null;
    _resolveNotificationTaps();
    if (!_disposed) notifyListeners();
  }

  void _replace(ScheduledTask task) {
    tasks = [
      for (final t in tasks)
        if (t.id == task.id) task else t,
    ];
  }

  void _replaceRun(String taskId, ScheduledTaskRun run) {
    final task = _task(taskId)!;
    _replace(
      task.withState(
        nextRunAt: task.nextRunAt,
        runs: [
          run,
          ...task.runs
              .where((r) => r.id != run.id)
              .indexed
              .where(
                (entry) =>
                    entry.$1 < 19 ||
                    entry.$2.awaitingPublication ||
                    entry.$2.status == 'running',
              )
              .map((entry) => entry.$2),
        ],
      ),
    );
  }

  Future<void> _removePayload(String id) async {
    final payloads = Map<String, dynamic>.from(
      _results['payloads'] as Map? ?? {},
    );
    if (payloads.remove(id) == null) return;
    _results = {..._results, 'payloads': payloads};
    await _store.writeResults(_results);
  }

  Future<void> _cancelNotification(String id) async {
    await notifications.cancel(id);
    _pendingNotifications.remove(id);
  }

  Future<ScheduledTaskRun> _register(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload? payload,
  ) async {
    final registered = await notifications.schedule(task, run, payload);
    if (registered) {
      _pendingNotifications.add(run.id);
    } else {
      _pendingNotifications.remove(run.id);
    }
    return run.update({
      'notificationState': registered ? 'registered' : 'unavailable',
    });
  }

  Future<void> _invalidate(ScheduledTask task, ScheduledTaskRun run) async {
    await _cancelNotification(run.id);
    if (_preparingId == run.id) await _cancellation?.cancel();
    await _removePayload(run.id);
    var invalid = run.update({
      'status': 'pending',
      'payloadId': null,
      'contextRevision': null,
      'preparedAt': null,
      'notificationState': 'none',
    });
    if (run.scheduledFor!.isAfter(_now()) && task.enabled) {
      invalid = await _register(task, invalid, null);
    }
    _replaceRun(task.id, invalid);
  }

  String _scheduleKey(ScheduledTask task) =>
      '${task.hour}:${task.minute}:${task.weekdays.join(',')}:'
      '${ScheduledTask.dateKey(task.onceDate)}:${ScheduledTask.dateKey(task.startDate)}:${ScheduledTask.dateKey(task.endDate)}';

  String _executionKey(ScheduledTask task, {bool? enabled}) => jsonEncode(
    task.toJson(enabled: enabled)..removeWhere(
      (key, _) => const {
        'notify',
        'showPreview',
        'unavailablePolicy',
        'revision',
        'scheduleRevision',
      }.contains(key),
    ),
  );

  Future<void> save(ScheduledTask task, {bool? enabled}) async {
    await load();
    validateScheduledTask(task);
    var notificationOnly = false;
    await _store.runExclusive(() async {
      final old = _task(task.id);
      if (old?.running == true) throw StateError('task_running');
      if (old != null &&
          _executionKey(old) == _executionKey(task, enabled: enabled)) {
        // Delivery preferences do not change the result, its preparation
        // budget, or the occurrence currently waiting to be published.
        notificationOnly = true;
        _replace(
          task.withState(
            nextRunAt: old.nextRunAt,
            enabled: old.enabled,
            exhausted: old.exhausted,
            runs: old.runs,
            revision: old.revision,
            scheduleRevision: old.scheduleRevision,
          ),
        );
        await _commit();
        return;
      }
      final scheduleChanged =
          old != null && _scheduleKey(old) != _scheduleKey(task);
      final requested = task.withState(
        nextRunAt: null,
        enabled: enabled,
        revision: (old?.revision ?? 0) + 1,
        scheduleRevision:
            (old?.scheduleRevision ?? 0) + (scheduleChanged ? 1 : 0),
      );
      final next = nextScheduledTaskRun(requested, _now());
      if (requested.enabled && next == null) throw StateError('schedule_ended');
      final runs = <ScheduledTaskRun>[];
      for (final run in old?.runs ?? <ScheduledTaskRun>[]) {
        final resumeCancelled =
            run.status == 'cancelled' &&
            !scheduleChanged &&
            run.scheduledFor == next &&
            requested.enabled;
        if (!run.awaitingPublication && !resumeCancelled) {
          runs.add(run);
          continue;
        }
        await _cancelNotification(run.id);
        if (_preparingId == run.id) await _cancellation?.cancel();
        await _removePayload(run.id);
        final reuse =
            !scheduleChanged && run.scheduledFor == next && requested.enabled;
        runs.add(
          run.update({
            'status': reuse ? 'pending' : 'cancelled',
            'taskRevision': requested.revision,
            'payloadId': null,
            'preparedAt': null,
            'contextRevision': null,
            'notificationState': 'none',
          }),
        );
      }
      tasks = [
        ...tasks.where((t) => t.id != task.id),
        requested.withState(
          nextRunAt: requested.enabled ? next : null,
          runs: runs,
          exhausted: next == null,
        ),
      ];
      await _commit();
    });
    await check(
      prepare: !notificationOnly,
      retryNotifications: notificationOnly,
    );
  }

  Future<void> delete(String id) async {
    await load();
    await _store.runExclusive(() async {
      final task = _task(id);
      if (task == null) return;
      if (task.running) throw StateError('task_running');
      for (final run in task.runs) {
        await _cancelNotification(run.id);
        if (_preparingId == run.id) await _cancellation?.cancel();
        await _removePayload(run.id);
      }
      tasks = tasks.where((t) => t.id != id).toList();
      await _commit();
    });
  }

  Future<void> runNow(String id) async {
    await load();
    await _store.runExclusive(() async {
      final task = _task(id);
      if (task == null) throw StateError('task_missing');
      if (task.running) throw StateError('task_running');
      if (_onRun == null) throw StateError('runner_not_ready');
      final run = ScheduledTaskRun(
        id: const Uuid().v4(),
        startedAt: _now(),
        status: 'running',
      );
      _replaceRun(id, run);
      await _commit();
      _onRun!(run.id, _task(id)!);
    });
  }

  Future<void> updateRun(String id, Map<String, Object?> result) =>
      _store.runExclusive(() async {
        final task = tasks
            .where((t) => t.runs.any((r) => r.id == id))
            .firstOrNull;
        final run = _run(id);
        if (task == null || run == null || run.status != 'running') return;
        _replaceRun(task.id, run.update(result));
        await _commit();
      });

  /// Context events invalidate only. They never directly spend model tokens.
  Future<void> check({
    bool prepare = false,
    bool executeDue = false,
    bool validateContext = true,
    bool retryNotifications = false,
  }) => _store.runExclusive(() async {
    if (!loaded || _disposed || preparation == null) return;
    final now = _now();
    final before = tasks;
    if (_offset != now.timeZoneOffset) {
      _offset = now.timeZoneOffset;
      _results = {..._results, 'timeZoneOffsetMinutes': _offset!.inMinutes};
      await _store.writeResults(_results);
      for (final task in tasks.toList()) {
        for (final run in task.runs.where(
          (r) => r.awaitingPublication && r.scheduledFor!.isAfter(now),
        )) {
          await _cancelNotification(run.id);
          if (_preparingId == run.id) await _cancellation?.cancel();
          await _removePayload(run.id);
          _replaceRun(
            task.id,
            run.update({
              'status': 'cancelled',
              'payloadId': null,
              'notificationState': 'none',
            }),
          );
        }
        _replace(
          _task(task.id)!.withState(
            nextRunAt: null,
            scheduleRevision: task.scheduleRevision + 1,
          ),
        );
      }
    }
    // Reconcile due results before arming a new occurrence or preparing content.
    for (final original in tasks.toList()) {
      var task = _task(original.id)!;
      for (final originalRun
          in task.runs.where((r) => r.awaitingPublication).toList()) {
        var run = _run(originalRun.id)!;
        if (!task.enabled) continue;
        var payload = _payload(run.id);
        final future = run.scheduledFor!.isAfter(now);
        if ((validateContext || !future) &&
            run.status != 'publishing' &&
            (run.contextRevision != null || payload != null)) {
          String? current;
          try {
            current = await preparation!.revision(task);
          } catch (_) {}
          // Target existence and task revision are checked even in snapshot mode.
          final invalid =
              current == null ||
              run.taskRevision != task.revision ||
              run.contextRevision != null &&
                  !preparation!.sameConfiguration(
                    run.contextRevision!,
                    current,
                  ) ||
              task.contextPolicy == ScheduledTaskContextPolicy.latest &&
                  current != run.contextRevision;
          if (invalid) {
            await _invalidate(task, run);
            run = _run(run.id)!;
            payload = null;
          }
        }
        if (future) {
          if (retryNotifications ||
              run.notificationState == 'none' ||
              !_pendingNotifications.contains(run.id) &&
                  (run.notificationState != 'unavailable' ||
                      retryNotifications)) {
            _replaceRun(task.id, await _register(task, run, payload));
          }
          continue;
        }
        if (run.status == 'preparing') {
          await _cancellation?.cancel();
          _replaceRun(task.id, run.update({'status': 'pending'}));
          run = _run(run.id)!;
        }
        if (preparation!.isBusy(task)) continue;
        if (payload != null) {
          // Durable publication intent survives a crash between chat commit and
          // history update. The publisher uses stable message IDs transactionally.
          _replaceRun(task.id, run.update({'status': 'publishing'}));
          await _commit();
          try {
            final conversationId = await preparation!.publish(
              task,
              run,
              payload,
            );
            _replaceRun(
              task.id,
              run.update({
                'status': 'completed',
                'conversationId': conversationId,
                'preview': payload.text.characters.take(200).toString(),
                'payloadId': null,
                'error': null,
              }),
            );
          } catch (e) {
            if (e is StateError &&
                (e.message == 'conversation_missing' ||
                    e.message == 'scheduled_context_changed')) {
              _replaceRun(
                task.id,
                run.update({
                  'status': 'failed',
                  'payloadId': null,
                  'error': e.toString(),
                }),
              );
            } else {
              rethrow;
            }
          }
          await _commit();
          await _removePayload(run.id);
        } else if (foreground &&
            _onRun != null &&
            now.difference(run.scheduledFor!) < const Duration(seconds: 30) &&
            !task.running) {
          // Lifecycle and context checks must not consume the timer's chance
          // to execute a due foreground task during its execution window.
          if (!executeDue) continue;
          await _cancelNotification(run.id);
          _replaceRun(
            task.id,
            run.update({
              'status': 'running',
              'startedAt': now.millisecondsSinceEpoch,
            }),
          );
          await _commit();
          _onRun!(run.id, _task(task.id)!);
        } else {
          _replaceRun(
            task.id,
            run.update({
              'status':
                  task.notify &&
                      task.unavailablePolicy ==
                          ScheduledTaskUnavailablePolicy.remind
                  ? 'reminded'
                  : 'skipped',
            }),
          );
        }
        task = _task(task.id)!;
      }
      task = _task(task.id)!;
      if (!task.enabled) continue;
      if (task.runs.any((r) => r.awaitingPublication)) continue;
      final next = nextScheduledTaskRun(task, now);
      _replace(
        task.withState(
          nextRunAt: next,
          enabled: next != null,
          exhausted: next == null,
        ),
      );
      if (next != null) {
        task = _task(task.id)!;
        final id =
            'scheduled:${task.id}:${task.scheduleRevision}:${next.millisecondsSinceEpoch}';
        if (!task.runs.any((r) => r.id == id)) {
          var run = ScheduledTaskRun(
            id: id,
            status: 'pending',
            scheduledFor: next,
            taskRevision: task.revision,
          );
          run = await _register(task, run, null);
          _replaceRun(task.id, run);
        }
      }
    }
    if (!identical(before, tasks)) await _commit();
    if (!prepare || _preparingId != null || _onRun == null) return;
    final attempts = List<int>.from(_results['attempts'] as List? ?? [])
      ..removeWhere(
        (time) =>
            now.millisecondsSinceEpoch - time >=
            const Duration(hours: 1).inMilliseconds,
      );
    // One global request at a time, at most six attempts/hour across all tasks.
    if (attempts.length >= 6) return;
    final candidates =
        tasks
            .where(
              (t) =>
                  t.enabled &&
                  t.canPrepare &&
                  !t.running &&
                  !preparation!.isBusy(t) &&
                  t.nextRunAt != null,
            )
            .toList()
          ..sort((a, b) => a.nextRunAt!.compareTo(b.nextRunAt!));
    for (final task in candidates) {
      final run = task.runs
          .where(
            (r) => r.status == 'pending' && r.scheduledFor == task.nextRunAt,
          )
          .firstOrNull;
      if (run == null ||
          !run.scheduledFor!.isAfter(now) ||
          run.scheduledFor!.difference(now) >
              Duration(minutes: task.preparationWindowMinutes) ||
          run.prepareAttempts >= task.maxPrepareAttempts ||
          run.lastPrepareAt != null &&
              now.difference(run.lastPrepareAt!) <
                  Duration(minutes: task.preparationCooldownMinutes)) {
        continue;
      }
      String revision;
      try {
        revision = await preparation!.revision(task);
      } catch (e) {
        continue;
      }
      attempts.add(now.millisecondsSinceEpoch);
      _results = {..._results, 'attempts': attempts};
      await _store.writeResults(_results);
      final preparing = run.update({
        'status': 'preparing',
        'startedAt': now.millisecondsSinceEpoch,
        'lastPrepareAt': now.millisecondsSinceEpoch,
        'prepareAttempts': run.prepareAttempts + 1,
        'taskRevision': task.revision,
        'contextRevision': revision,
        'error': null,
      });
      _replaceRun(task.id, preparing);
      await _commit();
      _preparingId = run.id;
      final cancellation = _cancellation = ScheduledRunCancellation();
      unawaited(_prepare(task, preparing, cancellation));
      break;
    }
  });

  Future<void> _prepare(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledRunCancellation cancellation,
  ) async {
    try {
      await notifications.beginPreparation();
      cancellation.check();
      final payload = await preparation!
          .prepare(task, run, cancellation)
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              throw TimeoutException('preparation_timeout');
            },
          );
      await _store.runExclusive(() async {
        cancellation.check();
        final current = _task(task.id);
        final latest = _run(run.id);
        if (_disposed ||
            current == null ||
            !current.enabled ||
            current.revision != task.revision ||
            latest?.status != 'preparing' ||
            !run.scheduledFor!.isAfter(_now())) {
          return;
        }
        final revision = await preparation!.revision(current);
        if (!preparation!.sameConfiguration(
              payload.contextRevision,
              revision,
            ) ||
            task.contextPolicy == ScheduledTaskContextPolicy.latest &&
                (revision != run.contextRevision ||
                    payload.contextRevision != run.contextRevision)) {
          await _invalidate(current, latest!);
          await _commit();
          return;
        }
        _results = {
          ..._results,
          'payloads': {
            ...?_results['payloads'] as Map?,
            run.id: payload.toJson(),
          },
        };
        await _store.writeResults(_results);
        var prepared = latest!.update({
          'status': 'prepared',
          'payloadId': run.id,
          'preparedAt': _now().millisecondsSinceEpoch,
          'contextRevision': payload.contextRevision,
          'notificationState': 'none',
        });
        _replaceRun(task.id, prepared);
        await _commit(); // Recoverable even if killed before registration.
        prepared = await _register(current, prepared, payload);
        _replaceRun(task.id, prepared);
        if (task.contextPolicy == ScheduledTaskContextPolicy.latest &&
            await preparation!.revision(current) != payload.contextRevision) {
          await _invalidate(current, prepared);
        }
        await _commit();
      });
    } catch (e) {
      await cancellation.cancel();
      try {
        await _store.runExclusive(() async {
          final current = _run(run.id);
          if (current?.status == 'preparing') {
            _replaceRun(
              task.id,
              current!.update({'status': 'pending', 'error': e.toString()}),
            );
            await _commit();
          }
        });
      } catch (failure) {
        _recordError(failure);
      }
    } finally {
      try {
        await notifications.endPreparation();
      } catch (e) {
        _recordError(e);
      }
      _preparingId = null;
      _cancellation = null;
    }
  }

  Future<String?> notificationTapped(String runId) async {
    if (_disposed) return null;
    final pending = _pendingNotificationTaps.putIfAbsent(
      runId,
      () => Completer<String?>(),
    );
    try {
      await check();
      await _store.runExclusive(() async {
        final task = tasks
            .where((t) => t.runs.any((r) => r.id == runId))
            .firstOrNull;
        final run = _run(runId);
        if (task == null || run == null) {
          _resolveNotificationTaps();
          return;
        }
        _replaceRun(task.id, run.update({'notificationState': 'interacted'}));
        await _commit();
      });
    } catch (_) {
      if (identical(_pendingNotificationTaps[runId], pending)) {
        _pendingNotificationTaps.remove(runId)!.complete(null);
      }
      rethrow;
    }
    // Do not hold the store lock while a busy chat delays publication.
    return pending.future;
  }

  void _resolveNotificationTaps() {
    for (final entry in _pendingNotificationTaps.entries.toList()) {
      final task = tasks
          .where((t) => t.runs.any((r) => r.id == entry.key))
          .firstOrNull;
      final run = _run(entry.key);
      if (run?.awaitingPublication == true && _payload(entry.key) != null) {
        continue;
      }
      _pendingNotificationTaps.remove(entry.key);
      entry.value.complete(run?.conversationId ?? task?.conversationId);
    }
  }

  void _recordError(Object e) {
    error = e.toString();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _disposed = true;
    super.dispose();
  }
}
