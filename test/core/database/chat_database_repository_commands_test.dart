import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late ChatDatabaseRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_commands_test_');
    repository = ChatDatabaseRepository.open(
      file: File('${directory.path}/chat.sqlite'),
    );
    await repository.ensureReady();
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  Conversation conversation({
    String id = 'conversation-1',
    List<String> suggestions = const ['suggestion'],
  }) {
    return Conversation(
      id: id,
      title: 'Conversation',
      chatSuggestions: suggestions,
    );
  }

  ChatMessage message({
    required String id,
    String conversationId = 'conversation-1',
    String role = 'assistant',
    String? groupId,
    int version = 0,
    bool isStreaming = false,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: id,
      conversationId: conversationId,
      groupId: groupId ?? id,
      version: version,
      isStreaming: isStreaming,
    );
  }

  test(
    'legacy append persists conversation and selection without active JSON',
    () async {
      final persisted = await repository.appendMessageToConversation(
        conversation: conversation(),
        message: message(
          id: 'message-1',
          groupId: 'group-1',
          version: 1,
          isStreaming: true,
        ),
        selectVersion: true,
      );

      expect(persisted.messageIds, const ['message-1']);
      expect(persisted.versionSelections, const {'group-1': 1});
      expect((await repository.getConversation('conversation-1'))?.messageIds, [
        'message-1',
      ]);
      expect(await repository.getActiveStreamingIds(), isEmpty);
    },
  );

  test(
    'append rolls back the conversation when message validation fails',
    () async {
      await expectLater(
        repository.appendMessageToConversation(
          conversation: conversation(),
          message: message(id: 'message-1', role: ''),
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('CHECK constraint failed: role'),
          ),
        ),
      );

      expect(await repository.getConversation('conversation-1'), isNull);
      expect(await repository.getMessage('message-1'), isNull);
      expect(await repository.getActiveStreamingIds(), isEmpty);
    },
  );

  test(
    'concurrent appends allocate unique order inside transactions',
    () async {
      final base = conversation();
      await Future.wait([
        for (var index = 0; index < 12; index++)
          repository.appendMessageToConversation(
            conversation: base,
            message: message(id: 'message-$index'),
          ),
      ]);

      final ids = await repository.getMessageIds('conversation-1');
      expect(ids, hasLength(12));
      expect(ids.toSet(), hasLength(12));
    },
  );

  test(
    'append version selects the new row in the linear group',
    () async {
      await repository.appendLinearMessageToConversation(
        conversation: conversation(),
        message: message(id: 'message-0', groupId: 'group-1'),
      );

      final result = await repository.appendMessageVersion(
        messageId: 'message-0',
        content: 'v1',
      );

      expect(result?.message.version, 1);
      final timeline = await repository.loadLinearMessageWindow(
        conversationId: 'conversation-1',
        fromStart: true,
      );
      expect(timeline.slots.single.revisionId, result!.message.id);
      expect(
        (await repository.getConversation('conversation-1'))?.versionSelections,
        const {'group-1': 1},
      );
    },
  );

  test('editing a middle user version preserves the active future', () async {
    final base = conversation();
    for (final item in [
      message(id: 'u1', role: 'user'),
      message(id: 'a1'),
      message(id: 'u2', role: 'user'),
      message(id: 'a2'),
    ]) {
      await repository.appendLinearMessageToConversation(
        conversation: base,
        message: item,
      );
    }

    final result = await repository.appendMessageVersion(
      messageId: 'u2',
      content: 'u2 edited',
    );
    final timeline = await repository.loadLinearMessageWindow(
      conversationId: base.id,
      fromStart: true,
    );

    expect(timeline.slots.map((slot) => slot.revisionId), [
      'u1',
      'a1',
      result!.message.id,
      'a2',
    ]);
    expect(await repository.getMessage('u2'), isNotNull);
    final persisted = await repository.getMessage(result.message.id);
    expect(persisted?.id, result.message.id);
    expect(persisted?.content, 'u2 edited');
  });

  test(
    'concurrent selection and append commands preserve unrelated state',
    () async {
      final base = conversation();
      await repository.appendMessageToConversation(
        conversation: base,
        message: message(id: 'message-0'),
      );

      await Future.wait([
        repository.setSelectedVersion(
          conversationId: 'conversation-1',
          groupId: 'group-1',
          version: 1,
        ),
        repository.setSelectedVersion(
          conversationId: 'conversation-1',
          groupId: 'group-2',
          version: 2,
        ),
        repository.appendMessageToConversation(
          conversation: base,
          message: message(id: 'message-1'),
        ),
      ]);

      expect(
        (await repository.getConversation('conversation-1'))?.versionSelections,
        const {'group-1': 1, 'group-2': 2},
      );
      expect(await repository.getMessageIds('conversation-1'), const [
        'message-0',
        'message-1',
      ]);
    },
  );

  test(
    'fork command rolls back its earlier rows when a later message fails',
    () async {
      await expectLater(
        repository.createConversationWithMessages(
          conversation: conversation(id: 'fork'),
          messages: [
            message(id: 'message-1', conversationId: 'fork'),
            message(id: 'message-2', conversationId: 'fork', role: ''),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('CHECK constraint failed: role'),
          ),
        ),
      );

      expect(await repository.getConversation('fork'), isNull);
      expect(await repository.getMessage('message-1'), isNull);
    },
  );

  test(
    'batch delete atomically updates selection, order and cascaded artifacts',
    () async {
      final messages = [
        message(id: 'message-v0', groupId: 'group-1'),
        message(id: 'user-1', role: 'user'),
        message(id: 'message-v1', groupId: 'group-1', version: 1),
        message(id: 'user-2', role: 'user'),
      ];
      await repository.putMigrationBatch(
        conversations: [
          conversation().copyWith(
            messageIds: messages.map((message) => message.id).toList(),
            versionSelections: const {'group-1': 1},
          ),
        ],
        messages: [
          for (final (index, message) in messages.indexed)
            (message: message, messageOrder: index),
        ],
        toolEventsByMessageId: const {
          'message-v0': [
            {'id': 'tool'},
          ],
        },
        geminiSignaturesByMessageId: const {'message-v0': 'signature'},
      );

      final result = await repository.deleteMessages(
        conversationId: 'conversation-1',
        messageIds: {'message-v0', 'user-1'},
        versionSelectionChanges: const {'group-1': 0},
      );

      expect(result?.messages.map((message) => message.id), [
        'message-v0',
        'user-1',
      ]);
      expect(await repository.getMessageIds('conversation-1'), [
        'message-v1',
        'user-2',
      ]);
      final persisted = await repository.getConversation('conversation-1');
      expect(persisted?.versionSelections, const {'group-1': 1});
      expect(persisted?.chatSuggestions, isEmpty);
      expect(await repository.getToolEvents('message-v0'), isEmpty);
      expect(await repository.getGeminiThoughtSignature('message-v0'), isNull);
    },
  );

  test(
    'batch delete rejects a partial target set without changing data',
    () async {
      final messages = [
        message(id: 'message-0', groupId: 'group-1'),
        message(id: 'message-1', groupId: 'group-1', version: 1),
      ];
      await repository.putMigrationBatch(
        conversations: [
          conversation().copyWith(
            messageIds: messages.map((message) => message.id).toList(),
            versionSelections: const {'group-1': 1},
          ),
        ],
        messages: [
          for (final (index, message) in messages.indexed)
            (message: message, messageOrder: index),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      await expectLater(
        repository.deleteMessages(
          conversationId: 'conversation-1',
          messageIds: {'message-0', 'missing'},
          versionSelectionChanges: const {'group-1': 0},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'delete_messages_not_found',
          ),
        ),
      );

      expect(await repository.getMessageIds('conversation-1'), const [
        'message-0',
        'message-1',
      ]);
      final persisted = await repository.getConversation('conversation-1');
      expect(persisted?.versionSelections, const {'group-1': 1});
      expect(persisted?.chatSuggestions, const ['suggestion']);
    },
  );

  test(
    'final checkpoint stores content, tools and streaming receipt atomically',
    () async {
      final streaming = message(id: 'message-1', isStreaming: true);
      await repository.appendMessageToConversation(
        conversation: conversation(),
        message: streaming,
      );

      await repository.updateStreamingCheckpoint(
        streaming.copyWith(content: 'final', isStreaming: false),
        const [
          {'id': 'tool', 'content': 'result'},
        ],
      );

      expect((await repository.getMessage('message-1'))?.content, 'final');
      expect(await repository.getToolEvents('message-1'), const [
        {'id': 'tool', 'content': 'result'},
      ]);
      expect(await repository.getActiveStreamingIds(), isEmpty);
    },
  );
}
