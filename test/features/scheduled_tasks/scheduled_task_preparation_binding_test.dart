import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/models/scheduled_task_payload.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/memory_provider_v2.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/memory/memory_repository.dart';
import 'package:Kelivo/core/services/prepared_scheduled_tasks.dart';
import 'package:Kelivo/core/services/scheduled_task_notifications.dart';
import 'package:Kelivo/core/services/scheduled_task_preparation.dart';
import 'package:Kelivo/core/services/scheduled_task_store.dart';
import 'package:Kelivo/core/services/scheduled_task_text_executor.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/scheduled_tasks/scheduled_task_preparation_binding.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../support/business_test_harness.dart';

class _Chat extends ChatService {
  _Chat(this.repository);
  final ChatDatabaseRepository repository;
  @override
  ChatDatabaseRepository get chatRepositoryOrNull => repository;
  @override
  Future<void> init() async {}
}

class _Notifications implements ScheduledTaskNotifications {
  final bodies = <String, String>{};
  final cancelled = <String>[];
  final finished = Completer<void>();
  @override
  Future<bool> schedule(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload? payload,
  ) async {
    bodies[run.id] = payload?.text ?? 'reminder';
    return true;
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    bodies.remove(id);
  }

  @override
  Future<Set<String>> pending() async => bodies.keys.toSet();
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> beginPreparation() async {}
  @override
  Future<void> endPreparation() async {
    if (!finished.isCompleted) finished.complete();
  }
}

// Use the real binding, context and revision code. Replace only model I/O so
// tests can hold a response in flight while persisted memory changes.
class _Preparation extends ScheduledTaskPreparation {
  _Preparation(this.executor);
  final ScheduledTaskTextExecutor executor;
  final captured = Completer<void>();
  Completer<void>? gate;
  int calls = 0;
  final published = <String>[];
  @override
  bool isBusy(ScheduledTask task) => executor.isBusy(task);
  @override
  Future<String> revision(ScheduledTask task) => executor.revision(task);
  @override
  bool sameConfiguration(String a, String b) =>
      executor.sameConfiguration(a, b);
  @override
  Future<ScheduledTaskPayload> prepare(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledRunCancellation cancellation,
  ) async {
    calls++;
    final revision = await executor.revision(task);
    final context = await executor.buildContext(
      task,
      executor.assistants.getById(task.assistantId)!,
      null,
      'm',
    );
    if (!captured.isCompleted) captured.complete();
    await gate
        ?.future; // Deliberately allow a cancelled provider to return late.
    return ScheduledTaskPayload(
      text: jsonEncode(context),
      title: 'Assistant',
      conversationId: 'chat',
      messageId: '${run.id}:result',
      contextRevision: revision,
      providerId: 'p',
      modelId: 'm',
    );
  }

  @override
  Future<String> publish(
    ScheduledTask task,
    ScheduledTaskRun run,
    ScheduledTaskPayload payload,
  ) async {
    published.add(payload.text);
    return payload.conversationId;
  }
}

class _Service extends ScheduledTasksService {
  _Service({required super.prepared});
  late _Preparation preparation;
  @override
  Future<void> configurePreparation(ScheduledTaskPreparation value) async {
    preparation = _Preparation(value as ScheduledTaskTextExecutor);
    await super.configurePreparation(preparation);
  }
}

