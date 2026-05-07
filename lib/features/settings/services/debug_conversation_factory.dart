import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';

class DebugConversationSeed {
  const DebugConversationSeed({
    required this.conversation,
    required this.messages,
    required this.totalContentBytes,
  });

  final Conversation conversation;
  final List<ChatMessage> messages;
  final int totalContentBytes;
}

class DebugConversationFactory {
  DebugConversationFactory._();

  static const int oversizedConversationBytes = 30 * 1024 * 1024;
  static const int manyMessagesCount = 1024;

  static DebugConversationSeed createOversizedConversation({
    required String title,
    required String? assistantId,
    required String chunkText,
    int targetBytes = oversizedConversationBytes,
  }) {
    if (targetBytes <= 0) {
      throw ArgumentError.value(targetBytes, 'targetBytes');
    }
    if (chunkText.isEmpty) {
      throw ArgumentError.value(chunkText, 'chunkText');
    }

    final conversation = Conversation(title: title, assistantId: assistantId);
    final messages = <ChatMessage>[];
    var totalBytes = 0;
    var index = 0;
    const uuid = Uuid();

    while (totalBytes < targetBytes) {
      final role = index.isEven ? 'user' : 'assistant';
      final messageId = uuid.v4();
      final content = _buildOversizedContent(
        chunkText: chunkText,
        index: index,
        role: role,
      );
      totalBytes += utf8.encode(content).length;
      messages.add(
        ChatMessage(
          id: messageId,
          role: role,
          content: content,
          conversationId: conversation.id,
          groupId: messageId,
        ),
      );
      index++;
    }

    conversation.messageIds
      ..clear()
      ..addAll(messages.map((message) => message.id));
    conversation.updatedAt = DateTime.now();

    return DebugConversationSeed(
      conversation: conversation,
      messages: messages,
      totalContentBytes: totalBytes,
    );
  }

  static DebugConversationSeed createManyMessagesConversation({
    required String title,
    required String? assistantId,
    required String Function(int index, String role) contentBuilder,
    int messageCount = manyMessagesCount,
  }) {
    if (messageCount <= 0) {
      throw ArgumentError.value(messageCount, 'messageCount');
    }

    final conversation = Conversation(title: title, assistantId: assistantId);
    final messages = <ChatMessage>[];
    var totalBytes = 0;
    const uuid = Uuid();

    for (var index = 0; index < messageCount; index++) {
      final role = index.isEven ? 'user' : 'assistant';
      final messageId = uuid.v4();
      final content = contentBuilder(index, role);
      totalBytes += utf8.encode(content).length;
      messages.add(
        ChatMessage(
          id: messageId,
          role: role,
          content: content,
          conversationId: conversation.id,
          groupId: messageId,
        ),
      );
    }

    conversation.messageIds
      ..clear()
      ..addAll(messages.map((message) => message.id));
    conversation.updatedAt = DateTime.now();

    return DebugConversationSeed(
      conversation: conversation,
      messages: messages,
      totalContentBytes: totalBytes,
    );
  }

  static String _buildOversizedContent({
    required String chunkText,
    required int index,
    required String role,
  }) {
    final buffer = StringBuffer()
      ..writeln('debug-message-index: $index')
      ..writeln('debug-message-role: $role');
    for (var block = 0; block < 128; block++) {
      buffer
        ..write(chunkText)
        ..write(' index=')
        ..write(index)
        ..write(' block=')
        ..write(block)
        ..write('\n');
    }
    return buffer.toString();
  }
}
