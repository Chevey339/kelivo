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

  test(
    'append version selects it without moving or deleting later groups',
    () async {
      final root = await Directory.systemTemp.createTemp('linear_edit_test_');
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/chat.sqlite'),
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });

      final conversation = Conversation(id: 'conversation', title: 'Linear');
      final original = ChatMessage(
        id: 'answer-v0',
        role: 'assistant',
        content: 'old answer',
        conversationId: conversation.id,
      );
      final later = ChatMessage(
        id: 'later-user',
        role: 'user',
        content: 'later question',
        conversationId: conversation.id,
      );
      await repository.putMigrationBatch(
        conversations: [conversation],
        messages: [
          (message: original, messageOrder: 4),
          (message: later, messageOrder: 9),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );

      final appended = await repository.appendMessageVersion(
        messageId: original.id,
        content: 'new answer',
      );
      final window = await repository.loadLinearMessageWindow(
        conversationId: conversation.id,
        fromStart: true,
      );

      expect(appended, isNotNull);
      expect(appended!.message.version, 1);
      expect(appended.conversation.versionSelections, {original.id: 1});
      expect(window.slots.map((slot) => slot.revisionId), [
        appended.message.id,
        later.id,
      ]);
      expect(await repository.getMessageIndex(conversation.id, later.id), 9);
    },
  );

  test(
    'context query collapses versions before truncate and tail limit',
    () async {
      final root = await Directory.systemTemp.createTemp('context_tail_test_');
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/chat.sqlite'),
      );
      addTearDown(() async {
        await repository.close();
        await root.delete(recursive: true);
      });

      final conversation = Conversation(
        id: 'conversation',
        title: 'Context',
        truncateIndex: 1,
        versionSelections: const {'answer': 0},
      );
      final messages = <ChatMessage>[
        ChatMessage(
          id: 'user-0',
          role: 'user',
          content: 'ignored prefix',
          conversationId: conversation.id,
        ),
        ChatMessage(
          id: 'answer-v0',
          role: 'assistant',
          content: 'selected answer',
          reasoningText: 'selected reasoning',
          conversationId: conversation.id,
          groupId: 'answer',
          version: 0,
        ),
        ChatMessage(
          id: 'user-1',
          role: 'user',
          content: 'middle',
          conversationId: conversation.id,
        ),
        ChatMessage(
          id: 'answer-v1',
          role: 'assistant',
          content: 'unselected answer',
          conversationId: conversation.id,
          groupId: 'answer',
          version: 1,
        ),
        ChatMessage(
          id: 'assistant-tail',
          role: 'assistant',
          content: 'tail',
          conversationId: conversation.id,
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

      final complete = await repository.getSelectedContextMessages(
        conversation.id,
        truncateIndex: conversation.truncateIndex,
        limit: 10,
      );
      final bounded = await repository.getSelectedContextMessages(
        conversation.id,
        truncateIndex: conversation.truncateIndex,
        limit: 2,
      );
      final throughUser = await repository.getSelectedContextMessages(
        conversation.id,
        truncateIndex: -1,
        limit: 10,
        throughRevisionId: 'user-1',
        includeFollowingAssistant: true,
      );
      final projections = await repository.getSelectedMessageProjections(
        conversation.id,
        summaryCharacters: 8,
      );

      expect(complete.map((message) => message.id), [
        'answer-v0',
        'user-1',
        'assistant-tail',
      ]);
      expect(complete.first.content, 'selected answer');
      expect(complete.first.reasoningText, 'selected reasoning');
      expect(bounded.map((message) => message.id), [
        'user-1',
        'assistant-tail',
      ]);
      expect(throughUser.map((message) => message.id), [
        'user-0',
        'answer-v0',
        'user-1',
        'assistant-tail',
      ]);
      expect(projections.map((message) => message.id), [
        'user-0',
        'answer-v0',
        'user-1',
        'assistant-tail',
      ]);
      expect(projections.first.content, 'ignored ');
    },
  );
}
