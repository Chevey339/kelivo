import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/message_graph_projector.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late ChatDatabaseRepository repository;
  final timestamp = DateTime.fromMicrosecondsSinceEpoch(1783784523123456);

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    repository = ChatDatabaseRepository(database);
    await repository.ensureReady();
  });

  tearDown(() => repository.close());

  Future<void> insertConversation(String id) => database
      .into(database.conversationRows)
      .insert(
        ConversationRowsCompanion.insert(
          id: id,
          title: id,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  Future<void> insertSlot({
    required String id,
    required String conversationId,
    required String role,
  }) => database
      .into(database.messageSlotRows)
      .insert(
        MessageSlotRowsCompanion.insert(
          id: id,
          conversationId: conversationId,
          role: role,
          createdAt: timestamp,
        ),
      );

  Future<void> insertRevision({
    required String id,
    required String conversationId,
    required String slotId,
    String? parentRevisionId,
    int revisionNo = 0,
    DateTime? deletedAt,
  }) => database
      .into(database.messageRevisionRows)
      .insert(
        MessageRevisionRowsCompanion.insert(
          id: id,
          conversationId: conversationId,
          slotId: slotId,
          parentRevisionId: Value(parentRevisionId),
          revisionNo: revisionNo,
          createdAt: timestamp,
          updatedAt: timestamp,
          deletedAt: Value(deletedAt),
        ),
      );

  Future<void> insertBranch({
    required String id,
    required String conversationId,
    String? parentBranchId,
    String? forkedFromRevisionId,
    String? leafRevisionId,
    DateTime? deletedAt,
  }) => database
      .into(database.conversationBranchRows)
      .insert(
        ConversationBranchRowsCompanion.insert(
          id: id,
          conversationId: conversationId,
          parentBranchId: Value(parentBranchId),
          forkedFromRevisionId: Value(forkedFromRevisionId),
          leafRevisionId: Value(leafRevisionId),
          causalityKind: 'native',
          createdAt: timestamp,
          deletedAt: Value(deletedAt),
        ),
      );

  Future<void> insertPart({
    required String revisionId,
    required int ordinal,
    required String kind,
    required String payload,
  }) => database
      .into(database.messagePartRows)
      .insert(
        MessagePartRowsCompanion.insert(
          conversationId: 'conversation-1',
          revisionId: revisionId,
          ordinal: ordinal,
          kind: kind,
          payload: payload,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  Future<void> insertState({
    required String conversationId,
    String? activeBranchId,
    String? contextStartRevisionId,
  }) => database
      .into(database.conversationStateRows)
      .insert(
        ConversationStateRowsCompanion.insert(
          conversationId: conversationId,
          activeBranchId: Value(activeBranchId),
          contextStartRevisionId: Value(contextStartRevisionId),
        ),
      );

  Future<void> insertMainGraph({String? boundaryId}) async {
    await insertConversation('conversation-1');
    for (final (id, role) in const [
      ('slot-u1', 'user'),
      ('slot-a1', 'assistant'),
      ('slot-u2', 'user'),
      ('slot-a2', 'assistant'),
    ]) {
      await insertSlot(id: id, conversationId: 'conversation-1', role: role);
    }
    await insertRevision(
      id: 'u1',
      conversationId: 'conversation-1',
      slotId: 'slot-u1',
    );
    await insertRevision(
      id: 'a1-v1',
      conversationId: 'conversation-1',
      slotId: 'slot-a1',
      parentRevisionId: 'u1',
      revisionNo: 1,
    );
    await insertRevision(
      id: 'u2',
      conversationId: 'conversation-1',
      slotId: 'slot-u2',
      parentRevisionId: 'a1-v1',
    );
    await insertRevision(
      id: 'a2',
      conversationId: 'conversation-1',
      slotId: 'slot-a2',
      parentRevisionId: 'u2',
    );
    await insertRevision(
      id: 'a1-v7',
      conversationId: 'conversation-1',
      slotId: 'slot-a1',
      parentRevisionId: 'u1',
      revisionNo: 7,
    );
    await insertBranch(
      id: 'branch-main',
      conversationId: 'conversation-1',
      leafRevisionId: 'a2',
    );
    await insertBranch(
      id: 'branch-regenerated',
      conversationId: 'conversation-1',
      parentBranchId: 'branch-main',
      forkedFromRevisionId: 'u1',
      leafRevisionId: 'a1-v7',
    );
    await insertState(
      conversationId: 'conversation-1',
      activeBranchId: 'branch-main',
      contextStartRevisionId: boundaryId,
    );
  }

  List<String> ids(Iterable<MessageGraphRevision> revisions) =>
      revisions.map((revision) => revision.id).toList(growable: false);

  test('projects the active ancestry and stable context boundary', () async {
    await insertMainGraph(boundaryId: 'u2');

    final projection = await repository.projectActiveMessageGraph(
      conversationId: 'conversation-1',
    );

    expect(projection, isNotNull);
    expect(projection!.branchId, 'branch-main');
    expect(ids(projection.revisions), ['u1', 'a1-v1', 'u2', 'a2']);
    expect(ids(projection.contextRevisions), ['u2', 'a2']);
    expect(projection.revisions.map((revision) => revision.slotId).toSet(), {
      'slot-u1',
      'slot-a1',
      'slot-u2',
      'slot-a2',
    });
  });

  test('timeline read model ignores legacy order and JSON selection', () async {
    await insertMainGraph(boundaryId: 'u2');
    await insertPart(
      revisionId: 'a1-v1',
      ordinal: 0,
      kind: 'reasoning',
      payload: 'thinking',
    );
    await insertPart(
      revisionId: 'a1-v1',
      ordinal: 1,
      kind: 'text',
      payload: 'selected',
    );
    await insertPart(
      revisionId: 'a1-v7',
      ordinal: 0,
      kind: 'text',
      payload: 'alternate',
    );
    await (database.update(
      database.conversationRows,
    )..where((row) => row.id.equals('conversation-1'))).write(
      const ConversationRowsCompanion(
        truncateIndex: Value(999),
        versionSelectionsJson: Value('{"slot-a1":7}'),
      ),
    );

    final timeline = await repository.projectMessageGraphTimeline(
      conversationId: 'conversation-1',
    );

    expect(timeline!.activeRevisions.map((revision) => revision.revisionId), [
      'u1',
      'a1-v1',
      'u2',
      'a2',
    ]);
    expect(timeline.selectedRevisionBySlot['slot-a1'], 'a1-v1');
    expect(timeline.contextStartRevisionId, 'u2');
    expect(timeline.contextRevisions.map((revision) => revision.revisionId), [
      'u2',
      'a2',
    ]);
    expect(timeline.revisionsBySlot['slot-a1'], hasLength(2));
    final selected = timeline.revisionsBySlot['slot-a1']!.firstWhere(
      (revision) => revision.revisionId == 'a1-v1',
    );
    expect(selected.text, 'selected');
    expect(selected.reasoning, 'thinking');
  });

  test(
    'active timeline pages use stable ancestry cursors and slot units',
    () async {
      await insertMainGraph(boundaryId: 'u2');

      final tail = await repository.loadActiveTimelinePage(
        conversationId: 'conversation-1',
        limit: 2,
      );
      expect(tail!.slots.map((slot) => slot.revisionId), ['u2', 'a2']);
      expect(tail.beforeRevisionId, 'u2');
      expect(tail.afterRevisionId, isNull);

      final before = await repository.loadActiveTimelinePage(
        conversationId: 'conversation-1',
        beforeRevisionId: tail.beforeRevisionId,
        limit: 2,
      );
      expect(before!.slots.map((slot) => slot.revisionId), ['u1', 'a1-v1']);
      expect(before.hasMoreBefore, isFalse);
      expect(before.hasMoreAfter, isTrue);
      expect(before.slots.last.versionCount, 2);

      final after = await repository.loadActiveTimelinePage(
        conversationId: 'conversation-1',
        afterRevisionId: before.slots.last.revisionId,
        limit: 2,
      );
      expect(after!.slots.map((slot) => slot.revisionId), ['u2', 'a2']);
      expect(after.hasMoreBefore, isTrue);
      expect(after.hasMoreAfter, isFalse);

      await expectLater(
        repository.loadActiveTimelinePage(
          conversationId: 'conversation-1',
          beforeRevisionId: 'a1-v7',
        ),
        throwsA(
          isA<MessageGraphIntegrityException>().having(
            (error) => error.message,
            'message',
            'message_graph_cursor_not_on_active_path',
          ),
        ),
      );
    },
  );

  test('five hundred alternates consume one active timeline slot', () async {
    await insertMainGraph();
    for (var revision = 8; revision < 508; revision++) {
      await insertRevision(
        id: 'a1-v$revision',
        conversationId: 'conversation-1',
        slotId: 'slot-a1',
        parentRevisionId: 'u1',
        revisionNo: revision,
      );
    }

    final page = await repository.loadActiveTimelinePage(
      conversationId: 'conversation-1',
      limit: 10,
    );

    expect(page!.slots, hasLength(4));
    final assistant = page.slots.singleWhere(
      (slot) => slot.slotId == 'slot-a1',
    );
    expect(assistant.revisionId, 'a1-v1');
    expect(assistant.versionCount, 502);
  });

  test('target revision projection excludes every future revision', () async {
    await insertMainGraph(boundaryId: 'u1');

    final projection = await repository.projectActiveMessageGraph(
      conversationId: 'conversation-1',
      targetRevisionId: 'a1-v1',
    );

    expect(ids(projection!.revisions), ['u1', 'a1-v1']);
    expect(ids(projection.contextRevisions), ['u1', 'a1-v1']);
    expect(ids(projection.revisions), isNot(containsAll(['u2', 'a2'])));
  });

  test(
    'projects an alternate branch by stable branch and revision IDs',
    () async {
      await insertMainGraph();

      final path = await repository.projectMessageGraphBranch(
        conversationId: 'conversation-1',
        branchId: 'branch-regenerated',
        targetRevisionId: 'a1-v7',
      );

      expect(ids(path.revisions), ['u1', 'a1-v7']);
      expect(path.branchLeafRevisionId, 'a1-v7');
      expect(path.targetRevisionId, 'a1-v7');
    },
  );

  test(
    'context boundary update is atomic, optimistic and idempotent',
    () async {
      await insertMainGraph();

      final updated = await repository.setMessageGraphContextBoundary(
        conversationId: 'conversation-1',
        revisionId: 'u2',
        expectedStateRevision: 0,
      );
      expect(updated!.stateRevision, 1);
      expect(updated.contextStartRevisionId, 'u2');
      expect(ids(updated.contextRevisions), ['u2', 'a2']);

      final idempotent = await repository.setMessageGraphContextBoundary(
        conversationId: 'conversation-1',
        revisionId: 'u2',
        expectedStateRevision: 1,
      );
      expect(idempotent!.stateRevision, 1);

      await expectLater(
        repository.setMessageGraphContextBoundary(
          conversationId: 'conversation-1',
          revisionId: 'u1',
          expectedStateRevision: 0,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'message_graph_state_conflict',
          ),
        ),
      );
      expect(
        (await repository.projectActiveMessageGraph(
          conversationId: 'conversation-1',
        ))!.contextStartRevisionId,
        'u2',
      );
    },
  );

  test('rejects a context boundary from a different branch', () async {
    await insertMainGraph();

    await expectLater(
      repository.setMessageGraphContextBoundary(
        conversationId: 'conversation-1',
        revisionId: 'a1-v7',
      ),
      throwsArgumentError,
    );
    final state = await database
        .select(database.conversationStateRows)
        .getSingle();
    expect(state.contextStartRevisionId, isNull);
    expect(state.stateRevision, 0);
  });

  test('detects a persisted boundary outside the active ancestry', () async {
    await insertMainGraph();
    await (database.update(
      database.conversationStateRows,
    )..where((row) => row.conversationId.equals('conversation-1'))).write(
      const ConversationStateRowsCompanion(
        contextStartRevisionId: Value('a1-v7'),
      ),
    );

    await expectLater(
      repository.projectActiveMessageGraph(conversationId: 'conversation-1'),
      throwsA(
        isA<MessageGraphIntegrityException>().having(
          (error) => error.message,
          'message',
          'message_graph_boundary_not_on_active_path',
        ),
      ),
    );
  });

  test(
    'rejects a cycle in an inactive branch during deep validation',
    () async {
      await insertMainGraph();
      await database.transaction(() async {
        await (database.update(
          database.messageRevisionRows,
        )..where((row) => row.id.equals('u1'))).write(
          const MessageRevisionRowsCompanion(parentRevisionId: Value('a1-v7')),
        );
      });

      await expectLater(
        repository.validateMessageGraph('conversation-1'),
        throwsA(
          isA<MessageGraphIntegrityException>().having(
            (error) => error.message,
            'message',
            'message_graph_revision_cycle',
          ),
        ),
      );
    },
  );

  test('rejects a parent branch cycle during deep validation', () async {
    await insertMainGraph();
    await database.transaction(() async {
      await (database.update(
        database.conversationBranchRows,
      )..where((row) => row.id.equals('branch-main'))).write(
        const ConversationBranchRowsCompanion(
          parentBranchId: Value('branch-regenerated'),
        ),
      );
    });

    await expectLater(
      repository.validateMessageGraph('conversation-1'),
      throwsA(
        isA<MessageGraphIntegrityException>().having(
          (error) => error.message,
          'message',
          'message_graph_branch_cycle',
        ),
      ),
    );
  });

  test('rejects two revisions of one slot on the same path', () async {
    await insertConversation('conversation-1');
    await insertSlot(
      id: 'slot-a1',
      conversationId: 'conversation-1',
      role: 'assistant',
    );
    await insertRevision(
      id: 'a1-v1',
      conversationId: 'conversation-1',
      slotId: 'slot-a1',
      revisionNo: 1,
    );
    await insertRevision(
      id: 'a1-v7',
      conversationId: 'conversation-1',
      slotId: 'slot-a1',
      parentRevisionId: 'a1-v1',
      revisionNo: 7,
    );
    await insertBranch(
      id: 'branch-invalid',
      conversationId: 'conversation-1',
      leafRevisionId: 'a1-v7',
    );
    await insertState(
      conversationId: 'conversation-1',
      activeBranchId: 'branch-invalid',
    );

    await expectLater(
      repository.projectActiveMessageGraph(conversationId: 'conversation-1'),
      throwsA(
        isA<MessageGraphIntegrityException>().having(
          (error) => error.message,
          'message',
          'message_graph_duplicate_slot_on_path',
        ),
      ),
    );
  });

  test(
    'rejects deleted branches and deleted revisions on active paths',
    () async {
      await insertMainGraph();
      await (database.update(database.conversationBranchRows)
            ..where((row) => row.id.equals('branch-main')))
          .write(ConversationBranchRowsCompanion(deletedAt: Value(timestamp)));

      await expectLater(
        repository.projectActiveMessageGraph(conversationId: 'conversation-1'),
        throwsA(
          isA<MessageGraphIntegrityException>().having(
            (error) => error.message,
            'message',
            'message_graph_branch_deleted',
          ),
        ),
      );

      await (database.update(database.conversationBranchRows)
            ..where((row) => row.id.equals('branch-main')))
          .write(const ConversationBranchRowsCompanion(deletedAt: Value(null)));
      await (database.update(database.messageRevisionRows)
            ..where((row) => row.id.equals('u2')))
          .write(MessageRevisionRowsCompanion(deletedAt: Value(timestamp)));
      await expectLater(
        repository.projectActiveMessageGraph(conversationId: 'conversation-1'),
        throwsA(
          isA<MessageGraphIntegrityException>().having(
            (error) => error.message,
            'message',
            'message_graph_deleted_revision_on_path',
          ),
        ),
      );
    },
  );

  test(
    'distinguishes a missing conversation from missing graph state',
    () async {
      expect(
        await repository.projectActiveMessageGraph(
          conversationId: 'missing-conversation',
        ),
        isNull,
      );
      await insertConversation('conversation-1');

      await expectLater(
        repository.projectActiveMessageGraph(conversationId: 'conversation-1'),
        throwsA(
          isA<MessageGraphIntegrityException>().having(
            (error) => error.message,
            'message',
            'message_graph_state_missing',
          ),
        ),
      );
    },
  );
}
