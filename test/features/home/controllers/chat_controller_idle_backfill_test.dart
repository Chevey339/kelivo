import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';

class _BackfillChatService extends ChatService {
  _BackfillChatService(this._messagesByConversation);

  final Map<String, List<ChatMessage>> _messagesByConversation;
  final Map<String, int> fullLoadCalls = <String, int>{};
  bool fullyCached = false;

  List<ChatMessage> _messages(String conversationId) =>
      _messagesByConversation[conversationId] ?? const <ChatMessage>[];

  int loadCallsFor(String conversationId) => fullLoadCalls[conversationId] ?? 0;

  @override
  bool isConversationFullyCached(String conversationId) => fullyCached;

  @override
  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    fullLoadCalls[conversationId] = loadCallsFor(conversationId) + 1;
    fullyCached = true;
    return List<ChatMessage>.of(_messages(conversationId));
  }

  @override
  int getMessageCount(String conversationId) =>
      _messages(conversationId).length;

  @override
  int getMessageIndex(String conversationId, String messageId) => _messages(
    conversationId,
  ).indexWhere((message) => message.id == messageId);

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    final all = _messages(conversationId);
    final start = (all.length - limit).clamp(0, all.length);
    final selected = all.sublist(start);
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
              parentRevisionId: null,
              role: message.role,
              createdAt: timestamp,
              updatedAt: timestamp,
              finalizedAt: timestamp,
              versionCount: 1,
              logicalIndex: start + offset,
            ),
            message: message,
          ),
      ],
      hasMoreBefore: start > 0,
      hasMoreAfter: false,
      totalSlotCount: all.length,
    );
  }

  @override
  Conversation? getConversation(String id) {
    final messages = _messagesByConversation[id];
    if (messages == null) return null;
    return Conversation(
      id: id,
      title: 'Conversation $id',
      messageIds: messages.map((message) => message.id).toList(),
    );
  }

  @override
  Map<String, int> getVersionSelections(String conversationId) =>
      const <String, int>{};

  @override
  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) => const <ChatMessage>[];

  @override
  Future<List<ChatMessage>> loadMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => const <ChatMessage>[];

  @override
  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) => const <String, int>{};

  @override
  Future<Map<String, int>> loadFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => const <String, int>{};
}

List<ChatMessage> _messages(String conversationId, int count) {
  return [
    for (var index = 0; index < count; index++)
      ChatMessage(
        id: '$conversationId-message-$index',
        role: index.isEven ? 'user' : 'assistant',
        content: '$conversationId message $index',
        conversationId: conversationId,
      ),
  ];
}

/// Lets queued idle-priority scheduler tasks run.
Future<void> _flushIdleTasks() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatController idle cache backfill', () {
    late _BackfillChatService chatService;
    late ChatController controller;

    setUp(() {
      chatService = _BackfillChatService(<String, List<ChatMessage>>{});
      controller = ChatController(chatService: chatService);
    });

    tearDown(() {
      controller.dispose();
    });

    Future<void> open(String conversationId) {
      return controller.setCurrentConversationAndLoad(
        chatService.getConversation(conversationId)!,
      );
    }

    test('opening a conversation backfills its full cache when idle', () async {
      chatService._messagesByConversation['conv-a'] = _messages('conv-a', 5);

      await open('conv-a');
      expect(chatService.loadCallsFor('conv-a'), 0);

      await _flushIdleTasks();

      expect(chatService.loadCallsFor('conv-a'), 1);
      expect(controller.messages, hasLength(5));
      expect(controller.totalMessageCount, 5);
    });

    test('committing a fetched window also schedules the backfill', () async {
      chatService._messagesByConversation['conv-a'] = _messages('conv-a', 3);

      final fetched = await controller.fetchConversationWindow(
        chatService.getConversation('conv-a')!,
      );
      controller.commitConversationWindow(fetched);
      await _flushIdleTasks();

      expect(chatService.loadCallsFor('conv-a'), 1);
    });

    test('abandons the backfill after switching away', () async {
      chatService._messagesByConversation['conv-a'] = _messages('conv-a', 5);
      chatService._messagesByConversation['conv-b'] = _messages('conv-b', 3);
      await open('conv-a');
      await open('conv-b');

      await controller.backfillCurrentConversationCache('conv-a');
      await _flushIdleTasks();

      expect(chatService.loadCallsFor('conv-a'), 0);
      expect(chatService.loadCallsFor('conv-b'), 1);
    });

    test('skips conversations beyond the slot threshold', () async {
      chatService._messagesByConversation['conv-a'] = _messages(
        'conv-a',
        ChatController.idleCacheBackfillSlotLimit + 1,
      );
      await open('conv-a');

      await controller.backfillCurrentConversationCache('conv-a');
      await _flushIdleTasks();

      expect(chatService.loadCallsFor('conv-a'), 0);
      expect(
        controller.messages.length,
        ChatService.defaultTimelineInitialSlots,
      );
    });

    test('pauses while generating and resumes when generation ends', () async {
      chatService._messagesByConversation['conv-a'] = _messages('conv-a', 5);
      await open('conv-a');
      controller.setConversationLoading('conv-a', true);

      await controller.backfillCurrentConversationCache('conv-a');
      expect(chatService.loadCallsFor('conv-a'), 0);

      controller.setConversationLoading('conv-a', false);
      await _flushIdleTasks();

      expect(chatService.loadCallsFor('conv-a'), 1);
    });

    test('skips an already fully cached conversation', () async {
      chatService._messagesByConversation['conv-a'] = _messages('conv-a', 5);
      await open('conv-a');
      chatService.fullyCached = true;

      await controller.backfillCurrentConversationCache('conv-a');

      expect(chatService.loadCallsFor('conv-a'), 0);
    });
  });
}
