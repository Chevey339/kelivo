import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
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
}
