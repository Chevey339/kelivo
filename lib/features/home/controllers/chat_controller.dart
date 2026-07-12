import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/database/message_graph_projector.dart';
import 'timeline_coordinator.dart';
import 'message_render_model.dart';

/// Controller for managing conversation state in the home page.
///
/// This controller handles:
/// - Current conversation and message list management
/// - Version selection for message groups
/// - Conversation loading states (for streaming)
/// - Conversation stream subscriptions
/// - Message grouping and collapsing logic
class ChatController extends ChangeNotifier {
  factory ChatController({required ChatService chatService}) {
    return ChatController._(chatService);
  }

  ChatController._(this._chatService) {
    timelineCoordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) => _chatService.loadTimelinePage(
            conversationId,
            beforeRevisionId: beforeRevisionId,
            afterRevisionId: afterRevisionId,
            fromStart: fromStart ?? false,
            limit: limit,
          ),
      retainWindow: _chatService.retainTimelineWindow,
    );
    timelineCoordinator.addListener(_syncTimelineWindow);
    _chatService.addListener(_syncCurrentConversationWithService);
  }

  final ChatService _chatService;
  late final TimelineCoordinator timelineCoordinator;

  // ============================================================================
  // State Fields
  // ============================================================================

  /// The currently active conversation.
  Conversation? _currentConversation;
  Conversation? get currentConversation => _currentConversation;

  /// Messages in the current conversation.
  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  /// Index in the persisted conversation where [_messages] starts.
  int _loadedStartIndex = 0;
  int get loadedStartIndex => _loadedStartIndex;

  /// Total persisted message count for the current conversation.
  int _totalMessageCount = 0;
  int get totalMessageCount => _totalMessageCount;

  bool get hasMoreBefore =>
      timelineCoordinator.conversationId == _currentConversation?.id
      ? timelineCoordinator.hasMoreBefore
      : _loadedStartIndex > 0;
  bool get hasMoreAfter =>
      timelineCoordinator.conversationId == _currentConversation?.id
      ? timelineCoordinator.hasMoreAfter
      : _loadedStartIndex + _messages.length < _totalMessageCount;

  /// Selected version per message group (groupId -> selected version index).
  Map<String, int> _versionSelections = <String, int>{};
  Map<String, int> get versionSelections => _versionSelections;

  /// Cached collapsed messages (invalidated on notifyListeners).
  List<ChatMessage>? _collapsedCache;
  Map<String, int>? _collapsedIdToIndex;
  Map<String, List<ChatMessage>>? _groupCache;
  List<ChatMessage>? _messagesWithVisibleGroupsCache;
  List<MessageRenderModel>? _renderModelsCache;

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

  void _syncCurrentConversationWithService() {
    final conversation = _currentConversation;
    if (conversation == null) return;
    if (_chatService.getConversation(conversation.id) != null) return;
    _clearCurrentConversationState();
    notifyListeners();
  }

  void _syncTimelineWindow() {
    if (timelineCoordinator.conversationId != _currentConversation?.id) return;
    _messages = timelineCoordinator.slots
        .map((slot) => slot.message)
        .toList(growable: true);
    _totalMessageCount = timelineCoordinator.totalSlotCount;
    _loadedStartIndex = timelineCoordinator.slots.isEmpty
        ? 0
        : timelineCoordinator.slots.first.identity.logicalIndex;
    invalidateCache();
    notifyListeners();
  }

  // ============================================================================
  // Conversation Management
  // ============================================================================

  /// Set the current conversation and load its messages.
  void setCurrentConversation(Conversation? conversation) {
    _currentConversation = conversation;
    if (conversation != null) {
      _loadVersionSelections();
      _loadCachedInitialMessageWindow(conversation.id);
    } else {
      timelineCoordinator.clear();
      _messages = [];
      _loadedStartIndex = 0;
      _totalMessageCount = 0;
      _versionSelections = <String, int>{};
    }
    notifyListeners();
  }

  Future<void> setCurrentConversationAndLoad(Conversation? conversation) async {
    _currentConversation = conversation;
    if (conversation == null) {
      timelineCoordinator.clear();
      _messages = [];
      _loadedStartIndex = 0;
      _totalMessageCount = 0;
      _versionSelections = <String, int>{};
    } else {
      await _loadInitialMessageWindow(conversation.id);
      _loadVersionSelections();
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
    timelineCoordinator.clear();
    _messages = [];
    _loadedStartIndex = 0;
    _totalMessageCount = 0;
    _versionSelections = <String, int>{};
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
      await _loadInitialMessageWindow(id);
      _loadVersionSelections();
      notifyListeners();
    }
  }

  /// Clear the current conversation state.
  void clearCurrentConversation() {
    _clearCurrentConversationState();
    notifyListeners();
  }

  void _clearCurrentConversationState() {
    timelineCoordinator.clear();
    _currentConversation = null;
    _messages = [];
    _loadedStartIndex = 0;
    _totalMessageCount = 0;
    _versionSelections = <String, int>{};
  }

  Future<void> _loadInitialMessageWindow(String conversationId) async {
    await timelineCoordinator.open(
      conversationId,
      limit: ChatService.defaultTimelineInitialSlots,
    );
    for (final slot in timelineCoordinator.slots.reversed) {
      if (slot.message.role != 'user') continue;
      timelineCoordinator.programmaticJump(slot.identity.slotId);
      break;
    }
    invalidateCache();
    await _preloadVisibleGroupData();
    await _ensureLoadedWindowHasVisibleMessages();
  }

  void _loadCachedInitialMessageWindow(String conversationId) {
    _totalMessageCount = _chatService.getMessageCount(conversationId);
    _messages = List.of(_chatService.getRecentMessages(conversationId));
    _loadedStartIndex = (_totalMessageCount - _messages.length)
        .clamp(0, _totalMessageCount)
        .toInt();
    _seedTimelineFromMessages();
  }

  void refreshLoadedMessageCount() {
    final conversation = _currentConversation;
    if (conversation == null) {
      _totalMessageCount = 0;
      _loadedStartIndex = 0;
      return;
    }
    _totalMessageCount = _chatService.getMessageCount(conversation.id);
    _loadedStartIndex = _loadedStartIndex.clamp(0, _totalMessageCount).toInt();
  }

  Future<bool> loadMoreBefore({
    int limit = ChatService.defaultHistoryPageSize,
  }) async {
    if (limit <= 0) return false;
    final loaded = await timelineCoordinator.loadBefore(limit: limit);
    if (!loaded) return false;
    await _preloadVisibleGroupData();
    return true;
  }

  Future<bool> loadMoreAfter({
    int limit = ChatService.defaultHistoryPageSize,
  }) async {
    if (limit <= 0) return false;
    final loaded = await timelineCoordinator.loadAfter(limit: limit);
    if (!loaded) return false;
    await _preloadVisibleGroupData();
    final fallbackLoaded = await _ensureLoadedWindowHasVisibleMessages();
    if (fallbackLoaded) return true;
    notifyListeners();
    return true;
  }

  Future<bool> loadStartWindow() async {
    final conversation = _currentConversation;
    if (conversation == null) return false;
    await timelineCoordinator.openStart(
      conversation.id,
      limit: ChatService.defaultLoadedWindowMax,
    );
    await _preloadVisibleGroupData();
    return _messages.isNotEmpty;
  }

  Future<bool> loadEndWindow() async {
    final conversation = _currentConversation;
    if (conversation == null) return false;
    await timelineCoordinator.open(
      conversation.id,
      limit: ChatService.defaultLoadedWindowMax,
    );
    timelineCoordinator.followTail();
    await _preloadVisibleGroupData();
    return _messages.isNotEmpty;
  }

  Future<bool> loadUntilMessageVisible(
    String messageId, {
    int pageSize = ChatService.defaultHistoryPageSize,
    int maxPages = 256,
  }) async {
    if (_messages.any((message) => message.id == messageId)) return true;

    final loaded = await loadWindowAroundMessage(
      messageId,
      leadingContext: pageSize,
    );
    return loaded && _messages.any((message) => message.id == messageId);
  }

  Future<bool> loadWindowAroundMessage(
    String messageId, {
    int leadingContext = ChatService.defaultHistoryPageSize,
  }) async {
    final conversation = _currentConversation;
    if (conversation == null) return false;

    final targetIndex = _chatService.getMessageIndex(
      conversation.id,
      messageId,
    );
    if (targetIndex < 0) return false;

    return _loadWindowAroundIndex(targetIndex, leadingContext: leadingContext);
  }

  Future<bool> _loadWindowAroundIndex(
    int targetIndex, {
    int leadingContext = ChatService.defaultHistoryPageSize,
    bool ensureVisible = true,
  }) async {
    final conversation = _currentConversation;
    if (conversation == null || targetIndex < 0) return false;

    _totalMessageCount = _chatService.getMessageCount(conversation.id);
    if (_totalMessageCount == 0) return false;

    final safeLeading = leadingContext
        .clamp(0, ChatService.defaultLoadedWindowMax - 1)
        .toInt();
    final maxStart = (_totalMessageCount - ChatService.defaultLoadedWindowMax)
        .clamp(0, _totalMessageCount)
        .toInt();
    final start = (targetIndex - safeLeading).clamp(0, maxStart).toInt();
    return _loadWindow(
      start: start,
      limit: ChatService.defaultLoadedWindowMax,
      ensureVisible: ensureVisible,
    );
  }

  int loadedWindowTruncateIndex() {
    final conversationId = _currentConversation?.id;
    final raw = conversationId == null
        ? -1
        : _chatService.getContextStartIndex(conversationId);
    if (raw < 0) return -1;
    if (raw <= _loadedStartIndex) return -1;

    final loadedEnd = _loadedStartIndex + _messages.length;
    if (raw >= loadedEnd) return _messages.length;
    return raw - _loadedStartIndex;
  }

  Conversation conversationForLoadedWindow(Conversation conversation) {
    if (_currentConversation?.id != conversation.id) return conversation;
    final localTruncateIndex = loadedWindowTruncateIndex();
    return conversation.copyWith(truncateIndex: localTruncateIndex);
  }

  List<ChatMessage> allCollapsedMessagesForCurrentConversation() {
    final conversation = _currentConversation;
    if (conversation == null) return const <ChatMessage>[];
    return collapseVersions(
      _chatService.getMessagesRange(
        conversation.id,
        start: 0,
        limit: _chatService.getMessageCount(conversation.id),
      ),
    );
  }

  Future<List<ChatMessage>> allMessagesForCurrentConversationContext() async {
    final conversation = _currentConversation;
    if (conversation == null) return const <ChatMessage>[];
    return messagesForCompleteHistoryContext(conversation);
  }

  Future<List<ChatMessage>> messagesForCompleteHistoryContext(
    Conversation conversation,
  ) {
    return _chatService.loadMessages(conversation.id);
  }

  Conversation conversationForCompleteHistoryContext(
    Conversation conversation,
  ) {
    final current =
        _chatService.getConversation(conversation.id) ?? conversation;
    return current.copyWith(
      truncateIndex: _chatService.getContextStartIndex(conversation.id),
    );
  }

  Future<bool> _loadWindow({
    required int start,
    required int limit,
    bool ensureVisible = false,
  }) async {
    final conversation = _currentConversation;
    if (conversation == null || limit <= 0) return false;

    _totalMessageCount = _chatService.getMessageCount(conversation.id);
    final safeStart = start.clamp(0, _totalMessageCount).toInt();
    final range = await _chatService.loadMessagesRange(
      conversation.id,
      start: safeStart,
      limit: limit,
    );
    if (range.isEmpty) return false;

    _messages = List.of(range);
    _loadedStartIndex = safeStart;
    _seedTimelineFromMessages();
    await _preloadVisibleGroupData();
    if (ensureVisible && await _ensureLoadedWindowHasVisibleMessages()) {
      return true;
    }
    notifyListeners();
    return true;
  }

  void _seedTimelineFromMessages() {
    final conversation = _currentConversation;
    if (conversation == null) return;
    final timelineMessages = collapseVersions(_messages);
    final timestamp = DateTime.fromMicrosecondsSinceEpoch(0);
    final counts = <String, int>{};
    for (final message in _messages) {
      counts.update(
        message.groupId ?? message.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    timelineCoordinator.seed(
      LoadedTimelinePage(
        conversationId: conversation.id,
        stateRevision: 0,
        contextStartRevisionId: _chatService.getContextStartRevisionId(
          conversation.id,
        ),
        slots: [
          for (final (offset, message) in timelineMessages.indexed)
            LoadedTimelineSlot(
              identity: ActiveTimelineSlot(
                slotId: message.groupId ?? message.id,
                revisionId: message.id,
                parentRevisionId: offset == 0
                    ? null
                    : timelineMessages[offset - 1].id,
                role: message.role,
                createdAt: timestamp,
                updatedAt: timestamp,
                finalizedAt: message.isStreaming ? null : timestamp,
                versionCount: counts[message.groupId ?? message.id] ?? 1,
                logicalIndex: _loadedStartIndex + offset,
              ),
              message: message,
            ),
        ],
        hasMoreBefore: _loadedStartIndex > 0,
        hasMoreAfter:
            _loadedStartIndex + timelineMessages.length < _totalMessageCount,
        totalSlotCount: _totalMessageCount,
      ),
    );
  }

  Future<bool> _ensureLoadedWindowHasVisibleMessages() async {
    final conversation = _currentConversation;
    if (conversation == null || _messages.isEmpty) return false;
    if (collapsedMessages.isNotEmpty) return false;

    final anchorIndex = _latestGroupAnchorIndexForLoadedWindow(conversation.id);
    if (anchorIndex == null) return false;

    return _loadWindowAroundIndex(anchorIndex, ensureVisible: false);
  }

  Future<void> _preloadVisibleGroupData() async {
    final conversation = _currentConversation;
    if (conversation == null || _messages.isEmpty) return;
    final groupIds = <String>{
      for (final message in _messages)
        if (message.version > 0 ||
            _versionSelections.containsKey(message.groupId ?? message.id))
          message.groupId ?? message.id,
    };
    if (groupIds.isEmpty) return;
    await Future.wait([
      _chatService.loadMessagesForGroups(conversation.id, groupIds),
      _chatService.loadFirstMessageIndicesForGroups(conversation.id, groupIds),
      if (_loadedStartIndex > 0)
        _chatService.loadMessagesRange(
          conversation.id,
          start: _loadedStartIndex - 1,
          limit: 1,
        ),
    ]);
    invalidateCache();
  }

  int? _latestGroupAnchorIndexForLoadedWindow(String conversationId) {
    if (_loadedStartIndex <= 0) return null;

    final groupIds = <String>{};
    for (final message in _messages) {
      if (message.version <= 0) continue;
      groupIds.add(message.groupId ?? message.id);
    }
    if (groupIds.isEmpty) return null;

    final firstIndices = _chatService.getFirstMessageIndicesForGroups(
      conversationId,
      groupIds,
    );

    int? latestAnchorIndex;
    for (final index in firstIndices.values) {
      if (index >= _loadedStartIndex) continue;
      if (latestAnchorIndex == null || index > latestAnchorIndex) {
        latestAnchorIndex = index;
      }
    }
    return latestAnchorIndex;
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
    if (_chatService.getConversation(_currentConversation!.id) == null) {
      _clearCurrentConversationState();
      notifyListeners();
      throw StateError('No current conversation');
    }

    if (hasMoreAfter) {
      await loadEndWindow();
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
    _totalMessageCount += 1;
    final overflow = _messages.length - ChatService.defaultLoadedWindowMax;
    if (overflow > 0) {
      _messages = _messages.sublist(overflow);
      _loadedStartIndex += overflow;
    }
    notifyListeners();
    return message;
  }

  /// Add an already-persisted tail message to the loaded window.
  ///
  /// ChatService appends new message versions and streaming placeholders to the
  /// persisted conversation before callers update UI state. This method keeps
  /// [_messages] as a real contiguous persisted range instead of mixing a tail
  /// message into an older loaded window.
  Future<bool> appendPersistedTailMessage(ChatMessage message) async {
    return appendPersistedTailMessages([message]);
  }

  /// Publishes one atomic persistence result to the loaded tail as one UI
  /// mutation. A send begins with a user/assistant pair, so refreshing the
  /// persisted count between those two messages would briefly create a false
  /// gap and trigger an unnecessary window reload.
  Future<bool> appendPersistedTailMessages(List<ChatMessage> messages) async {
    if (messages.isEmpty) return false;
    final conversation = _currentConversation;
    if (conversation == null ||
        messages.any((message) => message.conversationId != conversation.id)) {
      return false;
    }

    if (!_chatService.isTemporaryConversation(conversation.id)) {
      await timelineCoordinator.open(
        conversation.id,
        limit: ChatService.defaultLoadedWindowMax,
      );
      final user = messages.firstWhere(
        (message) => message.role == 'user',
        orElse: () => messages.first,
      );
      timelineCoordinator.programmaticJump(user.groupId ?? user.id);
      return true;
    }

    _totalMessageCount = _chatService.getMessageCount(conversation.id);

    for (final message in messages) {
      final existingIndex = _messages.indexWhere((m) => m.id == message.id);
      if (existingIndex >= 0) {
        _messages[existingIndex] = message;
      } else {
        _messages.add(message);
      }
    }

    final overflow = _messages.length - ChatService.defaultLoadedWindowMax;
    if (overflow > 0) {
      _messages = _messages.sublist(overflow);
      _loadedStartIndex += overflow;
    }
    notifyListeners();
    return false;
  }

  /// Update a message in the list.
  void updateMessageInList(String messageId, ChatMessage updatedMessage) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = updatedMessage;
      timelineCoordinator.replaceMessage(updatedMessage);
      timelineCoordinator.noteContentChanged(
        isGenerating: updatedMessage.isStreaming,
      );
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
      timelineCoordinator.replaceMessage(_messages[index]);
      timelineCoordinator.noteContentChanged(
        isGenerating: _messages[index].isStreaming,
      );
      notifyListeners();
    }
  }

  /// Remove messages after a given index.
  void removeMessagesAfter(int index) {
    if (index < _messages.length - 1) {
      _messages = _messages.sublist(0, index + 1);
      _totalMessageCount = _loadedStartIndex + _messages.length;
      notifyListeners();
    }
  }

  /// Remove specific message IDs from the list.
  void removeMessageIds(List<String> ids) {
    _messages.removeWhere((m) => ids.contains(m.id));
    _totalMessageCount = (_totalMessageCount - ids.length)
        .clamp(0, 1 << 31)
        .toInt();
    _loadedStartIndex = _loadedStartIndex.clamp(0, _totalMessageCount).toInt();
    notifyListeners();
  }

  /// Reload messages from storage.
  Future<void> reloadMessages() async {
    if (_currentConversation == null) return;
    final conversationId = _currentConversation!.id;
    _totalMessageCount = _chatService.getMessageCount(conversationId);
    if (_totalMessageCount == 0) {
      _messages = [];
      _loadedStartIndex = 0;
      notifyListeners();
      return;
    }

    final visibleCount = _messages.isEmpty
        ? ChatService.defaultInitialMessageMin
        : _messages.length.clamp(1, ChatService.defaultLoadedWindowMax).toInt();
    final start = _loadedStartIndex.clamp(0, _totalMessageCount).toInt();
    final maxStart = (_totalMessageCount - visibleCount)
        .clamp(0, _totalMessageCount)
        .toInt();
    final safeStart = start > maxStart ? maxStart : start;
    _messages = List.of(
      await _chatService.loadMessagesRange(
        conversationId,
        start: safeStart,
        limit: visibleCount,
      ),
    );
    _loadedStartIndex = safeStart;
    await _preloadVisibleGroupData();
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
    var candidates = _chatService.getMessagesForGroups(
      _currentConversation?.id ?? '',
      [groupId],
    );
    if (!candidates.any((message) => message.version == version) &&
        _currentConversation != null) {
      candidates = await _chatService.loadMessagesForGroups(
        _currentConversation!.id,
        [groupId],
      );
    }
    ChatMessage? target;
    for (final candidate in candidates) {
      if (candidate.version == version) {
        target = candidate;
        break;
      }
    }
    if (target == null) throw StateError('message_graph_revision_missing');
    _versionSelections[groupId] = version;
    if (_currentConversation != null) {
      await _chatService.selectMessageRevision(
        _currentConversation!.id,
        target.id,
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

  /// Get messages collapsed by version (cached).
  List<ChatMessage> get collapsedMessages {
    if (_collapsedCache != null) return _collapsedCache!;
    _collapsedCache = collapseVersions(_messagesWithVisibleGroups());
    _collapsedIdToIndex = <String, int>{};
    for (int i = 0; i < _collapsedCache!.length; i++) {
      _collapsedIdToIndex![_collapsedCache![i].id] = i;
    }
    return _collapsedCache!;
  }

  List<ChatMessage> _messagesWithVisibleGroups() {
    if (_messagesWithVisibleGroupsCache != null) {
      return _messagesWithVisibleGroupsCache!;
    }

    final conversation = _currentConversation;
    if (conversation == null || _messages.isEmpty) {
      return _messagesWithVisibleGroupsCache = _messages;
    }

    final targetGroupIds = <String>{};
    final versionedGroupIds = <String>{};
    for (final message in _messages) {
      final groupId = message.groupId ?? message.id;
      if (_versionSelections.containsKey(groupId)) {
        targetGroupIds.add(groupId);
      }
      if (message.version > 0) {
        targetGroupIds.add(groupId);
        versionedGroupIds.add(groupId);
      }
    }
    if (targetGroupIds.isEmpty) {
      return _messagesWithVisibleGroupsCache = _messages;
    }

    final visibleVersions = _chatService.getMessagesForGroups(
      conversation.id,
      targetGroupIds,
    );
    if (visibleVersions.isEmpty) {
      return _messagesWithVisibleGroupsCache = _messages;
    }

    final visibleIds = {for (final message in _messages) message.id};
    final byGroup = <String, List<ChatMessage>>{};
    for (final message in visibleVersions) {
      final groupId = message.groupId ?? message.id;
      byGroup.putIfAbsent(groupId, () => <ChatMessage>[]).add(message);
    }

    Map<String, int> firstIndices = const <String, int>{};
    if (_loadedStartIndex > 0 && versionedGroupIds.isNotEmpty) {
      firstIndices = _chatService.getFirstMessageIndicesForGroups(
        conversation.id,
        versionedGroupIds,
      );
    }
    final firstLoadedGroupId = _messages.isEmpty
        ? null
        : (_messages.first.groupId ?? _messages.first.id);
    final previousLoadedGroupId = _previousLoadedMessageGroupId(
      conversation.id,
    );

    final result = <ChatMessage>[];
    final emitted = <String>{};
    for (final message in _messages) {
      final groupId = message.groupId ?? message.id;
      final groupMessages = byGroup[groupId] ?? <ChatMessage>[message];
      final groupAnchorIndex = firstIndices[groupId] ?? _loadedStartIndex;
      final startsInsideGroup =
          groupId == firstLoadedGroupId && groupId == previousLoadedGroupId;
      if (groupAnchorIndex < _loadedStartIndex &&
          message.version > 0 &&
          !startsInsideGroup) {
        continue;
      }
      if (emitted.add(groupId)) {
        for (final candidate in groupMessages) {
          result.add(candidate);
          emitted.add(candidate.id);
        }
      } else if (!visibleIds.contains(message.id) && emitted.add(message.id)) {
        result.add(message);
      }
    }

    return _messagesWithVisibleGroupsCache = result;
  }

  String? _previousLoadedMessageGroupId(String conversationId) {
    if (_loadedStartIndex <= 0) return null;

    final previous = _chatService.getMessagesRange(
      conversationId,
      start: _loadedStartIndex - 1,
      limit: 1,
    );
    if (previous.isEmpty) return null;

    final message = previous.single;
    return message.groupId ?? message.id;
  }

  /// O(1) lookup of a message's index in the collapsed list.
  int indexOfCollapsedMessageId(String id) {
    collapsedMessages; // ensure cache is built
    return _collapsedIdToIndex?[id] ?? -1;
  }

  static List<ChatMessage> selectedCollapsedMessagesForExport({
    required Iterable<ChatMessage> collapsedMessages,
    required Set<String> selectedIds,
    required Iterable<ChatMessage> storedMessages,
  }) {
    if (selectedIds.isEmpty) return const <ChatMessage>[];

    final storedById = <String, ChatMessage>{
      for (final message in storedMessages) message.id: message,
    };

    return [
      for (final message in collapsedMessages)
        if (selectedIds.contains(message.id)) storedById[message.id] ?? message,
    ];
  }

  /// Get messages grouped by groupId (cached).
  Map<String, List<ChatMessage>> get groupedMessages {
    return _groupCache ??= groupMessagesByGroup();
  }

  /// Complete renderer projection for the current bounded timeline window.
  /// Computed once per message snapshot, never once per visible row.
  List<MessageRenderModel> get messageRenderModels {
    return _renderModelsCache ??= MessageRenderModelProjector.project(
      messages: collapsedMessages,
      byGroup: groupedMessages,
      versionSelections: _versionSelections,
      contextDividerIndex: _collapsedContextDividerIndex(),
    );
  }

  int _collapsedContextDividerIndex() {
    final raw = loadedWindowTruncateIndex();
    if (raw <= 0) return -1;
    final seen = <String>{};
    final limit = raw.clamp(0, _messages.length);
    var count = 0;
    for (var index = 0; index < limit; index++) {
      if (seen.add(_messages[index].groupId ?? _messages[index].id)) count++;
    }
    return count - 1;
  }

  /// Group all messages by their groupId.
  Map<String, List<ChatMessage>> groupMessagesByGroup() {
    final Map<String, List<ChatMessage>> byGroup =
        <String, List<ChatMessage>>{};
    for (final m in _messagesWithVisibleGroups()) {
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
    _messagesWithVisibleGroupsCache = null;
    _renderModelsCache = null;
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
    _chatService.removeListener(_syncCurrentConversationWithService);
    timelineCoordinator
      ..removeListener(_syncTimelineWindow)
      ..dispose();
    cancelAllStreams();
    super.dispose();
  }
}
