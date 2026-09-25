import 'dart:async';
import 'dart:convert';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/providers/memory_provider_v2.dart';
import 'package:Kelivo/core/services/memory/memory_repository.dart';
import 'package:Kelivo/core/database/business_data.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/features/home/services/context_assembly.dart';
import 'package:Kelivo/core/utils/token_estimator.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';

class _Chat extends ChatService {
  _Chat(this.repository);
  final ChatDatabaseRepository repository;
  final conversations = <String, Conversation>{};
  final revisions = <String, int>{};
  final storedMessages = <ChatMessage>[];
  @override
  ChatDatabaseRepository? get chatRepositoryOrNull => repository;
  @override
  Future<List<ChatMessage>> loadMessages(String id) async =>
      storedMessages.where((m) => m.conversationId == id).toList();
  @override
  List<ChatMessage> getMessages(String id) =>
      storedMessages.where((m) => m.conversationId == id).toList();

  @override
  bool get initialized => true;
  @override
  Conversation? getConversation(String id) => conversations[id];
  @override
  int contextRevision(String conversationId) => revisions[conversationId] ?? 0;

  @override
  Future<void> updateConversationExtras(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) update,
  ) async {
    await repository.updateConversationExtras(id, update);
    conversations[id] = (await repository.getConversation(id))!;
    revisions[id] = contextRevision(id) + 1;
    notifyListeners();
  }

  @override
  Future<int> resolveMessageCount(String id) async =>
      (await repository.getConversation(id))!.messageIds.length;

  @override
  Future<List<ChatMessage>> loadSelectedContextMessages(
    String id, {
    required int truncateIndex,
    required int limit,
    String? throughRevisionId,
    bool includeFollowingAssistant = false,
  }) {
    return repository.getSelectedContextMessages(
      id,
      truncateIndex: truncateIndex,
      limit: limit,
      throughRevisionId: throughRevisionId,
      includeFollowingAssistant: includeFollowingAssistant,
    );
  }
}

class _Routes extends Fake implements McpToolRouteSnapshot {}

class _Stream extends Fake implements stream_ctrl.StreamController {}

class _Generation extends Fake implements GenerationController {
  @override
  Map<String, String>? buildCustomHeaders(Assistant? assistant) => null;
  @override
  Map<String, dynamic>? buildCustomBody(Assistant? assistant) => null;
  @override
  McpToolRouteSnapshot captureMcpToolRoutes(Assistant? assistant) => _Routes();
  @override
  List<Map<String, dynamic>> buildToolDefinitions(
    SettingsProvider settings,
    Assistant? assistant,
    String providerKey,
    String modelId,
    bool hasBuiltInSearch, {
    McpToolRouteSnapshot? mcpRouteSnapshot,
    WorkspaceToolContext? workspaceContext,
    String? conversationId,
  }) => [];
}

class _Usage extends ContextUsageService {
  _Usage({
    required super.chatService,
    required super.settings,
    required super.assistants,
    required super.instructions,
    required super.worldBooks,
    required super.memories,
    required super.assemble,
    required super.runEstimate,
  });

  Future<void>? lastRefresh;

