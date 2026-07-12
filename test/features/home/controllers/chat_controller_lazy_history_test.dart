import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/database/message_graph_projector.dart';
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
  int contextStartIndex = -1;

  @override
  int getContextStartIndex(String conversationId) => contextStartIndex;

  @override
  List<ChatMessage> getMessages(String conversationId) {
    fullLoadCalls++;
    throw StateError('full message load should not run on conversation open');
  }

  @override
  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    fullLoadCalls++;
    return List.of(_messages);
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
  Future<List<ChatMessage>> loadRecentMessages(
    String conversationId, {
    int minMessages = 20,
    int textBudget = 20000,
    int maxMessages = 240,
  }) async => getRecentMessages(
    conversationId,
    minMessages: minMessages,
    textBudget: textBudget,
    maxMessages: maxMessages,
  );

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
  Future<List<ChatMessage>> loadMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) async => getMessagesRange(conversationId, start: start, limit: limit);

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    rangeLoadCalls++;
    final grouped = <String, List<ChatMessage>>{};
    for (final message in _messages) {
      grouped.putIfAbsent(message.groupId ?? message.id, () => []).add(message);
    }
    final activeMessages = <ChatMessage>[];
    for (final entry in grouped.entries) {
      final selectedVersion = versionSelections[entry.key];
      activeMessages.add(
        entry.value.firstWhere(
          (message) => selectedVersion == null
              ? message.version == 0
              : message.version == selectedVersion,
          orElse: () => entry.value.first,
        ),
      );
    }
    final effectiveLimit = limit;
    var start = 0;
    var end = activeMessages.length;
    if (fromStart) {
      start = 0;
      end = effectiveLimit.clamp(0, activeMessages.length);
    } else if (beforeRevisionId != null) {
      end = activeMessages.indexWhere(
        (message) => message.id == beforeRevisionId,
      );
      if (end < 0) return null;
      start = (end - effectiveLimit).clamp(0, end);
    } else if (afterRevisionId != null) {
      final cursor = activeMessages.indexWhere(
        (message) => message.id == afterRevisionId,
      );
      if (cursor < 0) return null;
      start = cursor + 1;
      end = (start + effectiveLimit).clamp(start, activeMessages.length);
    } else {
      start = (activeMessages.length - effectiveLimit).clamp(
        0,
        activeMessages.length,
      );
    }
    final selected = activeMessages.sublist(start, end);
    final counts = <String, int>{};
    for (final message in _messages) {
      counts.update(
        message.groupId ?? message.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final timestamp = DateTime(2026, 7, 11);
    return LoadedTimelinePage(
      conversationId: conversationId,
      stateRevision: 0,
      contextStartRevisionId: null,
      slots: [
        for (final (offset, message) in selected.indexed)
          LoadedTimelineSlot(
            identity: ActiveTimelineSlot(
              slotId: message.groupId ?? message.id,
              revisionId: message.id,
              parentRevisionId: start + offset == 0
                  ? null
                  : activeMessages[start + offset - 1].id,
              role: message.role,
              createdAt: timestamp,
              updatedAt: timestamp,
              finalizedAt: timestamp,
              versionCount: counts[message.groupId ?? message.id] ?? 1,
              logicalIndex: start + offset,
            ),
            message: message,
          ),
      ],
      hasMoreBefore: start > 0,
      hasMoreAfter: end < activeMessages.length,
      totalSlotCount: activeMessages.length,
    );
  }

  @override
  void retainTimelineWindow(
    String conversationId,
    Iterable<String> revisionIds,
  ) {}

  @override
  Map<String, int> getVersionSelections(String conversationId) =>
      Map<String, int>.from(versionSelections);

  @override
  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final remaining = groupIds.where((id) => id.isNotEmpty).toSet();
    if (remaining.isEmpty) return const <String, int>{};

    final result = <String, int>{};
    for (var i = 0; i < _messages.length && remaining.isNotEmpty; i++) {
      final groupId = _messages[i].groupId ?? _messages[i].id;
      if (remaining.remove(groupId)) result[groupId] = i;
    }
    return result;
  }

  @override
  Future<Map<String, int>> loadFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => getFirstMessageIndicesForGroups(conversationId, groupIds);

  @override
  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final targets = groupIds.where((id) => id.isNotEmpty).toSet();
    if (targets.isEmpty) return const <ChatMessage>[];

    return _messages
        .where((message) {
          final groupId = message.groupId ?? message.id;
          return targets.contains(groupId);
        })
        .toList(growable: false);
  }

  @override
  Future<List<ChatMessage>> loadMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => getMessagesForGroups(conversationId, groupIds);

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

    test('opening a conversation loads only the tail window', () async {
      await controller.setCurrentConversationAndLoad(conversation);

      expect(chatService.fullLoadCalls, 0);
      expect(chatService.recentLoadCalls, 0);
      expect(controller.messages, messages.sublist(60));
      expect(controller.loadedStartIndex, 60);
      expect(controller.totalMessageCount, 100);
      expect(controller.hasMoreBefore, isTrue);
    });

    test(
      'streaming and final snapshots survive viewport intent changes',
      () async {
        final placeholder = ChatMessage(
          id: 'streaming-assistant',
          role: 'assistant',
          content: '',
          conversationId: conversation.id,
          isStreaming: true,
        );
        messages = <ChatMessage>[
          ...List<ChatMessage>.generate(50, _message),
          placeholder,
        ];
        conversation = Conversation(
          id: conversation.id,
          title: conversation.title,
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages);
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);

        final partial = placeholder.copyWith(content: 'partial answer');
        controller.replaceMessageSnapshot(partial);
        controller.timelineCoordinator.noteContentChanged(isGenerating: true);
        controller.timelineCoordinator.userAnchored();
        expect(await controller.loadMoreBefore(), isTrue);
        expect(controller.messages.last.content, 'partial answer');
        expect(controller.messages.last.isStreaming, isTrue);

        final completed = partial.copyWith(
          content: 'complete answer',
          isStreaming: false,
        );
        expect(controller.publishTerminalMessage(completed), isTrue);
        expect(controller.timelineCoordinator.isGenerating, isFalse);
        controller.timelineCoordinator.followTail();

        expect(controller.messages.last.content, 'complete answer');
        expect(controller.messages.last.isStreaming, isFalse);
        expect(
          controller.timelineCoordinator.slots.last.message.content,
          'complete answer',
        );
        expect(
          controller.timelineCoordinator.slots.last.message.isStreaming,
          isFalse,
        );
      },
    );

    test(
      'viewport intent changes do not republish the message window',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);
        final originalMessages = controller.messages;
        var controllerNotifications = 0;
        var coordinatorNotifications = 0;
        controller.addListener(() => controllerNotifications++);
        controller.timelineCoordinator.addListener(
          () => coordinatorNotifications++,
        );

        for (var index = 0; index < 120; index++) {
          controller.timelineCoordinator.userAnchored();
        }
        for (var index = 0; index < 120; index++) {
          controller.timelineCoordinator.followTail();
        }

        expect(controllerNotifications, 0);
        expect(coordinatorNotifications, 2);
        expect(identical(controller.messages, originalMessages), isTrue);
      },
    );

    test(
      'terminal snapshot closes generation outside the loaded window',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);
        controller.timelineCoordinator.noteContentChanged(isGenerating: true);

        final replaced = controller.publishTerminalMessage(
          ChatMessage(
            id: 'evicted-assistant',
            role: 'assistant',
            content: 'finished while outside the window',
            conversationId: conversation.id,
            isStreaming: false,
          ),
        );

        expect(replaced, isFalse);
        expect(controller.timelineCoordinator.isGenerating, isFalse);
      },
    );

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
      () async {
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
      'opening falls back when recent versions have no visible anchors',
      () async {
        final anchors = List<ChatMessage>.generate(
          20,
          (index) => _versionedMessage(
            id: 'anchor-$index-v0',
            role: index.isEven ? 'user' : 'assistant',
            groupId: 'anchor-$index',
            version: 0,
          ),
        );
        final revisions = List<ChatMessage>.generate(
          20,
          (index) => _versionedMessage(
            id: 'anchor-$index-v1',
            role: index.isEven ? 'user' : 'assistant',
            groupId: 'anchor-$index',
            version: 1,
          ),
        );
        messages = <ChatMessage>[...anchors, ...revisions];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Long chat with only old revisions in the tail',
          messageIds: messages.map((message) => message.id).toList(),
          versionSelections: {
            for (var index = 0; index < anchors.length; index++)
              'anchor-$index': 1,
          },
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = Map<String, int>.from(
            conversation.versionSelections,
          );
        controller.dispose();
        controller = ChatController(chatService: chatService);

        await controller.setCurrentConversationAndLoad(conversation);

        expect(chatService.fullLoadCalls, 0);
        expect(controller.collapsedMessages, isNotEmpty);
        expect(controller.collapsedMessages.first.id, 'anchor-0-v1');
      },
    );

    test(
      'alternate revisions do not create a newer logical timeline page',
      () async {
        final anchors = List<ChatMessage>.generate(
          ChatService.defaultLoadedWindowMax,
          (index) => _versionedMessage(
            id: 'anchor-$index-v0',
            role: index.isEven ? 'user' : 'assistant',
            groupId: 'anchor-$index',
            version: 0,
          ),
        );
        final revisions = List<ChatMessage>.generate(
          ChatService.defaultLoadedWindowMax,
          (index) => _versionedMessage(
            id: 'anchor-$index-v1',
            role: index.isEven ? 'user' : 'assistant',
            groupId: 'anchor-$index',
            version: 1,
          ),
        );
        messages = <ChatMessage>[...anchors, ...revisions];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Long chat with old revisions at the tail',
          messageIds: messages.map((message) => message.id).toList(),
          versionSelections: {
            for (var index = 0; index < anchors.length; index++)
              'anchor-$index': 1,
          },
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = Map<String, int>.from(
            conversation.versionSelections,
          );
        controller.dispose();
        controller = ChatController(chatService: chatService);
        controller.setCurrentConversation(conversation);
        await controller.loadStartWindow();

        final loaded = await controller.loadMoreAfter(
          limit: ChatService.defaultLoadedWindowMax,
        );

        expect(loaded, isFalse);
        expect(chatService.fullLoadCalls, 0);
        expect(controller.collapsedMessages, isNotEmpty);
        expect(controller.collapsedMessages.last.id, 'anchor-359-v1');
      },
    );

    test(
      'loading the end window falls back when tail versions hide everything',
      () async {
        final anchors = List<ChatMessage>.generate(
          ChatService.defaultLoadedWindowMax,
          (index) => _versionedMessage(
            id: 'anchor-$index-v0',
            role: index.isEven ? 'user' : 'assistant',
            groupId: 'anchor-$index',
            version: 0,
          ),
        );
        final revisions = List<ChatMessage>.generate(
          ChatService.defaultLoadedWindowMax,
          (index) => _versionedMessage(
            id: 'anchor-$index-v1',
            role: index.isEven ? 'user' : 'assistant',
            groupId: 'anchor-$index',
            version: 1,
          ),
        );
        messages = <ChatMessage>[...anchors, ...revisions];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Long chat with old revisions at the tail',
          messageIds: messages.map((message) => message.id).toList(),
          versionSelections: {
            for (var index = 0; index < anchors.length; index++)
              'anchor-$index': 1,
          },
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = Map<String, int>.from(
            conversation.versionSelections,
          );
        controller.dispose();
        controller = ChatController(chatService: chatService);
        controller.setCurrentConversation(conversation);

        final loaded = await controller.loadEndWindow();

        expect(loaded, isTrue);
        expect(chatService.fullLoadCalls, 0);
        expect(controller.collapsedMessages, isNotEmpty);
        expect(controller.collapsedMessages.last.id, 'anchor-359-v1');
      },
    );

    test(
      'collapsed tail window keeps a version whose group anchor is visible',
      () async {
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
      () async {
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
      () async {
        controller.setCurrentConversation(conversation);

        final loaded = await controller.loadMoreBefore();

        expect(loaded, isTrue);
        expect(chatService.rangeLoadCalls, 1);
        expect(controller.messages, messages.sublist(60));
        expect(controller.loadedStartIndex, 60);
        expect(controller.hasMoreBefore, isTrue);
      },
    );

    test('loading older history keeps the visible window bounded', () async {
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
        expect(await controller.loadMoreBefore(), isTrue);
      }

      expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
      expect(controller.messages.first.id, 'message-4380');
      expect(controller.messages.last.id, 'message-4739');
      expect(controller.loadedStartIndex, 4380);
      expect(controller.hasMoreBefore, isTrue);
      expect(controller.hasMoreAfter, isTrue);
    });

    test('loading older history stops at the beginning', () async {
      controller.setCurrentConversation(conversation);

      await controller.loadMoreBefore(limit: 80);
      final loadedAgain = await controller.loadMoreBefore();

      expect(loadedAgain, isFalse);
      expect(controller.messages, messages);
      expect(controller.loadedStartIndex, 0);
      expect(controller.hasMoreBefore, isFalse);
    });

    test(
      'loading until a message is visible supports direct navigation',
      () async {
        controller.setCurrentConversation(conversation);

        final visible = await controller.loadUntilMessageVisible('message-10');

        expect(visible, isTrue);
        expect(controller.messages.first, messages[0]);
        expect(controller.messages, contains(messages[10]));
        expect(controller.loadedStartIndex, 0);
        expect(controller.hasMoreBefore, isFalse);
      },
    );

    test('direct navigation loads a bounded target window', () async {
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

      final visible = await controller.loadUntilMessageVisible('message-2500');

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

    test('loading newer history moves the bounded window forward', () async {
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
      await controller.loadUntilMessageVisible('message-2500');

      final loaded = await controller.loadMoreAfter();

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
      () async {
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
        await controller.loadUntilMessageVisible('message-2500');

        final appended = chatService.appendPersistedMessage(_message(5000));
        await controller.appendPersistedTailMessage(appended);

        expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
        expect(controller.messages.first.id, 'message-4641');
        expect(controller.messages.last.id, 'message-5000');
        expect(controller.loadedStartIndex, 4641);
        expect(controller.totalMessageCount, 5001);
        expect(controller.hasMoreAfter, isFalse);
      },
    );

    test(
      'appending a persisted tail message trims a full tail window',
      () async {
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
        await controller.loadEndWindow();

        final appended = chatService.appendPersistedMessage(_message(5000));
        await controller.appendPersistedTailMessage(appended);

        expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
        expect(controller.messages.first.id, 'message-4641');
        expect(controller.messages.last.id, 'message-5000');
        expect(controller.loadedStartIndex, 4641);
        expect(controller.totalMessageCount, 5001);
        expect(controller.hasMoreAfter, isFalse);
      },
    );

    test('publishes an atomic send pair through the timeline tail', () async {
      controller.setCurrentConversation(conversation);
      final user = chatService.appendPersistedMessage(_message(100));
      final assistant = chatService.appendPersistedMessage(_message(101));

      final reloaded = await controller.appendPersistedTailMessages([
        user,
        assistant,
      ]);

      expect(reloaded, isTrue);
      expect(chatService.rangeLoadCalls, 1);
      expect(controller.messages.map((message) => message.id), [
        ...messages.map((message) => message.id),
      ]);
      expect(controller.totalMessageCount, 102);
    });

    test(
      'mini map source includes all messages without expanding chat window',
      () async {
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
      chatService.contextStartIndex = 90;
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
      () async {
        final truncatedConversation = conversation.copyWith(truncateIndex: 30);
        chatService.contextStartIndex = 30;
        controller.setCurrentConversation(truncatedConversation);

        final contextMessages = await controller
            .allMessagesForCurrentConversationContext();
        final contextConversation = controller
            .conversationForCompleteHistoryContext(truncatedConversation);

        expect(contextMessages, messages);
        expect(contextConversation.truncateIndex, 30);
        expect(controller.messages, messages.sublist(80));
        expect(controller.loadedStartIndex, 80);
        expect(chatService.fullLoadCalls, 1);
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
