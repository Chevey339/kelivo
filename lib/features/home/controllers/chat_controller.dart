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

  /// Cached collapsed messages (invalidated on notifyListeners).
  List<ChatMessage>? _collapsedCache;
  Map<String, int>? _collapsedIdToIndex;
  Map<String, List<ChatMessage>>? _groupCache;

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

  /// Lazily migrate parentId for messages that don't have one yet.
  /// Should be called before operations that depend on tree structure
  /// (e.g., regenerate, send). Uses flat collapseVersions as the
  /// reference order for building the parentId chain.
  Future<void> ensureParentIdsMigrated() async {
    if (_messages.isEmpty) return;
    if (!_messages.any((m) => m.parentId == null)) return;

    final migrated = await _chatService.migrateParentIds(
      messages: _messages,
      versionSelections: _versionSelections,
      collapseVersions: (items, selections) {
        // Use flat collapse for migration (before tree structure exists)
        return _collapseVersionsFlat(items);
      },
    );
    if (migrated) {
      // Reload messages from storage to get updated parentIds
      final cid = _currentConversation?.id;
      if (cid != null) {
        _messages = List.of(_chatService.getMessages(cid));
        invalidateCache();
      }
    }
  }

  // ============================================================================
  // Conversation Management
  // ============================================================================

  /// Set the current conversation and load its messages.
  void setCurrentConversation(Conversation? conversation) {
    _currentConversation = conversation;
    if (conversation != null) {
      _messages = List.of(_chatService.getMessages(conversation.id));
      _loadVersionSelections();
    } else {
      _messages = [];
      _versionSelections = <String, int>{};
    }
    notifyListeners();
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
      _messages = List.of(_chatService.getMessages(id));
      _loadVersionSelections();
      notifyListeners();
    }
  }

  /// Clear the current conversation state.
  void clearCurrentConversation() {
    _currentConversation = null;
    _messages = [];
    _versionSelections.clear();
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
    _messages = List.of(_chatService.getMessages(_currentConversation!.id));
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
  /// When messages have parentId set (tree structure), uses tree traversal
  /// to follow the active branch. Falls back to flat order for legacy
  /// messages where all parentIds are null.
  List<ChatMessage> collapseVersions(List<ChatMessage> items) {
    if (items.isEmpty) return <ChatMessage>[];

    final hasTree = items.any((m) => m.parentId != null);
    if (!hasTree) {
      return _collapseVersionsFlat(items);
    }
    return _collapseVersionsTree(items);
  }

  List<ChatMessage> _collapseVersionsFlat(List<ChatMessage> items) {
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

    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }

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

  List<ChatMessage> _collapseVersionsTree(List<ChatMessage> items) {
    final Map<String, List<ChatMessage>> byGroup =
        <String, List<ChatMessage>>{};
    for (final m in items) {
      final gid = (m.groupId ?? m.id);
      byGroup.putIfAbsent(gid, () => <ChatMessage>[]).add(m);
    }
    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }

    ChatMessage selectFromGroup(List<ChatMessage> vers) {
      final gid = vers.first.groupId ?? vers.first.id;
      final sel = _versionSelections[gid];
      final idx = (sel != null && sel >= 0 && sel < vers.length)
          ? sel
          : (vers.length - 1);
      return vers[idx];
    }

    final Map<String, Set<String>> childGroupsByParent =
        <String, Set<String>>{};
    for (final entry in byGroup.entries) {
      for (final m in entry.value) {
        final parentId = m.parentId;
        if (parentId != null && parentId.isNotEmpty) {
          childGroupsByParent
              .putIfAbsent(parentId, () => <String>{})
              .add(entry.key);
        }
      }
    }

    final rootGroups = <String>[];
    for (final entry in byGroup.entries) {
      final parentId = entry.value.first.parentId;
      if (parentId == null || parentId.isEmpty) {
        rootGroups.add(entry.key);
      }
    }

    final Map<String, int> groupFirstIndex = <String, int>{};
    for (int i = 0; i < items.length; i++) {
      final gid = items[i].groupId ?? items[i].id;
      groupFirstIndex.putIfAbsent(gid, () => i);
    }
    rootGroups.sort(
      (a, b) => (groupFirstIndex[a] ?? 0).compareTo(groupFirstIndex[b] ?? 0),
    );

    final out = <ChatMessage>[];
    final visited = <String>{};

    void traverse(String groupId) {
      if (visited.contains(groupId)) return;
      visited.add(groupId);

      final vers = byGroup[groupId];
      if (vers == null || vers.isEmpty) return;

      final selected = selectFromGroup(vers);
      out.add(selected);

      // Find child groups that point to this selected message
      var childGids = childGroupsByParent[selected.id];

      // For user messages with multiple versions: if the selected version has
      // no children yet (e.g., "save only" edit before retry), fall back to
      // another version's children so the conversation remains visible.
      if ((childGids == null || childGids.isEmpty) &&
          selected.role == 'user' &&
          vers.length > 1) {
        for (final v in vers) {
          if (v.id == selected.id) continue;
          final cg = childGroupsByParent[v.id];
          if (cg != null && cg.isNotEmpty) {
            childGids = cg;
            break;
          }
        }
      }

      if (childGids == null || childGids.isEmpty) return;

      final sortedChildren = childGids.toList()
        ..sort(
          (a, b) =>
              (groupFirstIndex[a] ?? 0).compareTo(groupFirstIndex[b] ?? 0),
        );

      for (final childGid in sortedChildren) {
        traverse(childGid);
      }
    }

    for (final rootGid in rootGroups) {
      traverse(rootGid);
    }

    return out;
  }

  /// Get messages collapsed by version (cached).
  List<ChatMessage> get collapsedMessages {
    if (_collapsedCache != null) return _collapsedCache!;
    _collapsedCache = collapseVersions(_messages);
    _collapsedIdToIndex = <String, int>{};
    for (int i = 0; i < _collapsedCache!.length; i++) {
      _collapsedIdToIndex![_collapsedCache![i].id] = i;
    }
    return _collapsedCache!;
  }

  /// O(1) lookup of a message's index in the collapsed list.
  int indexOfCollapsedMessageId(String id) {
    collapsedMessages; // ensure cache is built
    return _collapsedIdToIndex?[id] ?? -1;
  }

  /// Get messages grouped by groupId (cached).
  Map<String, List<ChatMessage>> get groupedMessages {
    return _groupCache ??= groupMessagesByGroup();
  }

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
  // Cache Invalidation
  // ============================================================================

  /// Invalidate collapsed/grouped caches without firing listeners.
  ///
  /// Call this when _messages is mutated externally (e.g. by ChatActions)
  /// and the caller will fire its own notifyListeners().
  void invalidateCache() {
    _collapsedCache = null;
    _collapsedIdToIndex = null;
    _groupCache = null;
  }

  @override
  void notifyListeners() {
    invalidateCache();
    super.notifyListeners();
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