  @override
  Future<void> refresh(
    String conversationId, {
    String? draftText,
    bool force = false,
  }) => lastRefresh = super.refresh(
    conversationId,
    draftText: draftText,
    force: force,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late ChatDatabaseRepository repository;
  late _Chat chat;
  late WorldBookProvider books;
  late InstructionInjectionProvider injections;
  late UserProvider user;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late MemoryProviderV2 memories;
  late BuildContext context;
  late MessageBuilderService builder;

  setUp(() async {
    harness = await createBusinessTestHarness();
    repository = ChatDatabaseRepository(harness.database);
    await repository.ensureReady();
    chat = _Chat(repository);
    memories = MemoryProviderV2(
      repository: MemoryRepository(harness.preferences),
      chatRepository: repository,
    );
    books = WorldBookProvider(preferences: harness.preferences);
    injections = InstructionInjectionProvider(preferences: harness.preferences);
    user = UserProvider(preferences: harness.preferences);
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await harness.preferences.setString(
      BusinessEntityKind.assistant.sourceKey,
      jsonEncode([
        const Assistant(
          id: 'assistant',
          name: 'A',
          systemPrompt: '',
          enableMemory: true,
          allowPastConversationRecall: false,
        ).toJson(),
      ]),
    );
    assistants = AssistantProvider(preferences: harness.preferences);
    await assistants.loaded;
    await settings.setProviderConfig(
      'Test',
      ProviderConfig(
        id: 'Test',
        apiKey: 'test',
        enabled: true,
        name: 'Test',
        baseUrl: 'https://example.test',
        models: const ['opaque'],
        modelOverrides: const {
          'opaque': {'contextWindow': 100000},
        },
      ),
    );
    await settings.setCurrentModel('Test', 'opaque');
    await ContextLogger.setEnabled(false);
    await books.initialize();
    await injections.initialize();
    final conversation = Conversation(
      id: 'one',
      title: 'one',
      assistantId: 'assistant',
      extras: const {'keep': true},
    );
    await repository.putConversation(conversation);
    chat.conversations[conversation.id] = conversation;
  });

  tearDown(() {
    memories.dispose();
    books.dispose();
    injections.dispose();
    user.dispose();
    settings.dispose();
    assistants.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<WorldBookProvider>.value(value: books),
          ChangeNotifierProvider<InstructionInjectionProvider>.value(
            value: injections,
          ),
          ChangeNotifierProvider<UserProvider>.value(value: user),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );
    builder = MessageBuilderService(
      chatService: chat,
      contextProvider: context,
    );
  }

  Future<void> seedUser(String content) async {
    final m = ChatMessage(
      id: 'user',
      conversationId: 'one',
      role: 'user',
      content: content,
    );
    await repository.putMessage(m);
    chat.storedMessages.add(m);
  }

  MessageGenerationService generation() => MessageGenerationService(
    chatService: chat,
    messageBuilderService: builder,
    generationController: _Generation(),
    streamController: _Stream(),
    contextProvider: context,
  );
  Future<ContextAssemblyPreview> preview(MessageGenerationService g) =>
      g.previewContextAssembly(
        conversationId: 'one',
        providerKey: 'Test',
        modelId: 'opaque',
        assistantId: 'assistant',
      );
  Future<void> putProfile(String content) => harness.repository.upsertEntity(
    BusinessEntityKind.userProfileField,
    BusinessEntityValue(
      id: 'occupation',
      sortOrder: 0,
      payload: jsonEncode({
        'id': 'occupation',
        'value': content,
        'source': 'manual',
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      }),
    ),
  );
  Future<void> putMemory(
    String id,
    String content, {
    String? assistantId,
    String status = 'active',
  }) => harness.repository.upsertEntity(
    BusinessEntityKind.memoryEntry,
    BusinessEntityValue(
      id: id,
      sortOrder: 0,
      payload: jsonEncode({
        'id': id,
        'scope': assistantId == null ? 'global' : 'assistant',
        'assistantId': assistantId,
        'type': 'identity',
        'status': status,
        'content': content,
        'source': 'manual',
        'relatedIds': [],
        'createdAt': DateTime.now().microsecondsSinceEpoch,
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      }),
    ),
  );
  _Usage usageService(MessageGenerationService g) => _Usage(
    chatService: chat,
    settings: settings,
    assistants: assistants,
    instructions: injections,
    worldBooks: books,
    memories: memories,
    assemble: g.previewContextAssembly,
    runEstimate: <T>(T Function() computation) async => computation(),
  );

  testWidgets('profile edit invalidates the cached memory bucket', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(() async {
      await seedUser('hello');
      await putProfile('short');
      final g = generation();
      final usage = usageService(g)..setActiveConversation('one');
      try {
        await usage.refresh('one', force: true);
        final old = usage.current!.buckets.memory;
        await putProfile(List.filled(1000, 'word').join(' '));
        final rebuilt = estimateTokens((await preview(g)).memoryText);
        await usage.refresh('one');
        expect(rebuilt, greaterThan(old + 900));
        expect(usage.current!.buckets.memory, rebuilt);
      } finally {
        usage.dispose();
      }
    });
  });

