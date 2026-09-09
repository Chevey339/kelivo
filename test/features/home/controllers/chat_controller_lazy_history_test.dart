import 'dart:async';

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
  int timelinePageCalls = 0;
  int activeTimelineLoadCalls = 0;
  int messageIndexCalls = 0;
  int contextStartIndex = -1;
  bool temporary = false;
  int? timelineSelectedVersionOverride;
  bool requireGroupLoad = false;
  bool groupsLoaded = false;
  Completer<void>? groupLoadGate;
  final List<Set<String>> groupLoadRequests = <Set<String>>[];

  @override
  bool isTemporaryConversation(String? id) => temporary;

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
  Future<List<ChatMessage>> loadActiveTimelineMessages(
    String conversationId,
  ) async {
    activeTimelineLoadCalls++;
    return List<ChatMessage>.of(_messages);
  }

  @override
  Future<List<ChatMessage>> loadSelectedMessageProjections(
    String conversationId,
  ) async {
    activeTimelineLoadCalls++;
    return List<ChatMessage>.of(_messages);
  }

  @override
  int getMessageCount(String conversationId) => _messages.length;

  @override
  int getMessageIndex(String conversationId, String messageId) {
    messageIndexCalls++;
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
    bool cacheInTimeline = true,
  }) async => getMessagesRange(conversationId, start: start, limit: limit);

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    timelinePageCalls++;
    rangeLoadCalls++;
    final grouped = <String, List<ChatMessage>>{};
    for (final message in _messages) {
      grouped.putIfAbsent(message.groupId ?? message.id, () => []).add(message);
    }
    final activeMessages = <ChatMessage>[];
    for (final entry in grouped.entries) {
      final selectedVersion =
          timelineSelectedVersionOverride ?? versionSelections[entry.key];
      activeMessages.add(
        entry.value.firstWhere(
          (message) => selectedVersion == null
              ? identical(message, entry.value.last)
              : message.version == selectedVersion,
          orElse: () => entry.value.last,
        ),
      );
    }
    final effectiveLimit = limit;
    var start = 0;
    var end = activeMessages.length;
    if (fromStart) {
      start = 0;
      end = effectiveLimit.clamp(0, activeMessages.length);
    } else if (aroundRevisionId != null) {
      final target = activeMessages.indexWhere(
        (message) => message.id == aroundRevisionId,
      );
      if (target < 0) return null;
      final before = limit ~/ 2;
      start = (target - before).clamp(0, activeMessages.length - 1);
      end = (start + limit).clamp(start, activeMessages.length);
      start = (end - limit).clamp(0, end);
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
    if (requireGroupLoad && !groupsLoaded) return const <ChatMessage>[];
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
  ) async {
    groupLoadRequests.add(groupIds.toSet());
    await groupLoadGate?.future;
    groupsLoaded = true;
    return getMessagesForGroups(conversationId, groupIds);
  }

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
        expect(await controller.loadMoreBefore(), isTrue);
        expect(controller.messages.last.content, 'partial answer');
        expect(controller.messages.last.isStreaming, isTrue);

        final completed = partial.copyWith(
          content: 'complete answer',
          isStreaming: false,
        );
        expect(controller.publishTerminalMessage(completed), isTrue);

        expect(controller.messages.last.content, 'complete answer');
        expect(controller.messages.last.isStreaming, isFalse);
      },
    );

    test('visible version keeps its in-memory translation snapshot', () async {
      messages = <ChatMessage>[
        _versionedMessage(
          id: 'answer-v0',
          role: 'assistant',
          groupId: 'answer',
          version: 0,
        ),
        _versionedMessage(
          id: 'answer-v1',
          role: 'assistant',
          groupId: 'answer',
          version: 1,
        ),
      ];
      conversation = Conversation(
        id: conversation.id,
        title: conversation.title,
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages)
        ..versionSelections = const {'answer': 1};
      controller.dispose();
      controller = ChatController(chatService: chatService);
      await controller.setCurrentConversationAndLoad(conversation);

      final translating = controller.messages.single.copyWith(
        translation: 'Translating…',
      );
      expect(controller.replaceMessageSnapshot(translating), isTrue);
      expect(controller.collapsedMessages.single.translation, 'Translating…');

      final partial = translating.copyWith(translation: 'Translated chunk');
      expect(controller.replaceMessageSnapshot(partial), isTrue);
      expect(
        controller.collapsedMessages.single.translation,
        'Translated chunk',
      );
    });

    test('generation lifecycle signals are isolated by conversation', () async {
      await controller.setCurrentConversationAndLoad(conversation);
      final background = ChatMessage(
        id: 'background-assistant',
        role: 'assistant',
        content: '',
        conversationId: 'background-conversation',
        isStreaming: true,
      );
      final foreground = ChatMessage(
        id: 'evicted-assistant',
        role: 'assistant',
        content: '',
        conversationId: conversation.id,
        isStreaming: true,
      );

      controller.setConversationLoading(background.conversationId, true);
      expect(controller.isCurrentConversationLoading, isFalse);
      controller.setConversationLoading(foreground.conversationId, true);
      expect(controller.isCurrentConversationLoading, isTrue);

      controller.setConversationLoading(background.conversationId, false);
      expect(controller.isCurrentConversationLoading, isTrue);
      controller.setConversationLoading(foreground.conversationId, false);
      expect(controller.isCurrentConversationLoading, isFalse);
    });

    test('clears current conversation when the service deletes it', () async {
      chatService.knownConversationIds.add(conversation.id);
      await controller.setCurrentConversationAndLoad(conversation);

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

    test(
      'opening a 5000-message conversation keeps only the tail window',
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

        await controller.setCurrentConversationAndLoad(conversation);

        expect(chatService.fullLoadCalls, 0);
        expect(chatService.recentLoadCalls, 0);
        expect(controller.messages.length, 40);
        expect(controller.messages.first.id, 'message-4960');
        expect(controller.messages.last.id, 'message-4999');
        expect(controller.loadedStartIndex, 4960);
        expect(controller.totalMessageCount, 5000);
        expect(controller.hasMoreBefore, isTrue);
      },
    );

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

        await controller.setCurrentConversationAndLoad(conversation);

        expect(controller.messages.last.id, 'message-99');
        expect(controller.loadedStartIndex, 60);
        expect(controller.messages.length, 40);
        expect(
          controller.collapsedMessages.map((message) => message.id),
          isNot(contains('message-10-v1')),
        );
        expect(controller.collapsedMessages.first.id, 'message-60');
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
        await controller.setCurrentConversationAndLoad(conversation);
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
        await controller.setCurrentConversationAndLoad(conversation);

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

        await controller.setCurrentConversationAndLoad(conversation);

        final collapsedIds = controller.collapsedMessages
            .map((message) => message.id)
            .toList();
        expect(collapsedIds, contains('message-99-v1'));
        expect(collapsedIds, isNot(contains('message-99-v0')));
        expect(controller.collapsedMessages.last.id, 'message-99-v1');
      },
    );

    test(
      'collapse treats version selection as a version value, not an index',
      () async {
        messages = <ChatMessage>[
          _versionedMessage(
            id: 'answer-v1',
            role: 'assistant',
            groupId: 'answer',
            version: 1,
          ),
          _versionedMessage(
            id: 'answer-v2',
            role: 'assistant',
            groupId: 'answer',
            version: 2,
          ),
        ];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Sparse versions',
          messageIds: messages.map((message) => message.id).toList(),
          versionSelections: const <String, int>{'answer': 1},
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const <String, int>{'answer': 1};
        controller.dispose();
        controller = ChatController(chatService: chatService);

        await controller.setCurrentConversationAndLoad(conversation);

        expect(controller.collapsedMessages.single.id, 'answer-v1');
      },
    );

    test(
      'opening preloads the persisted selected version before first paint',
      () async {
        messages = <ChatMessage>[
          _versionedMessage(
            id: 'answer-v0',
            role: 'assistant',
            groupId: 'answer',
            version: 0,
          ),
          _versionedMessage(
            id: 'answer-v1',
            role: 'assistant',
            groupId: 'answer',
            version: 1,
          ),
        ];
        conversation = Conversation(
          id: conversation.id,
          title: conversation.title,
          messageIds: messages.map((message) => message.id).toList(),
          versionSelections: const {'answer': 1},
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const {'answer': 1}
          ..timelineSelectedVersionOverride = 0
          ..requireGroupLoad = true;
        controller.dispose();
        controller = ChatController(chatService: chatService);

        await controller.setCurrentConversationAndLoad(conversation);

        expect(chatService.groupsLoaded, isTrue);
        expect(controller.collapsedMessages.single.id, 'answer-v1');
        expect(controller.groupedMessages['answer'], hasLength(2));
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

        await controller.setCurrentConversationAndLoad(conversation);

        expect(controller.messages.first.id, 'message-61');
        expect(controller.loadedStartIndex, 61);
        expect(controller.collapsedMessages.last.id, 'final-v0');
        expect(controller.collapsedMessages.length, 40);
      },
    );

    test(
      'loading older history prepends one page before the visible window',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);

        final loaded = await controller.loadMoreBefore();

        expect(loaded, isTrue);
        expect(chatService.rangeLoadCalls, 2);
        expect(controller.messages, messages.sublist(40));
        expect(controller.loadedStartIndex, 40);
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
      await controller.setCurrentConversationAndLoad(conversation);

      for (var i = 0; i < 30; i++) {
        expect(await controller.loadMoreBefore(), isTrue);
      }

      expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
      expect(controller.messages.first.id, 'message-4360');
      expect(controller.messages.last.id, 'message-4719');
      expect(controller.loadedStartIndex, 4360);
      expect(controller.hasMoreBefore, isTrue);
      expect(controller.hasMoreAfter, isTrue);
    });

    test('loading older history stops at the beginning', () async {
      await controller.setCurrentConversationAndLoad(conversation);

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
        await controller.setCurrentConversationAndLoad(conversation);

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
      await controller.setCurrentConversationAndLoad(conversation);

      final visible = await controller.loadUntilMessageVisible('message-2500');

      expect(visible, isTrue);
      expect(chatService.rangeLoadCalls, 2);
      expect(controller.messages.length, 41);
      expect(controller.messages.first.id, 'message-2480');
      expect(controller.messages.last.id, 'message-2520');
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
      await controller.setCurrentConversationAndLoad(conversation);
      await controller.loadUntilMessageVisible('message-2500');

      final loaded = await controller.loadMoreAfter();

      expect(loaded, isTrue);
      expect(controller.messages.length, 61);
      expect(controller.messages.first.id, 'message-2480');
      expect(controller.messages.last.id, 'message-2540');
      expect(controller.loadedStartIndex, 2480);
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
        await controller.setCurrentConversationAndLoad(conversation);
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
        await controller.setCurrentConversationAndLoad(conversation);
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

    test('publishes an atomic send pair by appending to the tail', () async {
      await controller.setCurrentConversationAndLoad(conversation);
      final user = chatService.appendPersistedMessage(_message(100));
      final assistant = chatService.appendPersistedMessage(_message(101));
      final timelineLoadsBeforeAppend = chatService.timelinePageCalls;

      final appended = await controller.appendPersistedTailMessages([
        user,
        assistant,
      ]);

      expect(appended, isTrue);
      // Incremental append: no extra timeline query for a contiguous tail.
      expect(chatService.timelinePageCalls, timelineLoadsBeforeAppend);
      expect(controller.messages.map((message) => message.id), [
        ...messages.sublist(60, 100).map((message) => message.id),
        user.id,
        assistant.id,
      ]);
      expect(controller.loadedStartIndex, 60);
      expect(controller.totalMessageCount, 102);
      expect(controller.hasMoreAfter, isFalse);
    });

    test('batch append notifies listeners exactly once', () async {
      await controller.setCurrentConversationAndLoad(conversation);
      final user = chatService.appendPersistedMessage(_message(100));
      final assistant = chatService.appendPersistedMessage(_message(101));
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      await controller.appendPersistedTailMessages([user, assistant]);

      expect(notifyCount, 1);
    });

    test(
      'a persisted gap between window tail and batch forces a reload',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);
        // Persist two messages but only hand the last one to the controller:
        // the unseen row in between must trigger the full reload fallback.
        chatService.appendPersistedMessage(_message(100));
        final straggler = chatService.appendPersistedMessage(_message(101));
        final timelineLoadsBeforeAppend = chatService.timelinePageCalls;

        final appended = await controller.appendPersistedTailMessages([
          straggler,
        ]);

        expect(appended, isTrue);
        expect(chatService.timelinePageCalls, timelineLoadsBeforeAppend + 1);
        expect(controller.messages.last.id, straggler.id);
        expect(
          controller.messages.any((message) => message.id == 'message-100'),
          isTrue,
        );
        expect(controller.totalMessageCount, 102);
      },
    );

    test('a new version of a loaded tail group forces a reload', () async {
      await controller.setCurrentConversationAndLoad(conversation);
      final revision = chatService.appendPersistedMessage(
        _versionedMessage(
          id: 'message-99-v1',
          role: 'assistant',
          groupId: 'message-99',
          version: 1,
        ),
      );
      final timelineLoadsBeforeAppend = chatService.timelinePageCalls;

      final appended = await controller.appendPersistedTailMessage(revision);

      expect(appended, isTrue);
      expect(chatService.timelinePageCalls, timelineLoadsBeforeAppend + 1);
      expect(controller.collapsedMessages.last.id, 'message-99-v1');
      expect(controller.totalMessageCount, 100);
    });

    test(
      'multi-version conversations append incrementally without a false gap',
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
          title: 'Multi-version tail',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages);
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);
        expect(
          controller.totalMessageCount,
          ChatService.defaultLoadedWindowMax,
        );
        final timelineLoadsBeforeAppend = chatService.timelinePageCalls;

        // Slot count (360) and revision row count (721) diverge here; the gap
        // check must use row indices and therefore must not misfire.
        final appended = chatService.appendPersistedMessage(
          _message(messages.length),
        );
        final result = await controller.appendPersistedTailMessage(appended);

        expect(result, isTrue);
        expect(chatService.timelinePageCalls, timelineLoadsBeforeAppend);
        expect(controller.messages.last.id, appended.id);
        expect(
          controller.totalMessageCount,
          ChatService.defaultLoadedWindowMax + 1,
        );
        expect(controller.hasMoreAfter, isFalse);
      },
    );

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
        await controller.setCurrentConversationAndLoad(conversation);

        final miniMapMessages = await controller
            .loadAllCollapsedMessagesForCurrentConversation();

        expect(miniMapMessages.length, 5000);
        expect(miniMapMessages.first.id, 'message-0');
        expect(miniMapMessages.last.id, 'message-4999');
        expect(controller.messages.length, 40);
        expect(controller.loadedStartIndex, 4960);
        expect(chatService.fullLoadCalls, 0);
        expect(chatService.activeTimelineLoadCalls, 1);
      },
    );

    test(
      'cross-window target opens by revision cursor instead of offset',
      () async {
        messages = List<ChatMessage>.generate(500, _message);
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Cursor navigation',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages);
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);

        expect(await controller.loadUntilMessageVisible('message-10'), isTrue);

        expect(chatService.messageIndexCalls, 0);
        expect(
          controller.messages.any((message) => message.id == 'message-10'),
          isTrue,
        );
        expect(controller.messages.last.id, isNot('message-499'));
      },
    );

    test(
      'edited middle revision opens around its stable cursor instead of tail',
      () async {
        messages = List<ChatMessage>.generate(500, _message);
        final edited = ChatMessage(
          id: 'message-10-v2',
          role: messages[10].role,
          content: 'edited middle message',
          conversationId: 'conversation-1',
          groupId: 'message-10',
          version: 1,
        );
        messages.add(edited);
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Cursor navigation',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const {'message-10': 1};
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);

        final opened = await controller.openAroundPersistedMessage(edited);

        expect(opened, isTrue);
        expect(
          controller.messages.any((message) => message.id == edited.id),
          isTrue,
        );
        expect(controller.messages.last.id, isNot('message-499'));
      },
    );

    test(
      'edited visible revision preserves the current bounded timeline window',
      () async {
        messages = List<ChatMessage>.generate(500, _message);
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Visible edit',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages);
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);

        final startBeforeEdit = controller.loadedStartIndex;
        expect(
          controller.collapsedMessages
              .singleWhere(
                (message) => (message.groupId ?? message.id) == 'message-470',
              )
              .id,
          'message-470',
        );
        final idsBeforeEdit = controller.messages
            .map((message) => message.groupId ?? message.id)
            .toList();
        final timelineLoadsBeforeEdit = chatService.timelinePageCalls;
        final edited = ChatMessage(
          id: 'message-470-v2',
          role: messages[470].role,
          content: 'edited visible message with a different height',
          conversationId: 'conversation-1',
          groupId: 'message-470',
          version: 1,
        );
        messages.add(edited);
        chatService.versionSelections = const {'message-470': 1};

        final opening = controller.openAroundPersistedMessage(edited);

        expect(
          controller.collapsedMessages
              .singleWhere(
                (message) => (message.groupId ?? message.id) == 'message-470',
              )
              .id,
          edited.id,
        );
        final opened = await opening;

        expect(opened, isTrue);
        expect(controller.loadedStartIndex, startBeforeEdit);
        expect(chatService.timelinePageCalls, timelineLoadsBeforeEdit);
        expect(
          controller.messages.map((message) => message.groupId ?? message.id),
          idsBeforeEdit,
        );
        expect(
          controller.messages
              .singleWhere(
                (message) => (message.groupId ?? message.id) == 'message-470',
              )
              .id,
          edited.id,
        );
      },
    );

    test(
      'visible persisted mutation reconciles the window after truncation',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);
        final timelineLoadsBeforeMutation = chatService.timelinePageCalls;
        final regenerated = ChatMessage(
          id: 'message-80-v2',
          role: messages[80].role,
          content: '',
          conversationId: conversation.id,
          groupId: 'message-80',
          version: 1,
          isStreaming: true,
        );
        messages
          ..removeRange(81, messages.length)
          ..add(regenerated);
        chatService.versionSelections = const {'message-80': 1};

        final opened = await controller.openAroundPersistedMessage(
          regenerated,
          truncateFollowingSlots: true,
        );

        expect(opened, isTrue);
        expect(chatService.timelinePageCalls, timelineLoadsBeforeMutation);
        expect(controller.messages.first.id, 'message-60');
        expect(controller.messages.last.id, regenerated.id);
        expect(controller.totalMessageCount, 81);
        expect(controller.hasMoreAfter, isFalse);
        expect(
          controller.messages.any((message) => message.id == 'message-81'),
          isFalse,
        );
        expect(
          controller.messageRenderModels.any(
            (model) => model.message.id == 'message-81',
          ),
          isFalse,
        );
      },
    );

    test(
      'visible edit keeps every version switcher while groups reload',
      () async {
        messages = <ChatMessage>[
          _versionedMessage(
            id: 'answer-a-v0',
            role: 'assistant',
            groupId: 'answer-a',
            version: 0,
          ),
          _versionedMessage(
            id: 'answer-a-v1',
            role: 'assistant',
            groupId: 'answer-a',
            version: 1,
          ),
          _versionedMessage(
            id: 'answer-b-v0',
            role: 'assistant',
            groupId: 'answer-b',
            version: 0,
          ),
          _versionedMessage(
            id: 'answer-b-v1',
            role: 'assistant',
            groupId: 'answer-b',
            version: 1,
          ),
        ];
        conversation = Conversation(
          id: conversation.id,
          title: conversation.title,
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const {'answer-a': 1, 'answer-b': 1}
          ..requireGroupLoad = true;
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);
        expect(
          controller.messageRenderModels.map((model) => model.versionCount),
          [2, 2],
        );

        final edited = _versionedMessage(
          id: 'answer-a-v2',
          role: 'assistant',
          groupId: 'answer-a',
          version: 2,
        );
        messages.add(edited);
        chatService
          ..versionSelections = const {'answer-a': 2, 'answer-b': 1}
          ..groupsLoaded = false
          ..groupLoadRequests.clear()
          ..groupLoadGate = Completer<void>();

        final opening = controller.openAroundPersistedMessage(edited);
        await Future<void>.delayed(Duration.zero);

        expect(chatService.groupLoadRequests.single, {'answer-a', 'answer-b'});
        expect(
          controller.messageRenderModels.map((model) => model.versionCount),
          [3, 2],
        );

        chatService.groupLoadGate!.complete();
        expect(await opening, isTrue);
        expect(
          controller.messageRenderModels.map((model) => model.versionCount),
          [3, 2],
        );
      },
    );

    test(
      'regenerated middle revision opens around its stable cursor instead of tail',
      () async {
        messages = List<ChatMessage>.generate(5000, _message);
        final regenerated = ChatMessage(
          id: 'message-2500-v2',
          role: messages[2500].role,
          content: '',
          conversationId: 'conversation-1',
          groupId: 'message-2500',
          version: 1,
          isStreaming: true,
        );
        messages.add(regenerated);
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Very long regeneration',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const {'message-2500': 1};
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);

        final opened = await controller.openAroundPersistedMessage(regenerated);

        expect(opened, isTrue);
        expect(
          controller.messages.any((message) => message.id == regenerated.id),
          isTrue,
        );
        expect(controller.messages.first.id, 'message-2480');
        expect(controller.messages.last.id, 'message-2520');
        expect(controller.hasMoreBefore, isTrue);
        expect(controller.hasMoreAfter, isTrue);
      },
    );

    test(
      'mutation refresh removes a deleted slot from every window view',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);
        messages.removeWhere((message) => message.id == 'message-80');

        expect(
          await controller.refreshTimelineAfterMutation(
            removedRevisionIds: const {'message-80'},
          ),
          isTrue,
        );

        expect(
          controller.messages.any((message) => message.id == 'message-80'),
          isFalse,
        );
      },
    );

    test('mutation refresh keeps a full tail window at the tail', () async {
      messages = List<ChatMessage>.generate(1000, _message);
      conversation = Conversation(
        id: 'conversation-1',
        title: 'Long chat',
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages);
      controller.dispose();
      controller = ChatController(chatService: chatService);
      await controller.setCurrentConversationAndLoad(conversation);
      await controller.loadEndWindow();
      messages.removeLast();

      await controller.refreshTimelineAfterMutation(
        removedRevisionIds: const {'message-999'},
      );

      expect(controller.messages.last.id, 'message-998');
      expect(controller.hasMoreAfter, isFalse);
    });

    test('mutation refresh does not backfill the window head', () async {
      messages = List<ChatMessage>.generate(1000, _message);
      conversation = Conversation(
        id: 'conversation-1',
        title: 'Long chat',
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages);
      controller.dispose();
      controller = ChatController(chatService: chatService);
      await controller.setCurrentConversationAndLoad(conversation);
      await controller.loadEndWindow();
      final headBefore = controller.messages.first.id;
      final countBefore = controller.messages.length;
      messages.removeLast();

      await controller.refreshTimelineAfterMutation(
        removedRevisionIds: const {'message-999'},
      );

      // The refreshed window has to stay a prefix of the old one: pulling an
      // older message in at the head instead would keep the list length
      // unchanged and shift every slot by one, which leaves SuperSliverList
      // reusing its children with stale layout offsets and the viewport stuck
      // above the real bottom.
      expect(controller.messages.first.id, headBefore);
      expect(controller.messages.length, countBefore - 1);
      expect(controller.hasMoreBefore, isTrue);
      expect(controller.hasMoreAfter, isFalse);
    });

    test('mutation refresh keeps a full window after a batch delete', () async {
      messages = List<ChatMessage>.generate(1000, _message);
      conversation = Conversation(
        id: 'conversation-1',
        title: 'Long chat',
        messageIds: messages.map((message) => message.id).toList(),
      );
      chatService = _FakeLazyChatService(messages);
      controller.dispose();
      controller = ChatController(chatService: chatService);
      await controller.setCurrentConversationAndLoad(conversation);
      await controller.loadEndWindow();
      final removed = <String>{
        for (var index = 640; index < 999; index++) 'message-$index',
      };
      messages.removeRange(640, 999);

      await controller.refreshTimelineAfterMutation(
        removedRevisionIds: removed,
      );

      // Almost the whole window is gone, so trimming to the surviving slots
      // would leave a near-empty list that only refills on scroll. Keeping the
      // reloaded window is worth losing the child reuse here.
      expect(controller.messages.length, ChatService.defaultLoadedWindowMax);
      expect(controller.messages.last.id, 'message-999');
      // The window has to be the reloaded one, not the pre-delete window: it
      // starts at the new tail-anchored head and holds no deleted revision.
      expect(controller.messages.first.id, 'message-281');
      expect(
        controller.messages.every((message) => !removed.contains(message.id)),
        isTrue,
      );
    });

    test(
      'mutation refresh with survivor data edits the window in place',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);
        final callsBefore = chatService.timelinePageCalls;
        messages.removeWhere((message) => message.id == 'message-80');

        expect(
          await controller.refreshTimelineAfterMutation(
            removedRevisionIds: const {'message-80'},
            survivingVersionsByGroup: const {'message-80': <ChatMessage>[]},
          ),
          isTrue,
        );

        // The surviving slots keep their identity and order: the list widget
        // then sees a pure removal instead of a reshaped window that would
        // drop every measured row height and make the viewport drift.
        expect(controller.messages.map((message) => message.id), [
          for (var index = 60; index < 100; index++)
            if (index != 80) 'message-$index',
        ]);
        expect(controller.totalMessageCount, 99);
        expect(controller.hasMoreBefore, isTrue);
        expect(controller.hasMoreAfter, isFalse);
        expect(chatService.timelinePageCalls, callsBefore);
      },
    );

    test(
      'mutation refresh swaps the surviving version into its slot in place',
      () async {
        final survivor = _versionedMessage(
          id: 'answer-v0',
          role: 'assistant',
          groupId: 'answer',
          version: 0,
        );
        messages = [
          ...List<ChatMessage>.generate(10, _message),
          survivor,
          _versionedMessage(
            id: 'answer-v1',
            role: 'assistant',
            groupId: 'answer',
            version: 1,
          ),
        ];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Versioned chat',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const {'answer': 1};
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);
        expect(controller.messages.last.id, 'answer-v1');
        final callsBefore = chatService.timelinePageCalls;

        // The service applies the deletion and the new selection before the
        // timeline refresh runs, mirroring the view-model delete flow.
        messages.removeWhere((message) => message.id == 'answer-v1');
        chatService.versionSelections = const {'answer': 0};
        controller.loadVersionSelections();

        expect(
          await controller.refreshTimelineAfterMutation(
            removedRevisionIds: const {'answer-v1'},
            survivingVersionsByGroup: {
              'answer': [survivor],
            },
          ),
          isTrue,
        );

        expect(controller.messages.last.id, 'answer-v0');
        expect(controller.messages.length, 11);
        expect(controller.totalMessageCount, 11);
        expect(chatService.timelinePageCalls, callsBefore);
      },
    );

    test(
      'mutation refresh reloads when a deleted slot is outside the window',
      () async {
        messages = List<ChatMessage>.generate(1000, _message);
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Long chat',
          messageIds: messages.map((message) => message.id).toList(),
        );
        chatService = _FakeLazyChatService(messages);
        controller.dispose();
        controller = ChatController(chatService: chatService);
        await controller.setCurrentConversationAndLoad(conversation);
        final callsBefore = chatService.timelinePageCalls;
        messages.removeWhere((message) => message.id == 'message-100');

        expect(
          await controller.refreshTimelineAfterMutation(
            removedRevisionIds: const {'message-100'},
            survivingVersionsByGroup: const {'message-100': <ChatMessage>[]},
          ),
          isTrue,
        );

        // An in-place edit cannot track slot counts outside the window, so
        // this must fall back to the full reload.
        expect(chatService.timelinePageCalls, greaterThan(callsBefore));
        expect(controller.totalMessageCount, 999);
      },
    );

    test('temporary sends append directly to the linear window', () async {
      messages = <ChatMessage>[];
      conversation = Conversation(
        id: 'temporary-conversation',
        title: 'Temporary',
      );
      chatService = _FakeLazyChatService(messages)..temporary = true;
      controller.dispose();
      controller = ChatController(chatService: chatService);
      controller.setDraftConversation(conversation);
      final user = chatService.appendPersistedMessage(
        ChatMessage(
          id: 'temporary-user',
          role: 'user',
          content: 'secret',
          conversationId: conversation.id,
        ),
      );
      final assistant = chatService.appendPersistedMessage(
        ChatMessage(
          id: 'temporary-assistant',
          role: 'assistant',
          content: '',
          conversationId: conversation.id,
          isStreaming: true,
        ),
      );

      expect(
        await controller.appendPersistedTailMessages([user, assistant]),
        isTrue,
      );

      expect(controller.messages, [user, assistant]);
    });

    test('maps persisted truncate index into the loaded tail window', () async {
      final truncatedConversation = conversation.copyWith(truncateIndex: 90);
      chatService.contextStartIndex = 90;
      await controller.setCurrentConversationAndLoad(truncatedConversation);

      expect(controller.loadedWindowTruncateIndex(), 30);
      expect(
        controller
            .conversationForLoadedWindow(truncatedConversation)
            .truncateIndex,
        30,
      );
    });

    test(
      'model context source keeps complete history and persisted truncate index',
      () async {
        final truncatedConversation = conversation.copyWith(truncateIndex: 30);
        chatService.contextStartIndex = 30;
        await controller.setCurrentConversationAndLoad(truncatedConversation);

        final contextMessages = await controller
            .allMessagesForCurrentConversationContext();
        final contextConversation = controller
            .conversationForCompleteHistoryContext(truncatedConversation);

        expect(contextMessages, messages);
        expect(contextConversation.truncateIndex, 30);
        expect(controller.messages, messages.sublist(60));
        expect(controller.loadedStartIndex, 60);
        expect(chatService.fullLoadCalls, 1);
      },
    );

    test(
      'creating a draft conversation clears the loaded history window',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);

        final draft = await controller.createNewConversation(title: 'Draft');

        expect(draft.title, 'Draft');
        expect(controller.messages, isEmpty);
        expect(controller.loadedStartIndex, 0);
        expect(controller.totalMessageCount, 0);
        expect(controller.hasMoreBefore, isFalse);
      },
    );

    test(
      'allCollapsedMessagesForCurrentConversation uses loaded window only',
      () async {
        await controller.setCurrentConversationAndLoad(conversation);
        final rangeCallsBefore = chatService.rangeLoadCalls;

        final collapsed = controller
            .allCollapsedMessagesForCurrentConversation();

        expect(collapsed, controller.collapsedMessages);
        expect(collapsed.length, controller.messages.length);
        // Must not walk the full conversation via getMessagesRange.
        expect(chatService.rangeLoadCalls, rangeCallsBefore);
        expect(chatService.fullLoadCalls, 0);
      },
    );

    test(
      'fetch/open visible-group preload does not await full message order',
      () async {
        // Issue 2: first window + directed group preload must complete even
        // when a full-order backfill would be blocked. The fake never exposes
        // getMessageIds; hanging here would mean the controller still awaits
        // a full-order path on open.
        final user = _versionedMessage(
          id: 'user-1',
          role: 'user',
          groupId: 'user-1',
          version: 0,
        );
        final v0 = _versionedMessage(
          id: 'assistant-v0',
          role: 'assistant',
          groupId: 'assistant',
          version: 0,
        );
        final v1 = _versionedMessage(
          id: 'assistant-v1',
          role: 'assistant',
          groupId: 'assistant',
          version: 1,
        );
        messages = [user, v0, v1];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Multi-version gated order',
          messageIds: messages.map((m) => m.id).toList(),
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const {'assistant': 1}
          ..requireGroupLoad = true
          ..groupLoadGate = Completer<void>();
        controller.dispose();
        controller = ChatController(chatService: chatService);

        final fetchFuture = controller.fetchConversationWindow(conversation);
        // Preload is in-flight on the directed group path only.
        await Future<void>.delayed(Duration.zero);
        expect(chatService.groupLoadRequests, isNotEmpty);
        expect(chatService.fullLoadCalls, 0);
        expect(chatService.timelinePageCalls, 1);

        chatService.groupLoadGate!.complete();
        final fetched = await fetchFuture.timeout(const Duration(seconds: 2));
        controller.commitConversationWindow(fetched);

        expect(controller.collapsedMessages.map((m) => m.id), [
          'user-1',
          'assistant-v1',
        ]);
        expect(chatService.fullLoadCalls, 0);
        expect(
          chatService.groupLoadRequests.any((ids) => ids.contains('assistant')),
          isTrue,
        );
      },
    );

    test(
      'multi-version open preloads groups and projects the selected version',
      () async {
        final user = _versionedMessage(
          id: 'user-1',
          role: 'user',
          groupId: 'user-1',
          version: 0,
        );
        final v0 = _versionedMessage(
          id: 'assistant-v0',
          role: 'assistant',
          groupId: 'assistant',
          version: 0,
        );
        final v1 = _versionedMessage(
          id: 'assistant-v1',
          role: 'assistant',
          groupId: 'assistant',
          version: 1,
        );
        messages = [user, v0, v1];
        conversation = Conversation(
          id: 'conversation-1',
          title: 'Multi-version',
          messageIds: messages.map((m) => m.id).toList(),
        );
        chatService = _FakeLazyChatService(messages)
          ..versionSelections = const {'assistant': 1};
        controller.dispose();
        controller = ChatController(chatService: chatService);

        await controller.setCurrentConversationAndLoad(conversation);

        expect(controller.collapsedMessages.map((m) => m.id), [
          'user-1',
          'assistant-v1',
        ]);
        expect(chatService.groupLoadRequests, isNotEmpty);
        expect(
          chatService.groupLoadRequests.any((ids) => ids.contains('assistant')),
          isTrue,
        );
        expect(chatService.fullLoadCalls, 0);
        expect(
          controller.allCollapsedMessagesForCurrentConversation().map(
            (m) => m.id,
          ),
          ['user-1', 'assistant-v1'],
        );
      },
    );
  });
}
