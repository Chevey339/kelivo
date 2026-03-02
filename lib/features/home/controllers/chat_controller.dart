import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/services/chat/chat_service.dart';

/// Controller for managing conversation state in the home page.
///
/// This controller handles:
/// - Current conversation and message list management
/// - Version selection for message groups
/// - Conversation loading states (for streaming)
/// - Conversation stream subscriptions
/// - Message grouping and collapsing logic
class ChatController extends ChangeNotifier {
  ChatController({required ChatService chatService})
    : _chatService = chatService;

  final ChatService _chatService;

  // ============================================================================
  // State Fields
  // ============================================================================

  /// The currently active conversation.
  Conversation? _currentConversation;
  Conversation? get currentConversation => _currentConversation;

  /// Messages in the current conversation.
  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  /// Selected version per message group (groupId -> selected version index).
  Map<String, int> _versionSelections = <String, int>{};
  Map<String, int> get versionSelections => _versionSelections;

  static const int _messagePageSize = 12;
  int _loadedMessageCount = 0;
  bool _hasMoreMessages = false;
  bool get hasMoreMessages => _hasMoreMessages;
  bool _isLoadingMoreMessages = false;
  bool get isLoadingMoreMessages => _isLoadingMoreMessages;

  /// Conversation IDs that are currently generating (streaming).
  final Set<String> _loadingConversationIds = <String>{};
  Set<String> get loadingConversationIds => _loadingConversationIds;

  /// Active stream subscriptions per conversation.
  final Map<String, StreamSubscription<dynamic>> _conversationStreams =
      <String, StreamSubscription<dynamic>>{};
  Map<String, StreamSubscription<dynamic>> get conversationStreams =>
      _conversationStreams;

  // ============================================================================
  // Getters
  // ============================================================================

  /// Whether the current conversation is actively generating.
  bool get isCurrentConversationLoading {
    final cid = _currentConversation?.id;
    if (cid == null) return false;
    return _loadingConversationIds.contains(cid);
  }

  /// Get the ChatService instance.
  ChatService get chatService => _chatService;

  // ============================================================================
  // Conversation Management
  // ============================================================================

  /// Set the current conversation and load its messages.
  void setCurrentConversation(Conversation? conversation) {
    _currentConversation = conversation;
    if (conversation != null) {
      _loadRecentMessages(conversation);
      _loadVersionSelections();
    } else {
      _messages = [];
      _versionSelections = <String, int>{};
      _loadedMessageCount = 0;
      _hasMoreMessages = false;
      _isLoadingMoreMessages = false;
    }
    notifyListeners();
  }

  void _loadRecentMessages(Conversation conversation) {
    final total = conversation.messageIds.length;
    final start = total > _messagePageSize ? total - _messagePageSize : 0;
    final ids = conversation.messageIds.sublist(start, total);
    _messages = List.of(_chatService.getMessagesByIds(ids));
    _loadedMessageCount = _messages.length;
    _hasMoreMessages = start > 0;
    _isLoadingMoreMessages = false;
  }

  Future<void> loadMoreMessages() async {
    final convo = _currentConversation;
    if (convo == null || _isLoadingMoreMessages || !_hasMoreMessages) return;

    _isLoadingMoreMessages = true;
    notifyListeners();

    try {
      final total = convo.messageIds.length;
      final currentlyLoaded = _messages.length;
      if (currentlyLoaded >= total) {
        _hasMoreMessages = false;
        return;
      }

      final nextLoaded = (currentlyLoaded + _messagePageSize > total)
          ? total
          : currentlyLoaded + _messagePageSize;
      final start = total - nextLoaded;
      final end = total - currentlyLoaded;
      if (start < end) {
        final olderIds = convo.messageIds.sublist(start, end);
        final olderMessages = _chatService.getMessagesByIds(olderIds);
        if (olderMessages.isNotEmpty) {
          _messages = <ChatMessage>[...olderMessages, ..._messages];
        }
      }

      _loadedMessageCount = _messages.length;
      _hasMoreMessages = nextLoaded < total;
    } finally {
      _isLoadingMoreMessages = false;
      notifyListeners();
    }
  }

  Future<void> loadAllMessages() async {
    final convo = _currentConversation;
    if (convo == null || _isLoadingMoreMessages) return;

    final total = convo.messageIds.length;
    if (_messages.length >= total && !_hasMoreMessages) return;

    _isLoadingMoreMessages = true;
    notifyListeners();

    try {
      _messages = List.of(_chatService.getMessages(convo.id));
      _loadedMessageCount = _messages.length;
      _hasMoreMessages = false;
    } finally {
      _isLoadingMoreMessages = false;
      notifyListeners();
    }
  }