  testWidgets('memory item limit invalidates the cached memory bucket', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(() async {
      await seedUser('hello');
      await putMemory('one', List.filled(500, 'word').join(' '));
      await putMemory('two', List.filled(500, 'word').join(' '));
      await settings.setMemoryInjectionMaxItems(1);
      final g = generation();
      final usage = usageService(g)..setActiveConversation('one');
      try {
        await usage.refresh('one', force: true);
        final old = usage.current!.buckets.memory;
        await settings.setMemoryInjectionMaxItems(2);
        final rebuilt = estimateTokens((await preview(g)).memoryText);
        await usage.refresh('one');
        expect(rebuilt, greaterThan(old + 400));
        expect(usage.current!.buckets.memory, rebuilt);
      } finally {
        usage.dispose();
      }
    });
  });

  testWidgets('data URI in plain text is counted in full', (tester) async {
    await mount(tester);
    await tester.runAsync(() async {
      final body =
          'Decode this plain text: "data:text/plain;base64,${base64Encode(utf8.encode(List.filled(2000, 'hello ').join()))}"';
      await seedUser(body);
      final api = builder.buildApiMessages(
        messages: chat.storedMessages,
        versionSelections: {},
        currentConversation: chat.getConversation('one'),
      );
      await builder.processUserMessagesForApi(
        api,
        settings,
        const Assistant(id: 'assistant', name: 'A', enableMemory: false),
        conversation: chat.getConversation('one'),
        sourceMessages: chat.storedMessages,
        previewOnly: true,
      );
      await builder.inlineLocalImages(api);
      builder.stripInternalRevisionIds(api);
      expect(api.single['content'], body);
      final result = await preview(generation());
      expect(estimateTokens(result.historyText), estimateTokens(body));
    });
  });
  Future<PreparedGeneration> prepare(MessageGenerationService g) =>
      g.prepareApiMessagesWithInjections(
        messages: chat.storedMessages,
        versionSelections: {},
        currentConversation: chat.getConversation('one'),
        settings: settings,
        assistant: assistants.getById('assistant'),
        assistantId: 'assistant',
        providerKey: 'Test',
        modelId: 'opaque',
      );

  Future<void> record(ContextUsageService usage, PreparedGeneration request) =>
      usage.recordUsage(
        conversationId: 'one',
        providerKey: 'Test',
        modelId: 'opaque',
        assistantId: 'assistant',
        requestConfiguration: request.contextUsageConfiguration,
        requestRevision: request.contextUsageRevision,
        usage: const TokenUsage(promptTokens: 9, completionTokens: 1),
        assistantMessage: ChatMessage(
          conversationId: 'one',
          role: 'assistant',
          content: 'answer',
        ),
      );

  for (final change in [
    'profile',
    'memory',
    'archive',
    'delete',
    'scope',
    'limit',
  ]) {
    for (final force in [false, true]) {
      testWidgets(
        'exact usage and late responses reject $change edits, force=$force',
        (tester) async {
          await mount(tester);
          await tester.runAsync(() async {
            await seedUser('hello');
            await putProfile('short');
            await putMemory('m1', 'first fact');
            await putMemory('m2', 'second fact');
            await settings.setMemoryInjectionMaxItems(1);
            final g = generation();
            final usage = usageService(g);
            if (!force) usage.setActiveConversation('one');
            try {
              final request = await prepare(g);
              await record(usage, request);
              await usage.refresh('one', force: true);
              expect(usage.snapshot('one')!.state, ContextUsageState.exact);
              expect(usage.snapshot('one')!.usedTokens, 10);
              switch (change) {
                case 'profile':
                  await putProfile(List.filled(1000, 'word').join(' '));
                case 'memory':
                  await putMemory('m1', List.filled(500, 'word').join(' '));
                case 'archive':
                  await putMemory('m1', 'first fact', status: 'archived');
                case 'delete':
                  await harness.repository.deleteEntity(
                    BusinessEntityKind.memoryEntry,
                    'm1',
                  );
                case 'scope':
                  await putMemory('m1', 'first fact', assistantId: 'other');
                case 'limit':
                  await settings.setMemoryInjectionMaxItems(2);
              }
              final rebuilt = await preview(g);
              await usage.refresh('one', force: force);
              expect(usage.snapshot('one')!.state, ContextUsageState.estimated);
              expect(
                usage.snapshot('one')!.buckets.memory,
                estimateTokens(rebuilt.memoryText),
              );
              await record(usage, request);
              await usage.refresh('one', force: true);
              expect(usage.snapshot('one')!.state, ContextUsageState.estimated);
              expect(
                usage.snapshot('one')!.buckets.memory,
                estimateTokens(rebuilt.memoryText),
              );
            } finally {
              usage.dispose();
            }
          });
        },
      );
    }
  }

  testWidgets('an unrelated assistant memory preserves the exact anchor', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(() async {
      await seedUser('hello');
      await putProfile('short');
      final g = generation();
      final usage = usageService(g);
      try {
        await record(usage, await prepare(g));
        await usage.refresh('one', force: true);
        await putMemory('other-memory', 'Private fact', assistantId: 'other');
        await usage.refresh('one');
        expect(usage.snapshot('one')!.state, ContextUsageState.exact);
        expect(usage.snapshot('one')!.usedTokens, 10);
      } finally {
        usage.dispose();
      }
    });
  });

  testWidgets('memory edits during estimation discard the old estimate', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(() async {
      await seedUser('hello');
      await putProfile('short');
      final g = generation();
      final usage = usageService(g);
      try {
        await usage.refresh('one', force: true);
        final assembling = Completer<void>();
        final resume = Completer<void>();
        usage.bindAssembler(({
          required conversationId,
          required providerKey,
          required modelId,
          required assistantId,
        }) async {
          final old = await preview(g);
          assembling.complete();
          await resume.future;
          return old;
        });
        final pending = usage.refresh('one', force: true);
        await assembling.future;
        await putProfile(List.filled(1000, 'word').join(' '));
        resume.complete();
        await pending;
        expect(usage.snapshot('one')!.state, ContextUsageState.stale);
        usage.bindAssembler(g.previewContextAssembly);
        await usage.refresh('one');
        expect(
          usage.snapshot('one')!.buckets.memory,
          estimateTokens((await preview(g)).memoryText),
        );
      } finally {
        usage.dispose();
      }
    });
  });

  testWidgets(
    'memory provider changes refresh an open panel without a manual refresh',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        await seedUser('hello');
        await putProfile('short');
        final g = generation();
        final usage = usageService(g)..setActiveConversation('one');
        try {
          await usage.refresh('one', force: true);
          final updated = Completer<void>();
          usage.addListener(() {
            if (usage.current?.state == ContextUsageState.estimated &&
                usage.current!.buckets.memory > 1400 &&
                !updated.isCompleted) {
              updated.complete();
            }
          });
          await putProfile(List.filled(1000, 'word').join(' '));
          await memories.reloadCurrentScope();
          await updated.future.timeout(const Duration(seconds: 5));
        } finally {
          usage.dispose();
        }
      });
    },
  );
  testWidgets('a cache hit does not cancel forced exact recalibration', (
    tester,
  ) async {
    await mount(tester);
    await tester.runAsync(() async {
      await seedUser('hello');
      await putProfile('short');
      final g = generation();
      final usage = usageService(g);
      try {
        await record(usage, await prepare(g));
        await usage.refresh('one', force: true);
        final assembling = Completer<void>();
        final resume = Completer<void>();
        var assembled = false;
        usage.bindAssembler(({
          required conversationId,
          required providerKey,
          required modelId,
          required assistantId,
        }) async {
          assembling.complete();
          await resume.future;
          assembled = true;
          return const ContextAssemblyPreview(
            systemText: '',
            injectionsText: '',
            historyText: 'replacement',
            tools: [],
            images: [],
          );
        });
        final pending = usage.refresh('one', force: true);
        await assembling.future;
        await usage.refresh('one');
        resume.complete();
        await pending;
        expect(assembled, isTrue);
        expect(usage.snapshot('one')!.state, ContextUsageState.exact);
        expect(usage.snapshot('one')!.buckets.history, 10);
        expect(usage.snapshot('one')!.buckets.memory, 0);
      } finally {
        usage.dispose();
      }
    });
  });
  for (final changed in [false, true]) {
    for (final exact in [false, true]) {
      testWidgets(
        'memory refresh preserves draft changed=$changed exact=$exact',
        (tester) async {
          await mount(tester);
          await tester.runAsync(() async {
            await seedUser('hello');
            await putProfile('short');
            final g = generation();
            final usage = usageService(g)..setActiveConversation('one');
            try {
              if (exact) await record(usage, await prepare(g));
              final draft = List.filled(2000, 'word').join(' ');
              await usage.refresh('one', draftText: draft, force: true);
              final before = usage.current!;
              expect(before.buckets.draft, 2000);
              final previousRefresh = usage.lastRefresh;
              if (changed) await putProfile('a new occupation');
              await memories.reloadCurrentScope();
              expect(usage.lastRefresh, isNot(same(previousRefresh)));
              await usage.lastRefresh;
              final refreshed = usage.current!;
              expect(refreshed.buckets.draft, 2000);
              expect(
                refreshed.usedTokens,
                refreshed.buckets.nonDraftTotal + 2000,
              );
              if (!changed) {
                expect(refreshed.usedTokens, before.usedTokens);
                expect(refreshed.state, before.state);
              } else {
                expect(refreshed.state, ContextUsageState.estimated);
              }

              await usage.refresh('one', draftText: '');
              expect(usage.current!.buckets.draft, 0);
              expect(usage.current!.usedTokens, refreshed.usedTokens - 2000);
              await memories.reloadCurrentScope();
              await usage.lastRefresh;
              expect(usage.current!.buckets.draft, 0);
            } finally {
              usage.dispose();
            }
          });
        },
      );
    }
  }

  for (final latestDraft in ['', 'a newer draft']) {
    testWidgets(
      'in-flight exact recalibration uses the latest draft: $latestDraft',
      (tester) async {
        await mount(tester);
        await tester.runAsync(() async {
          await seedUser('hello');
          await putProfile('short');
          final g = generation();
          final usage = usageService(g);
          try {
            await record(usage, await prepare(g));
            await usage.refresh('one', draftText: 'old draft', force: true);
            final assembling = Completer<void>();
            final resume = Completer<void>();
            usage.bindAssembler(({
              required conversationId,
              required providerKey,
              required modelId,
              required assistantId,
            }) async {
              final preview = await g.previewContextAssembly(
                conversationId: conversationId,
                providerKey: providerKey,
                modelId: modelId,
                assistantId: assistantId,
              );
              assembling.complete();
              await resume.future;
              return preview;
            });
            final pending = usage.refresh('one', force: true);
            await assembling.future;
            await usage.refresh('one', draftText: latestDraft);
            resume.complete();
            await pending;
            expect(usage.current, isNull);
            final snapshot = usage.snapshot('one')!;
            expect(snapshot.state, ContextUsageState.exact);
            expect(snapshot.buckets.draft, estimateTokens(latestDraft));
            expect(snapshot.usedTokens, 10 + estimateTokens(latestDraft));
          } finally {
            usage.dispose();
          }
        });
      },
    );
  }

  testWidgets(
    'a background refresh sees a draft edit before its first estimate completes',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        await seedUser('hello');
        await putProfile('short');
        final g = generation();
        final usage = usageService(g)..setActiveConversation('one');
        try {
          final typed = usage.refresh(
            'one',
            draftText: List.filled(2000, 'word').join(' '),
          );
          // Supersede its pending memory check before any snapshot is published.
          final background = usage.refresh('one');
          await Future.wait([typed, background]);
          expect(usage.current!.buckets.draft, 2000);
          expect(
            usage.current!.usedTokens,
            usage.current!.buckets.nonDraftTotal + 2000,
          );
        } finally {
          usage.dispose();
        }
      });
    },
  );
}
