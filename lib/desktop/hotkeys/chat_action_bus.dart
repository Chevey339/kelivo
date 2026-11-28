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

sealed class ChatNavigationAction {
  const ChatNavigationAction();
}

final class PrefillChatImage extends ChatNavigationAction {
  const PrefillChatImage(this.path);
  final String path;
}

final class OpenCreationArtwork extends ChatNavigationAction {
  const OpenCreationArtwork(this.itemId);
  final String itemId;
}

final class OpenConversationMessage extends ChatNavigationAction {
  const OpenConversationMessage(
    this.conversationId,
    this.messageId, {
    this.selectVersion = false,
  });
  final bool selectVersion;
  final String conversationId, messageId;
}

class ChatActionBus {
  ChatActionBus._();
  static final ChatActionBus instance = ChatActionBus._();

  final _controller = StreamController<ChatAction>.broadcast();
  final _navigationController =
      StreamController<ChatNavigationAction>.broadcast();
  Stream<ChatAction> get stream => _controller.stream;
  Stream<ChatNavigationAction> get navigationStream =>
      _navigationController.stream;
  void fire(ChatAction action) => _controller.add(action);
  void fireNavigation(ChatNavigationAction action) =>
      _navigationController.add(action);
  void dispose() {
    unawaited(_controller.close());
    unawaited(_navigationController.close());
  }
}
