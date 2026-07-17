import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('ChatDatabaseRepository merge snapshot', () {
    late Directory directory;
    late ChatDatabaseRepository live;
    late ChatDatabaseRepository source;
    late File sourceFile;
    var sourceClosed = false;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('kelivo_merge_test_');
      live = ChatDatabaseRepository.open(
        file: File('${directory.path}/live.sqlite'),
      );
      sourceFile = File('${directory.path}/source.sqlite');
      source = ChatDatabaseRepository.open(file: sourceFile);
      sourceClosed = false;
      await live.ensureReady();
      await source.ensureReady();
    });

    tearDown(() async {
      await live.close();
      if (!sourceClosed) await source.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    Future<void> putConversation(
      ChatDatabaseRepository repository, {
      required String conversationId,
      required String title,
      required String messageId,
      required String content,
    }) {
      return repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: conversationId,
            title: title,
            messageIds: [messageId],
            mcpServerIds: const ['server'],
            versionSelections: {messageId: 0},
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: messageId,
              role: 'assistant',
              content: content,
              conversationId: conversationId,
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: {
          messageId: [
            {'id': 'tool', 'content': content},
          ],
        },
        geminiSignaturesByMessageId: {messageId: 'sig-$content'},
      );
    }

    test('无冲突 conversation 原 ID 导入且 order/关联数据完整', () async {
      await putConversation(
        source,
        conversationId: 'source-conversation',
        title: 'Source',
        messageId: 'source-message',
        content: 'answer',
      );
      await source.close();
      sourceClosed = true;

      final report = await live.mergeBackupSnapshot(sourceFile);

      expect(report.importedConversations, 1);
      expect(report.remappedConversations, 0);
      final conversation = await live.getConversation('source-conversation');
      expect(conversation?.messageIds, const ['source-message']);
      expect(
        (await live.getMessagesRange(
          'source-conversation',
          start: 0,
          limit: 10,
        )).single.content,
        'answer',
      );
      expect(await live.getToolEvents('source-message'), const [
        {'id': 'tool', 'content': 'answer'},
      ]);
      expect(
        await live.getGeminiThoughtSignature('source-message'),
        'sig-answer',
      );
    });

    test('相同 ID 与内容按 hash 去重，重复导入保持幂等', () async {
      for (final repository in [live, source]) {
        await putConversation(
          repository,
          conversationId: 'same-conversation',
          title: 'Same',
          messageId: 'same-message',
          content: 'same',
        );
      }
      await source.close();
      sourceClosed = true;

      final first = await live.mergeBackupSnapshot(sourceFile);
      final second = await live.mergeBackupSnapshot(sourceFile);

      expect(first.deduplicatedConversations, 1);
      expect(second.deduplicatedConversations, 1);
      expect(await live.getAllConversations(), hasLength(1));
    });

    test('同 conversation ID 异内容时整会话 remap 并可重复去重', () async {
      await putConversation(
        live,
        conversationId: 'collision',
        title: 'Local',
        messageId: 'local-message',
        content: 'local',
      );
      await putConversation(
        source,
        conversationId: 'collision',
        title: 'Imported',
        messageId: 'imported-message',
        content: 'imported',
      );
      await source.close();
      sourceClosed = true;

      final first = await live.mergeBackupSnapshot(sourceFile);
      final remappedId = first.remappedConversationIds['collision'];
      expect(remappedId, isNotNull);
      final remapped = await live.getConversation(remappedId!);
      expect(remapped?.title, 'Imported');
      expect(remapped?.messageIds.single, startsWith('merge-'));
      expect(remapped?.versionSelections.keys.single, startsWith('merge-'));
      expect(await live.getToolEvents(remapped!.messageIds.single), const [
        {'id': 'tool', 'content': 'imported'},
      ]);

      final second = await live.mergeBackupSnapshot(sourceFile);
      expect(second.importedConversations, 0);
      expect(second.deduplicatedConversations, 1);
      expect(await live.getAllConversations(), hasLength(2));
    });

    test('conversation ID 可用但 message ID 冲突时整会话 remap', () async {
      await putConversation(
        live,
        conversationId: 'local-conversation',
        title: 'Local',
        messageId: 'shared-message',
        content: 'local',
      );
      await putConversation(
        source,
        conversationId: 'source-conversation',
        title: 'Imported',
        messageId: 'shared-message',
        content: 'imported',
      );
      await source.close();
      sourceClosed = true;

      final report = await live.mergeBackupSnapshot(sourceFile);
      final remappedId = report.remappedConversationIds['source-conversation'];

      expect(remappedId, isNotNull);
      expect(await live.getConversation('source-conversation'), isNull);
      final remapped = await live.getConversation(remappedId!);
      expect(remapped?.messageIds.single, startsWith('merge-'));
      expect(
        (await live.getMessagesRange(
          remappedId,
          start: 0,
          limit: 1,
        )).single.content,
        'imported',
      );
    });

    test('非法 order 在事务写入前拒绝且 live 不变', () async {
      await putConversation(
        live,
        conversationId: 'local',
        title: 'Local',
        messageId: 'local-message',
        content: 'local',
      );
      await putConversation(
        source,
        conversationId: 'invalid',
        title: 'Invalid',
        messageId: 'invalid-message',
        content: 'invalid',
      );
      await source.close();
      sourceClosed = true;
      final raw = sqlite.sqlite3.open(sourceFile.path);
      try {
        raw.execute(
          'UPDATE message_rows SET message_order = 2 '
          "WHERE id = 'invalid-message';",
        );
      } finally {
        raw.close();
      }

      await expectLater(
        live.mergeBackupSnapshot(sourceFile),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'conversation_message_order',
          ),
        ),
      );

      expect(await live.getConversation('local'), isNotNull);
      expect(await live.getConversation('invalid'), isNull);
      expect(await live.getAllConversations(), hasLength(1));
    });
  });
}
