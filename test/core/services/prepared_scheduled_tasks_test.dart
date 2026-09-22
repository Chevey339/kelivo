import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/models/scheduled_task_payload.dart';
import 'package:Kelivo/core/services/prepared_scheduled_tasks.dart';
import 'package:Kelivo/core/services/scheduled_task_notifications.dart';
import 'package:Kelivo/core/services/scheduled_task_preparation.dart';
import 'package:Kelivo/core/services/scheduled_task_store.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';

import '../../support/business_test_harness.dart';

class _Notifications implements ScheduledTaskNotifications {
  final pendingBodies = <String, String>{};
  int registrations = 0;
  bool allowed = true;
  @override
  Future<bool> schedule(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload? payload,
  ) async {
    registrations++;
    if (!allowed ||
        !task.notify ||
        payload == null &&
            task.unavailablePolicy == ScheduledTaskUnavailablePolicy.skip) {
      pendingBodies.remove(run.id);
      return false;
    }
    pendingBodies[run.id] = payload == null
        ? 'reminder'
        : task.showPreview
        ? payload.text
        : 'hidden';
    return true;
  }

  @override
  Future<void> cancel(String runId) async {
    pendingBodies.remove(runId);
  }

  @override
  Future<Set<String>> pending() async => pendingBodies.keys.toSet();
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<void> beginPreparation() async {}
  @override
  Future<void> endPreparation() async {}
}

class _Preparation extends ScheduledTaskPreparation {
  String context = 'v1';
  bool busy = false, missing = false;
  bool revisionFails = false;
  final revisionFailures = <String>{};
  int calls = 0;
  final preparedTasks = <String>[];
  Completer<void>? gate;
  ScheduledRunCancellation? cancellation;
  final published = <String, String>{};
  @override
  bool isBusy(ScheduledTask task) => busy;
  @override
  Future<String> revision(ScheduledTask task) async {
    if (revisionFails || revisionFailures.contains(task.id)) {
      throw StateError('database_busy');
    }
    if (missing) throw StateError('conversation_missing');
    return context;
  }

  @override
  Future<ScheduledTaskPayload> prepare(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledRunCancellation cancellation,
  ) async {
    calls++;
    preparedTasks.add(task.id);
    this.cancellation = cancellation;
    final original = context;
    await gate?.future;
    // Deliberately ignore cancellation to reproduce a late provider response.
    return ScheduledTaskPayload(
      text: 'reply $original',
      title: 'Assistant',
      conversationId: task.conversationId ?? '${run.id}:chat',
      messageId: '${run.id}:result',
      contextRevision: original,
      providerId: 'p',
      modelId: 'm',
    );
  }

