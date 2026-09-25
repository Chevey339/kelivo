import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation_prompt_settings.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/world_book_activation.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

class _Chat extends ChatService {
  Future<void> Function()? afterHistoryRead;
  Future<void> Function()? beforeExtrasWrite;
  Future<void> Function()? afterExtrasWrite;

  @override
  Future<List<ChatMessage>> loadSelectedContextMessages(
    String id, {
    required int truncateIndex,
    required int limit,
    String? throughRevisionId,
    bool includeFollowingAssistant = false,
  }) async {
    final messages = await super.loadSelectedContextMessages(
      id,
      truncateIndex: truncateIndex,
      limit: limit,
      throughRevisionId: throughRevisionId,
      includeFollowingAssistant: includeFollowingAssistant,
    );
    final hook = afterHistoryRead;
    afterHistoryRead = null;
    await hook?.call();
    return messages;
  }

  @override
  Future<void> updateConversationExtras(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) update,
  ) async {
    final before = beforeExtrasWrite;
    beforeExtrasWrite = null;
    await before?.call();
    await super.updateConversationExtras(id, update);
    final after = afterExtrasWrite;
    afterExtrasWrite = null;
    await after?.call();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SettingsProvider settings;
  late AssistantProvider assistants;
  late InstructionInjectionProvider instructions;
  late WorldBookProvider books;
  late UserProvider user;
  late _Chat chat;
  late Assistant assistant;
  late String conversationId;
  late ChatMessage message;
  late ChatMessage alternate;
  late ChatMessage reply;
  late WorldBook book;
  late MessageGenerationService generation;
  late ContextUsageService usage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kelivo_world_book_usage_',
    );
    PathProviderPlatform.instance = FakePathProviderPlatform(directory.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: directory.path,
      supportDir: directory.path,
    );
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    assistants = AssistantProvider(preferences: harness.preferences);
    instructions = InstructionInjectionProvider(
      preferences: harness.preferences,
    );
    books = WorldBookProvider(preferences: harness.preferences);
    user = UserProvider(preferences: harness.preferences);
    await settings.loaded;
    await assistants.loaded;
    await instructions.initialize();
    await books.initialize();
    await settings.setProviderConfig(
      'Test',
      ProviderConfig(
        id: 'Test',
        enabled: true,
        name: 'Test',
        apiKey: 'k',
        baseUrl: 'https://example.test',
        models: const ['opaque'],
        modelOverrides: const {
          'opaque': {'contextWindow': 10000},
        },
      ),
    );
    await settings.setCurrentModel('Test', 'opaque');
    final id = await assistants.addAssistant(name: 'A');
    await assistants.setCurrentAssistant(id);
    await assistants.updateAssistant(
      assistants
          .getById(id)!
          .copyWith(
            systemPrompt: '',
            enableMemory: false,
            allowPastConversationRecall: false,
          ),
    );
    assistant = assistants.getById(id)!;
    chat = _Chat();
    await chat.init();
  });

  tearDown(() async {
    usage.dispose();
    user.dispose();
    books.dispose();
    instructions.dispose();
    assistants.dispose();
    settings.dispose();
    await chat.close();
    await Hive.close();
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    int sticky = 0,
    bool temporary = false,
    bool scoped = false,
    bool active = true,
  }) async {
    if (scoped) {
      await assistants.updateAssistant(
        assistant.copyWith(allowConversationPromptInjection: true),
      );
      assistant = assistants.getById(assistant.id)!;
    }
    book = WorldBook(
      id: 'book',
      entries: [
        WorldBookEntry(
          id: 'entry',
          content: 'short',
          constantActive: true,
          sticky: sticky,
        ),
      ],
    );
    await books.addBook(book);
    if (!scoped) {
      await books.setActiveBookIds(['book'], assistantId: assistant.id);
    }
    final conversation = await chat.createDraftConversation(
      title: 'A',
      assistantId: assistant.id,
      temporary: temporary,
    );
    conversationId = conversation.id;
    if (scoped) {
      await chat.updateConversationExtras(
        conversationId,
        (extras) => {
          ...extras,
          ConversationPromptSettings.worldBookIdsKey: ['book'],
        },
      );
    }
    message = await chat.addMessage(
      conversationId: conversationId,
      role: 'user',
      content: 'hello',
    );
    alternate = (await chat.appendMessageVersion(
      messageId: message.id,
      content: List.filled(100, 'aa').join(' '),
    ))!;
    await chat.setSelectedVersion(
      conversationId,
      message.groupId ?? message.id,
      message.version,
    );
    reply = await chat.addMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      isStreaming: true,
    );
    late BuildContext context;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider.value(value: instructions),
          ChangeNotifierProvider.value(value: books),
          ChangeNotifierProvider.value(value: user),
        ],
        child: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
    generation = MessageGenerationService(
      chatService: chat,
      messageBuilderService: MessageBuilderService(
        chatService: chat,
        contextProvider: context,
      ),
      generationController: _Generation(),
      streamController: _Stream(),
      contextProvider: context,
    );
    usage = ContextUsageService(
      chatService: chat,
      settings: settings,
      assistants: assistants,
      instructions: instructions,
      worldBooks: books,
      assemble: generation.previewContextAssembly,
      runEstimate: <T>(T Function() computation) async => computation(),
    );
    if (active) usage.setActiveConversation(conversationId);
  }

  Future<PreparedGeneration> prepare() =>
      generation.prepareApiMessagesWithInjections(
        messages: [message],
        versionSelections: chat.getVersionSelections(conversationId),
        currentConversation: chat.getConversation(conversationId),
        settings: settings,
        assistant: assistant,
        assistantId: assistant.id,
        providerKey: 'Test',
        modelId: 'opaque',
      );

  Future<void> record(PreparedGeneration prepared) => usage.recordUsage(
    conversationId: conversationId,
    providerKey: 'Test',
    modelId: 'opaque',
    assistantId: assistant.id,
    requestConfiguration: prepared.contextUsageConfiguration,
    requestRevision: prepared.contextUsageRevision,
    usage: const TokenUsage(promptTokens: 9, completionTokens: 1),
    assistantMessage: reply.copyWith(content: 'x', isStreaming: false),
  );

  Future<PreparedGeneration> anchor() async {
    final prepared = await prepare();
    await record(prepared);
    await usage.refresh(conversationId, force: true);
    expect(usage.snapshot(conversationId)!.state, ContextUsageState.exact);
    expect(usage.snapshot(conversationId)!.usedTokens, 10);
    return prepared;
  }

  for (final scoped in [false, true]) {
    for (final force in [false, true]) {
      testWidgets('world book invalidation scoped=$scoped force=$force', (
        tester,
      ) async {
        await tester.runAsync(() async {
          await mount(tester, scoped: scoped, active: !force);
          final prepared = await anchor();
          await books.setBookCollapsed(book.id, true);
          await books.addBook(
            const WorldBook(
              id: 'unselected',
              entries: [
                WorldBookEntry(
                  id: 'ignored',
                  content: 'unused',
                  constantActive: true,
                ),
              ],
            ),
          );
          await usage.refresh(conversationId);
          expect(
            usage.snapshot(conversationId)!.state,
            ContextUsageState.exact,
          );

          final changed = book.copyWith(
            entries: [
              book.entries.single.copyWith(
                content: List.filled(100, 'aa').join(' '),
              ),
            ],
          );
          await books.updateBook(changed);
          if (!force) expect(usage.current!.state, ContextUsageState.stale);
          await usage.refresh(conversationId, force: force);
          expect(
            usage.snapshot(conversationId)!.state,
            ContextUsageState.estimated,
          );
          expect(
            usage.snapshot(conversationId)!.usedTokens,
            greaterThanOrEqualTo(100),
          );
          await record(prepared);
          await usage.refresh(conversationId, force: true);
          expect(
            usage.snapshot(conversationId)!.state,
            ContextUsageState.estimated,
          );

          await anchor();
          await books.setEntryEnabled(book.id, 'entry', false);
          await usage.refresh(conversationId, force: force);
          expect(
            usage.snapshot(conversationId)!.state,
            ContextUsageState.estimated,
          );
          expect(usage.snapshot(conversationId)!.usedTokens, 1);

          await books.updateBook(changed);
          await anchor();
          await books.updateBook(changed.copyWith(enabled: false));
          await usage.refresh(conversationId, force: force);
          expect(
            usage.snapshot(conversationId)!.state,
            ContextUsageState.estimated,
          );
          expect(usage.snapshot(conversationId)!.usedTokens, 1);
        });
      });
    }
  }

  for (final temporary in [false, true]) {
    for (final editAt in [
      'none',
      'before_write',
      'during_write',
      'after_write',
      'after_preparation',
    ]) {
      testWidgets('activation provenance temporary=$temporary edit=$editAt', (
        tester,
      ) async {
        await tester.runAsync(() async {
          await mount(tester, sticky: 2, temporary: temporary);
          Future<void> editHistory() => chat.setSelectedVersion(
            conversationId,
            message.groupId ?? message.id,
            alternate.version,
          );
          switch (editAt) {
            case 'before_write':
              chat.afterHistoryRead = editHistory;
            case 'during_write':
              chat.beforeExtrasWrite = editHistory;
            case 'after_write':
              chat.afterExtrasWrite = editHistory;
          }
          final before = chat.contextRevision(conversationId);
          final prepared = await prepare();
          expect(
            chat.getConversation(conversationId)!.extras,
            contains(WorldBookActivation.extrasKey),
          );
          if (editAt == 'after_preparation') await editHistory();
          await record(prepared);
          await usage.refresh(conversationId, force: true);
          if (editAt == 'none') {
            expect(prepared.contextUsageRevision, before + 1);
            expect(
              prepared.contextUsageRevision,
              chat.contextRevision(conversationId),
            );
            expect(usage.current!.state, ContextUsageState.exact);
            expect(usage.current!.usedTokens, 10);
          } else {
            expect(chat.contextRevision(conversationId), before + 2);
            expect(
              prepared.contextUsageRevision,
              isNot(chat.contextRevision(conversationId)),
            );
            expect(usage.current!.state, ContextUsageState.estimated);
            expect(usage.current!.usedTokens, greaterThanOrEqualTo(100));
          }
        });
      });
    }
  }
}
