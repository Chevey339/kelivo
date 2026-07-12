import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/portable_ndjson_v2.dart';

void main() {
  group('PortableNdjsonV2', () {
    late Directory root;
    late ChatDatabaseRepository source;
    late ChatDatabaseRepository target;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('portable_ndjson_v2_test_');
      source = ChatDatabaseRepository.open(
        file: File('${root.path}/source.sqlite'),
      );
      target = ChatDatabaseRepository.open(
        file: File('${root.path}/target.sqlite'),
      );
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Portable',
        createdAt: DateTime.utc(2026, 7, 12),
        updatedAt: DateTime.utc(2026, 7, 12),
        messageIds: const ['user-1', 'assistant-1'],
      );
      final messages = [
        ChatMessage(
          id: 'user-1',
          role: 'user',
          content: 'hello',
          timestamp: DateTime.utc(2026, 7, 12),
          conversationId: conversation.id,
          groupId: 'user-slot',
          version: 1,
        ),
        ChatMessage(
          id: 'assistant-1',
          role: 'assistant',
          content: 'world',
          timestamp: DateTime.utc(2026, 7, 12, 0, 0, 1),
          conversationId: conversation.id,
          groupId: 'assistant-slot',
          version: 1,
        ),
      ];
      await source.putMigrationBatch(
        conversations: [conversation],
        messages: [
          for (final (index, message) in messages.indexed)
            (message: message, messageOrder: index),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await source.backfillMissingMessageGraphs();
    });

    tearDown(() async {
      await source.close();
      await target.close();
      await root.delete(recursive: true);
    });

    test(
      'active portable export round-trips through transactional merge',
      () async {
        final file = File('${root.path}/portable.ndjson');
        final exported = await PortableNdjsonV2.exportToFile(
          repository: source,
          destination: file,
        );

        expect(exported.conversations, 1);
        expect(exported.messages, 2);
        final lines = await file.readAsLines();
        expect(jsonDecode(lines.first)['format'], 'kelivo-portable-chat');
        expect(jsonDecode(lines.last)['recordsSha256'], exported.sha256);

        final report = await PortableNdjsonV2.importFromFile(
          target: target,
          source: file,
        );
        expect(report.importedConversations, 1);
        expect(await target.getConversation('conversation-1'), isNotNull);
        expect(
          (await target.getMessagesRange(
            'conversation-1',
            start: 0,
            limit: 10,
          )).map((message) => message.content),
          ['hello', 'world'],
        );
      },
    );

    test('rejects tampering before merging any conversation', () async {
      final file = File('${root.path}/tampered.ndjson');
      await PortableNdjsonV2.exportToFile(
        repository: source,
        destination: file,
        scope: PortableChatScope.allRevisions,
      );
      final text = await file.readAsString();
      await file.writeAsString(text.replaceFirst('world', 'tampered'));

      await expectLater(
        PortableNdjsonV2.importFromFile(target: target, source: file),
        throwsA(isA<FormatException>()),
      );
      expect(await target.getAllConversations(), isEmpty);
    });
  });
}
