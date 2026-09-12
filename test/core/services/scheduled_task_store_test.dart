import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/services/desktop_scheduled_tasks.dart';
import 'package:Kelivo/core/services/scheduled_task_store.dart';

import '../../support/business_test_harness.dart';

void main() {
  test(
    'SQLite persists task configuration, next run and conversation history',
    () async {
      final storage = await createBusinessTestHarness();
      final store = ScheduledTaskStore(storage.preferences);
      final task = ScheduledTask(
        id: 'task',
        name: 'Morning',
        prompt: 'Hello',
        assistantId: 'assistant',
        hour: 8,
        minute: 30,
        mode: ScheduledTaskMode.followUp,
        conversationId: 'chat',
        modelProvider: 'provider',
        modelId: 'model',
        startDate: DateTime(2026, 9, 11),
        endDate: DateTime(2026, 9, 30),
        nextRunAt: DateTime(2026, 9, 12, 8, 30),
        runs: [
          ScheduledTaskRun(
            id: 'run',
            startedAt: DateTime(2026, 9, 11, 8, 30),
            status: 'completed',
            conversationId: 'chat',
            preview: 'Reply',
          ),
        ],
      );
      await store.writeAll([task]);
      final reopened = ScheduledTaskStore(
        BusinessPreferences(storage.repository),
      );
      final saved = (await reopened.readAll()).single;
      expect(saved.toStoredJson(), task.toStoredJson());
    },
  );

  test(
    'corrupt SQLite task data is not overwritten by loading or saving',
    () async {
      final storage = await createBusinessTestHarness();
      await storage.preferences.setString(
        ScheduledTaskStore.preferenceKey,
        '[',
      );
      final desktop = DesktopScheduledTasks(
        store: ScheduledTaskStore(storage.preferences),
        now: () => DateTime(2026, 9, 11, 7),
      );
      addTearDown(desktop.dispose);
      await expectLater(desktop.load(), throwsStateError);
      await expectLater(
        desktop.save(
          const ScheduledTask(
            id: 't',
            name: 't',
            prompt: 't',
            assistantId: 'a',
            hour: 8,
            minute: 0,
          ),
        ),
        throwsStateError,
      );
      expect(
        storage.preferences.getString(ScheduledTaskStore.preferenceKey),
        '[',
      );
    },
  );

  test(
    'the restore write fence blocks starting a task before model execution',
    () async {
      final storage = await createBusinessTestHarness();
      final desktop = DesktopScheduledTasks(
        store: ScheduledTaskStore(storage.preferences),
        now: () => DateTime(2026, 9, 11, 7),
      );
      addTearDown(desktop.dispose);
      var executions = 0;
      await desktop.start((_, _) => executions++);
      await desktop.save(
        const ScheduledTask(
          id: 't',
          name: 't',
          prompt: 't',
          assistantId: 'a',
          hour: 8,
          minute: 0,
        ),
      );
      await storage.preferences.runWithRestoreWriteFence(() async {});
      await expectLater(desktop.runNow('t'), throwsStateError);
      expect(executions, 0);
      expect(desktop.tasks.single.runs, isEmpty);
    },
  );
}
