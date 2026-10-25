import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/message_timeline_index.dart';

class _FailOnceDatabase extends AppDatabase {
  _FailOnceDatabase() : super(NativeDatabase.memory());

  var installationAttempts = 0;

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    if (statement.startsWith(
      'CREATE INDEX IF NOT EXISTS idx_timeline_group_order',
    )) {
      installationAttempts++;
      if (installationAttempts == 1) {
        throw StateError('transient installation failure');
      }
    }
    await super.customStatement(statement, args);
  }
}

void main() {
  for (final groupCount in [1, 1000]) {
    test('bulk order shifts preserve indexed anchors across $groupCount groups', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ChatDatabaseRepository(db);
      addTearDown(repo.close);
      await repo.ensureReady();
      await db.customStatement(
        "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('c','test',1,1),('unopened','other',1,1)",
      );
      await db.customStatement(
        '''
WITH RECURSIVE seq(n) AS (VALUES(0) UNION ALL SELECT n+1 FROM seq WHERE n<1999)
INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order,group_id,version)
SELECT 'm'||n,'c','assistant',1,n,'g'||(n%?),n/? FROM seq
''',
        [groupCount, groupCount],
      );
      await db.customStatement(
        "INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order) VALUES('unread','unopened','user',1,0)",
      );
      final before = await repo.loadLinearMessageWindow(
        conversationId: 'c',
        fromStart: true,
        limit: 2000,
      );
      expect(before.totalSlotCount, groupCount);
      expect(
        await db
            .customSelect(
              "SELECT revision_id FROM timeline_revision_rows WHERE conversation_id='unopened'",
            )
            .get(),
        isEmpty,
      );
      final plan = await db
          .customSelect(
            "EXPLAIN QUERY PLAN SELECT message_order FROM timeline_revision_rows WHERE conversation_id='c' AND group_id='g0' ORDER BY message_order LIMIT 1",
          )
          .get();
      expect(
        plan.map((r) => r.read<String>('detail')).join('\n'),
        contains(
          'COVERING INDEX idx_timeline_revision_order (conversation_id=? AND group_id=?)',
        ),
      );
      await db.transaction(() async {
        await db.customStatement(
          "UPDATE message_rows SET message_order=message_order+2000 WHERE conversation_id='c' AND message_order>0",
        );
        await db.customStatement(
          "UPDATE message_rows SET message_order=message_order-2000+1 WHERE conversation_id='c' AND message_order>1999",
        );
      });
      final after = await repo.loadLinearMessageWindow(
        conversationId: 'c',
        fromStart: true,
        limit: 2000,
      );
      expect(
        after.slots.map((s) => (s.groupId, s.revisionId, s.versionCount)),
        before.slots.map((s) => (s.groupId, s.revisionId, s.versionCount)),
      );
      final anchors = await db
          .customSelect(
            "SELECT g.group_id,g.anchor_order,MIN(m.message_order) AS expected FROM timeline_group_rows g JOIN message_rows m ON m.conversation_id=g.conversation_id AND m.group_id=g.group_id WHERE g.conversation_id='c' GROUP BY g.group_id",
          )
          .get();
      for (final row in anchors) {
        expect(row.read<int>('anchor_order'), row.read<int>('expected'));
      }
      await db.customStatement(
        "UPDATE message_rows SET id='renamed' WHERE id='m0'",
      );
      expect(
        await db
            .customSelect(
              "SELECT revision_id FROM timeline_revision_rows WHERE revision_id='m0'",
            )
            .get(),
        isEmpty,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT revision_id FROM timeline_revision_rows WHERE revision_id='renamed'",
                )
                .getSingle())
            .read<String>('revision_id'),
        'renamed',
      );
      await db.customStatement("DELETE FROM message_rows WHERE id='renamed'");
      expect(await repo.getMessageCount('c'), 1999);
      await db.customStatement("DELETE FROM conversation_rows WHERE id='c'");
      expect(
        await db
            .customSelect(
              "SELECT * FROM timeline_revision_rows WHERE conversation_id='c'",
            )
            .get(),
        isEmpty,
      );
      expect(
        await db
            .customSelect(
              "SELECT * FROM timeline_group_rows WHERE conversation_id='c'",
            )
            .get(),
        isEmpty,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });
  }

  test('a failed installation rolls back and the same index can retry', () async {
    final db = _FailOnceDatabase();
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('c','test',1,1)",
    );
    await db.customStatement(
      "INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order) VALUES('m','c','user',1,0)",
    );
    final index = MessageTimelineIndex(db);
    await expectLater(
      Future.wait([
        index.ensureConversation('c'),
        index.ensureConversation('c'),
      ]),
      throwsStateError,
    );
    expect(db.installationAttempts, 1);
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name='timeline_state'",
          )
          .get(),
      isEmpty,
    );
    await index.ensureConversation('c');
    expect(db.installationAttempts, 2);
    final state = await db
        .customSelect(
          "SELECT ready,group_count,message_count FROM timeline_state WHERE conversation_id='c'",
        )
        .getSingle();
    expect(state.read<int>('ready'), 1);
    expect(state.read<int>('group_count'), 1);
    expect(state.read<int>('message_count'), 1);
    await db.customStatement(
      "INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order) VALUES('m2','c','assistant',1,1)",
    );
    await index.ensureConversation('c');
    expect(db.installationAttempts, 2);
    expect(
      (await db
              .customSelect(
                "SELECT message_count FROM timeline_state WHERE conversation_id='c'",
              )
              .getSingle())
          .read<int>('message_count'),
      2,
    );
  });

  test(
    'indexed windows match authoritative history through structural mutations',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ChatDatabaseRepository(db);
      addTearDown(repo.close);
      await repo.ensureReady();
      await db.customStatement(
        "INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES('c','test',1,1)",
      );
      final random = Random(1163);
      var nextOrder = 0;
      final selections = <String, int>{};
      for (var step = 0; step < 140; step++) {
        if (step < 30 || random.nextInt(3) == 0) {
          final group = random.nextBool() ? null : 'g${random.nextInt(8)}';
          await db.customStatement(
            'INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order,group_id,version) VALUES(?,?,?,?,?,?,?)',
            ['m$step', 'c', 'assistant', 1, nextOrder++, group, step],
          );
        } else {
          final existing = await db
              .customSelect(
                'SELECT id,group_id FROM message_rows WHERE conversation_id=\'c\' ORDER BY id',
              )
              .get();
          if (existing.isEmpty) continue;
          final picked = existing[random.nextInt(existing.length)];
          switch (random.nextInt(3)) {
            case 0:
              await db.customStatement('DELETE FROM message_rows WHERE id=?', [
                picked.read<String>('id'),
              ]);
            case 1:
              await db.customStatement(
                'UPDATE message_rows SET message_order=? WHERE id=?',
                [nextOrder++, picked.read<String>('id')],
              );
            case 2:
              final group =
                  picked.readNullable<String>('group_id') ??
                  picked.read<String>('id');
              selections[group] = random.nextInt(160);
              await db.customStatement(
                'UPDATE conversation_rows SET version_selections_json=? WHERE id=\'c\'',
                [jsonEncode(selections)],
              );
          }
        }
        final expected = await db
            .customSelect(
              _oracle,
              variables: [
                const Variable<String>('c'),
                const Variable<String>('c'),
                const Variable<String>('c'),
              ],
            )
            .get();
        final all = await repo.loadLinearMessageWindow(
          conversationId: 'c',
          fromStart: true,
          limit: 1000,
        );
        final physical = await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM message_rows WHERE conversation_id=\'c\'',
            )
            .getSingle();
        expect(await repo.getMessageCount('c'), physical.read<int>('n'));
        expect(
          all.totalSlotCount,
          expected.length,
          reason: 'mutation $step count',
        );
        expect(
          all.slots.map(
            (s) => (s.groupId, s.revisionId, s.versionCount, s.logicalIndex),
          ),
          expected.map(
            (r) => (
              r.read<String>('group_id'),
              r.read<String>('revision_id'),
              r.read<int>('version_count'),
              r.read<int>('logical_index'),
            ),
          ),
          reason: 'mutation $step',
        );
        final tail = await repo.loadLinearMessageWindow(
          conversationId: 'c',
          limit: 7,
        );
        expect(
          tail.slots.map((s) => s.revisionId),
          expected
              .skip(max(0, expected.length - 7))
              .map((r) => r.read<String>('revision_id')),
        );
        if (expected.isNotEmpty) {
          final at = random.nextInt(expected.length);
          final revision = expected[at].read<String>('revision_id');
          final before = await repo.loadLinearMessageWindow(
            conversationId: 'c',
            beforeRevisionId: revision,
            limit: 5,
          );
          expect(
            before.slots.map((s) => s.revisionId),
            expected
                .sublist(max(0, at - 5), at)
                .map((r) => r.read<String>('revision_id')),
          );
          final after = await repo.loadLinearMessageWindow(
            conversationId: 'c',
            afterRevisionId: revision,
            limit: 5,
          );
          expect(
            after.slots.map((s) => s.revisionId),
            expected
                .skip(at + 1)
                .take(5)
                .map((r) => r.read<String>('revision_id')),
          );
          final nearest = List<int>.generate(expected.length, (i) => i)
            ..sort((a, b) {
              final distance = (a - at).abs().compareTo((b - at).abs());
              return distance == 0 ? a.compareTo(b) : distance;
            });
          final positions = nearest.take(6).toList()..sort();
          final around = await repo.loadLinearMessageWindow(
            conversationId: 'c',
            aroundRevisionId: revision,
            limit: 6,
          );
          expect(
            around.slots.map((s) => s.revisionId),
            positions.map((i) => expected[i].read<String>('revision_id')),
          );
        }
      }
    },
  );

  test(
    'lazy rebuild and structural moves preserve null anchors and invalid selections',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ChatDatabaseRepository(db);
      addTearDown(repo.close);
      await repo.ensureReady();
      for (final id in ['a', 'b']) {
        await db.customStatement(
          'INSERT INTO conversation_rows(id,title,created_at,updated_at) VALUES(?,?,1,1)',
          [id, id],
        );
      }
      await db.customStatement(
        "INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order,group_id,version) VALUES('anchor','a','assistant',1,0,NULL,0),('revision','a','assistant',1,1,'anchor',1),('empty','a','user',1,2,'',0)",
      );
      Future<void> check(String id) async {
        final expected = await db
            .customSelect(
              _oracle,
              variables: List.generate(3, (_) => Variable<String>(id)),
            )
            .get();
        final actual = await repo.loadLinearMessageWindow(
          conversationId: id,
          fromStart: true,
          limit: 100,
        );
        expect(
          actual.slots.map((s) => (s.groupId, s.revisionId, s.versionCount)),
          expected.map(
            (r) => (
              r.read<String>('group_id'),
              r.read<String>('revision_id'),
              r.read<int>('version_count'),
            ),
          ),
        );
        final count = await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM message_rows WHERE conversation_id=?',
              variables: [Variable<String>(id)],
            )
            .getSingle();
        expect(await repo.getMessageCount(id), count.read<int>('n'));
      }

      await check('a');
      await check('b');
      await db.customStatement(
        "UPDATE conversation_rows SET version_selections_json='{\"anchor\":9}' WHERE id='a'",
      );
      await db.customStatement(
        "UPDATE message_rows SET version=9 WHERE id='anchor'",
      );
      await check('a');
      await db.customStatement(
        "UPDATE message_rows SET conversation_id='b',group_id=NULL WHERE id='revision'",
      );
      await check('a');
      await check('b');
      await db.customStatement("DELETE FROM message_rows WHERE id='anchor'");
      await check('a');
      for (final sql in MessageTimelineIndex.discardStatements) {
        await db.customStatement(sql);
      }
      await MessageTimelineIndex.install(db);
      await check('a');
      await check('b');
      expect(
        (await db
                .customSelect(
                  "SELECT version_selections_json FROM conversation_rows WHERE id='a'",
                )
                .getSingle())
            .read<String>('version_selections_json'),
        '{"anchor":9}',
      );
    },
  );
}

