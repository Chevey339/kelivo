import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';

class _FakeChatService extends ChatService {
  _FakeChatService({required this.messagesByConversation});

  final Map<String, List<ChatMessage>> messagesByConversation;

  @override
  List<ChatMessage> getMessages(String conversationId) {
    return List<ChatMessage>.of(
      messagesByConversation[conversationId] ?? const [],
    );
  }

  @override
  Map<String, int> getVersionSelections(String conversationId) {
    return const <String, int>{};
  }

  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    return const <Map<String, dynamic>>[];
  }

  @override
  String? getGeminiThoughtSignature(String assistantMessageId) {
    return null;
  }

  @override
  Future<void> updateMessage(
    String messageId, {
    String? content,
    int? totalTokens,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
  }) async {}
}

Future<HomePageController> _buildController(
  WidgetTester tester, {
  required ChatService chatService,
}) async {
  late BuildContext context;
  await tester.pumpWidget(
    ChangeNotifierProvider<ChatService>.value(
      value: chatService,
      child: MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  final controller = HomePageController(
    context: context,
    vsync: tester,
    scaffoldKey: GlobalKey<ScaffoldState>(),
    inputBarKey: GlobalKey(),
    inputFocus: FocusNode(),
    inputController: TextEditingController(),
    mediaController: ChatInputBarController(),
    scrollController: ScrollController(),
  );
  await tester.pump();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePageController visible window cache', () {
    testWidgets('replaces visible snapshot after local message mutation', (
      tester,
    ) async {
      final conversation = Conversation(
        id: 'c1',
        title: 'Test',
        messageIds: const ['u1', 'a1'],
      );
      final userMessage = ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'hello',
        conversationId: conversation.id,
      );
      final assistantMessage = ChatMessage(
        id: 'a1',
        role: 'assistant',
        content: 'world',
        conversationId: conversation.id,
      );
      final controller = await _buildController(
        tester,
        chatService: _FakeChatService(
          messagesByConversation: <String, List<ChatMessage>>{
            conversation.id: <ChatMessage>[userMessage, assistantMessage],
          },
        ),
      );

      controller.chatControllerForTesting.setCurrentConversation(conversation);
      controller.syncVisibleMessageWindowForTesting(
        resetToLatest: true,
        keepLatest: true,
      );

      final updatedAssistant = assistantMessage.copyWith(
        translation: 'translated',
      );
      controller.messages[1] = updatedAssistant;
      controller.replaceMessageInVisibleCachesForTesting(updatedAssistant);

      expect(controller.visibleMessages.last.translation, 'translated');
      expect(
        controller
            .visibleMessageGroups[updatedAssistant.groupId]!
            .last
            .translation,
        'translated',
      );

      controller.dispose();
    });

    testWidgets('keeps expanded translation state after ui restore', (
      tester,
    ) async {
      final conversation = Conversation(
        id: 'c2',
        title: 'Test',
        messageIds: const ['a2'],
      );
      final translatedMessage = ChatMessage(
        id: 'a2',
        role: 'assistant',
        content: 'world',
        translation: '译文',
        conversationId: conversation.id,
      );
      final controller = await _buildController(
        tester,
        chatService: _FakeChatService(
          messagesByConversation: <String, List<ChatMessage>>{
            conversation.id: <ChatMessage>[translatedMessage],
          },
        ),
      );

      controller.chatControllerForTesting.setCurrentConversation(conversation);
      controller.syncVisibleMessageWindowForTesting(
        resetToLatest: true,
        keepLatest: true,
      );

      controller.translations[translatedMessage.id]!.expanded = true;
      controller.restoreMessageUiStateForTesting();

      expect(controller.translations[translatedMessage.id]!.expanded, isTrue);

      controller.dispose();
    });
  });
}
