import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late ChatDatabaseRepository repository;
  final createdAt = DateTime.fromMicrosecondsSinceEpoch(1783784523123456);

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    repository = ChatDatabaseRepository(database);
    await repository.ensureReady();
    await database
        .into(database.conversationRows)
        .insert(
          ConversationRowsCompanion.insert(
            id: 'conversation-1',
            title: 'Conversation',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
    await database
        .into(database.messageSlotRows)
        .insert(
          MessageSlotRowsCompanion.insert(
            id: 'slot-a1',
            conversationId: 'conversation-1',
            role: 'assistant',
            createdAt: createdAt,
          ),
        );
    await database
        .into(database.messageRevisionRows)
        .insert(
          MessageRevisionRowsCompanion.insert(
            id: 'revision-a1',
            conversationId: 'conversation-1',
            slotId: 'slot-a1',
            revisionNo: 0,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
    await database
        .into(database.messageRows)
        .insert(
          MessageRowsCompanion.insert(
            id: 'revision-a1',
            conversationId: 'conversation-1',
            role: 'assistant',
            content: '',
            timestamp: createdAt,
            messageOrder: 0,
          ),
        );
  });

  tearDown(() => repository.close());

  Future<GenerationRun> createRun({String id = 'run-1'}) =>
      repository.createGenerationRun(
        id: id,
        conversationId: 'conversation-1',
        targetRevisionId: 'revision-a1',
        createdAt: createdAt,
      );

  test('creates a preparing run with monotonic counters at zero', () async {
    final run = await createRun();

    expect(run.state, GenerationRunState.preparing);
    expect(run.stateRevision, 0);
    expect(run.checkpointSeq, 0);
    expect(run.terminalAt, isNull);
    expect((await repository.getGenerationRun(run.id))?.id, run.id);
  });

  test('allows only the frozen state-machine transitions', () async {
    var run = await createRun();
    for (final next in const [
      GenerationRunState.requesting,
      GenerationRunState.streaming,
      GenerationRunState.waitingTool,
      GenerationRunState.streaming,
      GenerationRunState.completed,
    ]) {
      run = await repository.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: next,
        updatedAt: createdAt.add(Duration(microseconds: run.stateRevision + 1)),
      );
    }

    expect(run.state, GenerationRunState.completed);
    expect(run.stateRevision, 5);
    expect(run.terminalAt, isNotNull);
  });

  test('rejects invalid transitions without changing the row', () async {
    final run = await createRun();

    expect(
      () => repository.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: GenerationRunState.completed,
        updatedAt: createdAt.add(const Duration(microseconds: 1)),
      ),
      throwsArgumentError,
    );
    expect(
      (await repository.getGenerationRun(run.id))?.state,
      GenerationRunState.preparing,
    );
  });

  test('CAS permits exactly one competing terminal transition', () async {
    final run = await createRun();
    final attempts = await Future.wait([
      repository
          .transitionGenerationRun(
            id: run.id,
            expectedState: run.state,
            expectedStateRevision: run.stateRevision,
            nextState: GenerationRunState.failed,
            updatedAt: createdAt.add(const Duration(microseconds: 1)),
            errorCode: 'network',
          )
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      repository
          .transitionGenerationRun(
            id: run.id,
            expectedState: run.state,
            expectedStateRevision: run.stateRevision,
            nextState: GenerationRunState.cancelled,
            updatedAt: createdAt.add(const Duration(microseconds: 1)),
          )
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);

    expect(attempts.whereType<GenerationRun>(), hasLength(1));
    expect(attempts.whereType<GenerationRunTransitionConflict>(), hasLength(1));
    expect(
      (await repository.getGenerationRun(run.id))?.state.isTerminal,
      isTrue,
    );
  });

  test('allows at most one active run for a target revision', () async {
    var first = await createRun();
    await expectLater(createRun(id: 'run-2'), throwsA(anything));

    first = await repository.transitionGenerationRun(
      id: first.id,
      expectedState: first.state,
      expectedStateRevision: first.stateRevision,
      nextState: GenerationRunState.cancelled,
      updatedAt: createdAt.add(const Duration(microseconds: 1)),
    );
    expect(first.state, GenerationRunState.cancelled);
    expect((await createRun(id: 'run-2')).state, GenerationRunState.preparing);
  });

  test('checkpoint sequence advances monotonically on an active run', () async {
    var run = await createRun();
    run = await repository.transitionGenerationRun(
      id: run.id,
      expectedState: run.state,
      expectedStateRevision: run.stateRevision,
      nextState: GenerationRunState.requesting,
      updatedAt: createdAt.add(const Duration(microseconds: 1)),
    );
    run = await repository.transitionGenerationRun(
      id: run.id,
      expectedState: run.state,
      expectedStateRevision: run.stateRevision,
      nextState: GenerationRunState.streaming,
      updatedAt: createdAt.add(const Duration(microseconds: 2)),
    );

    run = await repository.checkpointGenerationRun(
      id: run.id,
      targetRevisionId: run.targetRevisionId,
      checkpointSeq: 3,
      updatedAt: createdAt.add(const Duration(microseconds: 3)),
    );
    expect(run.checkpointSeq, 3);
    await expectLater(
      repository.checkpointGenerationRun(
        id: run.id,
        targetRevisionId: run.targetRevisionId,
        checkpointSeq: 2,
        updatedAt: createdAt.add(const Duration(microseconds: 4)),
      ),
      throwsA(isA<GenerationRunCheckpointConflict>()),
    );
    expect((await repository.getGenerationRun(run.id))?.checkpointSeq, 3);
  });

  test('database constraints reject terminal and FK inconsistencies', () async {
    await expectLater(
      database
          .into(database.generationRunRows)
          .insert(
            GenerationRunRowsCompanion.insert(
              id: 'invalid-terminal',
              conversationId: 'conversation-1',
              targetRevisionId: 'revision-a1',
              state: GenerationRunState.completed.databaseValue,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          ),
      throwsA(anything),
    );
    await expectLater(
      repository.createGenerationRun(
        id: 'invalid-fk',
        conversationId: 'conversation-1',
        targetRevisionId: 'missing-revision',
        createdAt: createdAt,
      ),
      throwsA(anything),
    );
  });
}
