import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatDatabaseRepository deleteMessage', () {
    late Directory directory;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_delete_message_test_',
      );
      repository = ChatDatabaseRepository.open(
        file: File('${directory.path}/chat.sqlite'),
      );
      await repository.ensureReady();
    });

    tearDown(() async {
      await repository.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('takes the provider artifacts of the message with it', () async {
      final createdAt = DateTime.utc(2026, 8, 1);
      ChatMessage message(String id, String role, int minute) => ChatMessage(
        id: id,
        role: role,
        content: id,
        conversationId: 'topic',
        groupId: id,
        version: 0,
        timestamp: createdAt.add(Duration(minutes: minute)),
      );
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'topic',
            title: 'Topic',
            createdAt: createdAt,
            updatedAt: createdAt,
            messageIds: const ['u1', 'a1', 'u2', 'a2'],
          ),
        ],
        messages: [
          (message: message('u1', 'user', 0), messageOrder: 0),
          (message: message('a1', 'assistant', 1), messageOrder: 1),
          (message: message('u2', 'user', 2), messageOrder: 2),
          (message: message('a2', 'assistant', 3), messageOrder: 3),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.setProviderArtifact('a1', 'claude_turn', '[[]]');
      await repository.setProviderArtifact('a1', 'claude_container', '{}');
      await repository.setProviderArtifact('a2', 'claude_container', '{}');

      await repository.deleteMessage('a1');

      // Nothing reads an artifact whose message is gone, so the row goes too.
      for (final kind in ['claude_turn', 'claude_container']) {
        expect(
          await repository.getProviderArtifactsForMessages(['a1', 'a2'], kind),
          kind == 'claude_container' ? {'a2': '{}'} : isEmpty,
        );
      }
    });
  });
}