const _oracle = r'''WITH group_rows AS (
            SELECT
              COALESCE(m.group_id, m.id) AS group_id,
              MIN(m.message_order) AS anchor_order,
              COUNT(*) AS version_count,
              MAX(m.version) AS latest_version
            FROM message_rows m
            WHERE m.conversation_id = ?
            GROUP BY COALESCE(m.group_id, m.id)
          ),
          selections AS (
            SELECT j.key AS group_id, CAST(j.value AS INTEGER) AS version
            FROM conversation_rows c, json_each(c.version_selections_json) j
            WHERE c.id = ?
          ),
          ranked AS (
            SELECT
              m.id AS revision_id,
              g.group_id,
              g.anchor_order,
              g.version_count,
              ROW_NUMBER() OVER (
                PARTITION BY g.group_id
                ORDER BY
                  CASE
                    WHEN m.version = COALESCE(s.version, g.latest_version)
                    THEN 0 ELSE 1
                  END,
                  m.version DESC,
                  m.message_order DESC,
                  m.id DESC
              ) AS version_rank
            FROM group_rows g
            JOIN message_rows m
              ON m.conversation_id = ?
             AND COALESCE(m.group_id, m.id) = g.group_id
            LEFT JOIN selections s ON s.group_id = g.group_id
          ),
          ordered AS (
            SELECT
              revision_id,
              group_id,
              version_count,
              ROW_NUMBER() OVER (
                ORDER BY anchor_order, group_id
              ) - 1 AS logical_index,
              COUNT(*) OVER () AS total_count
            FROM ranked
            WHERE version_rank = 1
          )
          SELECT * FROM ordered ORDER BY logical_index;''';
