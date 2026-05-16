import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';

class _FakeLazyChatService extends ChatService {
  _FakeLazyChatService(this._messages);

  final List<ChatMessage> _messages;
  int fullLoadCalls = 0;
  int recentLoadCalls = 0;
  int rangeLoadCalls = 0;

  @override
  List<ChatMessage> getMessages(String conversationId) {
    fullLoadCalls++;
    throw StateError('full message load should not run on conversation open');
  }

  @override
  int getMessageCount(String conversationId) => _messages.length;

  @override
  int getMessageIndex(String conversationId, String messageId) {
    return _messages.indexWhere((message) => message.id == messageId);
  }

  @override
  List<ChatMessage> getRecentMessages(
    String conversationId, {
    int minMessages = 20,
    int textBudget = 20000,
    int maxMessages = 240,
  }) {
    recentLoadCalls++;
    const tailWindowSize = 20;
    final count = tailWindowSize > _messages.length
        ? _messages.length
        : tailWindowSize;
    return _messages.sublist(_messages.length - count);
  }

  @override
  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    rangeLoadCalls++;
    final end = (start + limit).clamp(0, _messages.length);
    return _messages.sublist(start, end);
  }

  @override
  Map<String, int> getVersionSelections(String conversationId) =>
      const <String, int>{};

  @override
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
  }) async {
    return Conversation(title: title ?? 'Draft', assistantId: assistantId);
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

void main() {
  group('ChatController lazy history', () {
    late List<ChatMessage> messages;
    late Conversation conversation;
    late _FakeLazyChatService chatService;
    late ChatController controller;

    setUp(() {
      messages = List<ChatMessage>.generate(100, _message);
      conversation = Conversation(
        id: 'conversation-1',
        title: 'Long chat',
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages);
      controller = ChatController(chatService: chatService);
    });

    tearDown(() {
      controller.dispose();
    });

    test('opening a conversation loads only the tail window', () {
      controller.setCurrentConversation(conversation);

      expect(chatService.fullLoadCalls, 0);
      expect(chatService.recentLoadCalls, 1);
      expect(controller.messages, messages.sublist(80));
      expect(controller.loadedStartIndex, 80);
      expect(controller.totalMessageCount, 100);
      expect(controller.hasMoreBefore, isTrue);
    });

    test('opening a 5000-message conversation keeps only the tail window', () {
      messages = List<ChatMessage>.generate(5000, _message);
      conversation = Conversation(
        id: 'conversation-1',
        title: 'Very long chat',
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages);
      controller.dispose();
      controller = ChatController(chatService: chatService);

      controller.setCurrentConversation(conversation);

      expect(chatService.fullLoadCalls, 0);
      expect(chatService.recentLoadCalls, 1);
      expect(controller.messages.length, 20);
      expect(controller.messages.first.id, 'message-4980');
      expect(controller.messages.last.id, 'message-4999');
      expect(controller.loadedStartIndex, 4980);
      expect(controller.totalMessageCount, 5000);
      expect(controller.hasMoreBefore, isTrue);
    });

    test(
      'loading older history prepends one page before the visible window',
      () {
        controller.setCurrentConversation(conversation);

        final loaded = controller.loadMoreBefore();

        expect(loaded, isTrue);
        expect(chatService.rangeLoadCalls, 1);
        expect(controller.messages, messages.sublist(60));
        expect(controller.loadedStartIndex, 60);
        expect(controller.hasMoreBefore, isTrue);
      },
    );

    test('loading older history keeps the visible window bounded', () {
      messages = List<ChatMessage>.generate(5000, _message);
      conversation = Conversation(
        id: 'conversation-1',
        title: 'Very long chat',
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages);
      controller.dispose();
      controller = ChatController(chatService: chatService);
      controller.setCurrentConversation(conversation);

      for (var i = 0; i < 30; i++) {
        expect(controller.loadMoreBefore(), isTrue);
      }

      expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
      expect(controller.messages.first.id, 'message-4380');
      expect(controller.messages.last.id, 'message-4739');
      expect(controller.loadedStartIndex, 4380);
      expect(controller.hasMoreBefore, isTrue);
      expect(controller.hasMoreAfter, isTrue);
    });

    test('loading older history stops at the beginning', () {
      controller.setCurrentConversation(conversation);

      controller.loadMoreBefore(limit: 80);
      final loadedAgain = controller.loadMoreBefore();

      expect(loadedAgain, isFalse);
      expect(controller.messages, messages);
      expect(controller.loadedStartIndex, 0);
      expect(controller.hasMoreBefore, isFalse);
    });

    test('loading until a message is visible supports direct navigation', () {
      controller.setCurrentConversation(conversation);

      final visible = controller.loadUntilMessageVisible('message-10');

      expect(visible, isTrue);
      expect(controller.messages.first, messages[0]);
      expect(controller.messages, contains(messages[10]));
      expect(controller.loadedStartIndex, 0);
      expect(controller.hasMoreBefore, isFalse);
    });

    test('direct navigation loads a bounded target window', () {
      messages = List<ChatMessage>.generate(5000, _message);
      conversation = Conversation(
        id: 'conversation-1',
        title: 'Very long chat',
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages);
      controller.dispose();
      controller = ChatController(chatService: chatService);
      controller.setCurrentConversation(conversation);

      final visible = controller.loadUntilMessageVisible('message-2500');

      expect(visible, isTrue);
      expect(chatService.rangeLoadCalls, 1);
      expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
      expect(controller.messages.first.id, 'message-2480');
      expect(controller.messages.last.id, 'message-2839');
      expect(
        controller.messages.any((message) => message.id == 'message-2500'),
        isTrue,
      );
      expect(controller.loadedStartIndex, 2480);
      expect(controller.hasMoreBefore, isTrue);
      expect(controller.hasMoreAfter, isTrue);
    });

    test('loading newer history moves the bounded window forward', () {
      messages = List<ChatMessage>.generate(5000, _message);
      conversation = Conversation(
        id: 'conversation-1',
        title: 'Very long chat',
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages);
      controller.dispose();
      controller = ChatController(chatService: chatService);
      controller.setCurrentConversation(conversation);
      controller.loadUntilMessageVisible('message-2500');

      final loaded = controller.loadMoreAfter();

      expect(loaded, isTrue);
      expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
      expect(controller.messages.first.id, 'message-2500');
      expect(controller.messages.last.id, 'message-2859');
      expect(controller.loadedStartIndex, 2500);
      expect(controller.hasMoreBefore, isTrue);
      expect(controller.hasMoreAfter, isTrue);
    });

    test(
      'mini map source includes all messages without expanding chat window',
      () {
        messages = List<ChatMessage>.generate(5000, _message);
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Very long chat',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages);
        controller.dispose();
        controller = ChatController(chatService: chatService);
        controller.setCurrentConversation(conversation);

        final miniMapMessages = controller
            .allCollapsedMessagesForCurrentConversation();

        expect(miniMapMessages.length, 5000);
        expect(miniMapMessages.first.id, 'message-0');
        expect(miniMapMessages.last.id, 'message-4999');
        expect(controller.messages.length, 20);
        expect(controller.loadedStartIndex, 4980);
        expect(chatService.fullLoadCalls, 0);
      },
    );

    test('maps persisted truncate index into the loaded tail window', () {
      final truncatedConversation = conversation.copyWith(truncateIndex: 90);
      controller.setCurrentConversation(truncatedConversation);

      expect(controller.loadedWindowTruncateIndex(), 10);
      expect(
        controller
            .conversationForLoadedWindow(truncatedConversation)
            .truncateIndex,
        10,
      );
    });

    test(
      'creating a draft conversation clears the loaded history window',
      () async {
        controller.setCurrentConversation(conversation);

        final draft = await controller.createNewConversation(title: 'Draft');

        expect(draft.title, 'Draft');
        expect(controller.messages, isEmpty);
        expect(controller.loadedStartIndex, 0);
        expect(controller.totalMessageCount, 0);
        expect(controller.hasMoreBefore, isFalse);
      },
    );
  });
}
