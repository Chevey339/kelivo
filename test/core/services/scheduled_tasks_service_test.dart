import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.scheduled.bridge');
  final calls = <MethodCall>[];
  late ScheduledTasksService service;
  const task = ScheduledTask(
    id: 'task',
    name: 'Daily',
    prompt: 'Do this',
    assistantId: 'assistant',
    hour: 8,
    minute: 0,
  );
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'list') {
            return {'tasks': <String>[], 'exactAlarms': true};
          }
          return null;
        });
    service = ScheduledTasksService(channel: channel);
  });
  tearDown(() => service.dispose());

  Future<void> native(String method, Object? args) async {
    final reply = Completer<void>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, args),
          ),
          (_) => reply.complete(),
        );
    await reply.future;
  }

  Map<String, String> run(String id) => {
    'runId': id,
    'task': jsonEncode(task.toJson()),
  };

  test(
    'native handoff returns immediately and duplicate active delivery is ignored',
    () async {
      var executions = 0;
      final gate = Completer<Map<String, Object?>>();
      await service.attach((task, cancellation, onConversation) async {
        executions++;
        await onConversation('new-conversation');
        return gate.future;
      });
      await native('run', run('run-1'));
      await native('run', run('run-1'));
      expect(executions, 1);
      expect(calls.where((c) => c.method == 'finish'), isEmpty);
      gate.complete({'status': 'completed', 'preview': 'done'});
      await pumpEventQueue();
      final result =
          calls.singleWhere((c) => c.method == 'finish').arguments as Map;
      expect(result['runId'], 'run-1');
      expect(result['preview'], 'done');
    },
  );

  test('cancellation remains visible when it arrives during setup', () async {
    final gate = Completer<void>();
    await service.attach((task, cancellation, onConversation) async {
      await gate.future;
      cancellation.check();
      return {'status': 'completed'};
    });
    await native('run', run('run-2'));
    await native('cancel', 'run-2');
    gate.complete();
    await pumpEventQueue();
    final result =
        calls.singleWhere((c) => c.method == 'finish').arguments as Map;
    expect(result['status'], 'failed');
    expect(result['error'], contains('cancelled'));
  });

  test(
    'a cleanup failure does not lose the original execution error',
    () async {
      await service.attach((task, cancellation, onConversation) async {
        cancellation.onCancel = () async => throw StateError('cleanup_failed');
        throw StateError('model_failed');
      });
      await native('run', run('run-3'));
      await pumpEventQueue();
      final result =
          calls.singleWhere((c) => c.method == 'finish').arguments as Map;
      expect(result['error'], contains('model_failed'));
    },
  );
}
