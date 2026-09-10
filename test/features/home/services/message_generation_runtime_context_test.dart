import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/logging/context_logger.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import '../../../support/business_test_harness.dart';

class _Context extends Fake implements BuildContext {
  @override
  InheritedElement?
  getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() => null;
}

class _Routes extends Fake implements McpToolRouteSnapshot {}

class _Stream extends Fake implements stream_ctrl.StreamController {}

class _Generation extends Fake implements GenerationController {
  int resolutions = 0;
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
  }) {
    resolutions++;
    return [];
  }
}

class _Chat extends ChatService {
  _Chat(this.conversation, this.messages);
  final Conversation conversation;
  final List<ChatMessage> messages;
  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
  @override
  List<ChatMessage> getMessages(String conversationId) => messages;
}

class _Builder extends MessageBuilderService {
  _Builder({required super.chatService, required super.contextProvider});
  @override
  void injectSystemPrompt(
    List<Map<String, dynamic>> messages,
    Assistant? assistant,
    String modelId,
  ) {
    messages.insert(0, {'role': 'system', 'content': assistant!.systemPrompt});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real preparation samples once, preserves history, and refreshes on next generation',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      await ContextLogger.setEnabled(false);
      await settings.setProviderConfig(
        'fixture',
        ProviderConfig(
          id: 'fixture',
          name: 'Fixture',
          enabled: true,
          apiKey: '',
          baseUrl: 'https://example.invalid/v1',
          providerType: ProviderKind.openai,
          modelOverrides: {
            'alias': {'apiModelId': 'upstream-model', 'name': 'Display name'},
          },
        ),
      );
      final conversation = Conversation(id: 'conversation', title: 'Test');
      final user = ChatMessage(
        id: 'u',
        conversationId: conversation.id,
        role: 'user',
        content: 'original',
        timestamp: DateTime.utc(2000),
      );
      final chat = _Chat(conversation, [user]);
      addTearDown(chat.dispose);
      final context = _Context();
      final controller = _Generation();
      var reads = 0;
      final service = MessageGenerationService(
        chatService: chat,
        messageBuilderService: _Builder(
          chatService: chat,
          contextProvider: context,
        ),
        generationController: controller,
        streamController: _Stream(),
        contextProvider: context,
        clock: () => DateTime.utc(2026, 12, 31, 23, 59, reads++),
      );
      const assistant = Assistant(
        id: 'a',
        name: 'A',
        systemPrompt: 'stable instructions',
        appendCurrentTimeToUserMessage: true,
        includeModelInfoInContext: true,
      );
      Future<PreparedGeneration> prepare(String id) =>
          service.prepareApiMessagesWithInjections(
            messages: [user],
            versionSelections: {},
            currentConversation: conversation,
            settings: settings,
            assistant: assistant,
            assistantId: assistant.id,
            providerKey: 'fixture',
            modelId: 'alias',
            processingMessageId: id,
          );
      final first = await prepare('generation-1');
      expect(reads, 1);
      expect(controller.resolutions, 1);
      expect(first.apiMessages.first['content'], 'stable instructions');
      expect(
        first.apiMessages.last['content'],
        contains('2026-12-31T23:59:00'),
      );
      expect(first.apiMessages.last['content'], contains('upstream-model'));
      expect(first.apiMessages.last['content'], contains('Display name'));
      expect(first.apiMessages.last['content'], isNot(contains('2000')));
      expect(user.content, 'original');
      expect(
        first.contextSnapshot!.context.messages.last.segments.last.source,
        ContextSource.runtimeContext,
      );
      for (final message in first.apiMessages) {
        expect(message.containsKey(kelivoContextSegmentsKey), isFalse);
        expect(
          message.containsKey(MessageBuilderService.internalRevisionIdKey),
          isFalse,
        );
      }
      final orphan = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'unpersisted'},
      ];
      await service.messageBuilderService.processUserMessagesForApi(
        orphan,
        settings,
        assistant,
      );
      expect(orphan.single['content'], 'unpersisted');
      final second = await prepare('generation-2');
      expect(reads, 2);
      expect(
        second.apiMessages.last['content'],
        contains('2026-12-31T23:59:01'),
      );
      expect(
        first.apiMessages.last['content'],
        contains('2026-12-31T23:59:00'),
      );
      expect(
        chat.preparedContexts.forConversation(conversation.id)!.generationId,
        'generation-2',
      );
      await chat.close();
      expect(chat.preparedContexts.forConversation(conversation.id), isNull);
    },
  );
}
