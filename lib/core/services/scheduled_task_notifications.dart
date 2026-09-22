import 'package:flutter/services.dart';

import '../models/scheduled_task.dart';
import '../models/scheduled_task_payload.dart';

abstract class ScheduledTaskNotifications {
  Future<bool> schedule(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload? payload,
  );
  Future<void> cancel(String runId);
  Future<Set<String>> pending();
  Future<bool> requestPermission();
  Future<void> beginPreparation();
  Future<void> endPreparation();
}

/// iOS owns only notification delivery and a finite background grace period.
class IosScheduledTaskNotifications implements ScheduledTaskNotifications {
  IosScheduledTaskNotifications({
    required this.reminderBody,
    required this.resultBody,
    MethodChannel? channel,
  }) : _channel =
           channel ?? const MethodChannel('app.scheduled_notifications') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'expired') await onExpiration?.call();
    });
  }
  Future<void> Function()? onExpiration;
  bool hideContent = false;
  final MethodChannel _channel;
  final String Function() reminderBody, resultBody;

  @override
  Future<bool> schedule(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload? payload,
  ) async {
    if (!task.notify ||
        payload == null &&
            task.unavailablePolicy == ScheduledTaskUnavailablePolicy.skip) {
      await cancel(run.id);
      return false;
    }
    return await _channel.invokeMethod<bool>('schedule', {
          'runId': run.id,
          'at': run.scheduledFor!.millisecondsSinceEpoch,
          'title': hideContent ? 'Kelivo' : payload?.title ?? task.name,
          'prepared': payload != null,
          'body': payload == null
              ? reminderBody()
              : task.showPreview && !hideContent
              ? payload.text
              : resultBody(),
          'payload': 'scheduled-task:${run.id}',
        }) ??
        false;
  }

  @override
  Future<void> cancel(String runId) =>
      _channel.invokeMethod<void>('cancel', runId);
  @override
  Future<Set<String>> pending() async =>
      (await _channel.invokeListMethod<String>('pending') ?? []).toSet();
  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('permission') ?? false;
  @override
  Future<void> beginPreparation() =>
      _channel.invokeMethod<void>('beginPreparation');
  @override
  Future<void> endPreparation() =>
      _channel.invokeMethod<void>('endPreparation');
}
