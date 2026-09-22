import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/models/scheduled_task_payload.dart';
import 'package:Kelivo/core/services/prepared_scheduled_tasks.dart';
import 'package:Kelivo/core/services/scheduled_task_notifications.dart';
import 'package:Kelivo/core/services/scheduled_task_preparation.dart';
import 'package:Kelivo/core/services/scheduled_task_store.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';
import '../../support/business_test_harness.dart';

class _Preparation extends ScheduledTaskPreparation {
  bool busy = true;
  Completer<void>? gate;
  final preparedTasks = <String>[];

  @override
  bool isBusy(ScheduledTask task) => busy;

  @override
  Future<String> revision(ScheduledTask task) async => 'context';

  @override
  Future<ScheduledTaskPayload> prepare(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledRunCancellation cancellation,
  ) async {
    preparedTasks.add(task.id);
    await gate?.future;
    return ScheduledTaskPayload(
      text: 'Prepared ${task.id}',
      title: 'Assistant',
      conversationId: '${run.id}:chat',
      messageId: '${run.id}:result',
      contextRevision: 'context',
      providerId: 'provider',
      modelId: 'model',
    );
  }

  @override
  Future<String> publish(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload payload,
  ) async => throw StateError('must_not_publish_early');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iOS management binds local persistence and notifications, never the desktop scheduler or Android channel',
    () async {
      final storage = await createBusinessTestHarness();
      final methods = <String>[];
      const notifications = MethodChannel('app.scheduled_notifications');
      const android = MethodChannel('app.scheduled_tasks');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(notifications, (call) async {
        methods.add(call.method);
        if (call.method == 'pending') return <String>[];
        return true;
      });
      messenger.setMockMethodCallHandler(android, (call) async {
        fail('Android method called on iOS: ${call.method}');
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        ScheduledTasksService.instance.dispose();
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(notifications, null);
        messenger.setMockMethodCallHandler(android, null);
      });
      ScheduledTasksService.configureDevice(storage.preferences);
      final service = ScheduledTasksService.instance;
      expect(ScheduledTasksService.supported, isTrue);
      expect(service.isIOS, isTrue);
      expect(service.isDesktop, isFalse);
      await service.refresh();
      expect(service.loaded, isTrue);
      expect(service.error, isNull);
      expect(methods, ['pending']);
    },
  );

  group('iOS permission updates', () {
    const channel = MethodChannel('test.scheduled.permission');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    final pending = <String, String>{};
    late bool allowed;
    late _Preparation preparation;
    late PreparedScheduledTasks scheduler;
    late ScheduledTasksService service;

    ScheduledTask task(String id, {int window = 120}) => ScheduledTask(
      id: id,
      name: id,
      prompt: 'Say hello',
      assistantId: 'assistant',
      hour: id == 'selected' ? 11 : 8,
      minute: 0,
      allowPreparation: true,
      preparationWindowMinutes: window,
    );

    setUp(() async {
      final storage = await createBusinessTestHarness();
      allowed = true;
      calls.clear();
      pending.clear();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'pending':
            return pending.keys.toList();
          case 'permission':
            return allowed;
          case 'schedule':
            final args = call.arguments as Map;
            if (allowed) {
              pending[args['runId'] as String] = args['body'] as String;
            }
            return allowed;
          case 'cancel':
            pending.remove(call.arguments);
        }
        return null;
      });
      preparation = _Preparation();
      scheduler = PreparedScheduledTasks(
        store: ScheduledTaskStore(storage.preferences),
        notifications: IosScheduledTaskNotifications(
          reminderBody: () => 'Reminder',
          resultBody: () => 'Result',
          channel: channel,
        ),
        now: () => DateTime(2026, 9, 21, 7),
      )..preparation = preparation;
      service = ScheduledTasksService(prepared: scheduler);
      addTearDown(() async {
        service.dispose();
        if (preparation.gate?.isCompleted == false) {
          preparation.gate!.complete();
        }
        await pumpEventQueue();
        messenger.setMockMethodCallHandler(channel, null);
      });
      await scheduler.start((_, _) => fail('must_not_execute_early'));
    });

    for (final permissionAllowed in [true, false]) {
      test(
        'permission then prepare now selects the requested task outside its automatic window (allowed=$permissionAllowed)',
        () async {
          allowed = permissionAllowed;
          await service.save(task('automatic'));
          await service.save(task('selected', window: 5));
          preparation.busy = false;
          preparation.gate = Completer<void>();

          // Use the real service calls in the same order as the task menu.
          await service.requestPermission();
          expect(
            calls.where((call) => call.method == 'permission'),
            hasLength(1),
          );
          expect(preparation.preparedTasks, isEmpty);
          expect(
            await service.prepareNow('selected'),
            ScheduledTaskPreparationStatus.preparing,
          );
          await pumpEventQueue();
          expect(preparation.preparedTasks, ['selected']);
          expect(
            service.tasks
                .firstWhere((task) => task.id == 'automatic')
                .runs
                .single
                .prepareAttempts,
            0,
          );
        },
      );
    }

    test(
      'permission refresh preserves prepared results and lifecycle state',
      () async {
        allowed = false;
        preparation.busy = false;
        await service.save(task('selected', window: 1440));
        await pumpEventQueue();
        final prepared = service.tasks.single.runs.single;
        expect(prepared.status, 'prepared');
        expect(prepared.notificationState, 'unavailable');
        expect(pending, isEmpty);

        preparation.busy = true;
        await service.save(task('automatic'));
        preparation.busy = false;
        scheduler.foreground = false;
        allowed = true;
        await service.requestPermission();
        await pumpEventQueue();

        final updated = service.tasks
            .firstWhere((task) => task.id == 'selected')
            .runs
            .single;
        expect(updated.id, prepared.id);
        expect(updated.payloadId, prepared.payloadId);
        expect(updated.prepareAttempts, prepared.prepareAttempts);
        expect(updated.notificationState, 'registered');
        expect(pending[updated.id], 'Prepared selected');
        expect(preparation.preparedTasks, ['selected']);
        expect(scheduler.foreground, isFalse);
      },
    );
  });
}
