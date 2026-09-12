import 'dart:convert';

import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schedule settings retain target, model and local calendar dates', () {
    final task = ScheduledTask(
      id: 'schedule',
      name: 'Weekly analysis',
      prompt: '',
      assistantId: 'assistant',
      hour: 8,
      minute: 30,
      weekdays: const [1, 3, 5],
      mode: ScheduledTaskMode.regenerate,
      conversationId: 'chat',
      messageId: 'question',
      modelProvider: 'provider',
      modelId: 'model',
      startDate: DateTime(2026, 9, 12),
      endDate: DateTime(2026, 12, 31),
    );
    final json = task.toJson();
    expect(json['startDate'], '2026-09-12');
    expect(json['endDate'], '2026-12-31');
    final decoded = ScheduledTask.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), json);
    expect(decoded.mode, ScheduledTaskMode.regenerate);
    expect(decoded.repeat, ScheduledTaskRepeat.custom);
    expect(decoded.startDate?.isUtc, isFalse);
  });

  test(
    'one-time date distinguishes a one-off from daily and weekday schedules',
    () {
      ScheduledTask task({
        List<int> days = const [1, 2, 3, 4, 5, 6, 7],
        DateTime? once,
      }) => ScheduledTask(
        id: 'schedule',
        name: 'Task',
        prompt: 'Prompt',
        assistantId: 'assistant',
        hour: 8,
        minute: 0,
        weekdays: days,
        onceDate: once,
      );
      expect(task().repeat, ScheduledTaskRepeat.daily);
      expect(task(days: [5, 4, 3, 2, 1]).repeat, ScheduledTaskRepeat.weekdays);
      expect(task(days: [2, 4]).repeat, ScheduledTaskRepeat.custom);
      final once = task(once: DateTime(2026, 9, 12));
      expect(once.repeat, ScheduledTaskRepeat.once);
      expect(
        ScheduledTask.fromJson(once.toJson()).repeat,
        ScheduledTaskRepeat.once,
      );
    },
  );
}
