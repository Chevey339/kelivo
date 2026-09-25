import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/models/scheduled_task_payload.dart';
import 'package:Kelivo/core/services/notification_service.dart';
import 'package:Kelivo/core/services/scheduled_task_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.scheduled.notifications');
  final calls = <MethodCall>[];
  late IosScheduledTaskNotifications notifications;
  const task = ScheduledTask(
    id: 't',
    name: 'Task',
    prompt: 'Hello',
    assistantId: 'a',
    hour: 21,
    minute: 0,
  );
  final run = ScheduledTaskRun(
    id: 'scheduled:t:1:42',
    status: 'prepared',
    scheduledFor: DateTime(2026, 9, 19, 21),
  );
  const payload = ScheduledTaskPayload(
    text: 'Private result',
    title: 'Assistant',
    conversationId: 'c',
    messageId: 'm',
    contextRevision: 'v1',
    providerId: 'p',
    modelId: 'm',
  );
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'schedule' || call.method == 'permission'
              ? true
              : null;
        });
    notifications = IosScheduledTaskNotifications(
      channel: channel,
      reminderBody: () => 'Reminder',
      resultBody: () => 'Result ready',
    );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'uses run identity for scheduling and taps, independent of completion IDs',
    () async {
      await notifications.schedule(task, run, payload);
      final args = calls.single.arguments as Map;
      expect(args['body'], payload.text);
      expect(args['at'], run.scheduledFor!.millisecondsSinceEpoch);
      expect(args['prepared'], isTrue);
      expect(
        NotificationService.scheduledRunIdFromPayload(
          args['payload'] as String,
        ),
        run.id,
      );
      expect(
        NotificationService.conversationIdFromPayload(
          args['payload'] as String,
        ),
        isNull,
      );
      expect(
        NotificationService.scheduledRunIdFromPayload('scheduled-task:'),
        isNull,
      );
      await notifications.cancel(run.id);
      expect(calls.last.arguments, run.id);
    },
  );
  test(
    'global privacy hides already prepared bodies when notifications are rebuilt',
    () async {
      notifications.hideContent = true;
      await notifications.schedule(task, run, payload);
      final args = calls.single.arguments as Map;
      expect(args['body'], 'Result ready');
      expect(args['title'], 'Kelivo');
      expect(calls.where((c) => c.method == 'permission'), isEmpty);
    },
  );
  test('reminder explicitly differs from a prepared result', () async {
    await notifications.schedule(
      ScheduledTask.fromJson({...task.toJson(), 'unavailablePolicy': 'remind'}),
      run,
      null,
    );
    expect((calls.single.arguments as Map)['body'], 'Reminder');
    expect((calls.single.arguments as Map)['prepared'], isFalse);
  });
  test(
    'the default skips missing results but still notifies prepared content',
    () async {
      await notifications.schedule(task, run, null);
      expect(calls.single.method, 'cancel');
      calls.clear();
      await notifications.schedule(task, run, payload);
      expect(calls.single.method, 'schedule');
      expect((calls.single.arguments as Map)['body'], payload.text);
    },
  );
}
