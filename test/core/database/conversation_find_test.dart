import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/models/conversation_find_candidate.dart';
import 'package:Kelivo/features/chat/services/conversation_find_service.dart';

void main() {
  test(
    'a first search can overlap a transaction loading another history',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ChatDatabaseRepository(db);
      addTearDown(repo.close);
      await db.customStatement("""
      INSERT INTO conversation_rows(id,title,created_at,updated_at)
      VALUES('search','Search',1,1),('other','Other',1,1)
    """);
      await db.customStatement("""
      INSERT INTO message_rows(id,conversation_id,role,timestamp,message_order)
      VALUES('s','search','user',1,0),('o','other','user',1,0)
    """);
      final holdingConnection = Completer<void>();
      final searchStarted = Completer<void>();
      final history = db.transaction(() async {
        await db.customSelect('SELECT 1').getSingle();
        holdingConnection.complete();
        await searchStarted.future;
        // The timeout gives the connection back if a queued installation
        // deadlocks, so teardown can still close the database.
        return repo
            .getMessageCount('other')
            .timeout(const Duration(seconds: 3));
      });
      await holdingConnection.future;
      final search = repo
          .conversationFindCandidates(
            'search',
            isCurrent: () {
              if (!searchStarted.isCompleted) searchStarted.complete();
              return true;
            },
          )
          .first;
      expect(await history, 1);
      expect((await search).single.id, 's');
    },
  );

  test(
    'leaving a preview stops paging and lets another conversation load',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ChatDatabaseRepository(db);
      addTearDown(repo.close);
      const pageSize = ConversationFindCandidate.batchSize;
      final messages = [
        for (var i = 0; i < pageSize + 1; i++)
          ChatMessage(
            id: 'm$i',
            conversationId: 'large',
            role: 'assistant',
            content: '明白',
          ),
        ChatMessage(
          id: 'read',
          conversationId: 'other',
          role: 'user',
          content: '另一条消息',
        ),
      ];
      await repo.putMigrationBatch(
        conversations: [
          for (final id in ['large', 'other']) Conversation(id: id, title: id),
        ],
        messages: [
          for (final (i, message) in messages.indexed)
            (message: message, messageOrder: i),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      var current = true;
      var pages = 0;
      final candidates = repo
          .conversationFindCandidates('large', isCurrent: () => current)
          .map((batch) {
            pages++;
            return batch;
          });
      final previews = StreamIterator(
        const ConversationFindService().searchPreviews(
          candidates,
          '明白',
          isCurrent: () => current,
        ),
      );
      addTearDown(previews.cancel);
      expect(await previews.moveNext(), isTrue);
      expect(previews.current, hasLength(pageSize));
      current = false;
      final other = await repo.loadLinearMessageWindow(conversationId: 'other');
      final bodies = await repo.getMessagesByIds([
        other.slots.single.revisionId,
      ]);
      expect(bodies.single.content, '另一条消息');
      expect(await previews.moveNext(), isFalse);
      expect(pages, 1);
    },
  );

  test('timeline page reads look up generation runs by message id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = ChatDatabaseRepository(db);
    addTearDown(repo.close);
    await repo.putConversation(Conversation(id: 'c', title: 'find'));
    await repo.loadLinearMessageWindow(conversationId: 'c');
    final plan = await db.customSelect("""
      EXPLAIN QUERY PLAN SELECT * FROM generation_run_rows
      WHERE target_revision_id IN ('one', 'two')
      ORDER BY created_at DESC, updated_at DESC, id DESC
    """).get();
    expect(
      plan.map((row) => row.read<String>('detail')).join('\n'),
      contains('SEARCH generation_run_rows USING INDEX'),
    );
  });

  test(
    'pages selected revisions in order, ignores tools and other conversations',
    () async {
      final repo = ChatDatabaseRepository(AppDatabase(NativeDatabase.memory()));
      addTearDown(repo.close);
      await repo.ensureReady();
      final c = Conversation(
        id: 'c',
        title: 'find',
        versionSelections: {'g': 0},
      );
      final other = Conversation(id: 'd', title: 'other');
      ChatMessage message(
        String id,
        String text, {
        String? group,
        int version = 0,
        String role = 'assistant',
        String conversation = 'c',
        List<MessagePart>? parts,
      }) => ChatMessage(
        id: id,
        role: role,
        content: text,
        groupId: group,
        version: version,
        conversationId: conversation,
        parts: parts,
      );
      final messages = [
        message('first', '🙂match match'),
        message('old', 'match', group: 'g'),
        message('new', 'new version', group: 'g', version: 1),
        message('tool', 'match', role: 'tool'),
        message('other', 'match', conversation: 'd'),
        message(
          'structured',
          '',
          parts: const [
            TextPart('visible'),
            ToolCallPart(
              '{"id":"t","name":"tool","arguments":{"q":"match"},"content":"match"}',
            ),
          ],
        ),
        for (var i = 0; i < 60; i++) message('m$i', 'ordinary'),
        message('last', 'match'),
      ];
      await repo.putMigrationBatch(
        conversations: [c, other],
        messages: [
          for (final (index, msg) in messages.indexed)
            (message: msg, messageOrder: index),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      Future<List<ConversationFindHit>> search(String q) async =>
          (await const ConversationFindService().search(
            repo.conversationFindCandidates('c'),
            q,
            defaultFindOptions,
          )).values.expand((h) => h).toList();
      expect((await search('match')).map((h) => h.messageId), [
        'first',
        'first',
        'old',
        'last',
      ]);
      expect(await search('new version'), isEmpty);
      await repo.putConversation(c.copyWith(versionSelections: {'g': 1}));
      expect((await search('new version')).single.messageId, 'new');
      expect((await search('match')).map((h) => h.messageId), [
        'first',
        'first',
        'last',
      ]);
    },
  );
}
