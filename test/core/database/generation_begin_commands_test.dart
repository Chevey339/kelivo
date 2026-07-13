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

  Future<Conversation> appendFuture(Conversation current) async {
    final afterUser = await repository.appendGraphMessageToConversation(
      conversation: current,
      message: user('user-2'),
    );
    return repository.appendGraphMessageToConversation(
      conversation: afterUser,
      message: assistant('assistant-tail').copyWith(isStreaming: false),
    );
  }

  Future<GenerationRun> advanceToStreaming(GenerationRun run) async {
    var current = await repository.transitionGenerationRun(
      id: run.id,
      expectedState: run.state,
      expectedStateRevision: run.stateRevision,
      nextState: GenerationRunState.requesting,
      updatedAt: timestamp.add(const Duration(microseconds: 2)),
    );
    current = await repository.transitionGenerationRun(
      id: current.id,
      expectedState: current.state,
      expectedStateRevision: current.stateRevision,
      nextState: GenerationRunState.streaming,
      updatedAt: timestamp.add(const Duration(microseconds: 3)),
    );
    return current;
  }

  test('begin send commits linear messages, parts and run together', () async {
    final result = await beginFirstSend();

    expect(result.userMessage?.id, 'user-1');
    expect(result.assistantMessage.id, 'assistant-1');
    expect(result.run.state, GenerationRunState.preparing);
    expect(result.run.targetRevisionId, 'assistant-1');
    expect(await repository.getMessageIds(conversation.id), [
      'user-1',
      'assistant-1',
    ]);
    expect(await database.select(database.messageSlotRows).get(), isEmpty);
    expect(await database.select(database.messageRevisionRows).get(), isEmpty);
    expect(
      await database.select(database.conversationBranchRows).get(),
      isEmpty,
    );
    expect(
      await database.select(database.conversationStateRows).get(),
      isEmpty,
    );
    expect(await repository.getMessageCount(conversation.id), 2);
    expect(
      await (database.select(database.messagePartRows)
            ..orderBy([(row) => OrderingTerm.asc(row.revisionId)]))
          .get()
          .then((rows) => rows.map((row) => row.payload).toList()),
      ['', 'Question'],
    );
  });

  test('run insert failure rolls back every linear send row', () async {
    final first = await beginFirstSend();

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
    expect(await repository.getMessageIds(conversation.id), [
      'user-1',
      'assistant-1',
    ]);
  });

  test(
    'default regeneration adds a selected version and preserves the future',
    () async {
      final first = await beginFirstSend();
      final withFuture = await appendFuture(first.conversation);
      final result = await repository.beginRegeneration(
        conversation: withFuture,
        assistantMessage: assistant(
          'assistant-2',
          groupId: 'assistant-1',
          version: 1,
        ),
        runId: 'run-2',
        truncateFuture: false,
      );

      expect(result.userMessage, isNull);
      expect(result.run.targetRevisionId, 'assistant-2');
      final window = await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        fromStart: true,
      );
      expect(window.slots.map((slot) => slot.revisionId), [
        'user-1',
        'assistant-2',
        'user-2',
        'assistant-tail',
      ]);
      expect(await repository.getMessageCount(conversation.id), 5);
      expect(result.conversation.versionSelections['assistant-1'], 1);
    },
  );

  test('truncate regeneration physically deletes only later groups', () async {
    final first = await beginFirstSend();
    final withFuture = await appendFuture(first.conversation);

    final result = await repository.beginRegeneration(
      conversation: withFuture,
      assistantMessage: assistant(
        'assistant-2',
        groupId: 'assistant-1',
        version: 1,
      ),
      runId: 'run-2',
      truncateFuture: true,
    );

    final window = await repository.loadLinearMessageWindow(
      conversationId: conversation.id,
      fromStart: true,
    );
    expect(window.slots.map((slot) => slot.revisionId), [
      'user-1',
      'assistant-2',
    ]);
    expect(await repository.getMessage('assistant-1'), isNotNull);
    expect(await repository.getMessage('user-2'), isNull);
    expect(await repository.getMessage('assistant-tail'), isNull);
    expect(result.run.targetRevisionId, 'assistant-2');
    expect(await repository.getMessageCount(conversation.id), 3);
  });

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

  test(
    'message snapshot and run checkpoint sequence commit together',
    () async {
      final begin = await beginFirstSend();
      final run = await advanceToStreaming(begin.run);

      final checkpoint = begin.assistantMessage.copyWith(content: 'partial');
      await repository.updateStreamingCheckpoint(
        checkpoint,
        const [],
        generationRunId: run.id,
        checkpointSeq: 1,
      );
      expect((await repository.getMessage(checkpoint.id))?.content, 'partial');
      expect((await repository.getGenerationRun(run.id))?.checkpointSeq, 1);

      await expectLater(
        repository.updateStreamingCheckpoint(
          checkpoint.copyWith(content: 'stale'),
          const [],
          generationRunId: run.id,
          checkpointSeq: 1,
        ),
        throwsA(isA<GenerationRunCheckpointConflict>()),
      );
      expect((await repository.getMessage(checkpoint.id))?.content, 'partial');
    },
  );

  test(
    'final snapshot, receipt cleanup and terminal run commit together',
    () async {
      final begin = await beginFirstSend();
      final run = await advanceToStreaming(begin.run);
      final finalMessage = begin.assistantMessage.copyWith(
        content: 'final',
        isStreaming: false,
        totalTokens: 9,
      );

      final completed = await repository.finalizeGenerationRun(
        message: finalMessage,
        toolEvents: const [
          {'id': 'tool-1', 'name': 'search'},
        ],
        generationRunId: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        terminalState: GenerationRunState.completed,
        checkpointSeq: 1,
      );

      expect(completed.state, GenerationRunState.completed);
      expect(completed.checkpointSeq, 1);
      expect(completed.terminalAt, isNotNull);
      expect((await repository.getMessage(finalMessage.id))?.content, 'final');
      expect(await repository.getActiveStreamingIds(), isEmpty);
      await expectLater(
        repository.updateStreamingCheckpoint(
          finalMessage.copyWith(content: 'late', isStreaming: true),
          const [],
          generationRunId: run.id,
          checkpointSeq: 2,
        ),
        throwsA(isA<GenerationRunCheckpointConflict>()),
      );
      expect((await repository.getMessage(finalMessage.id))?.content, 'final');
    },
  );

  test(
    'terminal CAS failure rolls back final message and receipt cleanup',
    () async {
      final begin = await beginFirstSend();
      final run = await advanceToStreaming(begin.run);

      await expectLater(
        repository.finalizeGenerationRun(
          message: begin.assistantMessage.copyWith(
            content: 'must roll back',
            isStreaming: false,
          ),
          toolEvents: const [],
          generationRunId: run.id,
          expectedState: run.state,
          expectedStateRevision: run.stateRevision + 1,
          terminalState: GenerationRunState.failed,
          checkpointSeq: 1,
          errorCode: 'generation_failed',
        ),
        throwsA(isA<GenerationRunTransitionConflict>()),
      );

      final message = await repository.getMessage(begin.assistantMessage.id);
      expect(message?.content, isEmpty);
      expect(message?.isStreaming, isTrue);
      expect((await repository.getGenerationRun(run.id))?.state, run.state);
      expect(await repository.getActiveStreamingIds(), [
        begin.assistantMessage.id,
      ]);
    },
  );

  test(
    'preparation failure terminates without inventing a checkpoint',
    () async {
      final begin = await beginFirstSend();

      final failed = await repository.finalizeGenerationRun(
        message: begin.assistantMessage.copyWith(isStreaming: false),
        toolEvents: const [],
        generationRunId: begin.run.id,
        expectedState: GenerationRunState.preparing,
        expectedStateRevision: 0,
        terminalState: GenerationRunState.failed,
        errorCode: 'preparation_failed',
      );

      expect(failed.state, GenerationRunState.failed);
      expect(failed.checkpointSeq, 0);
      expect(failed.errorCode, 'preparation_failed');
      expect(await repository.getActiveStreamingIds(), isEmpty);
    },
  );
}
