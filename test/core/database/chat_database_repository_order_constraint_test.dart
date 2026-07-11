import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late ChatDatabaseRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_order_test_');
    repository = ChatDatabaseRepository.open(
      file: File('${directory.path}/chat.sqlite'),
    );
    await repository.ensureReady();
    await repository.putMigrationBatch(
      conversations: [
        Conversation(
          id: 'conversation-1',
          title: 'Conversation',
          messageIds: const ['message-0', 'message-1', 'message-2'],
        ),
      ],
      messages: [
        for (var index = 0; index < 3; index++)
          (
            message: ChatMessage(
              id: 'message-$index',
              role: index.isEven ? 'user' : 'assistant',
              content: 'content-$index',
              conversationId: 'conversation-1',
              groupId: 'group-$index',
            ),
            messageOrder: index,
          ),
      ],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'reorders existing messages without transient UNIQUE conflicts',
    () async {
      await repository.updateMessageOrder('conversation-1', const [
        'message-2',
        'message-1',
        'message-0',
      ]);

      expect(await repository.getMessageIds('conversation-1'), const [
        'message-2',
        'message-1',
        'message-0',
      ]);
    },
  );

  test(
    'graph deletion leaves sparse physical order without compaction',
    () async {
      await repository.clearAllData();
      var conversation = Conversation(id: 'graph-conversation', title: 'Graph');
      final original = ChatMessage(
        id: 'assistant-v0',
        role: 'assistant',
        content: 'v0',
        conversationId: conversation.id,
        groupId: 'assistant-slot',
        version: 0,
      );
      conversation = await repository.appendGraphMessageToConversation(
        conversation: conversation,
        message: original,
      );
      final alternate = ChatMessage(
        id: 'assistant-v1',
        role: 'assistant',
        content: 'v1',
        conversationId: conversation.id,
        groupId: 'assistant-slot',
        version: 1,
      );
      conversation = await repository.appendGraphMessageToConversation(
        conversation: conversation,
        message: alternate,
        selectVersion: true,
      );
      await repository.selectMessageGraphRevision(
        conversationId: conversation.id,
        revisionId: original.id,
      );
      final tail = ChatMessage(
        id: 'user-tail',
        role: 'user',
        content: 'tail',
        conversationId: conversation.id,
      );
      await repository.appendGraphMessageToConversation(
        conversation: conversation,
        message: tail,
      );

      await repository.deleteGraphMessages(
        conversationId: conversation.id,
        revisionIds: {alternate.id},
      );

      expect(await repository.getMessageIds(conversation.id), [
        original.id,
        tail.id,
      ]);
      expect(await repository.getMessageIndex(conversation.id, tail.id), 2);
    },
  );
}
