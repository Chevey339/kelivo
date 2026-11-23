import 'dart:async';

enum ChatAction {
  newTopic,
  toggleLeftPanelAssistants,
  toggleLeftPanelTopics,
  focusInput,
  openHistory,
  switchModel,
  enterGlobalSearch,
  exitGlobalSearch,
}

sealed class CreationChatAction {
  const CreationChatAction();
}

final class PrefillChatImage extends CreationChatAction {
  const PrefillChatImage(this.path);
  final String path;
}

final class OpenCreationArtwork extends CreationChatAction {
  const OpenCreationArtwork(this.itemId);
  final String itemId;
}

final class OpenCreationConversation extends CreationChatAction {
  const OpenCreationConversation(this.conversationId, this.messageId);
  final String conversationId, messageId;
}

class ChatActionBus {
  ChatActionBus._();
  static final ChatActionBus instance = ChatActionBus._();

  final _controller = StreamController<ChatAction>.broadcast();
  final _creationController = StreamController<CreationChatAction>.broadcast();
  Stream<ChatAction> get stream => _controller.stream;
  Stream<CreationChatAction> get creationStream => _creationController.stream;
  void fire(ChatAction action) => _controller.add(action);
  void fireCreation(CreationChatAction action) =>
      _creationController.add(action);
  void dispose() {
    unawaited(_controller.close());
    unawaited(_creationController.close());
  }
}
