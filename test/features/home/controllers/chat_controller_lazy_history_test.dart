import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';

class _FakeLazyChatService extends ChatService {
  _FakeLazyChatService(this._messages);

  final List<ChatMessage> _messages;
  Map<String, int> versionSelections = const <String, int>{};
  final Set<String> knownConversationIds = <String>{};
  final Set<String> deletedConversationIds = <String>{};
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
      Map<String, int>.from(versionSelections);

  @override
  Conversation? getConversation(String id) {
    if (deletedConversationIds.contains(id)) return null;
    if (!knownConversationIds.contains(id)) return null;
    return Conversation(
      id: id,
      title: 'Conversation',
      messageIds: _messages.map((message) => message.id).toList(),
    );
  }

  ChatMessage appendPersistedMessage(ChatMessage message) {
    _messages.add(message);
    return message;
  }

  @override
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
    bool temporary = false,
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

ChatMessage _versionedMessage({
  required String id,
  required String role,
  required String groupId,
  required int version,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: id,
    conversationId: 'conversation-1',
    groupId: groupId,
    version: version,
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

    test('clears current conversation when the service deletes it', () async {
      chatService.knownConversationIds.add(conversation.id);
      controller.setCurrentConversation(conversation);

      chatService.deletedConversationIds.add(conversation.id);
      chatService.notifyListeners();

      expect(controller.currentConversation, isNull);
      expect(controller.messages, isEmpty);
      expect(controller.totalMessageCount, 0);
      await expectLater(
        controller.addMessage(role: 'user', content: 'stale send'),
        throwsStateError,
      );
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
      'collapsed tail window excludes a version whose group anchor is older',
      () {
        messages = <ChatMessage>[
          ...List<ChatMessage>.generate(100, _message),
          _versionedMessage(
            id: 'message-10-v1',
            role: 'user',
            groupId: 'message-10',
            version: 1,
          ),
        ];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Long chat with edited old message',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages);
        controller.dispose();
        controller = ChatController(chatService: chatService);

        controller.setCurrentConversation(conversation);

        expect(controller.messages.last.id, 'message-10-v1');
        expect(controller.loadedStartIndex, 81);
        expect(controller.messages.length, 20);
        expect(
          controller.collapsedMessages.map((message) => message.id),
          isNot(contains('message-10-v1')),
        );
        expect(controller.collapsedMessages.first.id, 'message-81');
        expect(controller.collapsedMessages.last.id, 'message-99');
      },
    );

    test(
      'collapsed tail window keeps a version whose group anchor is visible',
      () {
        messages = <ChatMessage>[
          ...List<ChatMessage>.generate(99, _message),
          _versionedMessage(
            id: 'message-99-v0',
            role: 'assistant',
            groupId: 'message-99',
            version: 0,
          ),
          _versionedMessage(
            id: 'message-99-v1',
            role: 'assistant',
            groupId: 'message-99',
            version: 1,
          ),
        ];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Long chat with edited recent message',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages);
        controller.dispose();
        controller = ChatController(chatService: chatService);

        controller.setCurrentConversation(conversation);

        final collapsedIds = controller.collapsedMessages
            .map((message) => message.id)
            .toList();
        expect(collapsedIds, contains('message-99-v1'));
        expect(collapsedIds, isNot(contains('message-99-v0')));
        expect(controller.collapsedMessages.last.id, 'message-99-v1');
      },
    );

    test(
      'collapsed tail window loads selected version when recent window starts inside final version group',
      () {
        final finalVersions = List<ChatMessage>.generate(
          21,
          (index) => _versionedMessage(
            id: 'final-v$index',
            role: 'assistant',
            groupId: 'final-group',
            version: index,
          ),
        );
        messages = <ChatMessage>[
          ...List<ChatMessage>.generate(100, _message),
          ...finalVersions,
        ];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Long chat with a long multi-version final message',
          messageIds: messages.map((message) => message.id).toList(),
          versionSelections: const <String, int>{'final-group': 0},
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const <String, int>{'final-group': 0};
        controller.dispose();
        controller = ChatController(chatService: chatService);

        controller.setCurrentConversation(conversation);

        expect(controller.messages.first.id, 'final-v1');
        expect(controller.loadedStartIndex, 101);
        expect(controller.collapsedMessages.map((message) => message.id), [
          'final-v0',
        ]);
      },
    );

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
      'appending a persisted tail message from a middle window loads the tail',
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
        controller.loadUntilMessageVisible('message-2500');

        final appended = chatService.appendPersistedMessage(_message(5000));
        controller.appendPersistedTailMessage(appended);

        expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
        expect(controller.messages.first.id, 'message-4641');
        expect(controller.messages.last.id, 'message-5000');
        expect(controller.loadedStartIndex, 4641);
        expect(controller.totalMessageCount, 5001);
        expect(controller.hasMoreAfter, isFalse);
      },
    );

    test('appending a persisted tail message trims a full tail window', () {
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
      controller.loadEndWindow();

      final appended = chatService.appendPersistedMessage(_message(5000));
      controller.appendPersistedTailMessage(appended);

      expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
      expect(controller.messages.first.id, 'message-4641');
      expect(controller.messages.last.id, 'message-5000');
      expect(controller.loadedStartIndex, 4641);
      expect(controller.totalMessageCount, 5001);
      expect(controller.hasMoreAfter, isFalse);
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
      'model context source keeps complete history and persisted truncate index',
      () {
        final truncatedConversation = conversation.copyWith(truncateIndex: 30);
        controller.setCurrentConversation(truncatedConversation);

        final contextMessages = controller
            .allMessagesForCurrentConversationContext();
        final contextConversation = controller
            .conversationForCompleteHistoryContext(truncatedConversation);

        expect(contextMessages, messages);
        expect(contextConversation.truncateIndex, 30);
        expect(controller.messages, messages.sublist(80));
        expect(controller.loadedStartIndex, 80);
        expect(chatService.fullLoadCalls, 0);
      },
    );

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
