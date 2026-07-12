import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
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
    await repository.backfillMissingMessageGraphs();

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
}
