import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/models/scheduled_task_payload.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/scheduled_task_text_executor.dart';
import 'package:Kelivo/core/services/prepared_scheduled_tasks.dart';
import 'package:Kelivo/core/services/scheduled_task_notifications.dart';
import 'package:Kelivo/core/services/scheduled_task_store.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';
import '../../support/business_test_harness.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';
  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

class _Notifications implements ScheduledTaskNotifications {
  @override
  Future<Set<String>> pending() async => {};
  @override
  Future<bool> schedule(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload? payload,
  ) async => false;
  @override
  Future<void> cancel(String runId) async {}
  @override
  Future<void> beginPreparation() async {}
  @override
  Future<void> endPreparation() async {}
  @override
  Future<bool> requestPermission() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final policy in ScheduledTaskContextPolicy.values) {
    test(
      'due ${policy.name} publication retains the delivered body after later chat changes, without duplication',
      () async {
        final storage = await createBusinessTestHarness(
          initial: {
            'assistants_v1': jsonEncode([
              const Assistant(id: 'a', name: 'Assistant').toJson(),
            ]),
          },
        );
        final directory = await Directory.systemTemp.createTemp(
          'kelivo_scheduled_publication_',
        );
        final previousPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(directory.path);
        final repository = ChatDatabaseRepository(storage.database);
        final chat = ChatService(existingRepository: repository);
        final controller = ChatController(chatService: chat);
        final settings = SettingsProvider(storage.preferences);
        final assistants = AssistantProvider(preferences: storage.preferences);
        addTearDown(() async {
          controller.dispose();
          await chat.close();
          chat.dispose();
          settings.dispose();
          assistants.dispose();
          PathProviderPlatform.instance = previousPaths;
          await directory.delete(recursive: true);
        });
        await Future.wait([chat.init(), settings.loaded, assistants.loaded]);
        final conversation = await chat.createConversation(
          title: 'Chat',
          assistantId: 'a',
        );
        await chat.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'Original message',
        );
        await controller.setCurrentConversationAndLoad(
          chat.getConversation(conversation.id),
        );
        expect(controller.messages, hasLength(1));
        final preparedRevision = await repository.scheduledContextRevision(
          conversation.id,
        );
        await chat.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'After the notification',
        );
        final executor = ScheduledTaskTextExecutor(
          chat: chat,
          assistants: assistants,
          settings: settings,
          busy: (_) => false,
          promptConfiguration: (_) => null,
          buildContext: (_, _, _, _) async => [],
          onPublished: (id) async {
            if (controller.currentConversation?.id != id) return;
            controller.updateCurrentConversation(chat.getConversation(id));
            await controller.refreshTimelineAfterMutation();
          },
        );
        final task = ScheduledTask(
          id: 'task',
          name: 'Task',
          prompt: 'Scheduled instruction',
          assistantId: 'a',
          hour: 21,
          minute: 0,
          mode: ScheduledTaskMode.followUp,
          conversationId: conversation.id,
          contextPolicy: policy,
        );
        final run = ScheduledTaskRun(
          id: 'run',
          status: 'prepared',
          scheduledFor: DateTime(2026, 9, 19, 21),
        );
        final payload = ScheduledTaskPayload(
          text: 'Prepared reply',
          title: 'Assistant',
          conversationId: conversation.id,
          messageId: 'run:result',
          contextRevision: jsonEncode({
            'chat': preparedRevision,
            'config': 'old config',
          }),
          providerId: 'p',
          modelId: 'm',
        );
        await executor.publish(task, run, payload);
        expect(controller.messages.map((m) => m.content), [
          'Original message',
          'After the notification',
          'Scheduled instruction',
          'Prepared reply',
        ]);
        await executor.publish(task, run, payload);
        expect(controller.messages, hasLength(4));
        await chat.deleteConversation(conversation.id);
        await expectLater(
          executor.publish(task, run, payload),
          throwsStateError,
        );
        expect(chat.getConversation(conversation.id), isNull);
      },
    );
  }

  for (final mode in [ScheduledTaskMode.newChat, ScheduledTaskMode.followUp]) {
    test(
      'deleting the assistant while a due ${mode.name} result waits for chat prevents publication',
      () async {
        final storage = await createBusinessTestHarness(
          initial: {
            'assistants_v1': jsonEncode([
              const Assistant(id: 'a', name: 'Scheduled owner').toJson(),
              const Assistant(id: 'b', name: 'Other assistant').toJson(),
            ]),
          },
        );
        final directory = await Directory.systemTemp.createTemp(
          'kelivo_scheduled_owner_',
        );
        final previousPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(directory.path);
        final repository = ChatDatabaseRepository(storage.database);
        final chat = ChatService(existingRepository: repository);
        final settings = SettingsProvider(storage.preferences);
        final assistants = AssistantProvider(preferences: storage.preferences);
        final store = ScheduledTaskStore(storage.preferences);
        final due = DateTime(2026, 9, 19, 21);
        var busy = true;
        final scheduler =
            PreparedScheduledTasks(
                store: store,
                notifications: _Notifications(),
                now: () => due.add(const Duration(minutes: 1)),
              )
              ..preparation = ScheduledTaskTextExecutor(
                chat: chat,
                assistants: assistants,
                settings: settings,
                busy: (_) => busy,
                promptConfiguration: (_) =>
                    throw StateError('context_should_not_be_read_after_due'),
                buildContext: (_, _, _, _) async =>
                    throw StateError('must_not_generate'),
              );
        addTearDown(() async {
          scheduler.dispose();
          await chat.close();
          chat.dispose();
          settings.dispose();
          assistants.dispose();
          PathProviderPlatform.instance = previousPaths;
          await directory.delete(recursive: true);
        });
        await Future.wait([chat.init(), settings.loaded, assistants.loaded]);
        final conversation = mode == ScheduledTaskMode.followUp
            ? await chat.createConversation(
                title: 'Existing chat',
                assistantId: 'a',
              )
            : null;
        final count = chat.getAllConversations().length;
        final run = ScheduledTaskRun(
          id: 'run',
          status: 'prepared',
          scheduledFor: due,
          payloadId: 'run',
          prepareAttempts: 1,
        );
        final task = ScheduledTask(
          id: 'task',
          name: 'Task',
          prompt: 'Say hello',
          assistantId: 'a',
          hour: 21,
          minute: 0,
          mode: mode,
          conversationId: conversation?.id,
          onceDate: due,
          nextRunAt: due,
          allowPreparation: true,
          runs: [run],
        );
        final payload = ScheduledTaskPayload(
          text: 'Already delivered reply',
          title: 'Scheduled owner',
          conversationId: conversation?.id ?? 'scheduled-chat',
          messageId: 'run:result',
          contextRevision: '{}',
          providerId: 'p',
          modelId: 'm',
        );
        await store.writeAll([task]);
        await store.writeResults({
          'payloads': {run.id: payload.toJson()},
        });
        await scheduler.start(
          (_, _) => fail('A prepared occurrence must not run again'),
        );
        expect(scheduler.tasks.single.runs.single.status, 'prepared');
        expect(await assistants.deleteAssistant('a'), isTrue);
        busy = false;
        await scheduler.check();
        final failed = scheduler.tasks.single.runs.single;
        expect(failed.status, 'failed');
        expect(failed.error, contains('assistant_missing'));
        expect(failed.payloadId, isNull);
        expect(store.payload(await store.readResults(), run.id), isNull);
        expect(chat.getAllConversations(), hasLength(count));
        expect(await repository.getMessage(payload.messageId), isNull);
        await scheduler.check();
        expect(scheduler.tasks.single.runs.single.status, 'failed');
        expect(chat.getAllConversations(), hasLength(count));
      },
    );
  }
}
