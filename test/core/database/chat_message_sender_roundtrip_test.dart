import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';

void main() {
  test('reply identity survives updates, reopening and JSON export', () async {
    final root = await Directory.systemTemp.createTemp('sender_roundtrip_');
    final file = File('${root.path}/chat.sqlite');
    var repository = ChatDatabaseRepository.open(file: file);
    try {
      await repository.ensureReady();
      await repository.putConversation(Conversation(id: 'chat', title: 'Chat'));
      final reply = ChatMessage(
        id: 'reply',
        role: 'assistant',
        conversationId: 'chat',
        content: 'Hello',
        senderId: 'assistant-b',
        senderName: 'Reviewer',
        senderAvatar: 'https://example.com/reviewer.png',
      );
      await repository.putMessage(reply);
      await repository.updateMessage(reply.copyWith(content: 'Reviewed'));
      await repository.close();
      repository = ChatDatabaseRepository.open(file: file);
      await repository.ensureReady();
      final restored = (await repository.getMessage('reply'))!;
      final exported = ChatMessage.fromJson(restored.toJson());
      expect(exported.content, 'Reviewed');
      expect(exported.senderId, 'assistant-b');
      expect(exported.senderName, 'Reviewer');
      expect(exported.senderAvatar, 'https://example.com/reviewer.png');
      final edited = await repository.appendMessageVersion(
        messageId: 'reply',
        content: 'Edited',
      );
      expect(edited!.message.senderId, 'assistant-b');
      expect(edited.message.senderName, 'Reviewer');
      expect(edited.message.senderAvatar, 'https://example.com/reviewer.png');
    } finally {
      await repository.close();
      await root.delete(recursive: true);
    }
  });
}
