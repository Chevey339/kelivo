import '../models/scheduled_task.dart';
import '../models/scheduled_task_payload.dart';
import 'scheduled_tasks_service.dart';

enum ScheduledTaskPreparationStatus {
  disabled,
  waiting,
  preparing,
  prepared,
  awaitingPublication,
  waitingForChat,
  queued,
  outsideWindow,
  cooldown,
  attemptsExhausted,
  hourlyLimit,
  unavailable,
}

abstract class ScheduledTaskPreparation {
  bool sameConfiguration(String before, String after) => true;
  Future<String> revision(ScheduledTask task);
  bool isBusy(ScheduledTask task);
  Future<ScheduledTaskPayload> prepare(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledRunCancellation cancellation,
  );
  Future<String> publish(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload payload,
  );
}
