import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';

ChatMessage _assistantMessage({
  required String id,
  String content = 'answer',
  String? reasoningSegmentsJson,
}) {
  return ChatMessage(
    id: id,
    role: 'assistant',
    content: content,
    conversationId: 'conversation-1',
    reasoningSegmentsJson: reasoningSegmentsJson,
  );
}

class _FakeLazyChatService extends ChatService {
  _FakeLazyChatService(this._storedMessages);

  final List<ChatMessage> _storedMessages;

  @override
  int getMessageCount(String conversationId) => _storedMessages.length;

  @override
  List<ChatMessage> getRecentMessages(
    String conversationId, {
    int minMessages = ChatService.defaultInitialMessageMin,
    int textBudget = ChatService.defaultInitialTextBudget,
    int maxMessages = ChatService.defaultInitialMessageMax,
  }) {
    final start = (_storedMessages.length - minMessages)
        .clamp(0, _storedMessages.length)
        .toInt();
    return _storedMessages.sublist(start);
  }

  @override
  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    final safeStart = start.clamp(0, _storedMessages.length).toInt();
    final end = (safeStart + limit)
        .clamp(safeStart, _storedMessages.length)
        .toInt();
    return _storedMessages.sublist(safeStart, end);
  }

  @override
  int getMessageIndex(String conversationId, String messageId) {
    return _storedMessages.indexWhere((message) => message.id == messageId);
  }

  @override
  Map<String, int> getVersionSelections(String conversationId) =>
      <String, int>{};

  @override
  Conversation? getConversation(String id) {
    return Conversation(
      id: id,
      title: 'conversation',
      messageIds: _storedMessages.map((message) => message.id).toList(),
    );
  }
}

ChatMessage _message(int index) {
  return ChatMessage(
    id: 'message-$index',
    role: index.isEven ? 'user' : 'assistant',
    content: 'message $index',
    conversationId: 'conversation-1',
  );
}

Conversation _conversation(List<ChatMessage> messages) {
  return Conversation(
    id: 'conversation-1',
    title: 'conversation',
    messageIds: messages.map((message) => message.id).toList(),
  );
}

void main() {
  group('ChatController lazy history window', () {
    test(
      'initial load keeps only recent window and can load older messages',
      () {
        final storedMessages = List<ChatMessage>.generate(60, _message);
        final controller = ChatController(
          chatService: _FakeLazyChatService(storedMessages),
        );

        controller.setCurrentConversation(_conversation(storedMessages));

        expect(controller.totalMessageCount, 60);
        expect(controller.messages.first.id, 'message-40');
        expect(controller.messages.last.id, 'message-59');
        expect(controller.hasMoreBefore, isTrue);
        expect(controller.hasMoreAfter, isFalse);

        final loaded = controller.loadMoreBefore(limit: 10);

        expect(loaded, isTrue);
        expect(controller.messages.first.id, 'message-30');
        expect(controller.messages.last.id, 'message-59');
        expect(controller.loadedStartIndex, 30);
      },
    );

    test('can load a window around a searched message', () {
      final storedMessages = List<ChatMessage>.generate(80, _message);
      final controller = ChatController(
        chatService: _FakeLazyChatService(storedMessages),
      );

      controller.setCurrentConversation(_conversation(storedMessages));
      final loaded = controller.loadUntilMessageVisible('message-5');

      expect(loaded, isTrue);
      expect(
        controller.messages.any((message) => message.id == 'message-5'),
        isTrue,
      );
      expect(controller.hasMoreBefore, isFalse);
      expect(controller.hasMoreAfter, isFalse);
    });

    test('complete history context is independent from loaded UI window', () {
      final storedMessages = List<ChatMessage>.generate(70, _message);
      final conversation = _conversation(storedMessages);
      final controller = ChatController(
        chatService: _FakeLazyChatService(storedMessages),
      );

      controller.setCurrentConversation(conversation);

      expect(controller.messages.length, 20);
      expect(
        controller.messagesForCompleteHistoryContext(conversation),
        hasLength(70),
      );
    });
  });

  group('ChatController export selection', () {
    test('uses latest stored message metadata for selected exports', () {
      final visible = _assistantMessage(id: 'assistant-1');
      final latest = _assistantMessage(
        id: 'assistant-1',
        reasoningSegmentsJson: '{"segments":[{"text":"thinking"}]}',
      );

      final selected = ChatController.selectedCollapsedMessagesForExport(
        collapsedMessages: [visible],
        selectedIds: const {'assistant-1'},
        storedMessages: [latest],
      );

      expect(selected, hasLength(1));
      expect(
        selected.single.reasoningSegmentsJson,
        '{"segments":[{"text":"thinking"}]}',
      );
    });

    test('returns empty when no selected ids are provided', () {
      final selected = ChatController.selectedCollapsedMessagesForExport(
        collapsedMessages: [_assistantMessage(id: 'assistant-1')],
        selectedIds: const <String>{},
        storedMessages: [_assistantMessage(id: 'assistant-1')],
      );

      expect(selected, isEmpty);
    });

    test('falls back to visible message when storage has no matching id', () {
      final visible = _assistantMessage(
        id: 'assistant-1',
        content: 'visible fallback',
      );

      final selected = ChatController.selectedCollapsedMessagesForExport(
        collapsedMessages: [visible],
        selectedIds: const {'assistant-1'},
        storedMessages: const <ChatMessage>[],
      );

      expect(selected, [visible]);
    });
  });
}
