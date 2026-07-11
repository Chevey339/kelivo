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

  test('deletes and compacts order in one transaction', () async {
    await repository.deleteMessage('message-1');

    expect(await repository.getMessageIds('conversation-1'), const [
      'message-0',
      'message-2',
    ]);
    await repository.putMessage(
      ChatMessage(
        id: 'message-3',
        role: 'assistant',
        content: 'content-3',
        conversationId: 'conversation-1',
        groupId: 'group-3',
      ),
    );
    expect(await repository.getMessageIds('conversation-1'), const [
      'message-0',
      'message-2',
      'message-3',
    ]);
  });
}
