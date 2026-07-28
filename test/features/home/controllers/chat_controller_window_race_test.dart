import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';

class _PageRequest {
  _PageRequest({required this.conversationId, required this.completer});

  final String conversationId;
  final Completer<LoadedTimelinePage?> completer;
}

class _ControlledChatService extends ChatService {
  _ControlledChatService(this._messagesByConversation);

  final Map<String, List<ChatMessage>> _messagesByConversation;
  final List<_PageRequest> pageRequests = <_PageRequest>[];

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) {
    final completer = Completer<LoadedTimelinePage?>();
    pageRequests.add(
      _PageRequest(conversationId: conversationId, completer: completer),
    );
    return completer.future;
  }

  void completePage(
    _PageRequest request,
    List<ChatMessage> messages, {
    required int startIndex,
    int? totalSlotCount,
  }) {
    final timestamp = DateTime(2026, 7, 11);
    request.completer.complete(
      LoadedTimelinePage(
        conversationId: request.conversationId,
        stateRevision: 0,
        contextStartRevisionId: null,
        slots: [
          for (final (offset, message) in messages.indexed)
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
                logicalIndex: startIndex + offset,
              ),
              message: message,
            ),
        ],
        hasMoreBefore: startIndex > 0,
        hasMoreAfter: false,
        totalSlotCount: totalSlotCount ?? startIndex + messages.length,
      ),
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
  int getMessageCount(String conversationId) =>
      _messagesByConversation[conversationId]?.length ?? 0;

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

ChatMessage _message(String conversationId, int index) {
  return ChatMessage(
    id: '$conversationId-message-$index',
    role: index.isEven ? 'user' : 'assistant',
    content: '$conversationId message $index',
    conversationId: conversationId,
  );
}

void main() {
  group('ChatController window race', () {
    late _ControlledChatService service;
    late ChatController controller;

    setUp(() {
      service = _ControlledChatService({
        'conv-a': [for (var i = 0; i < 5; i++) _message('conv-a', i)],
        'conv-b': [for (var i = 0; i < 3; i++) _message('conv-b', i)],
      });
      controller = ChatController(chatService: service);
    });

    tearDown(() {
      controller.dispose();
    });

    test('switching clears the window synchronously and exposes loading', () {
      final conversation = service.getConversation('conv-a')!;
      unawaited(controller.setCurrentConversationAndLoad(conversation));

      expect(controller.currentConversation?.id, 'conv-a');
      expect(controller.messages, isEmpty);
      expect(controller.isLoadingWindow, isTrue);
    });

    test(
      'late page from conversation A is discarded after switching to B',
      () async {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        final switchA = controller.setCurrentConversationAndLoad(
          service.getConversation('conv-a')!,
        );
        final switchB = controller.setCurrentConversationAndLoad(
          service.getConversation('conv-b')!,
        );
        expect(service.pageRequests, hasLength(2));

        // A's page arrives late and must not touch the current window.
        service.completePage(
          service.pageRequests[0],
          [_message('conv-a', 3), _message('conv-a', 4)],
          startIndex: 3,
          totalSlotCount: 5,
        );
        await switchA;
        expect(controller.currentConversation?.id, 'conv-b');
        expect(controller.messages, isEmpty);
        expect(controller.isLoadingWindow, isTrue);
        expect(notifyCount, 0);

        service.completePage(service.pageRequests[1], [
          for (var i = 0; i < 3; i++) _message('conv-b', i),
        ], startIndex: 0);
        await switchB;
        expect(controller.messages.map((m) => m.conversationId).toSet(), {
          'conv-b',
        });
        expect(controller.messages, hasLength(3));
        expect(controller.isLoadingWindow, isFalse);
        expect(notifyCount, 1);
      },
    );

    test('loadMoreBefore applies normally for the same conversation', () async {
      final open = controller.setCurrentConversationAndLoad(
        service.getConversation('conv-a')!,
      );
      service.completePage(
        service.pageRequests.single,
        [_message('conv-a', 2), _message('conv-a', 3), _message('conv-a', 4)],
        startIndex: 2,
        totalSlotCount: 5,
      );
      await open;
      expect(controller.hasMoreBefore, isTrue);

      final loadMore = controller.loadMoreBefore(limit: 2);
      service.completePage(
        service.pageRequests.last,
        [_message('conv-a', 0), _message('conv-a', 1)],
        startIndex: 0,
        totalSlotCount: 5,
      );
      expect(await loadMore, isTrue);
      expect(controller.messages.map((m) => m.id), [
        for (var i = 0; i < 5; i++) 'conv-a-message-$i',
      ]);
      expect(controller.loadedStartIndex, 0);
      expect(controller.hasMoreBefore, isFalse);
    });

    test('loadMoreBefore result is discarded after switching away', () async {
      final open = controller.setCurrentConversationAndLoad(
        service.getConversation('conv-a')!,
      );
      service.completePage(
        service.pageRequests.single,
        [_message('conv-a', 2), _message('conv-a', 3), _message('conv-a', 4)],
        startIndex: 2,
        totalSlotCount: 5,
      );
      await open;

      final loadMore = controller.loadMoreBefore(limit: 2);
      final switchB = controller.setCurrentConversationAndLoad(
        service.getConversation('conv-b')!,
      );
      expect(service.pageRequests, hasLength(3));

      // The stale pagination completes after the switch; it must not notify.
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);
      service.completePage(
        service.pageRequests[1],
        [_message('conv-a', 0), _message('conv-a', 1)],
        startIndex: 0,
        totalSlotCount: 5,
      );
      expect(await loadMore, isFalse);
      expect(notifyCount, 0);
      expect(controller.messages, isEmpty);

      service.completePage(service.pageRequests[2], [
        for (var i = 0; i < 3; i++) _message('conv-b', i),
      ], startIndex: 0);
      await switchB;
      expect(controller.messages.map((m) => m.conversationId).toSet(), {
        'conv-b',
      });
      expect(controller.messages, hasLength(3));
    });
  });
}
