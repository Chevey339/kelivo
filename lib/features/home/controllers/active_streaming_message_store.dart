import '../../../core/models/chat_message.dart';

/// Keeps generation identity independent from the currently loaded timeline.
class ActiveStreamingMessageStore {
  final Map<String, ChatMessage> _messagesByConversation =
      <String, ChatMessage>{};

  ChatMessage? operator [](String conversationId) {
    return _messagesByConversation[conversationId];
  }

  void put(ChatMessage message) {
    _messagesByConversation[message.conversationId] = message;
  }

  bool isActive(ChatMessage message) {
    return _messagesByConversation[message.conversationId]?.id == message.id;
  }

  ChatMessage? cancellationTarget(
    String conversationId,
    List<ChatMessage> loadedMessages,
  ) {
    final active = _messagesByConversation[conversationId];
    if (active != null) return active;
    for (var index = loadedMessages.length - 1; index >= 0; index--) {
      final message = loadedMessages[index];
      if (message.conversationId == conversationId &&
          message.role == 'assistant' &&
          message.isStreaming) {
        return message;
      }
    }
    return null;
  }

  void removeIfMatches(ChatMessage message) {
    if (_messagesByConversation[message.conversationId]?.id == message.id) {
      _messagesByConversation.remove(message.conversationId);
    }
  }
}
