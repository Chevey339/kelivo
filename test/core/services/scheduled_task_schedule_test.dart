import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/services/scheduled_task_schedule.dart';

ScheduledTask task({
  List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
  DateTime? onceDate,
  DateTime? startDate,
  DateTime? endDate,
}) => ScheduledTask(
  id: 'task',
  name: 'Daily',
  prompt: 'Hello',
  assistantId: 'assistant',
  hour: 8,
  minute: 0,
  weekdays: weekdays,
  onceDate: onceDate,
  startDate: startDate,
  endDate: endDate,
);

void main() {
  test(
    'daily recurrence is strictly in the future, including exact deadlines',
    () {
      expect(
        nextScheduledTaskRun(task(), DateTime(2026, 9, 11, 7, 59)),
        DateTime(2026, 9, 11, 8),
      );
      expect(
        nextScheduledTaskRun(task(), DateTime(2026, 9, 11, 8)),
        DateTime(2026, 9, 12, 8),
      );
      expect(
        nextScheduledTaskRun(task(), DateTime(2026, 9, 11, 8, 1)),
        DateTime(2026, 9, 12, 8),
      );
    },
  );

  test('workdays skip the weekend and custom days wrap to next week', () {
    expect(
      nextScheduledTaskRun(
        task(weekdays: [1, 2, 3, 4, 5]),
        DateTime(2026, 9, 11, 9),
      ),
      DateTime(2026, 9, 14, 8),
    );
    expect(
      nextScheduledTaskRun(task(weekdays: [5]), DateTime(2026, 9, 11, 9)),
      DateTime(2026, 9, 18, 8),
    );
  });

  test('active dates are inclusive and may start more than a week away', () {
    final value = task(
      startDate: DateTime(2027, 1, 1),
      endDate: DateTime(2027, 1, 2),
    );
    expect(
      nextScheduledTaskRun(value, DateTime(2026, 9, 11)),
      DateTime(2027, 1, 1, 8),
    );
    expect(
      nextScheduledTaskRun(value, DateTime(2027, 1, 1, 8)),
      DateTime(2027, 1, 2, 8),
    );
    expect(nextScheduledTaskRun(value, DateTime(2027, 1, 2, 8)), isNull);
  });

  test('one-time schedules expire without replay and respect active dates', () {
    final value = task(onceDate: DateTime(2026, 9, 11));
    expect(
      nextScheduledTaskRun(value, DateTime(2026, 9, 11, 7)),
      DateTime(2026, 9, 11, 8),
    );
    expect(nextScheduledTaskRun(value, DateTime(2026, 9, 11, 8)), isNull);
    expect(
      nextScheduledTaskRun(
        task(onceDate: DateTime(2026, 9, 11), startDate: DateTime(2026, 9, 12)),
        DateTime(2026, 9, 10),
      ),
      isNull,
    );
  });

  test('invalid days and reversed active dates are rejected', () {
    expect(
      () => nextScheduledTaskRun(task(weekdays: []), DateTime(2026)),
      throwsArgumentError,
    );
    expect(
      () => nextScheduledTaskRun(task(weekdays: [0, 8]), DateTime(2026)),
      throwsArgumentError,
    );
    expect(
      () => nextScheduledTaskRun(
        task(startDate: DateTime(2026, 9, 12), endDate: DateTime(2026, 9, 11)),
        DateTime(2026),
      ),
      throwsArgumentError,
    );
  });
}
