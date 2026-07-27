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
      const <String, int>{'group-a': 1};

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
  group('ChatController fetch/commit conversation window', () {
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

    Future<void> openConversation(String id) async {
      final open = controller.setCurrentConversationAndLoad(
        service.getConversation(id)!,
      );
      final messages = service._messagesByConversation[id]!;
      service.completePage(service.pageRequests.last, messages, startIndex: 0);
      await open;
    }

    test('fetch does not mutate current state or notify', () async {
      await openConversation('conv-a');
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      final fetch = controller.fetchConversationWindow(
        service.getConversation('conv-b')!,
      );
      service.completePage(
        service.pageRequests.last,
        service._messagesByConversation['conv-b']!,
        startIndex: 0,
      );
      final fetched = await fetch;

      expect(fetched.conversation.id, 'conv-b');
      expect(fetched.page, isNotNull);
      expect(fetched.versionSelections, const {'group-a': 1});
      expect(controller.currentConversation?.id, 'conv-a');
      expect(controller.messages.map((m) => m.conversationId).toSet(), {
        'conv-a',
      });
      expect(controller.messages, hasLength(5));
      expect(controller.isLoadingWindow, isFalse);
      expect(notifyCount, 0);
    });

    test('commit installs the fetched window atomically', () async {
      await openConversation('conv-a');
      final fetch = controller.fetchConversationWindow(
        service.getConversation('conv-b')!,
      );
      service.completePage(
        service.pageRequests.last,
        service._messagesByConversation['conv-b']!,
        startIndex: 0,
      );
      final fetched = await fetch;

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.commitConversationWindow(fetched);

      expect(controller.currentConversation?.id, 'conv-b');
      expect(controller.messages.map((m) => m.conversationId).toSet(), {
        'conv-b',
      });
      expect(controller.messages, hasLength(3));
      expect(controller.totalMessageCount, 3);
      expect(controller.versionSelections, const {'group-a': 1});
      expect(controller.isLoadingWindow, isFalse);
      expect(notifyCount, 1);
    });

    test('commit supersedes an in-flight window load', () async {
      // Start a regular open of conv-a whose page is still pending.
      final open = controller.setCurrentConversationAndLoad(
        service.getConversation('conv-a')!,
      );
      expect(controller.isLoadingWindow, isTrue);

      // Fetch and commit conv-b before conv-a's page arrives.
      final fetch = controller.fetchConversationWindow(
        service.getConversation('conv-b')!,
      );
      service.completePage(
        service.pageRequests.last,
        service._messagesByConversation['conv-b']!,
        startIndex: 0,
      );
      controller.commitConversationWindow(await fetch);
      expect(controller.currentConversation?.id, 'conv-b');
      expect(controller.isLoadingWindow, isFalse);

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      // conv-a's late page must be discarded and must not clear the flag.
      service.completePage(
        service.pageRequests.first,
        service._messagesByConversation['conv-a']!,
        startIndex: 0,
      );
      await open;

      expect(controller.currentConversation?.id, 'conv-b');
      expect(controller.messages.map((m) => m.conversationId).toSet(), {
        'conv-b',
      });
      expect(controller.isLoadingWindow, isFalse);
      expect(notifyCount, 0);
    });
  });
}