void main() {
  const assistant = Assistant(
    id: 'a',
    name: 'Assistant',
    systemPrompt: '',
    enableMemory: true,
  );
  const other = Assistant(id: 'other', name: 'Other');
  const task = ScheduledTask(
    id: 'task',
    name: 'Task',
    prompt: 'Hello',
    assistantId: 'a',
    hour: 21,
    minute: 0,
    allowPreparation: true,
    modelProvider: 'p',
    modelId: 'm',
  );
  late BusinessTestHarness storage;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late MemoryProviderV2 memories;
  late MemoryProvider legacyMemories;
  late MessageBuilderService builder;
  late UserProvider user;
  late InstructionInjectionProvider instructions;
  late WorldBookProvider books;
  late _Chat chat;
  late ChatController controller;
  late _Notifications notifications;
  late PreparedScheduledTasks scheduler;
  late _Service service;
  late ScheduledTaskPreparationBinding binding;
  late DateTime now;
  late String memoryId;

  setUp(() async {
    storage = await createBusinessTestHarness(
      initial: {
        'assistants_v1': jsonEncode([assistant.toJson(), other.toJson()]),
      },
    );
    settings = SettingsProvider(storage.preferences);
    assistants = AssistantProvider(preferences: storage.preferences);
    instructions = InstructionInjectionProvider(
      preferences: storage.preferences,
    );
    books = WorldBookProvider(preferences: storage.preferences);
    user = UserProvider(preferences: storage.preferences);
    final repo = ChatDatabaseRepository(storage.database);
    chat = _Chat(repo);
    controller = ChatController(chatService: chat);
    final memoryRepository = MemoryRepository(storage.preferences);
    memories = MemoryProviderV2(
      repository: memoryRepository,
      chatRepository: repo,
    );
    legacyMemories = MemoryProvider(preferences: storage.preferences);
    await legacyMemories.initialize();
    await legacyMemories.add(assistantId: 'a', content: 'Lives in Berlin');
    await legacyMemories.add(
      assistantId: 'other',
      content: 'Other assistant memory',
    );
    await Future.wait([settings.loaded, assistants.loaded]);
    await settings.setMemoryPromptLang('en');
    await settings.setProviderConfig(
      'p',
      ProviderConfig(
        id: 'p',
        enabled: true,
        name: 'Test',
        apiKey: '',
        baseUrl: 'http://unused.invalid',
        models: ['m'],
      ),
    );
    await memoryRepository.putProfileField(
      'location',
      'Paris',
      MemorySource.manual,
    );
    for (final content in ['Quiet mornings', 'Coffee before work']) {
      final memory = await memoryRepository.create(
        scope: MemoryScope.assistant,
        assistantId: 'a',
        type: MemoryType.identity,
        content: content,
        source: MemorySource.manual,
      );
      memoryId = memory.id;
    }
    // The memory UI is viewing another assistant; its cache is not the input
    // for this task's revision calculation.
    await memories.initialize(assistantId: 'other');
    now = DateTime(2026, 9, 19, 20);
    notifications = _Notifications();
    scheduler = PreparedScheduledTasks(
      store: ScheduledTaskStore(storage.preferences),
      notifications: notifications,
      now: () => now,
    );
    service = _Service(prepared: scheduler);
    binding = ScheduledTaskPreparationBinding(service);
  });
  tearDown(() {
    binding.dispose();
    service.dispose();
    controller.dispose();
    chat.dispose();
    assistants.dispose();
    settings.dispose();
    memories.dispose();
    legacyMemories.dispose();
    instructions.dispose();
    books.dispose();
    user.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<MemoryProviderV2>.value(value: memories),
          ChangeNotifierProvider<MemoryProvider>.value(value: legacyMemories),
          ChangeNotifierProvider<InstructionInjectionProvider>.value(
            value: instructions,
          ),
          ChangeNotifierProvider<WorldBookProvider>.value(value: books),
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<ChatService>.value(value: chat),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      builder = MessageBuilderService(
        chatService: chat,
        contextProvider: context,
      );
      await binding.attach(context, builder, controller);
      await scheduler.start((_, _) {});
    });
    expect(memories.entries, isEmpty);
  }

  Future<void> waitFor(String status) async {
    for (var i = 0; i < 200; i++) {
      final run = scheduler.tasks.single.runs.first;
      if (run.status == status &&
          (status != 'prepared' || run.notificationState == 'registered')) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('Expected $status, got ${scheduler.tasks.single.runs.first.status}');
  }

  for (final change in ['create', 'edit', 'delete', 'mode']) {
    testWidgets('legacy $change invalidates the selected memory snapshot', (
      tester,
    ) async {
      await tester.runAsync(() => settings.setLegacyMemoryMode(true));
      await mount(tester);
      await tester.runAsync(() async {
        await scheduler.save(task);
        await waitFor('prepared');
        await notifications.finished.future;
        final before = scheduler.tasks.single.runs.first;
        final body = notifications.bodies[before.id]!;
        expect(body, contains('Lives in Berlin'));
        expect(body, isNot(contains('Paris')));
        expect(body, isNot(contains('Quiet mornings')));
        expect(body, isNot(contains('Other assistant memory')));
        final ordinary = <Map<String, dynamic>>[];
        await builder.injectMemoryAndRecentChats(
          ordinary,
          assistant,
          settings: settings,
        );
        expect(jsonEncode(ordinary), contains('Lives in Berlin'));
        expect(jsonEncode(ordinary), isNot(contains('Paris')));

        final legacyId = legacyMemories.getForAssistant('a').single.id;
        switch (change) {
          case 'create':
            await legacyMemories.add(
              assistantId: 'a',
              content: 'Likes cycling',
            );
          case 'edit':
            await legacyMemories.update(
              id: legacyId,
              content: 'Lives in Hamburg',
            );
          case 'delete':
            await legacyMemories.delete(id: legacyId);
          case 'mode':
            await settings.setLegacyMemoryMode(false);
        }
        await waitFor('pending');
        final executor = service.preparation.executor;
        final context = jsonEncode(
          await executor.buildContext(task, assistant, null, 'm'),
        );
        expect(await executor.revision(task), isNot(before.contextRevision));
        expect(context, isNot(body));
        if (change == 'mode') {
          expect(context, contains('Paris'));
          expect(context, isNot(contains('Lives in Berlin')));
        }
        expect(notifications.cancelled, contains(before.id));
        expect(notifications.bodies[before.id], 'reminder');
        expect(service.preparation.calls, 1);
        now = now.add(const Duration(minutes: 11));
        await scheduler.lifecycle(false);
        await waitFor('prepared');
        expect(notifications.bodies[before.id], context);
        expect(service.preparation.calls, 2);
      });
    });
  }

  for (final legacy in [false, true]) {
    testWidgets(
      'inactive memory data does not invalidate the selected mode (legacy: $legacy)',
      (tester) async {
        await tester.runAsync(() => settings.setLegacyMemoryMode(legacy));
        await mount(tester);
        await tester.runAsync(() async {
          await scheduler.save(task);
          await waitFor('prepared');
          await notifications.finished.future;
          final before = scheduler.tasks.single.runs.first;
          if (legacy) {
            await memories.putProfileField(
              'location',
              'Tokyo',
              MemorySource.manual,
            );
          } else {
            await legacyMemories.update(
              id: legacyMemories.getForAssistant('a').single.id,
              content: 'Lives in Hamburg',
            );
          }
          await scheduler.check();
          expect(
            await service.preparation.executor.revision(task),
            before.contextRevision,
          );
          expect(scheduler.tasks.single.runs.first.status, 'prepared');
          expect(notifications.cancelled, isEmpty);
          expect(service.preparation.calls, 1);
        });
      },
    );
  }

  testWidgets(
    'switching to legacy memory invalidates a V2 preparation in flight',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        final preparation = service.preparation;
        preparation.gate = Completer<void>();
        await scheduler.save(task);
        await preparation.captured.future;
        final id = scheduler.tasks.single.runs.first.id;
        await settings.setLegacyMemoryMode(true);
        await waitFor('pending');
        preparation.gate!.complete();
        await notifications.finished.future;
        expect(scheduler.tasks.single.runs.first.status, 'pending');
        expect(notifications.bodies[id], 'reminder');
        expect(preparation.calls, 1);
      });
    },
  );

  for (final change in [
    'profile',
    'create',
    'edit',
    'delete',
    'language',
    'limit',
  ]) {
    testWidgets(
      '$change invalidates the prepared notification using actual injected memory',
      (tester) async {
        await mount(tester);
        await tester.runAsync(() async {
          await scheduler.save(task);
          await waitFor('prepared');
          await notifications.finished.future;
          final before = scheduler.tasks.single.runs.first;
          final body = notifications.bodies[before.id];
          expect(body, contains('Paris'));
          expect(body, contains('Quiet mornings'));
          final executor = service.preparation.executor;
          switch (change) {
            case 'profile':
              await memories.putProfileField(
                'location',
                'Tokyo',
                MemorySource.manual,
              );
            case 'create':
              await memories.create(
                scope: MemoryScope.global,
                type: MemoryType.identity,
                content: 'Avoid caffeine',
                source: MemorySource.manual,
              );
            case 'edit':
              await memories.updateContent(memoryId, 'Prefers tea');
            case 'delete':
              await memories.hardDelete(memoryId);
            case 'language':
              await settings.setMemoryPromptLang('zh');
            case 'limit':
              await settings.setMemoryInjectionMaxItems(1);
          }
          await waitFor('pending'); // Requires the real binding's listener.
          final revision = await executor.revision(task);
          final context = await executor.buildContext(
            task,
            assistant,
            null,
            'm',
          );
          expect(revision, isNot(before.contextRevision));
          expect(jsonEncode(context), isNot(body));
          expect(notifications.cancelled, contains(before.id));
          expect(notifications.bodies[before.id], 'reminder');
          expect(service.preparation.calls, 1);
          expect(service.preparation.published, isEmpty);
          expect(scheduler.tasks.single.nextRunAt, DateTime(2026, 9, 19, 21));

          now = now.add(const Duration(minutes: 11));
          await scheduler.lifecycle(false);
          await waitFor('prepared');
          expect(notifications.bodies[before.id], jsonEncode(context));
          expect(service.preparation.calls, 2);
        });
      },
    );
  }

  testWidgets(
    'a response prepared before a profile change cannot restore its notification',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        final preparation = service.preparation;
        preparation.gate = Completer<void>();
        await scheduler.save(task);
        await preparation.captured.future;
        final id = scheduler.tasks.single.runs.first.id;
        await memories.putProfileField(
          'location',
          'Tokyo',
          MemorySource.manual,
        );
        await waitFor('pending');
        preparation.gate!.complete();
        await notifications.finished.future;
        expect(scheduler.tasks.single.runs.first.status, 'pending');
        expect(notifications.bodies[id], 'reminder');
        expect(preparation.published, isEmpty);
        expect(preparation.calls, 1);
      });
    },
  );
}
