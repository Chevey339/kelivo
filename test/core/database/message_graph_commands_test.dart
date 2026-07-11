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
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
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

  Future<void> insertNode({
    required String conversationId,
    required String slotId,
    required String revisionId,
    required String role,
    required String text,
    String? parentRevisionId,
    int revisionNo = 0,
  }) async {
    await database
        .into(database.messageSlotRows)
        .insert(
          MessageSlotRowsCompanion.insert(
            id: slotId,
            conversationId: conversationId,
            role: role,
            createdAt: timestamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.messageRevisionRows)
        .insert(
          MessageRevisionRowsCompanion.insert(
            id: revisionId,
            conversationId: conversationId,
            slotId: slotId,
            parentRevisionId: Value(parentRevisionId),
            revisionNo: revisionNo,
            createdAt: timestamp,
            updatedAt: timestamp,
            finalizedAt: Value(timestamp),
          ),
        );
    await database
        .into(database.messagePartRows)
        .insert(
          MessagePartRowsCompanion.insert(
            conversationId: conversationId,
            revisionId: revisionId,
            ordinal: 0,
            kind: 'text',
            payload: text,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<void> insertBranch({
    required String id,
    required String conversationId,
    required String leafRevisionId,
    String? parentBranchId,
    String? forkedFromRevisionId,
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
        ),
      );

  Future<void> insertFixture({bool includeAlternate = true}) async {
    await insertConversation('conversation-1');
    await insertNode(
      conversationId: 'conversation-1',
      slotId: 'slot-u1',
      revisionId: 'u1',
      role: 'user',
      text: 'U1',
    );
    await insertNode(
      conversationId: 'conversation-1',
      slotId: 'slot-a1',
      revisionId: 'a1-v1',
      role: 'assistant',
      text: 'A1-v1',
      parentRevisionId: 'u1',
      revisionNo: 1,
    );
    await insertNode(
      conversationId: 'conversation-1',
      slotId: 'slot-u2',
      revisionId: 'u2',
      role: 'user',
      text: 'U2',
      parentRevisionId: 'a1-v1',
    );
    await insertNode(
      conversationId: 'conversation-1',
      slotId: 'slot-a2',
      revisionId: 'a2',
      role: 'assistant',
      text: 'A2',
      parentRevisionId: 'u2',
    );
    await insertBranch(
      id: 'branch-main',
      conversationId: 'conversation-1',
      leafRevisionId: 'a2',
    );
    if (includeAlternate) {
      await insertNode(
        conversationId: 'conversation-1',
        slotId: 'slot-a1',
        revisionId: 'a1-v7',
        role: 'assistant',
        text: 'A1-v7',
        parentRevisionId: 'u1',
        revisionNo: 7,
      );
      await insertBranch(
        id: 'branch-alt',
        conversationId: 'conversation-1',
        leafRevisionId: 'a1-v7',
        parentBranchId: 'branch-main',
        forkedFromRevisionId: 'u1',
      );
    }
    await database
        .into(database.conversationStateRows)
        .insert(
          ConversationStateRowsCompanion.insert(
            conversationId: 'conversation-1',
            activeBranchId: const Value('branch-main'),
            contextStartRevisionId: const Value('u1'),
          ),
        );
  }

  List<String> revisionIds(Iterable<MessageGraphRevision> revisions) =>
      revisions.map((revision) => revision.id).toList(growable: false);

  Future<String> textOf(String revisionId) async => (await (database.select(
    database.messagePartRows,
  )..where((row) => row.revisionId.equals(revisionId))).getSingle()).payload;

  test(
    'edit user creates a complete branch and preserves the old future',
    () async {
      await insertFixture();

      final result = await repository.editMessageGraphUser(
        conversationId: 'conversation-1',
        targetRevisionId: 'u2',
        text: 'U2 edited',
        expectedStateRevision: 0,
      );

      expect(revisionIds(result.projection.revisions), [
        'u1',
        'a1-v1',
        result.revisionId,
      ]);
      expect(await textOf(result.revisionId), 'U2 edited');
      expect(result.projection.stateRevision, 1);
      expect(result.projection.contextStartRevisionId, 'u1');
      final old = await repository.projectMessageGraphBranch(
        conversationId: 'conversation-1',
        branchId: 'branch-main',
      );
      expect(revisionIds(old.revisions), ['u1', 'a1-v1', 'u2', 'a2']);
    },
  );

  test('regenerate old assistant excludes every later turn', () async {
    await insertFixture();

    final result = await repository.regenerateMessageGraphAssistant(
      conversationId: 'conversation-1',
      targetRevisionId: 'a1-v1',
    );

    expect(revisionIds(result.projection.revisions), ['u1', result.revisionId]);
    expect(await textOf(result.revisionId), '');
    expect(
      revisionIds(result.projection.revisions),
      isNot(containsAll(['u2', 'a2'])),
    );
  });

  test(
    'stable revision selection activates the exact alternate path',
    () async {
      await insertFixture();

      final projection = await repository.selectMessageGraphRevision(
        conversationId: 'conversation-1',
        revisionId: 'a1-v7',
      );

      expect(revisionIds(projection.revisions), ['u1', 'a1-v7']);
      expect(projection.branchId, 'branch-alt');
      expect(projection.stateRevision, 1);
    },
  );

  test(
    'delete current revision selects latest alternate without compacting',
    () async {
      await insertFixture();

      final result = await repository.deleteMessageGraphRevision(
        conversationId: 'conversation-1',
        revisionId: 'a1-v1',
        confirmCascade: false,
      );

      expect(result.deletedRevisionCount, 3);
      expect(result.deletedBranchCount, 2);
      expect(revisionIds(result.projection.revisions), ['u1', 'a1-v7']);
      final deleted = await (database.select(
        database.messageRevisionRows,
      )..where((row) => row.deletedAt.isNotNull())).get();
      expect(deleted.map((row) => row.id).toSet(), {'a1-v1', 'u2', 'a2'});
      expect(
        await database.select(database.messageRevisionRows).get(),
        hasLength(5),
      );
    },
  );

  test(
    'delete the last slot revision requires explicit cascade confirmation',
    () async {
      await insertFixture(includeAlternate: false);

      await expectLater(
        repository.deleteMessageGraphRevision(
          conversationId: 'conversation-1',
          revisionId: 'u2',
          confirmCascade: false,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'message_graph_delete_requires_confirmation',
          ),
        ),
      );
      expect(
        (await database.select(database.messageRevisionRows).get()).every(
          (row) => row.deletedAt == null,
        ),
        isTrue,
      );
    },
  );

  test('delete one alternate touches no unrelated revisions', () async {
    await insertFixture();
    for (var index = 8; index < 208; index++) {
      await insertNode(
        conversationId: 'conversation-1',
        slotId: 'slot-a1',
        revisionId: 'a1-v$index',
        role: 'assistant',
        text: 'alternate $index',
        parentRevisionId: 'u1',
        revisionNo: index,
      );
    }

    final result = await repository.deleteMessageGraphRevision(
      conversationId: 'conversation-1',
      revisionId: 'a1-v7',
      confirmCascade: false,
    );

    expect(result.deletedRevisionCount, 1);
    final count = database.messageRevisionRows.id.count();
    final deletedCount =
        await (database.selectOnly(database.messageRevisionRows)
              ..addColumns([count])
              ..where(database.messageRevisionRows.deletedAt.isNotNull()))
            .map((row) => row.read(count))
            .getSingle();
    expect(deletedCount, 1);
  });

  test(
    'fork clones only the requested path with new stable IDs and parts',
    () async {
      await insertFixture();

      final result = await repository.forkMessageGraphConversation(
        sourceConversationId: 'conversation-1',
        sourceBranchId: 'branch-main',
        sourceRevisionId: 'u2',
        targetConversationId: 'conversation-fork',
        title: 'Fork',
      );

      expect(revisionIds(result.projection.revisions), hasLength(3));
      expect(
        revisionIds(
          result.projection.revisions,
        ).toSet().intersection({'u1', 'a1-v1', 'u2'}),
        isEmpty,
      );
      expect(result.revisionIds.keys, containsAll(['u1', 'a1-v1', 'u2']));
      expect(await textOf(result.revisionIds['u2']!), 'U2');
      expect(
        result.projection.contextStartRevisionId,
        result.revisionIds['u1'],
      );
      expect(
        await (database.select(database.messageRevisionRows)
              ..where((row) => row.conversationId.equals('conversation-fork')))
            .get(),
        hasLength(3),
      );
    },
  );

  test(
    'wrong mutation role and stale state roll back without partial rows',
    () async {
      await insertFixture();
      final beforeRevisions =
          (await database.select(database.messageRevisionRows).get()).length;
      final beforeBranches =
          (await database.select(database.conversationBranchRows).get()).length;

      await expectLater(
        repository.editMessageGraphUser(
          conversationId: 'conversation-1',
          targetRevisionId: 'a1-v1',
          text: 'bad',
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.regenerateMessageGraphAssistant(
          conversationId: 'conversation-1',
          targetRevisionId: 'a1-v1',
          expectedStateRevision: 9,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await database.select(database.messageRevisionRows).get()).length,
        beforeRevisions,
      );
      expect(
        (await database.select(database.conversationBranchRows).get()).length,
        beforeBranches,
      );
    },
  );
}
