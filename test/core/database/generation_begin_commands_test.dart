import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late ChatDatabaseRepository repository;
  late Conversation conversation;
  final timestamp = DateTime.fromMicrosecondsSinceEpoch(1783784523123456);

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    repository = ChatDatabaseRepository(database);
    await repository.ensureReady();
    conversation = Conversation(
      id: 'conversation-1',
      title: 'Conversation',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  });

  tearDown(() => repository.close());

  ChatMessage user(String id) => ChatMessage(
    id: id,
    conversationId: conversation.id,
    role: 'user',
    content: 'Question',
    timestamp: timestamp,
  );

  ChatMessage assistant(String id, {String? groupId, int version = 0}) =>
      ChatMessage(
        id: id,
        conversationId: conversation.id,
        role: 'assistant',
        content: '',
        timestamp: timestamp.add(const Duration(microseconds: 1)),
        modelId: 'model',
        providerId: 'provider',
        isStreaming: true,
        groupId: groupId,
        version: version,
      );

  Future<GenerationBeginResult> beginFirstSend() =>
      repository.beginSendGeneration(
        conversation: conversation,
        userMessage: user('user-1'),
        assistantMessage: assistant('assistant-1'),
        runId: 'run-1',
      );

  test(
    'begin send commits user, assistant, graph, branch and run together',
    () async {
      final result = await beginFirstSend();

      expect(result.userMessage?.id, 'user-1');
      expect(result.assistantMessage.id, 'assistant-1');
      expect(result.run.state, GenerationRunState.preparing);
      expect(result.run.targetRevisionId, 'assistant-1');
      expect(
        (await repository.projectActiveMessageGraph(
          conversationId: conversation.id,
        ))?.revisions.map((revision) => revision.id),
        ['user-1', 'assistant-1'],
      );
      expect(await repository.getMessageCount(conversation.id), 2);
      expect(
        await (database.select(database.messagePartRows)
              ..orderBy([(row) => OrderingTerm.asc(row.revisionId)]))
            .get()
            .then((rows) => rows.map((row) => row.payload).toList()),
        ['', 'Question'],
      );
    },
  );

  test(
    'run insert failure rolls back every send row and branch mutation',
    () async {
      final first = await beginFirstSend();
      final before = await repository.projectActiveMessageGraph(
        conversationId: conversation.id,
      );

      await expectLater(
        repository.beginSendGeneration(
          conversation: first.conversation,
          userMessage: user('user-2'),
          assistantMessage: assistant('assistant-2'),
          runId: 'run-1',
        ),
        throwsA(anything),
      );

      expect(await repository.getMessage('user-2'), isNull);
      expect(await repository.getMessage('assistant-2'), isNull);
      expect(await repository.getMessageCount(conversation.id), 2);
      final after = await repository.projectActiveMessageGraph(
        conversationId: conversation.id,
      );
      expect(after?.targetRevisionId, before?.targetRevisionId);
      expect(after?.stateRevision, before?.stateRevision);
    },
  );

  test(
    'begin regeneration commits alternate revision, branch and run together',
    () async {
      final first = await beginFirstSend();
      final before = await repository.projectActiveMessageGraph(
        conversationId: conversation.id,
      );
      final result = await repository.beginRegeneration(
        conversation: first.conversation,
        assistantMessage: assistant(
          'assistant-2',
          groupId: 'assistant-1',
          version: 1,
        ),
        runId: 'run-2',
      );

      expect(result.userMessage, isNull);
      expect(result.run.targetRevisionId, 'assistant-2');
      final active = await repository.projectActiveMessageGraph(
        conversationId: conversation.id,
      );
      expect(active?.revisions.map((revision) => revision.id), [
        'user-1',
        'assistant-2',
      ]);
      expect(active?.branchId, isNot(equals(before?.branchId)));
      expect(await repository.getMessageCount(conversation.id), 3);
    },
  );

  test('invalid begin input is rejected before any database write', () async {
    expect(
      () => repository.beginSendGeneration(
        conversation: conversation,
        userMessage: assistant('not-user'),
        assistantMessage: assistant('assistant-1'),
        runId: 'run-1',
      ),
      throwsArgumentError,
    );
    expect(await database.select(database.conversationRows).get(), isEmpty);
  });
}
