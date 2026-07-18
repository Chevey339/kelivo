import '../../../core/models/chat_message.dart';

/// Keeps generation identity independent from the currently loaded timeline.
class ActiveStreamingMessageStore {
  final Map<String, ChatMessage> _messagesById = <String, ChatMessage>{};
  final Map<String, List<String>> _messageIdsByConversation =
      <String, List<String>>{};

  ChatMessage? operator [](String conversationId) {
    final ids = _messageIdsByConversation[conversationId];
    if (ids == null || ids.isEmpty) return null;
    return _messagesById[ids.last];
  }

  void put(ChatMessage message) {
    _messagesById[message.id] = message;
    final ids = _messageIdsByConversation.putIfAbsent(
      message.conversationId,
      () => <String>[],
    );
    if (!ids.contains(message.id)) ids.add(message.id);
  }

  bool isActive(ChatMessage message) {
    return _messagesById.containsKey(message.id);
  }

  bool hasActiveConversation(String conversationId) =>
      _messageIdsByConversation[conversationId]?.isNotEmpty ?? false;

  List<ChatMessage> activeMessages(String conversationId) =>
      List<ChatMessage>.unmodifiable(
        (_messageIdsByConversation[conversationId] ?? const <String>[])
            .map((id) => _messagesById[id])
            .whereType<ChatMessage>(),
      );

  ChatMessage? cancellationTarget(
    String conversationId,
    List<ChatMessage> loadedMessages,
    Map<String, int> versionSelections,
  ) {
    final active = activeMessages(conversationId);
    if (active.isNotEmpty) {
      final groups = <String>{
        for (final message in active) message.groupId ?? message.id,
      };
      for (final groupId in groups) {
        final selectedVersion = versionSelections[groupId];
        if (selectedVersion == null) continue;
        for (final message in active) {
          if ((message.groupId ?? message.id) == groupId &&
              message.version == selectedVersion) {
            return message;
          }
        }
        // The selected sibling is terminal. Do not silently stop a different
        // model; the user can switch to an answer that is still generating.
        return null;
      }
      return active.last;
    }
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
    if (_messagesById.remove(message.id) == null) return;
    final ids = _messageIdsByConversation[message.conversationId];
    ids?.remove(message.id);
    if (ids?.isEmpty ?? false) {
      _messageIdsByConversation.remove(message.conversationId);
    }
  }
}
