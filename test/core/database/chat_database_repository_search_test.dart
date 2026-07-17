import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
  test(
    'search defaults to selected versions and can include every version',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chat_search_versions_',
      );
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/search.sqlite'),
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });
      final now = DateTime.utc(2026, 7, 12);
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Versions',
        createdAt: now,
        updatedAt: now,
        versionSelections: const {'slot-1': 2},
      );
      ChatMessage version(String id, int number, String content) => ChatMessage(
        id: id,
        role: 'assistant',
        content: content,
        timestamp: now,
        conversationId: conversation.id,
        groupId: 'slot-1',
        version: number,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [
          (message: version('v1', 1, 'hidden-only-token'), messageOrder: 0),
          (message: version('v2', 2, 'visible-only-token'), messageOrder: 1),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      expect(
        await repository.searchConversationMatches(
          tokens: const ['hidden-only-token'],
        ),
        isEmpty,
      );
      expect(
        (await repository.searchConversationMatches(
          tokens: const ['visible-only-token'],
        )).single.messageId,
        'v2',
      );
      expect(
        (await repository.searchConversationMatches(
          tokens: const ['hidden-only-token'],
          includeAllRevisions: true,
        )).single.messageId,
        'v1',
      );
    },
  );

  test('search uses FTS for words and substring fallback for CJK', () async {
    final root = await Directory.systemTemp.createTemp('chat_search_test_');
    final repository = ChatDatabaseRepository.open(
      file: File('${root.path}/search.sqlite'),
    );
    addTearDown(() async {
      await repository.close();
      await root.delete(recursive: true);
    });
    final conversation = Conversation(
      id: 'conversation-1',
      title: 'Search',
      createdAt: DateTime.utc(2026, 7, 12),
      updatedAt: DateTime.utc(2026, 7, 12),
      messageIds: const ['revision-1'],
    );
    final message = ChatMessage(
      id: 'revision-1',
      role: 'assistant',
      content: 'A searchable needle appears here，测试中文短词。',
      timestamp: DateTime.utc(2026, 7, 12),
      conversationId: conversation.id,
      groupId: 'slot-1',
      version: 1,
    );
    await repository.putMigrationBatch(
      conversations: [conversation],
      messages: [(message: message, messageOrder: 0)],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );

    final word = await repository.searchConversationMatches(
      tokens: const ['needle'],
    );
    final cjk = await repository.searchConversationMatches(
      tokens: const ['中文'],
    );

    expect(word.single.messageId, 'revision-1');
    expect(word.single.groupId, 'slot-1');
    expect(cjk.single.messageId, 'revision-1');

    await repository.updateMessage(
      message.copyWith(content: 'replacement token'),
    );
    expect(
      await repository.searchConversationMatches(tokens: const ['needle']),
      isEmpty,
    );
    expect(
      (await repository.searchConversationMatches(
        tokens: const ['replacement'],
      )).single.messageId,
      'revision-1',
    );
  });

  test(
    'FTS uses message rows as external content instead of copying bodies',
    () async {
      final root = await Directory.systemTemp.createTemp('chat_search_fts_');
      final file = File('${root.path}/search.sqlite');
      final repository = ChatDatabaseRepository.open(file: file);
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Search',
        createdAt: DateTime.utc(2026, 7, 12),
        updatedAt: DateTime.utc(2026, 7, 12),
        messageIds: const ['revision-1'],
      );
      final message = ChatMessage(
        id: 'revision-1',
        role: 'user',
        content: 'body stored only in message rows',
        timestamp: DateTime.utc(2026, 7, 12),
        conversationId: conversation.id,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [(message: message, messageOrder: 0)],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      expect(
        await repository.searchConversationMatches(tokens: const ['stored']),
        isNotEmpty,
      );
      await repository.close();

      final database = sqlite.sqlite3.open(file.path);
      try {
        final sql = database
            .select(
              "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'message_search_fts';",
            )
            .single['sql']
            .toString();
        expect(sql, contains("content='message_rows'"));
        expect(sql, contains("content_rowid='rowid'"));
      } finally {
        database.close();
        await root.delete(recursive: true);
      }
    },
  );
}
