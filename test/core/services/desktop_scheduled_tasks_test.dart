import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/desktop_power_state.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/backup_portability.dart';
import '../../support/business_test_harness.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/services/desktop_scheduled_tasks.dart';
import 'package:Kelivo/core/services/scheduled_task_store.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';

const task = ScheduledTask(
  id: 'task',
  name: 'Morning',
  prompt: 'Hello',
  assistantId: 'assistant',
  hour: 8,
  minute: 0,
);

void complete(FakeAsync async, Future<void> operation) {
  var done = false;
  Object? error;
  operation.then(
    (_) => done = true,
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  async.flushMicrotasks();
  expect(done, isTrue, reason: 'operation did not complete');
  if (error != null) throw error!;
}

class _MemoryTaskDisk {
  List<ScheduledTask> tasks = [];
}

class _MemoryTaskStore extends ScheduledTaskStore {
  _MemoryTaskStore(super.preferences, this.disk, {this.ready});
  final _MemoryTaskDisk disk;
  final Future<void>? ready;
  @override
  Future<List<ScheduledTask>> readAll() async {
    await ready;
    return List.of(disk.tasks);
  }

  @override
  Future<void> writeAll(List<ScheduledTask> items) async {
    disk.tasks = List.of(items);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessPreferences prefs;
  late _MemoryTaskDisk disk;
  setUp(() async {
    prefs = (await createBusinessTestHarness()).preferences;
    disk = _MemoryTaskDisk();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DesktopPowerState.channel, (call) async {
          expect(call.method, 'state');
          return {'sleeping': false, 'lastWakeAt': 0};
        });
  });

  test('desktop schedules stay local to this device', () {
    expect(
      BusinessKeyRegistry.classify(ScheduledTaskStore.preferenceKey),
      BusinessKeyDisposition.preference,
    );
    final local = BusinessSettingsRouter.normalizeAndRoute({
      ScheduledTaskStore.preferenceKey: 'local tasks',
    });
    final incoming = BusinessSettingsRouter.normalizeAndRoute({
      ScheduledTaskStore.preferenceKey: 'foreign tasks',
    });
    expect(
      BackupPortability.portable(local).preferences,
      isNot(contains(ScheduledTaskStore.preferenceKey)),
    );
    expect(
      BackupPortability.preserveDeviceState(
        BackupPortability.portable(incoming),
        local,
      ).preferences[ScheduledTaskStore.preferenceKey],
      'local tasks',
    );
  });

  test(
    'a live app runs at the deadline once and persists the result and chat',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 9, 11, 7, 59, 58);
        final desktop = DesktopScheduledTasks(
          store: _MemoryTaskStore(prefs, disk),
          now: () => start.add(async.elapsed),
        );
        final service = ScheduledTasksService(desktop: desktop);
        var executions = 0;
        complete(
          async,
          service.attach((task, cancellation, onConversation) async {
            executions++;
            await onConversation('chat');
            return {'status': 'completed', 'preview': 'Hello back'};
          }),
        );
        complete(async, service.save(task));
        async.elapse(const Duration(seconds: 1));
        expect(executions, 0);
        async.elapse(const Duration(seconds: 1));
        expect(executions, 1);
        expect(service.tasks.single.nextRunAt, DateTime(2026, 9, 12, 8));
        final run = service.tasks.single.runs.single;
        expect(run.status, 'completed');
        expect(run.conversationId, 'chat');
        expect(run.preview, 'Hello back');
        expect(disk.tasks, hasLength(1));
        expect(disk.tasks.single.runs.single.preview, 'Hello back');
        async.elapse(const Duration(minutes: 1));
        expect(executions, 1);
        service.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'reopening after a missed deadline skips it, even within the same minute',
    () {
      fakeAsync((async) {
        var now = DateTime(2026, 9, 11, 7, 59);
        final first = DesktopScheduledTasks(
          store: _MemoryTaskStore(prefs, disk),
          now: () => now,
        );
        complete(async, first.save(task));
        first.dispose();
        now = DateTime(2026, 9, 11, 8, 0, 1);
        final reopened = DesktopScheduledTasks(
          store: _MemoryTaskStore(prefs, disk),
          now: () => now,
        );
        var executions = 0;
        complete(async, reopened.start((_, _) => executions++));
        async.elapse(const Duration(seconds: 5));
        expect(executions, 0);
        expect(reopened.tasks.single.nextRunAt, DateTime(2026, 9, 12, 8));
        expect(reopened.tasks.single.runs, isEmpty);
        reopened.dispose();
      });
    },
  );

  test('an expired one-time task is disabled on reopen without executing', () {
    fakeAsync((async) {
      final once = ScheduledTask.fromJson({
        ...task.toJson(),
        'onceDate': '2026-09-11',
      });
      disk.tasks = [once];
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk),
        now: () => DateTime(2026, 9, 12),
      );
      var executions = 0;
      complete(async, desktop.start((_, _) => executions++));
      async.elapse(const Duration(seconds: 2));
      expect(desktop.tasks.single.enabled, isFalse);
      expect(desktop.tasks.single.exhausted, isTrue);
      expect(desktop.tasks.single.nextRunAt, isNull);
      expect(executions, 0);
      desktop.dispose();
    });
  });

  for (final once in [false, true]) {
    test(
      '15 seconds of event-loop blocking still executes once, once=$once',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 9, 11, 7, 59, 59);
          final desktop = DesktopScheduledTasks(
            store: _MemoryTaskStore(prefs, disk),
            now: () => start.add(async.elapsed),
          );
          final service = ScheduledTasksService(desktop: desktop);
          var executions = 0;
          complete(
            async,
            service.attach((_, _, _) async {
              executions++;
              return {'status': 'completed'};
            }),
          );
          complete(
            async,
            service.save(
              ScheduledTask.fromJson({
                ...task.toJson(),
                if (once) 'onceDate': '2026-09-11',
              }),
            ),
          );
          async.elapseBlocking(const Duration(seconds: 15));
          async.elapse(Duration.zero);
          expect(executions, 1);
          expect(service.tasks.single.runs.single.status, 'completed');
          expect(service.tasks.single.enabled, !once);
          async.elapse(const Duration(seconds: 5));
          expect(executions, 1);
          service.dispose();
        });
      },
    );
  }

  test('native sleep and wake skip missed time but not a later deadline', () {
    fakeAsync((async) {
      final start = DateTime(2026, 9, 11, 7, 59, 59);
      var power = const DesktopPowerState(sleeping: true);
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk),
        now: () => start.add(async.elapsed),
        readPowerState: () async => power,
      );
      var executions = 0;
      complete(async, desktop.start((_, _) => executions++));
      complete(async, desktop.save(task));
      complete(
        async,
        desktop.save(
          ScheduledTask.fromJson({
            ...task.toJson(),
            'id': 'after-wake',
            'minute': 2,
          }),
        ),
      );
      complete(
        async,
        desktop.save(
          ScheduledTask.fromJson({
            ...task.toJson(),
            'id': 'once',
            'onceDate': '2026-09-11',
          }),
        ),
      );
      async.elapseBlocking(const Duration(minutes: 1));
      async.elapse(Duration.zero);
      expect(executions, 0);
      expect(desktop.tasks.every((task) => task.runs.isEmpty), isTrue);
      power = DesktopPowerState(lastWakeAt: start.add(async.elapsed));
      // The wake event arrived natively; Dart remains busy past the 08:02 task.
      async.elapseBlocking(const Duration(minutes: 2));
      async.elapse(Duration.zero);
      expect(executions, 1);
      expect(
        desktop.tasks.singleWhere((t) => t.id == 'after-wake').runs,
        hasLength(1),
      );
      final missed = desktop.tasks.singleWhere((t) => t.id == 'task');
      expect(missed.runs, isEmpty);
      expect(missed.nextRunAt, DateTime(2026, 9, 12, 8));
      final once = desktop.tasks.singleWhere((t) => t.id == 'once');
      expect(once.enabled, isFalse);
      expect(once.runs, isEmpty);
      desktop.dispose();
    });
  });

  test('a delayed power snapshot does not consume a run after detach', () {
    fakeAsync((async) {
      final start = DateTime(2026, 9, 11, 7, 59, 59);
      final power = Completer<DesktopPowerState>();
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk),
        now: () => start.add(async.elapsed),
        readPowerState: () => power.future,
      );
      var executions = 0;
      complete(async, desktop.start((_, _) => executions++));
      complete(async, desktop.save(task));
      async.elapse(const Duration(seconds: 1));
      desktop.stop();
      power.complete(const DesktopPowerState());
      async.flushMicrotasks();
      expect(executions, 0);
      expect(desktop.tasks.single.runs, isEmpty);
      desktop.dispose();
    });
  });

  test(
    'power snapshot errors preserve pending tasks for a successful retry',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 9, 11, 7, 59, 59);
        var failed = true;
        final desktop = DesktopScheduledTasks(
          store: _MemoryTaskStore(prefs, disk),
          now: () => start.add(async.elapsed),
          readPowerState: () async {
            if (failed) throw StateError('power_monitor_unavailable');
            return const DesktopPowerState();
          },
        );
        var executions = 0;
        complete(async, desktop.start((_, _) => executions++));
        complete(async, desktop.save(task));
        async.elapseBlocking(const Duration(seconds: 15));
        async.elapse(Duration.zero);
        expect(executions, 0);
        expect(desktop.error, contains('power_monitor_unavailable'));
        expect(desktop.tasks.single.runs, isEmpty);
        failed = false;
        async.elapse(const Duration(seconds: 1));
        expect(executions, 1);
        expect(desktop.error, isNull);
        desktop.dispose();
      });
    },
  );

  test(
    'setting the clock behind an old wake timestamp does not suppress tasks',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 9, 11, 7, 59, 59);
        final desktop = DesktopScheduledTasks(
          store: _MemoryTaskStore(prefs, disk),
          now: () => start.add(async.elapsed),
          readPowerState: () async =>
              DesktopPowerState(lastWakeAt: DateTime(2026, 9, 11, 9)),
        );
        var executions = 0;
        complete(async, desktop.start((_, _) => executions++));
        complete(async, desktop.save(task));
        async.elapse(const Duration(seconds: 1));
        expect(executions, 1);
        desktop.dispose();
      });
    },
  );

  test('pause, delete and stop disarm future occurrences', () {
    fakeAsync((async) {
      final base = DateTime(2026, 9, 11, 7, 59, 57);
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk),
        now: () => base.add(async.elapsed),
      );
      var executions = 0;
      complete(async, desktop.start((_, _) => executions++));
      complete(async, desktop.save(task));
      complete(async, desktop.save(task, enabled: false));
      expect(desktop.tasks.single.nextRunAt, isNull);
      async.elapse(const Duration(seconds: 1));
      complete(async, desktop.save(task, enabled: true));
      complete(async, desktop.delete(task.id));
      async.elapse(const Duration(seconds: 1));
      complete(async, desktop.save(task));
      desktop.stop();
      async.elapse(const Duration(seconds: 2));
      expect(executions, 0);
      expect(desktop.tasks.single.runs, isEmpty);
      desktop.dispose();
    });
  });

  test('detach while preferences load cannot start a stale runner', () {
    fakeAsync((async) {
      disk.tasks = [task];
      final gate = Completer<void>();
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk, ready: gate.future),
      );
      final starting = desktop.start((_, _) => fail('stale callback'));
      async.flushMicrotasks();
      desktop.stop();
      gate.complete();
      complete(async, starting);
      expect(async.periodicTimerCount, 0);
      desktop.dispose();
    });
  });

  test('no polling timer remains when all tasks are paused or deleted', () {
    fakeAsync((async) {
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk),
        now: () => DateTime(2026, 9, 11, 7),
      );
      complete(async, desktop.start((_, _) {}));
      expect(async.periodicTimerCount, 0);
      complete(async, desktop.save(task));
      expect(async.periodicTimerCount, 1);
      complete(async, desktop.save(task, enabled: false));
      expect(async.periodicTimerCount, 0);
      complete(async, desktop.save(task, enabled: true));
      expect(async.periodicTimerCount, 1);
      complete(async, desktop.delete(task.id));
      expect(async.periodicTimerCount, 0);
      desktop.dispose();
    });
  });

  test(
    'running tasks reject duplicate starts and edits while other tasks run',
    () {
      fakeAsync((async) {
        final desktop = DesktopScheduledTasks(
          store: _MemoryTaskStore(prefs, disk),
          now: () => DateTime(2026, 9, 11, 7),
        );
        final service = ScheduledTasksService(desktop: desktop);
        final gate = Completer<Map<String, Object?>>();
        var executions = 0;
        complete(
          async,
          service.attach((_, _, _) {
            executions++;
            return gate.future;
          }),
        );
        complete(async, service.save(task));
        complete(
          async,
          service.save(
            ScheduledTask.fromJson({...task.toJson(), 'id': 'second'}),
          ),
        );
        complete(async, service.runNow('task'));
        complete(async, expectLater(service.runNow('task'), throwsStateError));
        complete(async, expectLater(service.save(task), throwsStateError));
        complete(async, expectLater(service.delete('task'), throwsStateError));
        complete(async, service.runNow('second'));
        expect(executions, 2);
        gate.complete({'status': 'completed'});
        async.flushMicrotasks();
        expect(service.tasks.every((task) => !task.running), isTrue);
        service.dispose();
      });
    },
  );

  test('a crashed run is marked interrupted rather than replayed', () {
    fakeAsync((async) {
      final interrupted = task.withState(
        nextRunAt: null,
        runs: [
          ScheduledTaskRun(
            id: 'old-run',
            startedAt: DateTime(2026, 9, 10),
            status: 'running',
            conversationId: 'old-chat',
          ),
        ],
      );
      disk.tasks = [interrupted];
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk),
        now: () => DateTime(2026, 9, 11, 9),
      );
      var executions = 0;
      complete(async, desktop.start((_, _) => executions++));
      final run = desktop.tasks.single.runs.single;
      expect(run.status, 'interrupted');
      expect(run.conversationId, 'old-chat');
      expect(run.error, 'process_terminated');
      expect(executions, 0);
      desktop.dispose();
    });
  });

  test('startup failures are reported and the same task can run again', () {
    fakeAsync((async) {
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk),
        now: () => DateTime(2026, 9, 11, 7),
      );
      final service = ScheduledTasksService(desktop: desktop);
      complete(
        async,
        service.attach((_, _, _) async => throw StateError('model_missing')),
      );
      complete(async, service.save(task));
      complete(async, service.runNow(task.id));
      async.flushMicrotasks();
      expect(service.tasks.single.runs.single.status, 'failed');
      expect(service.tasks.single.runs.single.error, contains('model_missing'));
      complete(async, service.runNow(task.id));
      async.flushMicrotasks();
      expect(service.tasks.single.runs, hasLength(2));
      service.dispose();
    });
  });

  test('desktop executions time out and cancel during setup', () {
    fakeAsync((async) {
      final desktop = DesktopScheduledTasks(
        store: _MemoryTaskStore(prefs, disk),
        now: () => DateTime(2026, 9, 11, 7),
      );
      final service = ScheduledTasksService(desktop: desktop);
      ScheduledRunCancellation? token;
      complete(
        async,
        service.attach((_, cancellation, _) {
          token = cancellation;
          return Completer<Map<String, Object?>>().future;
        }),
      );
      complete(async, service.save(task));
      complete(async, service.runNow(task.id));
      async.elapse(const Duration(minutes: 10));
      expect(token!.cancelled, isTrue);
      expect(service.tasks.single.runs.single.status, 'failed');
      expect(
        service.tasks.single.runs.single.error,
        contains('execution_timeout'),
      );
      service.dispose();
    });
  });
}
