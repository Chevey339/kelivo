import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/context_operation.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ChatDatabaseRepository repo;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatDatabaseRepository(db);
    await repo.ensureReady();
    await db.customStatement(
      "INSERT INTO conversation_rows(id,title,created_at,updated_at,truncate_index) VALUES('c','test',1,1,-1)",
    );
    await db.customStatement('''
WITH RECURSIVE seq(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM seq WHERE n<556)
INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order,version)
SELECT 'm'||n,'c',CASE WHEN n%2=0 THEN 'user' ELSE 'assistant' END,1,n,0 FROM seq
''');
    // A later revision keeps its group's original position in the timeline.
    await db.customStatement(
      "INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order,group_id,version) VALUES('a1','c','assistant',1,557,'m1',1)",
    );
  });
  tearDown(() => repo.close());

  ContextOperation operation({String summary = 'summary'}) => ContextOperation(
    id: 's',
    kind: ContextOperationKind.compress,
    anchorGroupId: 'm1',
    appliedAfterGroupId: 'm3',
    sourceGroups: ['m0', 'm1'],
    dependencies: [],
    createdAt: DateTime(2026),
    summary: summary,
    originalSummary: summary,
    compressionDetails: {'largeOpaquePayload': 'x' * (2 * 1024 * 1024)},
  );

  Future<void> writeOperation(ContextOperation op) => db.customStatement(
    "INSERT INTO extension_entity_rows(kind,id,owner_id,sort_order,payload,updated_at) VALUES('conversationContext','c','c',0,?,1) "
    'ON CONFLICT(kind,id) DO UPDATE SET payload=excluded.payload',
    [
      jsonEncode([op.toJson()]),
    ],
  );

  test(
    'regeneration locates adjacent selected reply and optional tail using headers',
    () async {
      final source = await repo.getRegenerationSourceGroups(
        'c',
        'm0',
        assistantAsNewReply: false,
        deleteTrailingMessages: false,
      );
      expect(source.targetGroupId, 'm1');
      expect(source.removedGroups, isEmpty);
      final tail = await repo.getRegenerationSourceGroups(
        'c',
        'm0',
        assistantAsNewReply: false,
        deleteTrailingMessages: true,
      );
      expect(tail.targetGroupId, 'm1');
      expect(tail.removedGroups, {for (var i = 2; i <= 556; i++) 'm$i'});
      final newReply = await repo.getRegenerationSourceGroups(
        'c',
        'a1',
        assistantAsNewReply: true,
        deleteTrailingMessages: true,
      );
      expect(newReply.targetGroupId, isNull);
      expect(newReply.removedGroups, tail.removedGroups);
      final stale = await repo.getRegenerationSourceGroups(
        'c',
        'm1',
        assistantAsNewReply: false,
        deleteTrailingMessages: true,
      );
      expect(stale.targetGroupId, isNull);
      expect(stale.removedGroups, isEmpty);
      final last = await repo.getRegenerationSourceGroups(
        'c',
        'm556',
        assistantAsNewReply: false,
        deleteTrailingMessages: true,
      );
      expect(last.targetGroupId, isNull);
      expect(last.removedGroups, isEmpty);
      await db.customStatement(
        "UPDATE message_rows SET role='user' WHERE id='a1'",
      );
      final adjacentUser = await repo.getRegenerationSourceGroups(
        'c',
        'm0',
        assistantAsNewReply: false,
        deleteTrailingMessages: true,
      );
      expect(adjacentUser.targetGroupId, isNull);
      expect(adjacentUser.removedGroups, contains('m1'));
    },
  );

  test(
    'source metadata omits large payloads and unrelated selection keeps the revision',
    () async {
      await writeOperation(operation());
      final state = await repo.readContextMutationState('c');
      expect(state.operations.single.sourceGroups, ['m0', 'm1']);
      expect(state.operations.single, isNot(isA<ContextOperation>()));
      final metadata =
          (await db
                  .customSelect(
                    "SELECT metadata FROM context_operation_state WHERE conversation_id='c'",
                  )
                  .getSingle())
              .read<String>('metadata');
      expect(metadata.length, lessThan(500));
      final first = await repo.readContextOperations('c');
      await repo.setSelectedVersion(
        conversationId: 'c',
        groupId: 'm4',
        version: 0,
        expectedContextState: state.revision,
      );
      expect(
        (await repo.readContextMutationState('c')).revision,
        state.revision,
      );
      expect(identical(first, await repo.readContextOperations('c')), isTrue);
    },
  );

  test(
    'payload-only SQL updates invalidate approvals and the decoded cache',
    () async {
      await writeOperation(operation());
      final state = await repo.readContextMutationState('c');
      await repo.readContextOperations('c');
      await writeOperation(operation(summary: 'changed'));
      expect((await repo.readContextOperations('c')).single.summary, 'changed');
      await expectLater(
        repo.setSelectedVersion(
          conversationId: 'c',
          groupId: 'm1',
          version: 0,
          expectedContextState: state.revision,
        ),
        throwsStateError,
      );
      expect((await repo.getConversation('c'))!.versionSelections, isEmpty);
      expect((await repo.readContextOperations('c')).single.revoked, isFalse);
    },
  );

  test(
    'source revocations commit with selection and roll back atomically',
    () async {
      await writeOperation(operation());
      final state = await repo.readContextMutationState('c');
      await expectLater(
        db.transaction(() async {
          await repo.setSelectedVersion(
            conversationId: 'c',
            groupId: 'm1',
            version: 0,
            expectedContextState: state.revision,
          );
          expect(
            (await repo.readContextOperations('c')).single.revoked,
            isTrue,
          );
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(
        (await repo.readContextMutationState('c')).revision,
        state.revision,
      );
      expect((await repo.readContextOperations('c')).single.revoked, isFalse);
      await repo.setSelectedVersion(
        conversationId: 'c',
        groupId: 'm1',
        version: 0,
        expectedContextState: state.revision,
      );
      expect((await repo.readContextOperations('c')).single.revoked, isTrue);
    },
  );

  test(
    'rolled-back installation, delete and replacement cannot leave stale state',
    () async {
      await writeOperation(operation());
      await expectLater(
        db.transaction(() async {
          await repo.readContextMutationState('c');
          throw StateError('rollback first read');
        }),
        throwsStateError,
      );
      final state = await repo.readContextMutationState('c');
      await db.customStatement(
        "DELETE FROM extension_entity_rows WHERE kind='conversationContext' AND id='c'",
      );
      final deleted = await repo.readContextMutationState('c');
      expect(deleted.revision, isNot(state.revision));
      expect(deleted.operations, isEmpty);
      await writeOperation(operation());
      expect(
        (await repo.readContextMutationState('c')).revision,
        isNot(deleted.revision),
      );
      await db.customStatement("DELETE FROM conversation_rows WHERE id='c'");
      expect(
        await db.customSelect('SELECT * FROM context_operation_state').get(),
        isEmpty,
      );
    },
  );
}
