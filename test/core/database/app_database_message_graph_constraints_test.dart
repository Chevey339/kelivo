import 'package:Kelivo/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  final timestamp = DateTime.fromMicrosecondsSinceEpoch(1783784523123456);

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    await database.customSelect('SELECT 1;').getSingle();
  });

  tearDown(() => database.close());

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
    String role = 'assistant',
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
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? finalizedAt,
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
          createdAt: createdAt ?? timestamp,
          updatedAt: updatedAt ?? timestamp,
          finalizedAt: Value(finalizedAt),
          deletedAt: Value(deletedAt),
        ),
      );

  Future<void> insertBranch({
    required String id,
    required String conversationId,
    String? parentBranchId,
    String? forkedFromRevisionId,
    String? leafRevisionId,
    String causalityKind = 'native',
  }) => database
      .into(database.conversationBranchRows)
      .insert(
        ConversationBranchRowsCompanion.insert(
          id: id,
          conversationId: conversationId,
          parentBranchId: Value(parentBranchId),
          forkedFromRevisionId: Value(forkedFromRevisionId),
          leafRevisionId: Value(leafRevisionId),
          causalityKind: causalityKind,
          createdAt: timestamp,
        ),
      );

  test('accepts a valid graph with sparse revision numbers', () async {
    await insertConversation('conversation-1');
    await insertSlot(
      id: 'slot-user',
      conversationId: 'conversation-1',
      role: 'user',
    );
    await insertSlot(id: 'slot-assistant', conversationId: 'conversation-1');
    await insertRevision(
      id: 'revision-user',
      conversationId: 'conversation-1',
      slotId: 'slot-user',
      revisionNo: 0,
    );
    await insertRevision(
      id: 'revision-assistant-v7',
      conversationId: 'conversation-1',
      slotId: 'slot-assistant',
      parentRevisionId: 'revision-user',
      revisionNo: 7,
      finalizedAt: timestamp,
    );
    await insertBranch(
      id: 'branch-main',
      conversationId: 'conversation-1',
      leafRevisionId: 'revision-assistant-v7',
    );
    await database
        .into(database.conversationStateRows)
        .insert(
          ConversationStateRowsCompanion.insert(
            conversationId: 'conversation-1',
            activeBranchId: const Value('branch-main'),
            contextStartRevisionId: const Value('revision-user'),
          ),
        );

    expect(await database.select(database.messageSlotRows).get(), hasLength(2));
    expect(
      (await database.select(database.messageRevisionRows).get()).map(
        (row) => row.revisionNo,
      ),
      containsAll([0, 7]),
    );
  });

  test('rejects duplicate revisions and invalid enum values', () async {
    await insertConversation('conversation-1');
    await insertSlot(id: 'slot-1', conversationId: 'conversation-1');
    await insertRevision(
      id: 'revision-1',
      conversationId: 'conversation-1',
      slotId: 'slot-1',
      revisionNo: 9,
    );

    await expectLater(
      insertRevision(
        id: 'revision-2',
        conversationId: 'conversation-1',
        slotId: 'slot-1',
        revisionNo: 9,
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertSlot(
        id: 'slot-bad',
        conversationId: 'conversation-1',
        role: 'unknown',
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertBranch(
        id: 'branch-bad',
        conversationId: 'conversation-1',
        causalityKind: 'invented',
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('rejects cross-conversation graph references', () async {
    await insertConversation('conversation-1');
    await insertConversation('conversation-2');
    await insertSlot(id: 'slot-1', conversationId: 'conversation-1');
    await insertSlot(id: 'slot-2', conversationId: 'conversation-2');
    await insertRevision(
      id: 'revision-1',
      conversationId: 'conversation-1',
      slotId: 'slot-1',
    );

    await expectLater(
      insertRevision(
        id: 'revision-cross-slot',
        conversationId: 'conversation-2',
        slotId: 'slot-1',
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertRevision(
        id: 'revision-cross-parent',
        conversationId: 'conversation-2',
        slotId: 'slot-2',
        parentRevisionId: 'revision-1',
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertBranch(
        id: 'branch-cross-leaf',
        conversationId: 'conversation-2',
        leafRevisionId: 'revision-1',
      ),
      throwsA(isA<SqliteException>()),
    );

    await insertBranch(
      id: 'branch-1',
      conversationId: 'conversation-1',
      leafRevisionId: 'revision-1',
    );
    await expectLater(
      insertBranch(
        id: 'branch-cross-parent',
        conversationId: 'conversation-2',
        parentBranchId: 'branch-1',
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertBranch(
        id: 'branch-cross-fork',
        conversationId: 'conversation-2',
        forkedFromRevisionId: 'revision-1',
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      database
          .into(database.conversationStateRows)
          .insert(
            ConversationStateRowsCompanion.insert(
              conversationId: 'conversation-2',
              activeBranchId: const Value('branch-1'),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      database
          .into(database.conversationStateRows)
          .insert(
            ConversationStateRowsCompanion.insert(
              conversationId: 'conversation-2',
              contextStartRevisionId: const Value('revision-1'),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('rejects self parents and invalid graph timestamps', () async {
    await insertConversation('conversation-1');
    await insertSlot(id: 'slot-1', conversationId: 'conversation-1');

    await expectLater(
      insertRevision(
        id: 'revision-self',
        conversationId: 'conversation-1',
        slotId: 'slot-1',
        parentRevisionId: 'revision-self',
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertRevision(
        id: 'revision-time',
        conversationId: 'conversation-1',
        slotId: 'slot-1',
        updatedAt: timestamp.subtract(const Duration(microseconds: 1)),
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertRevision(
        id: 'revision-negative',
        conversationId: 'conversation-1',
        slotId: 'slot-1',
        revisionNo: -1,
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertBranch(
        id: 'branch-self',
        conversationId: 'conversation-1',
        parentBranchId: 'branch-self',
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      database
          .into(database.conversationStateRows)
          .insert(
            ConversationStateRowsCompanion.insert(
              conversationId: 'conversation-1',
              stateRevision: const Value(-1),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('conversation cascade removes the complete graph', () async {
    await insertConversation('conversation-1');
    await insertSlot(id: 'slot-1', conversationId: 'conversation-1');
    await insertRevision(
      id: 'revision-1',
      conversationId: 'conversation-1',
      slotId: 'slot-1',
    );
    await insertBranch(
      id: 'branch-1',
      conversationId: 'conversation-1',
      leafRevisionId: 'revision-1',
    );
    await database
        .into(database.conversationStateRows)
        .insert(
          ConversationStateRowsCompanion.insert(
            conversationId: 'conversation-1',
            activeBranchId: const Value('branch-1'),
          ),
        );

    await (database.delete(
      database.conversationRows,
    )..where((row) => row.id.equals('conversation-1'))).go();

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
  });

  test('ancestry and slot revision queries use graph indexes', () async {
    await insertConversation('conversation-1');
    await insertSlot(id: 'slot-1', conversationId: 'conversation-1');
    await insertRevision(
      id: 'revision-1',
      conversationId: 'conversation-1',
      slotId: 'slot-1',
    );

    Future<String> plan(String sql) async {
      final rows = await database
          .customSelect(
            'EXPLAIN QUERY PLAN $sql',
            variables: const [Variable<String>('conversation-1')],
          )
          .get();
      return rows.map((row) => row.read<String>('detail')).join('\n');
    }

    expect(
      await plan(
        'SELECT id FROM message_revision_rows '
        'WHERE conversation_id = ? AND parent_revision_id IS NULL '
        'ORDER BY id ASC;',
      ),
      contains('idx_message_revisions_parent'),
    );
    expect(
      await plan(
        'SELECT id FROM message_revision_rows '
        'WHERE conversation_id = ? AND slot_id = \'slot-1\' '
        'ORDER BY revision_no DESC, id ASC;',
      ),
      contains('idx_message_revisions_slot_version'),
    );
  });

  test(
    'message parts require a same-conversation revision and unique ordinal',
    () async {
      await insertConversation('conversation-1');
      await insertConversation('conversation-2');
      await insertSlot(id: 'slot-1', conversationId: 'conversation-1');
      await insertRevision(
        id: 'revision-1',
        conversationId: 'conversation-1',
        slotId: 'slot-1',
      );
      final part = MessagePartRowsCompanion.insert(
        conversationId: 'conversation-1',
        revisionId: 'revision-1',
        ordinal: 0,
        kind: 'text',
        payload: 'hello',
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await database.into(database.messagePartRows).insert(part);

      await expectLater(
        database.into(database.messagePartRows).insert(part),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        database
            .into(database.messagePartRows)
            .insert(
              MessagePartRowsCompanion.insert(
                conversationId: 'conversation-2',
                revisionId: 'revision-1',
                ordinal: 1,
                kind: 'text',
                payload: 'cross',
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        database
            .into(database.messagePartRows)
            .insert(
              MessagePartRowsCompanion.insert(
                conversationId: 'conversation-1',
                revisionId: 'revision-1',
                ordinal: 1,
                kind: 'unknown',
                payload: 'bad',
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    },
  );
}
