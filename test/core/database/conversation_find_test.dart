import 'dart:async';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_regex.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/models/conversation_find_candidate.dart';
import 'package:Kelivo/features/chat/services/conversation_find_service.dart';
import 'package:Kelivo/features/chat/services/conversation_find_worker.dart';

class _SelectObserver extends QueryInterceptor {
  void Function(String)? onSelect;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    onSelect?.call(statement);
    return executor.runSelect(statement, args);
  }
}

void main() {
  test(
    'preview prefilter preserves rendered hits, counts, order and spans',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ChatDatabaseRepository(db);
      addTearDown(repo.close);
      ChatMessage msg(
        String id,
        String body, {
        String role = 'assistant',
        List<MessagePart>? parts,
        String? translation,
      }) => ChatMessage(
        id: id,
        conversationId: 'c',
        role: role,
        content: body,
        parts: parts,
        translation: translation,
      );
      final largeCss = '```css\n${'.button { color: red; }\n' * 900}```';
      const image = ImagePart(uri: '/images/明白.png');
      const file = FilePart(uri: '/files/note', name: '明白.txt');
      const tool = ToolCallPart('{"name":"read_file","content":"明白"}');
      final messages = [
        msg('plain', '已经明白。明白。 Foobar'),
        msg('markdown', '明**白** fo**ob**ar'),
        msg('entity', '&#x660e;&#x767d; fo&#111;bar'),
        msg(
          'split',
          '',
          parts: const [TextPart('明'), TextPart('白 fo'), TextPart('obar')],
        ),
        msg(
          'reasoning',
          '',
          parts: const [ReasoningPart('hidden'), TextPart('明白 Foobar')],
        ),
        msg(
          'hidden',
          '',
          parts: const [
            ReasoningPart('明白 Foobar'),
            TextPart('ordinary answer'),
          ],
        ),
        msg('translation', 'ordinary prose', translation: '明白 FOOBAR'),
        msg('unicode', 'Straße ﬃ Kelvin ПРИВЕТ'),
        msg('nul', 'prefix\u0000fo**ob**ar'),
        msg('stream', 'ordinary prose'),
        msg('large-miss', largeCss),
        msg('large-hit', '$largeCss\n\n明白'),
        msg('attachments', '', role: 'user', parts: const [image, file]),
        msg('tool-miss', '', parts: const [TextPart('ordinary prose'), tool]),
        msg(
          'large-attached-miss',
          '',
          parts: [image, TextPart(largeCss), tool],
        ),
        msg(
          'large-reasoning-miss',
          '',
          parts: [const ReasoningPart('明白'), TextPart(largeCss)],
        ),
        msg('tool-hit', '', parts: const [tool, TextPart('已经明白。')]),
        msg(
          'split-file',
          '',
          role: 'user',
          parts: const [TextPart('明'), file, TextPart('白')],
        ),
        msg(
          'citation',
          '',
          parts: const [
            TextPart('See [cite:doc].'),
            ToolCallPart(
              '{"name":"search_web","content":"{\\"items\\":[{\\"id\\":\\"doc\\",\\"index\\":7}]}"}',
            ),
          ],
        ),
      ];
      await repo.putMigrationBatch(
        conversations: [Conversation(id: 'c', title: 'find')],
        messages: [
          for (final (i, m) in messages.indexed) (message: m, messageOrder: i),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await db.customStatement(
        "UPDATE message_rows SET is_streaming=1 WHERE id='stream'",
      );
      Future<List<Object>> results(
        ConversationFindService finder,
        String q, {
        required bool optimized,
      }) async {
        final worker = ConversationFindWorker();
        try {
          final source = repo.conversationFindCandidates(
            'c',
            prefilter: optimized ? finder.previewPrefilter(q) : null,
            worker: optimized ? worker : null,
          );
          return await finder
              .searchPreviews(
                source,
                q,
                worker: optimized ? worker : null,
                liveCandidate: (row) => row.id == 'stream'
                    ? ConversationFindCandidate(msg('stream', '明白 Foobar'))
                    : row,
              )
              .expand((page) => page)
              .map((p) => [p.hit, p.role, p.matchCount, p.before, p.segments])
              .toList();
        } finally {
          worker.close();
        }
      }

      const finder = ConversationFindService();
      final hanCandidates = await repo
          .conversationFindCandidates(
            'c',
            prefilter: finder.previewPrefilter('明白'),
          )
          .expand((page) => page.map((r) => r.id))
          .toList();
      expect(hanCandidates, contains('reasoning'));
      expect(hanCandidates, isNot(contains('hidden')));
      expect(hanCandidates, contains('large-hit'));
      expect(hanCandidates, isNot(contains('large-miss')));
      expect(hanCandidates, containsAll(['tool-hit', 'split-file']));
      for (final miss in [
        'attachments',
        'tool-miss',
        'large-attached-miss',
        'large-reasoning-miss',
      ]) {
        expect(hanCandidates, isNot(contains(miss)));
      }
      for (final q in [
        '明白',
        'FOOBAR',
        'STRASSE',
        'ffi',
        'KELVIN',
        'привет',
        '7',
        '。',
      ]) {
        final all = await results(finder, q, optimized: false);
        expect(all, isNotEmpty, reason: q);
        expect(await results(finder, q, optimized: true), all, reason: q);
      }
      final visual = ConversationFindService(
        assistant: Assistant(
          id: 'a',
          name: 'a',
          regexRules: const [
            AssistantRegex(
              id: 'replace',
              name: 'replace',
              pattern: 'ordinary prose',
              replacement: '新词',
              visualOnly: true,
              scopes: [AssistantRegexScope.assistant],
            ),
          ],
        ),
      );
      expect(visual.previewPrefilter('新词'), isNull);
      expect(await results(visual, '新词', optimized: true), isNotEmpty);
    },
  );

  test(
    'sparse and dense preview pages hydrate only candidates and keep the tail',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = ChatDatabaseRepository(db);
      addTearDown(repo.close);
      const finder = ConversationFindService();
      final expected = [for (var i = 325; i < 525; i++) 'm$i', 'm706'];
      final matching = expected.toSet();
      await repo.putMigrationBatch(
        conversations: [Conversation(id: 'c', title: 'find')],
        messages: [
          for (var i = 0; i <= 706; i++)
            (
              message: ChatMessage(
                id: 'm$i',
                conversationId: 'c',
                role: 'user',
                content: matching.contains('m$i') ? '青柠雨伞' : '普通对话 青山',
              ),
              messageOrder: i,
            ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      final pages = await repo
          .conversationFindCandidates(
            'c',
            prefilter: finder.previewPrefilter('青柠'),
          )
          .toList();
      expect(pages.expand((page) => page.map((r) => r.id)), expected);
      expect(
        pages.every((p) => p.length <= ConversationFindCandidate.batchSize),
        isTrue,
      );
      expect(
        await repo
            .conversationFindCandidates(
              'c',
              prefilter: finder.previewPrefilter('missing'),
            )
            .toList(),
        isEmpty,
      );
    },
  );

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

  test('cancelling a preview skips the remaining reads in its page', () async {
    final observer = _SelectObserver();
    final db = AppDatabase(NativeDatabase.memory().interceptWith(observer));
    final repo = ChatDatabaseRepository(db);
    addTearDown(repo.close);
    await repo.putMigrationBatch(
      conversations: [Conversation(id: 'c', title: 'find')],
      messages: [
        (
          message: ChatMessage(
            id: 'm',
            conversationId: 'c',
            role: 'user',
            content: '明白',
          ),
          messageOrder: 0,
        ),
      ],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    for (final table in [
      'message_rows',
      'message_part_rows',
      'generation_run_rows',
    ]) {
      final worker = ConversationFindWorker();
      addTearDown(worker.close);
      final readsAfterCancel = <String>[];
      observer.onSelect = (sql) {
        if (!worker.isCurrent) {
          readsAfterCancel.add(sql);
        } else if (sql.contains('FROM "$table"')) {
          worker.close();
        }
      };
      final pages = await repo
          .conversationFindCandidates(
            'c',
            prefilter: const ConversationFindService().previewPrefilter('明白'),
            worker: worker,
          )
          .toList();
      observer.onSelect = null;
      expect(worker.isCurrent, isFalse, reason: table);
      expect(pages, isEmpty, reason: table);
      expect(readsAfterCancel, isEmpty, reason: table);
    }
  });

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
