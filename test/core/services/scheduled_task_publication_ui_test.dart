import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/models/scheduled_task_payload.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/scheduled_task_text_executor.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'prepared publication refreshes the open timeline and does not duplicate on reconciliation',
    () async {
      final storage = await createBusinessTestHarness();
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
        contextPolicy: ScheduledTaskContextPolicy.snapshot,
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
        contextRevision: '{}',
        providerId: 'p',
        modelId: 'm',
      );
      await executor.publish(task, run, payload);
      expect(controller.messages.map((m) => m.content), [
        'Original message',
        'Scheduled instruction',
        'Prepared reply',
      ]);
      await executor.publish(task, run, payload);
      expect(controller.messages, hasLength(3));
    },
  );
}
