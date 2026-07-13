import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
  test(
    'linear window keeps a version group at its first row position',
    () async {
      final root = await Directory.systemTemp.createTemp('linear_window_test_');
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/chat.sqlite'),
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });

      final conversation = Conversation(
        id: 'conversation',
        title: 'Linear',
        versionSelections: const {'answer': 1},
      );
      final messages = <ChatMessage>[
        ChatMessage(
          id: 'user',
          role: 'user',
          content: 'question',
          conversationId: conversation.id,
        ),
        ChatMessage(
          id: 'answer-v0',
          role: 'assistant',
          content: 'old answer',
          conversationId: conversation.id,
          groupId: 'answer',
          version: 0,
        ),
        ChatMessage(
          id: 'later-user',
          role: 'user',
          content: 'later question',
          conversationId: conversation.id,
        ),
        ChatMessage(
          id: 'answer-v1',
          role: 'assistant',
          content: 'new answer',
          conversationId: conversation.id,
          groupId: 'answer',
          version: 1,
        ),
      ];
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [
          for (final (index, message) in messages.indexed)
            (message: message, messageOrder: index),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final window = await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        limit: 20,
      );

      expect(window.totalSlotCount, 3);
      expect(window.slots.map((slot) => slot.revisionId), [
        'user',
        'answer-v1',
        'later-user',
      ]);
      expect(window.slots[1].logicalIndex, 1);
      expect(window.slots[1].versionCount, 2);

      final aroundSibling = await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        aroundRevisionId: 'answer-v0',
        limit: 1,
      );
      expect(aroundSibling.slots.single.revisionId, 'answer-v1');

      final before = await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        beforeRevisionId: 'later-user',
        limit: 20,
      );
      expect(before.slots.map((slot) => slot.revisionId), [
        'user',
        'answer-v1',
      ]);

      final after = await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        afterRevisionId: 'answer-v0',
        limit: 20,
      );
      expect(after.slots.map((slot) => slot.revisionId), ['later-user']);
    },
  );
}
