import 'package:Kelivo/features/chat/utils/prompt_injection_selection.dart';
import 'package:Kelivo/features/home/widgets/world_book_sheet.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/conversation_system_prompt_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/conversation_prompt_settings.dart';
import 'package:Kelivo/core/models/instruction_injection.dart';
import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/world_book_activation.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';

class _Chat extends ChatService {
  _Chat(this.repository);
  final ChatDatabaseRepository repository;
  final conversations = <String, Conversation>{};
  int historyReads = 0;

  @override
  bool get initialized => true;
  @override
  Conversation? getConversation(String id) => conversations[id];

  @override
  Future<void> updateConversationExtras(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) update,
  ) async {
    await repository.updateConversationExtras(id, update);
    conversations[id] = (await repository.getConversation(id))!;
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
    historyReads++;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late ChatDatabaseRepository repository;
  late _Chat chat;
  late WorldBookProvider books;
  late InstructionInjectionProvider injections;
  late UserProvider user;
  late SettingsProvider settings;
  late BuildContext context;
  late MessageBuilderService builder;

  setUp(() async {
    harness = await createBusinessTestHarness();
    repository = ChatDatabaseRepository(harness.database);
    await repository.ensureReady();
    chat = _Chat(repository);
    books = WorldBookProvider(preferences: harness.preferences);
    injections = InstructionInjectionProvider(preferences: harness.preferences);
    user = UserProvider(preferences: harness.preferences);
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await ContextLogger.setEnabled(false);
    await books.initialize();
    await injections.initialize();
    for (final id in ['one', 'two']) {
      final conversation = Conversation(
        id: id,
        title: id,
        assistantId: 'assistant',
        extras: const {'keep': true},
      );
      await repository.putConversation(conversation);
      chat.conversations[id] = conversation;
    }
  });

  Future<void> mount(
    WidgetTester tester, {
    Widget child = const SizedBox(),
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<WorldBookProvider>.value(value: books),
          ChangeNotifierProvider<InstructionInjectionProvider>.value(
            value: injections,
          ),
          ChangeNotifierProvider<UserProvider>.value(value: user),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return Scaffold(body: child);
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

  testWidgets(
    'preparation uses saved conversation prompts even when the controller snapshot is stale',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        final stale = chat.getConversation('one')!;
        await injections.add(
          const InstructionInjection(
            id: 'local',
            title: 'Local',
            prompt: 'LOCAL_INJECTION',
          ),
        );
        await books.addBook(
          const WorldBook(
            id: 'local',
            entries: [
              WorldBookEntry(
                id: 'entry',
                content: 'LOCAL_BOOK',
                constantActive: true,
              ),
            ],
          ),
        );
        await chat.updateConversationExtras(
          'one',
          (extras) => const ConversationPromptSettings(
            systemPrompt: 'SAVED',
            instructionIds: ['local'],
            worldBookIds: ['local'],
          ).applyTo(extras),
        );
        final generation = MessageGenerationService(
          chatService: chat,
          messageBuilderService: builder,
          generationController: _Generation(),
          streamController: _Stream(),
          contextProvider: context,
        );
        final prepared = await generation.prepareApiMessagesWithInjections(
          messages: [
            ChatMessage(
              id: 'user',
              role: 'user',
              content: 'hello',
              conversationId: 'one',
            ),
          ],
          versionSelections: {},
          currentConversation: stale,
          settings: settings,
          assistant: const Assistant(
            id: 'assistant',
            name: 'Assistant',
            systemPrompt: 'OLD',
            allowConversationSystemPrompt: true,
            allowConversationPromptInjection: true,
          ),
          assistantId: 'assistant',
          providerKey: 'test',
          modelId: 'model',
        );
        expect(prepared.apiMessages.first['content'], contains('SAVED'));
        expect(
          prepared.apiMessages.first['content'],
          contains('LOCAL_INJECTION'),
        );
        expect(prepared.apiMessages.first['content'], contains('LOCAL_BOOK'));
        expect(prepared.apiMessages.first['content'], isNot(contains('OLD')));
      });
    },
  );

  testWidgets(
    'rapid conversation selection changes are atomic and preserve assistant defaults',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        await books.setActiveBookIds(['shared'], assistantId: 'assistant');
        await Future.wait([
          togglePromptSelection(
            context,
            'first',
            kind: PromptSelectionKind.worldBook,
            conversationId: 'one',
          ),
          togglePromptSelection(
            context,
            'second',
            kind: PromptSelectionKind.worldBook,
            conversationId: 'one',
          ),
        ]);
        expect(
          ConversationPromptSettings.fromExtras(
            chat.getConversation('one')!.extras,
          ).worldBookIds.toSet(),
          {'first', 'second'},
        );
        await setPromptSelection(
          context,
          [],
          kind: PromptSelectionKind.worldBook,
          conversationId: 'one',
        );
        expect(
          ConversationPromptSettings.fromExtras(
            chat.getConversation('one')!.extras,
          ).worldBookIds,
          isEmpty,
        );
        expect(books.activeBookIdsFor('assistant'), ['shared']);
      });
    },
  );

  testWidgets(
    'world book picker saves only the selected conversation and displays enabled counts',
    (tester) async {
      await tester.runAsync(() async {
        await books.addBook(
          const WorldBook(
            id: 'pick',
            name: 'Pick me',
            entries: [
              WorldBookEntry(id: 'a', content: 'A', constantActive: true),
              WorldBookEntry(
                id: 'b',
                content: 'B',
                constantActive: true,
                enabled: false,
              ),
            ],
          ),
        );
      });
      await mount(
        tester,
        child: const WorldBookSheet(
          assistantId: 'assistant',
          conversationId: 'one',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1/2 enabled'), findsOneWidget);
      expect(find.text('World Book (0/1)'), findsOneWidget);
      await tester.tap(find.text('Pick me'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.text('World Book (1/1)'), findsOneWidget);
      expect(
        ConversationPromptSettings.fromExtras(
          chat.getConversation('one')!.extras,
        ).worldBookIds,
        ['pick'],
      );
      expect(
        ConversationPromptSettings.fromExtras(
          chat.getConversation('two')!.extras,
        ).worldBookIds,
        isEmpty,
      );
      expect(books.activeBookIdsFor('assistant'), isEmpty);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets(
      '${platform.name} conversation prompt editor saves and clears only its own conversation',
      (tester) async {
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(
          tester,
          platform: platform,
          child: const ConversationSystemPromptButton(
            assistantId: 'assistant',
            conversationId: 'one',
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('conversation-system-prompt-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(Dialog),
          platform == TargetPlatform.macOS ? findsOneWidget : findsNothing,
        );
        await tester.enterText(
          find.byType(TextField),
          'Only this conversation',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          // Wait for the save transaction before reading its result.
          final saved = await repository.getConversation('one');
          expect(
            saved!.extras[ConversationPromptSettings.systemPromptKey],
            'Only this conversation',
          );
          expect(
            chat
                .getConversation('two')!
                .extras
                .containsKey(ConversationPromptSettings.systemPromptKey),
            isFalse,
          );
        });
        await tester.tap(
          find.byKey(const ValueKey('conversation-system-prompt-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use assistant prompt'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final saved = await repository.getConversation('one');
          expect(
            saved!.extras.containsKey(
              ConversationPromptSettings.systemPromptKey,
            ),
            isFalse,
          );
          expect(saved.extras['keep'], true);
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'conversation system prompt overrides only when allowed; empty restores assistant',
    (tester) async {
      await mount(tester);
      const assistant = Assistant(
        id: 'assistant',
        name: 'Assistant',
        systemPrompt: 'BASE',
        allowConversationSystemPrompt: true,
      );
      final conversation = chat
          .getConversation('one')!
          .copyWith(
            extras: const {
              ConversationPromptSettings.systemPromptKey: 'CUSTOM {model_id}',
            },
          );
      for (final scenario in [
        (assistant, conversation, 'CUSTOM model'),
        (
          assistant.copyWith(allowConversationSystemPrompt: false),
          conversation,
          'BASE',
        ),
        (assistant, chat.getConversation('two')!, 'BASE'),
      ]) {
        final messages = <Map<String, dynamic>>[
          {'role': 'user', 'content': 'hello'},
        ];
        builder.injectSystemPrompt(
          messages,
          scenario.$1,
          'model',
          conversation: scenario.$2,
        );
        expect(messages.first, {'role': 'system', 'content': scenario.$3});
        expect(messages, hasLength(2));
      }
      final decoded = Assistant.fromJson(
        assistant.copyWith(allowConversationPromptInjection: true).toJson(),
      );
      expect(decoded.allowConversationSystemPrompt, isTrue);
      expect(decoded.allowConversationPromptInjection, isTrue);
    },
  );

  testWidgets(
    'conversation selections, including empty, replace assistant selections',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        for (final id in ['shared', 'local']) {
          await books.addBook(
            WorldBook(
              id: id,
              entries: [
                WorldBookEntry(
                  id: id,
                  content: 'BOOK_$id',
                  constantActive: true,
                ),
              ],
            ),
          );
          await injections.add(
            InstructionInjection(id: id, title: id, prompt: 'PROMPT_$id'),
          );
        }
        await books.setActiveBookIds(['shared'], assistantId: 'assistant');
        await injections.setActiveIds(['shared'], assistantId: 'assistant');
        await chat.updateConversationExtras(
          'one',
          (extras) => const ConversationPromptSettings(
            instructionIds: ['local'],
            worldBookIds: ['local'],
          ).applyTo(extras),
        );
        for (final scenario in [
          ('one', true, 'local'),
          ('two', true, ''),
          ('one', false, 'shared'),
        ]) {
          final messages = <Map<String, dynamic>>[
            {'role': 'user', 'content': 'hello'},
          ];
          final conversation = chat.getConversation(scenario.$1);
          await builder.injectInstructionPrompts(
            messages,
            'assistant',
            conversation: conversation,
            conversationScoped: scenario.$2,
          );
          await builder.injectWorldBookPrompts(
            messages,
            'assistant',
            conversation: conversation,
            conversationScoped: scenario.$2,
          );
          if (scenario.$3.isEmpty) {
            expect(messages, hasLength(1));
          } else {
            expect(messages.first['content'], contains('BOOK_${scenario.$3}'));
            expect(
              messages.first['content'],
              contains('PROMPT_${scenario.$3}'),
            );
            expect(
              messages.first['content'],
              isNot(contains(scenario.$3 == 'local' ? 'shared' : 'local')),
            );
          }
        }
        expect(chat.getConversation('one')!.extras['keep'], true);
        expect(books.activeBookIdsFor('assistant'), ['shared']);
        expect(injections.activeIdsFor('assistant'), ['shared']);
      });
    },
  );

  testWidgets(
    'timers use full selected history despite a bounded request and survive reloading',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        await books.addBook(
          const WorldBook(
            id: 'timed',
            entries: [
              WorldBookEntry(
                id: 'entry',
                content: 'TIMED',
                keywords: ['dragon'],
                scanDepth: 1,
                sticky: 2,
                cooldown: 2,
                delay: 3,
              ),
            ],
          ),
        );
        await books.setActiveBookIds(['timed'], assistantId: 'assistant');
        final history = <ChatMessage>[];
        Future<ChatMessage> add(String role, String content) async {
          final message = ChatMessage(
            id: 'm${history.length}',
            conversationId: 'one',
            role: role,
            content: content,
          );
          history.add(message);
          await repository.putMessage(message);
          chat.conversations['one'] = (await repository.getConversation(
            'one',
          ))!;
          return message;
        }

        Future<List<Map<String, dynamic>>> inject(
          List<ChatMessage> source,
        ) async {
          final messages = builder.buildApiMessages(
            messages: source,
            versionSelections: {},
            currentConversation: chat.getConversation('one'),
          );
          await builder.injectWorldBookPrompts(
            messages,
            'assistant',
            conversation: chat.getConversation('one'),
            sourceMessages: source,
          );
          return messages;
        }

        await add('user', 'hello');
        // A completed empty reply still counts; the new streaming placeholder does not.
        await add('assistant', '');
        final trigger = await add('user', 'dragon');
        final placeholder = ChatMessage(
          id: 'pending',
          role: 'assistant',
          content: '',
          conversationId: 'one',
          isStreaming: true,
        );
        final triggered = await inject([trigger, placeholder]);
        expect(triggered.first['content'], contains('TIMED'));
        final persisted = (await repository.getConversation('one'))!;
        expect(
          (persisted.extras[WorldBookActivation.extrasKey]
              as Map)['messageCount'],
          3,
        );
        expect(chat.historyReads, 1);
        // Simulate reloading the serialized conversation and constructing a fresh builder.
        chat.conversations['one'] = Conversation.fromJson(persisted.toJson());
        builder = MessageBuilderService(
          chatService: chat,
          contextProvider: context,
        );
        expect(
          (await inject([trigger, placeholder])).first['content'],
          contains('TIMED'),
        );
        await add('assistant', 'away');
        final next = await add('user', 'away');
        expect((await inject([next])).first['content'], contains('TIMED'));
        await add('assistant', 'away');
        final cooling = await add('user', 'dragon');
        expect(await inject([cooling]), hasLength(1));
        // Regenerating before the trigger must not count later conversation messages.
        expect(await inject([history.first]), hasLength(1));
        expect(chat.getConversation('one')!.extras['keep'], isTrue);
      });
    },
  );

  testWidgets(
    'world book injection keeps position, role and priority ordering',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        await books.addBook(
          const WorldBook(
            id: 'positions',
            entries: [
              WorldBookEntry(
                id: 'after',
                content: 'AFTER',
                constantActive: true,
              ),
              WorldBookEntry(
                id: 'before',
                content: 'BEFORE',
                constantActive: true,
                position: WorldBookInjectionPosition.beforeSystemPrompt,
              ),
              WorldBookEntry(
                id: 'top',
                content: 'TOP',
                constantActive: true,
                position: WorldBookInjectionPosition.topOfChat,
                role: WorldBookInjectionRole.assistant,
              ),
              WorldBookEntry(
                id: 'bottom',
                content: 'BOTTOM',
                constantActive: true,
                position: WorldBookInjectionPosition.bottomOfChat,
              ),
            ],
          ),
        );
        await books.setActiveBookIds(['positions'], assistantId: 'assistant');
        final messages = <Map<String, dynamic>>[
          {'role': 'system', 'content': 'BASE'},
          {'role': 'user', 'content': 'hello'},
        ];
        await builder.injectWorldBookPrompts(messages, 'assistant');
        expect(messages.first['content'], 'BEFORE\nBASE\nAFTER');
        expect(messages[1], {'role': 'assistant', 'content': 'TOP'});
        expect(messages[messages.length - 2]['content'], contains('BOTTOM'));
        expect(messages.last, {'role': 'user', 'content': 'hello'});
      });
    },
  );
}