  /// Update the current conversation reference (e.g., after title change).
  void updateCurrentConversation(Conversation? conversation) {
    _currentConversation = conversation;
    notifyListeners();
  }

  /// Load version selections for the current conversation.
  void _loadVersionSelections() {
    final cid = _currentConversation?.id;
    if (cid == null) {
      _versionSelections = <String, int>{};
      return;
    }
    try {
      _versionSelections = _chatService.getVersionSelections(cid);
    } catch (_) {
      _versionSelections = <String, int>{};
    }
  }

  /// Reload version selections (public method for external use).
  void loadVersionSelections() {
    _loadVersionSelections();
    notifyListeners();
  }

  /// Create a new conversation and set it as current.
  Future<Conversation> createNewConversation({
    required String title,
    String? assistantId,
  }) async {
    final conversation = await _chatService.createDraftConversation(
      title: title,
      assistantId: assistantId,
    );
    _currentConversation = conversation;
    _messages = [];
    _versionSelections.clear();
    _loadedMessageCount = 0;
    _hasMoreMessages = false;
    _isLoadingMoreMessages = false;
    notifyListeners();
    return conversation;
  }

  /// Switch to an existing conversation.
  Future<void> switchConversation(String id) async {
    if (_currentConversation?.id == id) return;

    _chatService.setCurrentConversation(id);
    final convo = _chatService.getConversation(id);
    if (convo != null) {
      _currentConversation = convo;
      _loadRecentMessages(convo);
      _loadVersionSelections();
      notifyListeners();
    }
  }

  /// Clear the current conversation state.
  void clearCurrentConversation() {
    _currentConversation = null;
    _messages = [];
    _versionSelections.clear();
    _loadedMessageCount = 0;
    _hasMoreMessages = false;
    _isLoadingMoreMessages = false;
    notifyListeners();
  }

  // ============================================================================
  // Message Management
  // ============================================================================

  /// Add a message to the current conversation.
  Future<ChatMessage> addMessage({
    required String role,
    required String content,
    String? modelId,
    String? providerId,
    bool isStreaming = false,
    String? groupId,
    int? version,
  }) async {
    if (_currentConversation == null) {
      throw StateError('No current conversation');
    }

    final message = await _chatService.addMessage(
      conversationId: _currentConversation!.id,
      role: role,
      content: content,
      modelId: modelId,
      providerId: providerId,
      isStreaming: isStreaming,
      groupId: groupId,
      version: version,
    );

    _messages.add(message);
    _loadedMessageCount = _messages.length;
    final total =
        _currentConversation?.messageIds.length ?? _loadedMessageCount;
    _hasMoreMessages = _loadedMessageCount < total;
    notifyListeners();
    return message;
  }

