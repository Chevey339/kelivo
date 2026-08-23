import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ChatDatabaseRepository repository;
  late Conversation conversation;

  ChatMessage message({
    required String id,
    required String role,
    required String content,
    String? groupId,
    int version = 0,
    bool isStreaming = false,
  }) => ChatMessage(
    id: id,
    conversationId: conversation.id,
    role: role,
    content: content,
    groupId: groupId,
    version: version,
    isStreaming: isStreaming,
  );

  Future<void> seed({bool includeAlternate = false}) async {
    final messages = <ChatMessage>[
      message(id: 'user-0', role: 'user', content: 'question'),
      message(
        id: 'assistant-v0',
        role: 'assistant',
        content: 'answer v0',
        groupId: 'assistant-group',
      ),
      message(id: 'user-1', role: 'user', content: 'later question'),
      message(id: 'assistant-1', role: 'assistant', content: 'later answer'),
      if (includeAlternate)
        message(
          id: 'assistant-v1',
          role: 'assistant',
          content: 'answer v1',
          groupId: 'assistant-group',
          version: 1,
        ),
    ];
    await repository.putMigrationBatch(
      conversations: [
        conversation.copyWith(
          messageIds: messages.map((message) => message.id).toList(),
          versionSelections: includeAlternate
              ? const {'assistant-group': 1}
              : const {},
        ),
      ],
      messages: [
        for (final (index, item) in messages.indexed)
          (message: item, messageOrder: index),
      ],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
  }

  Future<List<String>> visibleIds() async =>
      (await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        fromStart: true,
      )).slots.map((slot) => slot.revisionId).toList(growable: false);

  Future<Map<String, int>> messageOrders() async {
    final rows = await database
        .customSelect(
          'SELECT id, message_order FROM message_rows '
          'WHERE conversation_id = ?;',
          variables: [Variable.withString(conversation.id)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('id'): row.read<int>('message_order'),
    };
  }

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ChatDatabaseRepository(database);
    await repository.ensureReady();
    conversation = Conversation(id: 'conversation', title: 'Linear');
  });

  tearDown(() => repository.close());

  test(
    'save-only appends and selects a version without changing the future',
    () async {
      await seed();

      final result = await repository.appendMessageVersion(
        messageId: 'assistant-v0',
        content: 'edited answer',
      );
      final window = await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        fromStart: true,
      );

      expect(result, isNotNull);
      expect(window.slots.map((slot) => slot.revisionId), [
        'user-0',
        result!.message.id,
        'user-1',
        'assistant-1',
      ]);
      expect(window.slots[1].versionCount, 2);
      expect(await repository.getMessageIndex(conversation.id, 'user-1'), 2);
    },
  );

  test(
    'default assistant regeneration keeps the future and exposes n/m',
    () async {
      await seed();

      final result = await repository.beginRegeneration(
        conversation: conversation,
        assistantMessage: message(
          id: 'assistant-v1',
          role: 'assistant',
          content: '',
          groupId: 'assistant-group',
          version: 1,
          isStreaming: true,
        ),
        runId: 'run-default',
        truncateFuture: false,
      );
      final window = await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        fromStart: true,
      );

      expect(window.slots.map((slot) => slot.revisionId), [
        'user-0',
        'assistant-v1',
        'user-1',
        'assistant-1',
      ]);
      expect(window.slots[1].versionCount, 2);
      expect(result.conversation.versionSelections, {'assistant-group': 1});
    },
  );

  test(
    'truncate regeneration deletes later groups but keeps group siblings',
    () async {
      await seed();

      await repository.beginRegeneration(
        conversation: conversation,
        assistantMessage: message(
          id: 'assistant-v1',
          role: 'assistant',
          content: '',
          groupId: 'assistant-group',
          version: 1,
          isStreaming: true,
        ),
        runId: 'run-truncate',
        truncateFuture: true,
      );

      expect(await visibleIds(), ['user-0', 'assistant-v1']);
      expect(await repository.getMessage('assistant-v0'), isNotNull);
      expect(await repository.getMessage('user-1'), isNull);
      expect(await repository.getMessage('assistant-1'), isNull);
    },
  );

  test(
    'truncate regeneration keeps appended versions of earlier groups',
    () async {
      await seed();
      final editedUser = await repository.appendMessageVersion(
        messageId: 'user-0',
        content: 'edited question',
      );

      final result = await repository.beginRegeneration(
        conversation: editedUser!.conversation,
        assistantMessage: message(
          id: 'assistant-v1',
          role: 'assistant',
          content: '',
          groupId: 'assistant-group',
          version: 1,
          isStreaming: true,
        ),
        runId: 'run-truncate-after-edit',
        truncateFuture: true,
      );

      expect(await visibleIds(), [editedUser.message.id, 'assistant-v1']);
      expect(await repository.getMessage(editedUser.message.id), isNotNull);
      expect(result.conversation.versionSelections, {
        'user-0': 1,
        'assistant-group': 1,
      });
    },
  );

  test('version switching changes only the selected row', () async {
    await seed(includeAlternate: true);

    await repository.setSelectedVersion(
      conversationId: conversation.id,
      groupId: 'assistant-group',
      version: 0,
    );

    expect(await visibleIds(), [
      'user-0',
      'assistant-v0',
      'user-1',
      'assistant-1',
    ]);
    expect(await repository.getMessageIndex(conversation.id, 'user-1'), 2);
  });

  test(
    'deleting one version or the complete group never deletes the future',
    () async {
      await seed(includeAlternate: true);

      await repository.deleteMessages(
        conversationId: conversation.id,
        messageIds: const {'assistant-v1'},
        versionSelectionChanges: const {},
      );
      expect(await visibleIds(), [
        'user-0',
        'assistant-v0',
        'user-1',
        'assistant-1',
      ]);
      expect(
        (await repository.getConversation(conversation.id))?.versionSelections,
        {'assistant-group': 0},
      );

      await repository.deleteMessages(
        conversationId: conversation.id,
        messageIds: const {'assistant-v0'},
        versionSelectionChanges: const {},
      );
      expect(await visibleIds(), ['user-0', 'user-1', 'assistant-1']);
      expect(await repository.getMessageIndex(conversation.id, 'user-1'), 2);
    },
  );

  test(
    'deleting the old version after a save-only edit keeps the group in place',
    () async {
      await seed();

      // Save-only edit: appends a new revision whose message_order lands at
      // the end of the conversation.
      final result = await repository.appendMessageVersion(
        messageId: 'assistant-v0',
        content: 'edited answer',
      );
      final editedId = result!.message.id;

      // Deleting the original (anchor) revision must not let the surviving
      // revision drift to the appended end-of-conversation position.
      await repository.deleteMessages(
        conversationId: conversation.id,
        messageIds: const {'assistant-v0'},
        versionSelectionChanges: const {},
      );

      expect(await visibleIds(), ['user-0', editedId, 'user-1', 'assistant-1']);
      expect(await repository.getMessageIndex(conversation.id, editedId), 1);
      expect(await repository.getMessageIds(conversation.id), [
        'user-0',
        editedId,
        'user-1',
        'assistant-1',
      ]);
    },
  );

  test('recreating a deleted middle reply keeps it after its user', () async {
    await seed();
    final deleted = await repository.deleteMessages(
      conversationId: conversation.id,
      messageIds: const {'assistant-v0'},
      versionSelectionChanges: const {},
    );

    await repository.beginAssistantGeneration(
      conversation: deleted!.conversation,
      assistantMessage: message(
        id: 'assistant-recreated',
        role: 'assistant',
        content: '',
        isStreaming: true,
      ),
      anchorGroupId: 'user-0',
      runId: 'run-recreated',
      truncateFuture: false,
    );

    expect(await visibleIds(), [
      'user-0',
      'assistant-recreated',
      'user-1',
      'assistant-1',
    ]);
    expect(await messageOrders(), {
      'user-0': 0,
      'assistant-recreated': 1,
      'user-1': 2,
      'assistant-1': 3,
    });
  });

  test('anchored insertion shifts an occupied suffix in order', () async {
    await seed();

    await repository.beginAssistantGeneration(
      conversation: conversation,
      assistantMessage: message(
        id: 'assistant-inserted',
        role: 'assistant',
        content: '',
        isStreaming: true,
      ),
      anchorGroupId: 'user-0',
      runId: 'run-inserted',
      truncateFuture: false,
    );

    expect(await messageOrders(), {
      'user-0': 0,
      'assistant-inserted': 1,
      'assistant-v0': 2,
      'user-1': 3,
      'assistant-1': 4,
    });
  });
}