  @override
  Future<String> publish(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload payload,
  ) async {
    if (missing) throw StateError('conversation_missing');
    published[payload.messageId] = payload.text;
    return payload.conversationId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness storage;
  late ScheduledTaskStore store;
  late _Notifications notifications;
  late _Preparation preparation;
  late PreparedScheduledTasks scheduler;
  late DateTime now;
  final executions = <String>[];

  ScheduledTask task({
    String id = 'task',
    bool allow = true,
    ScheduledTaskContextPolicy policy = ScheduledTaskContextPolicy.latest,
    ScheduledTaskUnavailablePolicy unavailable =
        ScheduledTaskUnavailablePolicy.remind,
    bool preview = true,
    bool once = false,
    String prompt = 'Hello',
  }) => ScheduledTask(
    id: id,
    name: 'Evening',
    prompt: prompt,
    assistantId: 'a',
    hour: 21,
    minute: 0,
    mode: ScheduledTaskMode.followUp,
    conversationId: 'chat',
    allowPreparation: allow,
    contextPolicy: policy,
    unavailablePolicy: unavailable,
    showPreview: preview,
    onceDate: once ? DateTime(2026, 9, 19) : null,
  );
  void onRun(String id, ScheduledTask _) {
    executions.add(id);
  }

  Future<void> settle() async {
    for (var i = 0; i < 100; i++) {
      if (!scheduler.tasks.any(
        (t) => t.runs.any((r) => r.status == 'preparing'),
      )) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Preparation did not settle');
  }

  ScheduledTaskRun run() => scheduler.tasks.first.runs.first;

  Future<void> waitForTap() async {
    for (var i = 0; i < 100; i++) {
      if (run().notificationState == 'interacted') {
        await Future<void>.delayed(Duration.zero);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Notification tap was not recorded');
  }

  setUp(() async {
    now = DateTime(2026, 9, 19, 20);
    executions.clear();
    storage = await createBusinessTestHarness();
    store = ScheduledTaskStore(storage.preferences);
    notifications = _Notifications();
    preparation = _Preparation();
    scheduler = PreparedScheduledTasks(
      store: store,
      notifications: notifications,
      now: () => now,
    )..preparation = preparation;
    await scheduler.start(onRun);
  });
  tearDown(() {
    scheduler.dispose();
  });

  test(
    'prepare now targets only the selected occurrence outside its automatic window',
    () async {
      for (final id in ['earlier', 'selected']) {
        await scheduler.save(
          ScheduledTask.fromJson({
            ...task(id: id).toJson(),
            'hour': id == 'earlier' ? 8 : 11,
            'preparationWindowMinutes': 5,
          }),
        );
      }
      final before = scheduler.tasks.last;
      expect(preparation.calls, 0);
      expect(
        await scheduler.prepareNow('selected'),
        ScheduledTaskPreparationStatus.preparing,
      );
      await settle();
      expect(preparation.preparedTasks, ['selected']);
      final prepared = scheduler.tasks.firstWhere((t) => t.id == 'selected');
      expect(prepared.nextRunAt, before.nextRunAt);
      expect(prepared.runs.single.id, before.runs.single.id);
      expect(prepared.runs.single.prepareAttempts, 1);
      expect(prepared.runs.single.status, 'prepared');
      expect(notifications.pendingBodies[prepared.runs.single.id], 'reply v1');
      expect(preparation.published, isEmpty);
      expect(executions, isEmpty);
      expect(
        await scheduler.prepareNow('selected'),
        ScheduledTaskPreparationStatus.prepared,
      );
      expect(preparation.calls, 1);
    },
  );

  test(
    'prepare now bypasses cooldown and an exhausted occurrence attempt limit',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      preparation.context = 'v2';
      expect(
        await scheduler.prepareNow('task'),
        ScheduledTaskPreparationStatus.preparing,
      );
      await settle();
      expect(run().id, id);
      expect(run().prepareAttempts, 2);
      expect(notifications.pendingBodies[id], 'reply v2');
      preparation.context = 'v3';
      await scheduler.check(prepare: true);
      expect(preparation.calls, 2);
      expect(
        scheduler.preparationStatus(scheduler.tasks.single),
        ScheduledTaskPreparationStatus.attemptsExhausted,
      );
      expect(
        await scheduler.prepareNow('task'),
        ScheduledTaskPreparationStatus.preparing,
      );
      await settle();
      expect(preparation.calls, 3);
      expect(run().prepareAttempts, 3);
      expect(run().id, id);
      expect(notifications.pendingBodies[id], 'reply v3');
      expect(preparation.published, isEmpty);

      // Manual work does not reset the budget or resume automatic requests.
      preparation.context = 'v4';
      await scheduler.check(prepare: true);
      expect(preparation.calls, 3);
      expect(
        scheduler.preparationStatus(scheduler.tasks.single),
        ScheduledTaskPreparationStatus.attemptsExhausted,
      );
    },
  );

  test(
    'repeated manual preparation is single-flight and reports busy work',
    () async {
      for (final id in ['one', 'two']) {
        await scheduler.save(
          ScheduledTask.fromJson({
            ...task(id: id).toJson(),
            'preparationWindowMinutes': 5,
          }),
        );
      }
      preparation.gate = Completer<void>();
      final results = await Future.wait([
        scheduler.prepareNow('one'),
        scheduler.prepareNow('one'),
      ]);
      expect(results, everyElement(ScheduledTaskPreparationStatus.preparing));
      expect(
        await scheduler.prepareNow('two'),
        ScheduledTaskPreparationStatus.queued,
      );
      expect(preparation.preparedTasks, ['one']);
      preparation.gate!.complete();
      await settle();
      preparation.busy = true;
      expect(
        await scheduler.prepareNow('two'),
        ScheduledTaskPreparationStatus.waitingForChat,
      );
      preparation.busy = false;
      expect(
        await scheduler.prepareNow('two'),
        ScheduledTaskPreparationStatus.preparing,
      );
      await settle();
      expect(preparation.preparedTasks, ['one', 'two']);
    },
  );

  test(
    'manual preflight failure records its reason and can be retried immediately',
    () async {
      await scheduler.save(
        ScheduledTask.fromJson({
          ...task().toJson(),
          'preparationWindowMinutes': 5,
        }),
      );
      preparation.revisionFails = true;
      expect(
        await scheduler.prepareNow('task'),
        ScheduledTaskPreparationStatus.unavailable,
      );
      expect(run().error, contains('database_busy'));
      expect(run().prepareAttempts, 0);
      preparation.revisionFails = false;
      expect(
        await scheduler.prepareNow('task'),
        ScheduledTaskPreparationStatus.preparing,
      );
      await settle();
      expect(run().error, isNull);
      expect(run().prepareAttempts, 1);
    },
  );

  test('manual preparation bypasses the global hourly limit', () async {
    for (var i = 0; i < 6; i++) {
      await scheduler.save(task(id: '$i'));
      await settle();
    }
    await scheduler.save(task(id: 'manual'));
    expect(
      scheduler.preparationStatus(scheduler.tasks.last),
      ScheduledTaskPreparationStatus.hourlyLimit,
    );
    expect(
      await scheduler.prepareNow('manual'),
      ScheduledTaskPreparationStatus.preparing,
    );
    await settle();
    expect(preparation.calls, 7);
    expect(preparation.preparedTasks.last, 'manual');
    final prepared = scheduler.tasks.last.runs.single;
    expect(prepared.status, 'prepared');
    expect(notifications.pendingBodies[prepared.id], 'reply v1');

    await scheduler.save(task(id: 'automatic'));
    await settle();
    expect(preparation.calls, 7);
    expect(
      scheduler.preparationStatus(scheduler.tasks.last),
      ScheduledTaskPreparationStatus.hourlyLimit,
    );

    preparation.context = 'v2';
    expect(
      await scheduler.prepareNow('manual'),
      ScheduledTaskPreparationStatus.preparing,
    );
    await settle();
    expect(preparation.calls, 8);
    expect(preparation.preparedTasks.last, 'manual');
    expect(notifications.pendingBodies[prepared.id], 'reply v2');
  });

  for (final change in [
    {'enabled': false},
    {'allowPreparation': false},
    {'mode': 'regenerate', 'messageId': 'question'},
  ]) {
    test('manual preparation respects task eligibility: $change', () async {
      await scheduler.save(
        ScheduledTask.fromJson({...task().toJson(), ...change}),
      );
      expect(
        await scheduler.prepareNow('task'),
        ScheduledTaskPreparationStatus.disabled,
      );
      expect(preparation.calls, 0);
      expect(executions, isEmpty);
    });
  }

  test(
    'manual preparation does not start a model request after a one-off task is due',
    () async {
      await scheduler.save(
        ScheduledTask.fromJson({
          ...task(once: true).toJson(),
          'preparationWindowMinutes': 5,
        }),
      );
      now = DateTime(2026, 9, 19, 21);
      expect(
        await scheduler.prepareNow('task'),
        ScheduledTaskPreparationStatus.waiting,
      );
      expect(preparation.calls, 0);
      expect(executions, isEmpty);
    },
  );

  test(
    'finishing one request drains earlier queued tasks without another trigger',
    () async {
      preparation.gate = Completer<void>();
      await scheduler.save(
        ScheduledTask.fromJson({...task(id: 'eleven').toJson(), 'hour': 11}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await scheduler.save(
        ScheduledTask.fromJson({...task(id: 'ten').toJson(), 'hour': 10}),
      );
      await scheduler.save(
        ScheduledTask.fromJson({...task(id: 'eight').toJson(), 'hour': 8}),
      );
      expect(preparation.calls, 1);
      expect(
        scheduler.preparationStatus(
          scheduler.tasks.firstWhere((t) => t.id == 'eleven'),
        ),
        ScheduledTaskPreparationStatus.preparing,
      );
      expect(
        scheduler.preparationStatus(
          scheduler.tasks.firstWhere((t) => t.id == 'eight'),
        ),
        ScheduledTaskPreparationStatus.queued,
      );
      preparation.gate!.complete();
      for (var i = 0; i < 100 && preparation.calls < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await settle();
      expect(preparation.preparedTasks, ['eleven', 'eight', 'ten']);
      expect(
        scheduler.tasks.every((t) => t.runs.first.status == 'prepared'),
        isTrue,
      );
      expect(
        scheduler.tasks.map(scheduler.preparationStatus),
        everyElement(ScheduledTaskPreparationStatus.prepared),
      );
    },
  );

  test(
    'unrelated activity does not keep postponing an eligible queued task',
    () async {
      preparation.busy = true;
      await scheduler.save(task());
      expect(
        scheduler.preparationStatus(scheduler.tasks.single),
        ScheduledTaskPreparationStatus.waitingForChat,
      );
      preparation.busy = false;
      for (var i = 0; i < 3; i++) {
        await scheduler.activityChanged();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      await settle();
      expect(preparation.calls, 1);
      expect(run().status, 'prepared');
    },
  );

  test(
    'a transient context read failure preserves prepared content and reports its cause',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      preparation.revisionFails = true;
      await scheduler.activityChanged();
      expect(run().status, 'prepared');
      expect(run().error, contains('database_busy'));
      expect(notifications.pendingBodies[id], 'reply v1');
      expect(store.payload(await store.readResults(), id)?.text, 'reply v1');
      preparation.revisionFails = false;
      await scheduler.activityChanged();
      expect(run().error, isNull);
      expect(preparation.calls, 1);
    },
  );

  for (final change in [
    {'showPreview': false},
    {'notify': false},
  ]) {
    test(
      'notification privacy still applies when context reads fail: $change',
      () async {
        await scheduler.save(task(once: true));
        await settle();
        final before = run();
        expect(notifications.pendingBodies[before.id], 'reply v1');
        preparation.revisionFails = true;
        await scheduler.save(
          ScheduledTask.fromJson({
            ...scheduler.tasks.single.toJson(),
            ...change,
          }),
        );
        final expectedBody = change['notify'] == false ? null : 'hidden';
        expect(notifications.pendingBodies[before.id], expectedBody);
        expect(run().status, 'prepared');
        expect(run().error, contains('database_busy'));
        expect(run().prepareAttempts, before.prepareAttempts);
        expect(
          store.payload(await store.readResults(), before.id)?.text,
          'reply v1',
        );

        now = now.add(const Duration(seconds: 31));
        preparation.revisionFails = false;
        await scheduler.check(validateContext: false);
        expect(run().error, isNull);
        expect(notifications.pendingBodies[before.id], expectedBody);
        now = before.scheduledFor!;
        await scheduler.check();
        expect(preparation.published, {'${before.id}:result': 'reply v1'});
        expect(preparation.calls, 1);
      },
    );
  }

  for (final change in ['context', 'read failure']) {
    test(
      'a due prepared result is published unchanged after $change on resume',
      () async {
        await scheduler.save(task(once: true));
        await settle();
        final id = run().id;
        await scheduler.lifecycle(false);
        now = DateTime(2026, 9, 20, 10);
        if (change == 'context') preparation.context = 'v2';
        if (change == 'read failure') preparation.revisionFails = true;
        await scheduler.lifecycle(true);
        expect(run().status, 'completed');
        expect(preparation.published, {'$id:result': 'reply v1'});
        expect(preparation.calls, 1);
        await scheduler.check();
        expect(preparation.published, hasLength(1));
      },
    );
  }

  test(
    'context checks that fail before generation are visible without spending attempts',
    () async {
      preparation.revisionFails = true;
      await scheduler.save(task());
      expect(run().status, 'pending');
      expect(run().error, contains('database_busy'));
      expect(run().prepareAttempts, 0);
      expect(preparation.calls, 0);
      expect(
        scheduler.preparationStatus(scheduler.tasks.single),
        ScheduledTaskPreparationStatus.unavailable,
      );
    },
  );

  test(
    'a failed earlier preflight does not block later tasks and retries after 30 seconds',
    () async {
      preparation.revisionFailures.add('eight');
      await scheduler.save(
        ScheduledTask.fromJson({...task(id: 'eight').toJson(), 'hour': 8}),
      );
      await scheduler.save(
        ScheduledTask.fromJson({...task(id: 'eleven').toJson(), 'hour': 11}),
      );
      await settle();
      expect(preparation.preparedTasks, ['eleven']);
      preparation.revisionFailures.clear();
      now = now.add(const Duration(seconds: 29));
      await scheduler.check(prepare: true, validateContext: false);
      expect(preparation.calls, 1);
      now = now.add(const Duration(seconds: 1));
      await scheduler.check(prepare: true, validateContext: false);
      await settle();
      expect(preparation.preparedTasks, ['eleven', 'eight']);
    },
  );

  test(
    'editing the preparation prompt invalidates the result while retaining its budget',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      await scheduler.save(
        ScheduledTask.fromJson({
          ...scheduler.tasks.single.toJson(),
          'preparationPrompt': '只输出一句自然的问候',
        }),
      );
      expect(run().id, id);
      expect(run().payloadId, isNull);
      expect(run().prepareAttempts, 1);
      expect(
        scheduler.preparationStatus(scheduler.tasks.single),
        ScheduledTaskPreparationStatus.cooldown,
      );
      expect(store.payload(await store.readResults(), id), isNull);
      expect(notifications.pendingBodies[id], 'reminder');
      now = now.add(const Duration(minutes: 10));
      await scheduler.check(prepare: true);
      await settle();
      expect(preparation.calls, 2);
      expect(run().prepareAttempts, 2);
      expect(run().status, 'prepared');
      preparation.context = 'v2';
      await scheduler.activityChanged();
      expect(
        scheduler.preparationStatus(scheduler.tasks.single),
        ScheduledTaskPreparationStatus.attemptsExhausted,
      );
    },
  );

  test(
    'stopping the scheduler prevents a finishing request from draining the queue',
    () async {
      preparation.gate = Completer<void>();
      await scheduler.save(task(id: 'first'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await scheduler.save(task(id: 'second'));
      scheduler.stop();
      preparation.gate!.complete();
      await settle();
      expect(preparation.preparedTasks, ['first']);
      expect(
        scheduler.tasks
            .expand((t) => t.runs)
            .where((r) => r.status == 'prepared'),
        isEmpty,
      );
    },
  );

  for (final trigger in ['activity', 'resume', 'privacy']) {
    for (final policy in ScheduledTaskUnavailablePolicy.values) {
      test(
        '$trigger check preserves a due foreground task (${policy.name})',
        () async {
          await scheduler.save(
            task(allow: false, once: true, unavailable: policy),
          );
          final id = run().id;
          if (trigger == 'resume') await scheduler.lifecycle(false);
          now = DateTime(2026, 9, 19, 21, 0, 1);
          switch (trigger) {
            case 'activity':
              await scheduler.activityChanged();
            case 'resume':
              await scheduler.lifecycle(true);
            case 'privacy':
              await scheduler.check(retryNotifications: true);
          }
          expect(run().id, id);
          expect(run().status, 'pending');
          expect(scheduler.tasks.single.enabled, isTrue);
          expect(scheduler.tasks.single.nextRunAt, DateTime(2026, 9, 19, 21));
          expect(executions, isEmpty);

          await scheduler.check(executeDue: true);
          await scheduler.check(executeDue: true);
          expect(run().status, 'running');
          expect(executions, [id]);
        },
      );
    }
  }

  for (final policy in ScheduledTaskUnavailablePolicy.values) {
    test(
      'a foreground task outside the execution window still ${policy.name}s',
      () async {
        await scheduler.save(
          task(allow: false, once: true, unavailable: policy),
        );
        now = DateTime(2026, 9, 19, 21, 0, 30);
        await scheduler.lifecycle(true);
        expect(
          run().status,
          policy == ScheduledTaskUnavailablePolicy.remind
              ? 'reminded'
              : 'skipped',
        );
        expect(scheduler.tasks.single.enabled, isFalse);
        await scheduler.check(executeDue: true);
        expect(executions, isEmpty);
      },
    );
  }

  test(
    'opening at noon prepares the next morning with the default window',
    () async {
      now = DateTime(2026, 9, 19, 12);
      final morning = ScheduledTask.fromJson(
        {...task().toJson(), 'hour': 8}..remove('preparationWindowMinutes'),
      );
      await scheduler.save(morning);
      await settle();

      expect(run().status, 'prepared');
      expect(run().scheduledFor, DateTime(2026, 9, 20, 8));
      expect(notifications.pendingBodies.values.single, 'reply v1');
      expect(preparation.published, isEmpty);
      await scheduler.lifecycle(false);
      expect(preparation.calls, 1);
    },
  );

  test(
    'preparation starts at the 24-hour boundary and keeps its due time',
    () async {
      now = DateTime(2026, 9, 19, 7, 59);
      await scheduler.save(
        ScheduledTask.fromJson({
          ...task().toJson(),
          'hour': 8,
          'onceDate': '2026-09-20',
        }),
      );
      await settle();
      expect(preparation.calls, 0);
      expect(run().status, 'pending');
      expect(
        scheduler.preparationStatus(scheduler.tasks.single),
        ScheduledTaskPreparationStatus.outsideWindow,
      );

      now = DateTime(2026, 9, 19, 8);
      await scheduler.check(prepare: true);
      await settle();
      expect(run().status, 'prepared');
      expect(run().scheduledFor, DateTime(2026, 9, 20, 8));
      expect(preparation.published, isEmpty);
      expect(scheduler.tasks.single.nextRunAt, DateTime(2026, 9, 20, 8));
    },
  );

  test(
    'preparation does not publish, advance the schedule or exhaust a one-shot task',
    () async {
      await scheduler.save(task(once: true));
      await settle();
      expect(run().status, 'prepared');
      expect(run().startedAt, now);
      expect(run().prepareAttempts, 1);
      expect(scheduler.tasks.single.nextRunAt, DateTime(2026, 9, 19, 21));
      expect(scheduler.tasks.single.enabled, isTrue);
      expect(scheduler.tasks.single.running, isFalse);
      expect(preparation.published, isEmpty);
      expect(notifications.pendingBodies.values.single, 'reply v1');
      await scheduler.check(prepare: true);
      expect(preparation.calls, 1);
    },
  );

  test(
    'latest context invalidates without generating; fixed time, run and budget survive',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      preparation.context = 'v2';
      await scheduler.activityChanged();
      expect(run().status, 'pending');
      expect(run().id, id);
      expect(notifications.pendingBodies[id], 'reminder');
      expect(preparation.calls, 1);
      await scheduler.lifecycle(false);
      expect(preparation.calls, 1); // cooldown
      now = now.add(const Duration(minutes: 11));
      await scheduler.lifecycle(false);
      await settle();
      expect(run().id, id);
      expect(run().prepareAttempts, 2);
      expect(notifications.pendingBodies[id], 'reply v2');
      preparation.context = 'v3';
      await scheduler.activityChanged();
      now = now.add(const Duration(minutes: 11));
      await scheduler.lifecycle(false);
      await settle();
      expect(preparation.calls, 2);
      expect(run().scheduledFor, DateTime(2026, 9, 19, 21));
    },
  );

  test(
    'reading or switching apps with unchanged context reuses one candidate',
    () async {
      await scheduler.save(task());
      await settle();
      for (var i = 0; i < 4; i++) {
        await scheduler.activityChanged();
        await scheduler.lifecycle(false);
        await scheduler.lifecycle(true);
      }
      expect(preparation.calls, 1);
      expect(run().status, 'prepared');
    },
  );

  test(
    'snapshot mode retains content but cannot revive a deleted target',
    () async {
      await scheduler.save(task(policy: ScheduledTaskContextPolicy.snapshot));
      await settle();
      preparation.context = 'v2';
      await scheduler.activityChanged();
      expect(run().status, 'prepared');
      preparation.missing = true;
      await scheduler.activityChanged();
      expect(run().status, 'pending');
      expect(notifications.pendingBodies.values.single, 'reminder');
      now = DateTime(2026, 9, 19, 21);
      await scheduler.check();
      expect(preparation.published, isEmpty);
    },
  );

  test('a late result cannot resurrect invalidated content', () async {
    preparation.gate = Completer<void>();
    await scheduler.save(task());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(run().status, 'preparing');
    preparation.context = 'v2';
    await scheduler.activityChanged();
    preparation.gate!.complete();
    await settle();
    expect(run().status, 'pending');
    expect(notifications.pendingBodies.values.single, 'reminder');
    expect(store.payload(await store.readResults(), run().id), isNull);
  });

  test(
    'editing the prompt keeps this occurrence and consumes no extra budget during cooldown',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      await scheduler.save(task(prompt: 'Different'));
      await settle();
      expect(run().id, id);
      expect(run().prepareAttempts, 1);
      expect(preparation.calls, 1);
      expect(run().status, 'pending');
      expect(notifications.pendingBodies.values.single, 'reminder');
    },
  );

  for (final change in [
    <String, dynamic>{},
    {'showPreview': false},
    {'notify': false},
    {'unavailablePolicy': 'skip'},
  ]) {
    test(
      'notification-only save preserves the prepared result: $change',
      () async {
        await scheduler.save(
          ScheduledTask.fromJson({
            ...task(once: true).toJson(),
            'maxPrepareAttempts': 1,
          }),
        );
        await settle();
        final before = run();
        final old = scheduler.tasks.single;
        // The form submits a definition, without runtime history or revisions.
        await scheduler.save(
          ScheduledTask.fromJson({...old.toJson(), 'revision': 0, ...change}),
        );
        await settle();
        expect(run().status, 'prepared');
        expect(run().id, before.id);
        expect(run().preparedAt, before.preparedAt);
        expect(run().prepareAttempts, 1);
        expect(scheduler.tasks.single.revision, old.revision);
        expect(scheduler.tasks.single.nextRunAt, old.nextRunAt);
        expect(
          store.payload(await store.readResults(), before.id)?.text,
          'reply v1',
        );
        expect(
          notifications.pendingBodies[before.id],
          change['notify'] == false
              ? null
              : change['showPreview'] == false
              ? 'hidden'
              : 'reply v1',
        );
        expect(preparation.calls, 1);

        now = DateTime(2026, 9, 19, 21);
        await scheduler.check();
        expect(preparation.published, {'${before.id}:result': 'reply v1'});
        expect(preparation.calls, 1);
      },
    );
  }

  test(
    'notification toggle reuses the result without another preparation',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      for (final notify in [false, true]) {
        await scheduler.save(
          ScheduledTask.fromJson({
            ...scheduler.tasks.single.toJson(),
            'notify': notify,
          }),
        );
        expect(run().status, 'prepared');
        expect(notifications.pendingBodies[id], notify ? 'reply v1' : null);
      }
      expect(preparation.calls, 1);
    },
  );

  test(
    'preview edit keeps an in-flight preparation and applies the new privacy',
    () async {
      preparation.gate = Completer<void>();
      await scheduler.save(task());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(run().status, 'preparing');
      final id = run().id;
      await scheduler.save(task(preview: false));
      expect(run().status, 'preparing');
      expect(preparation.cancellation!.cancelled, isFalse);
      preparation.gate!.complete();
      await settle();
      expect(run().status, 'prepared');
      expect(notifications.pendingBodies[id], 'hidden');
      expect(preparation.calls, 1);
    },
  );

  test(
    'preview edit preserves a due one-shot result waiting for chat to finish',
    () async {
      await scheduler.save(task(once: true));
      await settle();
      final before = run();
      preparation.busy = true;
      now = DateTime(2026, 9, 19, 21);
      await scheduler.save(task(once: true, preview: false));
      expect(run().id, before.id);
      expect(run().status, 'prepared');
      expect(scheduler.tasks.single.nextRunAt, before.scheduledFor);
      preparation.busy = false;
      await scheduler.check();
      expect(preparation.published, {'${before.id}:result': 'reply v1'});
    },
  );

  for (final mode in [ScheduledTaskMode.newChat, ScheduledTaskMode.followUp]) {
    test(
      'a busy ${mode.name} notification tap waits for publication before navigation',
      () async {
        await scheduler.save(
          ScheduledTask.fromJson({
            ...task(once: true).toJson(),
            'mode': mode.name,
            'conversationId': mode == ScheduledTaskMode.newChat ? null : 'chat',
          }),
        );
        await settle();
        final id = run().id;
        preparation.busy = true;
        now = DateTime(2026, 9, 19, 21);
        var navigated = false;
        final navigation = scheduler.notificationTapped(id).then((value) {
          navigated = true;
          return value;
        });
        await waitForTap();
        expect(navigated, isFalse);
        expect(preparation.published, isEmpty);
        expect(run().notificationState, 'interacted');
        preparation.busy = false;
        await scheduler.check();
        expect(
          await navigation,
          mode == ScheduledTaskMode.newChat ? '$id:chat' : 'chat',
        );
        expect(preparation.published, {'$id:result': 'reply v1'});
        await scheduler.check();
        expect(preparation.published, hasLength(1));
      },
    );
  }

  for (final action in ['delete', 'dispose']) {
    test('$action clears a notification tap waiting for publication', () async {
      await scheduler.save(task(once: true));
      await settle();
      final id = run().id;
      preparation.busy = true;
      now = DateTime(2026, 9, 19, 21);
      var navigated = false;
      final navigation = scheduler.notificationTapped(id).then((value) {
        navigated = true;
        return value;
      });
      await waitForTap();
      expect(navigated, isFalse);
      if (action == 'delete') {
        await scheduler.delete('task');
      } else {
        scheduler.dispose();
        scheduler = PreparedScheduledTasks(
          store: store,
          notifications: notifications,
        );
      }
      expect(await navigation, isNull);
      expect(preparation.published, isEmpty);
    });
  }

  test(
    'disable and delete cancel a prepared notification and discard its payload',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      await scheduler.save(scheduler.tasks.single, enabled: false);
      expect(notifications.pendingBodies, isEmpty);
      expect(store.payload(await store.readResults(), id), isNull);
      await scheduler.delete('task');
      expect(scheduler.tasks, isEmpty);
    },
  );

  test(
    'reenabling before the deadline reuses the cancelled occurrence and its budget',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      await scheduler.save(scheduler.tasks.single, enabled: false);
      await scheduler.save(scheduler.tasks.single, enabled: true);
      expect(run().id, id);
      expect(run().status, 'pending');
      expect(run().prepareAttempts, 1);
      expect(notifications.pendingBodies[id], 'reminder');
      now = now.add(const Duration(minutes: 11));
      await scheduler.lifecycle(false);
      await settle();
      expect(run().status, 'prepared');
      expect(run().prepareAttempts, 2);
    },
  );

  test(
    'manual history pruning cannot remove a future prepared occurrence',
    () async {
      await scheduler.save(task());
      await settle();
      final id = run().id;
      for (var i = 0; i < 23; i++) {
        await scheduler.runNow('task');
        await scheduler.updateRun(executions.last, {'status': 'completed'});
      }
      expect(
        scheduler.tasks.single.runs.any(
          (r) => r.id == id && r.status == 'prepared',
        ),
        isTrue,
      );
      now = DateTime(2026, 9, 19, 21);
      await scheduler.check();
      expect(preparation.published, {'$id:result': 'reply v1'});
    },
  );

  test(
    'restart reconciles the exact prepared result once and only then exhausts one-shot',
    () async {
      await scheduler.save(task(once: true));
      await settle();
      final id = run().id;
      scheduler.dispose();
      now = DateTime(2026, 9, 20, 10);
      scheduler = PreparedScheduledTasks(
        store: ScheduledTaskStore(storage.preferences),
        notifications: notifications,
        now: () => now,
      )..preparation = preparation;
      await scheduler.start(onRun);
      expect(preparation.published, {'$id:result': 'reply v1'});
      expect(scheduler.tasks.single.enabled, isFalse);
      expect(run().status, 'completed');
      await scheduler.check();
      expect(preparation.published, hasLength(1));
      expect(preparation.calls, 1);
      expect(await scheduler.notificationTapped(id), 'chat');
      expect(run().notificationState, 'interacted');
    },
  );

  test(
    'foreground due execution uses the same occurrence; manual run does not consume it',
    () async {
      await scheduler.save(task(allow: false));
      final dueId = run().id;
      await scheduler.runNow('task');
      final manualId = executions.single;
      expect(manualId, isNot(dueId));
      await scheduler.updateRun(manualId, {'status': 'completed'});
      now = DateTime(2026, 9, 19, 21);
      await scheduler.check(executeDue: true);
      expect(executions, [manualId, dueId]);
      await scheduler.check(executeDue: true);
      expect(executions, hasLength(2));
    },
  );

  test(
    'returning after missed days prepares only the next occurrence',
    () async {
      await scheduler.save(task());
      await settle();
      final originalId = run().id;
      now = DateTime(2026, 9, 23, 10);
      await scheduler.lifecycle(true);
      await settle();
      expect(preparation.published, {'$originalId:result': 'reply v1'});
      expect(preparation.calls, 2); // One old result and today's upcoming run.
      expect(scheduler.tasks.single.runs, hasLength(2));
      expect(run().status, 'prepared');
      expect(run().scheduledFor, DateTime(2026, 9, 23, 21));
      expect(executions, isEmpty);
      expect(scheduler.tasks.single.nextRunAt, DateTime(2026, 9, 23, 21));
    },
  );

  test(
    'reply in progress defers publication without advancing or duplicating the run',
    () async {
      await scheduler.save(task(policy: ScheduledTaskContextPolicy.snapshot));
      await settle();
      final id = run().id;
      preparation.busy = true;
      now = DateTime(2026, 9, 19, 21);
      await scheduler.check(executeDue: true);
      expect(preparation.published, isEmpty);
      expect(run().id, id);
      preparation.busy = false;
      await scheduler.check(executeDue: true);
      expect(preparation.published, {'$id:result': 'reply v1'});
    },
  );

  test(
    'permission denial does not repeatedly register or claim delivery',
    () async {
      notifications.allowed = false;
      await scheduler.save(task(allow: false));
      final count = notifications.registrations;
      for (var i = 0; i < 5; i++) {
        await scheduler.check();
      }
      expect(notifications.registrations, count);
      expect(run().notificationState, 'unavailable');
      notifications.allowed = true;
      await scheduler.lifecycle(true);
      expect(run().notificationState, 'registered');
    },
  );

  test(
    'hidden previews still publish the actual saved body; skip creates no reminder',
    () async {
      await scheduler.save(task(preview: false));
      await settle();
      expect(notifications.pendingBodies.values.single, 'hidden');
      now = DateTime(2026, 9, 19, 21);
      await scheduler.check();
      expect(preparation.published.values.single, 'reply v1');
      await scheduler.delete('task');
      await scheduler.save(
        task(
          id: 'skip',
          allow: false,
          unavailable: ScheduledTaskUnavailablePolicy.skip,
        ),
      );
      expect(notifications.pendingBodies, isEmpty);
    },
  );

  test(
    'global hourly budget and single-flight hold across many tasks',
    () async {
      for (var i = 0; i < 9; i++) {
        await scheduler.save(task(id: '$i'));
        await settle();
      }
      for (var i = 0; i < 9; i++) {
        await scheduler.check(prepare: true);
        await settle();
      }
      expect(preparation.calls, 6);
      expect(
        scheduler.tasks
            .where((t) => t.runs.first.status == 'pending')
            .map(scheduler.preparationStatus),
        everyElement(ScheduledTaskPreparationStatus.hourlyLimit),
      );
      expect(
        scheduler.tasks
            .expand((t) => t.runs)
            .where((r) => r.status == 'prepared'),
        hasLength(6),
      );
    },
  );
}