  /// Update a message in the list.
  void updateMessageInList(String messageId, ChatMessage updatedMessage) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = updatedMessage;
      notifyListeners();
    }
  }

  /// Update a message by ID with optional new values.
  Future<void> updateMessage(
    String messageId, {
    String? content,
    int? totalTokens,
    bool? isStreaming,
  }) async {
    await _chatService.updateMessage(
      messageId,
      content: content,
      totalTokens: totalTokens,
      isStreaming: isStreaming,
    );

    // Update in local list
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        content: content ?? _messages[index].content,
        totalTokens: totalTokens ?? _messages[index].totalTokens,
        isStreaming: isStreaming ?? _messages[index].isStreaming,
      );
      notifyListeners();
    }
  }

  /// Remove messages after a given index.
  void removeMessagesAfter(int index) {
    if (index < _messages.length - 1) {
      _messages = _messages.sublist(0, index + 1);
      notifyListeners();
    }
  }

  /// Remove specific message IDs from the list.
  void removeMessageIds(List<String> ids) {
    _messages.removeWhere((m) => ids.contains(m.id));
    notifyListeners();
  }

  /// Reload messages from storage.
  void reloadMessages() {
    if (_currentConversation == null) return;
    final convo =
        _chatService.getConversation(_currentConversation!.id) ??
        _currentConversation!;
    _currentConversation = convo;

    final total = convo.messageIds.length;
    if (total == 0) {
      _messages = [];
      _loadedMessageCount = 0;
      _hasMoreMessages = false;
      notifyListeners();
      return;
    }

    final desiredWindow = _messages.isNotEmpty
        ? _messages.length
        : (_loadedMessageCount > 0 ? _loadedMessageCount : _messagePageSize);
    final windowSize = desiredWindow > total ? total : desiredWindow;
    final start = total - windowSize;
    final ids = convo.messageIds.sublist(start, total);
    _messages = List.of(_chatService.getMessagesByIds(ids));
    _loadedMessageCount = _messages.length;
    _hasMoreMessages = start > 0;
    notifyListeners();
  }

  // ============================================================================
  // Version Selection
  // ============================================================================

  /// Get the selected version index for a message group.
  int getSelectedVersion(String groupId) {
    return _versionSelections[groupId] ?? -1;
  }

  /// Set the selected version for a message group.
  Future<void> setSelectedVersion(String groupId, int version) async {
    _versionSelections[groupId] = version;
    if (_currentConversation != null) {
      await _chatService.setSelectedVersion(
        _currentConversation!.id,
        groupId,
        version,
      );
    }
    notifyListeners();
  }

  /// Remove version selection for a group.
  void removeVersionSelection(String groupId) {
    _versionSelections.remove(groupId);
    notifyListeners();
  }

  // ============================================================================
  // Loading State Management
  // ============================================================================

  /// Check if a specific conversation is loading.
  bool isConversationLoading(String conversationId) {
    return _loadingConversationIds.contains(conversationId);
  }

  /// Set the loading state for a conversation.
  void setConversationLoading(String conversationId, bool loading) {
    final prev = _loadingConversationIds.contains(conversationId);
    if (loading) {
      _loadingConversationIds.add(conversationId);
    } else {
      _loadingConversationIds.remove(conversationId);
    }
    if (prev != loading) {
      notifyListeners();
    }
  }

  // ============================================================================
  // Stream Subscription Management
  // ============================================================================

  /// Get the stream subscription for a conversation.
  StreamSubscription<dynamic>? getStreamSubscription(String conversationId) {
    return _conversationStreams[conversationId];
  }

  /// Set a stream subscription for a conversation.
  void setStreamSubscription(
    String conversationId,
    StreamSubscription<dynamic> subscription,
  ) {
    _conversationStreams[conversationId] = subscription;
  }

  /// Cancel and remove a stream subscription.
  Future<void> cancelStreamSubscription(String conversationId) async {
    final sub = _conversationStreams.remove(conversationId);
    await sub?.cancel();
  }

  /// Cancel all stream subscriptions.
  Future<void> cancelAllStreams() async {
    for (final sub in _conversationStreams.values) {
      await sub.cancel();
    }
    _conversationStreams.clear();
  }

  // ============================================================================
  // Version Collapsing Logic
  // ============================================================================

  /// Collapse message versions to show only the selected version per group.
  ///
  /// This groups messages by their groupId and returns only the message
  /// at the selected version index for each group.
  List<ChatMessage> collapseVersions(List<ChatMessage> items) {
    final Map<String, List<ChatMessage>> byGroup =
        <String, List<ChatMessage>>{};
    final List<String> order = <String>[];

    for (final m in items) {
      final gid = (m.groupId ?? m.id);
      final list = byGroup.putIfAbsent(gid, () {
        order.add(gid);
        return <ChatMessage>[];
      });
      list.add(m);
    }

    // Sort each group by version
    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }

    // Select the appropriate version from each group
    final out = <ChatMessage>[];
    for (final gid in order) {
      final vers = byGroup[gid]!;
      final sel = _versionSelections[gid];
      final idx = (sel != null && sel >= 0 && sel < vers.length)
          ? sel
          : (vers.length - 1);
      out.add(vers[idx]);
    }

    return out;
  }

  /// Get messages collapsed by version (convenience method).
  List<ChatMessage> get collapsedMessages => collapseVersions(_messages);

  /// Group all messages by their groupId.
  Map<String, List<ChatMessage>> groupMessagesByGroup() {
    final Map<String, List<ChatMessage>> byGroup =
        <String, List<ChatMessage>>{};
    for (final m in _messages) {
      final gid = (m.groupId ?? m.id);
      byGroup.putIfAbsent(gid, () => <ChatMessage>[]).add(m);
    }
    return byGroup;
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  @override
  void dispose() {
    cancelAllStreams();
    super.dispose();
  }
}
