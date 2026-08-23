import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/database/chat_database_repository.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/screen_wakelock.dart';
import 'message_render_model.dart';

/// Initial window for a conversation switch, loaded by
/// [ChatController.fetchConversationWindow] and installed atomically by
/// [ChatController.commitConversationWindow].
class FetchedConversationWindow {
  const FetchedConversationWindow({
    required this.conversation,
    required this.page,
    required this.versionSelections,
    required this.needsVisibleGroupPreloadRetry,
  });

  final Conversation conversation;
  final LoadedTimelinePage? page;
  final Map<String, int> versionSelections;
  final bool needsVisibleGroupPreloadRetry;
}

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
    _chatService.addListener(_syncCurrentConversationWithService);
  }

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

  /// Index in the persisted conversation where [_messages] starts.
  int _loadedStartIndex = 0;
  int get loadedStartIndex => _loadedStartIndex;

  /// Total persisted message count for the current conversation.
  int _totalMessageCount = 0;
  int get totalMessageCount => _totalMessageCount;

  /// versionCount from the latest loaded timeline window, keyed by groupId.
  Map<String, int> _windowVersionCounts = <String, int>{};
  bool get hasMoreBefore => _loadedStartIndex > 0;
  bool get hasMoreAfter =>
      _loadedStartIndex + _messages.length < _totalMessageCount;

  /// Whether an initial/around-message window load is in flight.
  bool _isLoadingWindow = false;
  bool get isLoadingWindow => _isLoadingWindow;

  /// Serial of the latest window load; only it may clear [_isLoadingWindow].
  int _windowLoadSerial = 0;

  /// Slot budget for the idle cache backfill: the current conversation's
  /// cache ceiling is its full history or this threshold, whichever is lower.
  @visibleForTesting
  static const int idleCacheBackfillSlotLimit = 5000;

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

  // ============================================================================
  // Conversation Management
  // ============================================================================

  /// Sets a newly created empty draft without opening a persisted window.
  void setDraftConversation(Conversation conversation) {
    // Unknown count (-1) is not "has messages"; only reject when known non-zero.
    if (_chatService.isMessageCountKnown(conversation.id) &&
        _chatService.getMessageCount(conversation.id) != 0) {
      throw StateError('persisted_conversation_requires_async_open');
    }
    _currentConversation = conversation;
    _messages = [];
    _loadedStartIndex = 0;
    _totalMessageCount = 0;
    _windowVersionCounts = <String, int>{};
    _versionSelections = <String, int>{};
    notifyListeners();
  }

  Future<void> setCurrentConversationAndLoad(Conversation? conversation) async {
    _currentConversation = conversation;
    _messages = [];
    _loadedStartIndex = 0;
    _totalMessageCount = 0;
    _windowVersionCounts = <String, int>{};
    _versionSelections = <String, int>{};
    if (conversation != null) {
      _loadVersionSelections();
      await _loadInitialMessageWindow(conversation.id);
      if (_currentConversation?.id != conversation.id) return;
    }
    notifyListeners();
  }

  /// Fetch phase of a conversation switch: loads the initial window for
  /// [conversation] without mutating any current state. Install the result
  /// with [commitConversationWindow].
  Future<FetchedConversationWindow> fetchConversationWindow(
    Conversation conversation,
  ) async {
    final page = await _chatService.loadTimelinePage(
      conversation.id,
      limit: ChatService.defaultTimelineInitialSlots,
    );
    Map<String, int> versionSelections;
    try {
      versionSelections = _chatService.getVersionSelections(conversation.id);
    } catch (_) {
      versionSelections = <String, int>{};
    }
    final groupIds = <String>{
      for (final slot in page?.slots ?? const <LoadedTimelineSlot>[])
        if (slot.identity.versionCount > 1 ||
            slot.message.version > 0 ||
            versionSelections.containsKey(
              slot.message.groupId ?? slot.message.id,
            ))
          slot.message.groupId ?? slot.message.id,
    };
    var needsVisibleGroupPreloadRetry = false;
    if (groupIds.isNotEmpty) {
      try {
        await Future.wait([
          _chatService.loadMessagesForGroups(conversation.id, groupIds),
          _chatService.loadFirstMessageIndicesForGroups(
            conversation.id,
            groupIds,
          ),
        ]);
      } catch (_) {
        needsVisibleGroupPreloadRetry = true;
      }
    }
    return FetchedConversationWindow(
      conversation: conversation,
      page: page,
      versionSelections: versionSelections,
      needsVisibleGroupPreloadRetry: needsVisibleGroupPreloadRetry,
    );
  }

  /// Commit phase of a conversation switch: installs a window previously
  /// fetched by [fetchConversationWindow]. Supersedes any in-flight window
  /// load, so its late page and loading-flag clear both lose.
  void commitConversationWindow(
    FetchedConversationWindow fetched, {
    VoidCallback? onDeferredGroupDataLoaded,
  }) {
    _windowLoadSerial++;
    _isLoadingWindow = false;
    _currentConversation = fetched.conversation;
    _replaceWindow(fetched.page);
    _versionSelections = fetched.versionSelections;
    notifyListeners();
    if (fetched.needsVisibleGroupPreloadRetry) {
      unawaited(
        _preloadVisibleGroupData()
            .then((_) {
              if (_currentConversation?.id != fetched.conversation.id) return;
              notifyListeners();
              onDeferredGroupDataLoaded?.call();
            })
            .catchError((Object _) {}),
      );
    }
    _scheduleIdleCacheBackfill(fetched.conversation.id);
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
    _loadedStartIndex = 0;
    _totalMessageCount = 0;
    _windowVersionCounts = <String, int>{};
    _versionSelections = <String, int>{};
    notifyListeners();
    return conversation;
  }

  /// Clear the current conversation state.
  void clearCurrentConversation() {
    _clearCurrentConversationState();
    notifyListeners();
  }

  void _clearCurrentConversationState() {
    _currentConversation = null;
    _messages = [];
    _loadedStartIndex = 0;
    _totalMessageCount = 0;
    _windowVersionCounts = <String, int>{};
    _versionSelections = <String, int>{};
  }

  Future<void> _loadInitialMessageWindow(String conversationId) async {
    final serial = ++_windowLoadSerial;
    _isLoadingWindow = true;
    try {
      final page = await _chatService.loadTimelinePage(
        conversationId,
        limit: ChatService.defaultTimelineInitialSlots,
      );
      // Discard the page if the conversation changed while loading.
      if (_currentConversation?.id != conversationId) return;
      _replaceWindow(page);
    } finally {
      if (serial == _windowLoadSerial) _isLoadingWindow = false;
    }
    invalidateCache();
    await _preloadVisibleGroupData();
    _scheduleIdleCacheBackfill(conversationId);
  }

  /// Queues a silent full-cache backfill for [conversationId] to run once the
  /// UI is idle (i.e. after the first frame of a freshly opened window).
  void _scheduleIdleCacheBackfill(String conversationId) {
    final Future<void> task;
    try {
      task = SchedulerBinding.instance.scheduleTask(
        () => backfillCurrentConversationCache(conversationId),
        Priority.idle,
        debugLabel: 'chat.idleCacheBackfill',
      );
    } catch (_) {
      // No scheduler binding (bare unit tests): warm-up is optional.
      return;
    }
    unawaited(task.catchError((Object _) {}));
  }

  /// Silently warms the full message cache for the current conversation.
  ///
  /// Cache warm-up only: no listeners are notified and every guard failure
  /// just skips the load. Guards: the conversation must still be current, its
  /// slot count must fit [idleCacheBackfillSlotLimit], and it must not be
  /// generating (a streaming write owns the single connection queue). The
  /// current conversation is exempt from cache eviction; if a backfill pushes
  /// the cache over budget, tail truncation (cache plan measure 13) keeps the
  /// newest entries.
  @visibleForTesting
  Future<void> backfillCurrentConversationCache(String conversationId) async {
    if (_currentConversation?.id != conversationId) return;
    if (_totalMessageCount > idleCacheBackfillSlotLimit) return;
    if (isConversationLoading(conversationId)) return;
    if (_chatService.isConversationFullyCached(conversationId)) return;
    try {
      await _chatService.loadMessages(conversationId);
    } catch (_) {
      // Warm-up failures lose nothing user-visible.
    }
  }

  void _replaceWindow(LoadedTimelinePage? page) {
    if (page == null) {
      _messages = <ChatMessage>[];
      _loadedStartIndex = 0;
      _totalMessageCount = 0;
      _windowVersionCounts = <String, int>{};
      return;
    }
    _messages = page.slots.map((slot) => slot.message).toList(growable: true);
    _loadedStartIndex = page.slots.isEmpty
        ? 0
        : page.slots.first.identity.logicalIndex;
    _totalMessageCount = page.totalSlotCount;
    _windowVersionCounts = {
      for (final slot in page.slots)
        slot.identity.slotId: slot.identity.versionCount,
    };
    invalidateCache();
  }

  void _mergeWindowVersionCounts(LoadedTimelinePage page) {
    final next = Map<String, int>.of(_windowVersionCounts);
    for (final slot in page.slots) {
      next[slot.identity.slotId] = slot.identity.versionCount;
    }
    _windowVersionCounts = next;
  }

  Future<bool> loadMoreBefore({
    int limit = ChatService.defaultHistoryPageSize,
  }) async {
    if (limit <= 0) return false;
    final conversation = _currentConversation;
    if (conversation == null || _messages.isEmpty || !hasMoreBefore) {
      return false;
    }
    final page = await _chatService.loadTimelinePage(
      conversation.id,
      beforeRevisionId: _messages.first.id,
      limit: limit,
    );
    if (_currentConversation?.id != conversation.id) return false;
    if (page == null || page.slots.isEmpty) return false;
    final existing = {for (final message in _messages) message.id};
    _messages.insertAll(0, [
      for (final slot in page.slots)
        if (existing.add(slot.message.id)) slot.message,
    ]);
    _loadedStartIndex = page.slots.first.identity.logicalIndex;
    _totalMessageCount = page.totalSlotCount;
    _mergeWindowVersionCounts(page);
    if (_messages.length > ChatService.defaultLoadedWindowMax) {
      _messages.removeRange(
        ChatService.defaultLoadedWindowMax,
        _messages.length,
      );
    }
    invalidateCache();
    await _preloadVisibleGroupData();
    notifyListeners();
    return true;
  }

  Future<bool> loadMoreAfter({
    int limit = ChatService.defaultHistoryPageSize,
  }) async {
    if (limit <= 0) return false;
    final conversation = _currentConversation;
    if (conversation == null || _messages.isEmpty || !hasMoreAfter) {
      return false;
    }
    final page = await _chatService.loadTimelinePage(
      conversation.id,
      afterRevisionId: _messages.last.id,
      limit: limit,
    );
    if (_currentConversation?.id != conversation.id) return false;
    if (page == null || page.slots.isEmpty) return false;
    final existing = {for (final message in _messages) message.id};
    _messages.addAll([
      for (final slot in page.slots)
        if (existing.add(slot.message.id)) slot.message,
    ]);
    _totalMessageCount = page.totalSlotCount;
    _mergeWindowVersionCounts(page);
    if (_messages.length > ChatService.defaultLoadedWindowMax) {
      final removeCount = _messages.length - ChatService.defaultLoadedWindowMax;
      _messages.removeRange(0, removeCount);
      _loadedStartIndex += removeCount;
    }
    invalidateCache();
    await _preloadVisibleGroupData();
    notifyListeners();
    return true;
  }

  Future<bool> loadStartWindow() async {
    final conversation = _currentConversation;
    if (conversation == null) return false;
    final page = await _chatService.loadTimelinePage(
      conversation.id,
      fromStart: true,
      limit: ChatService.defaultLoadedWindowMax,
    );
    // Discard the page if the conversation changed while loading.
    if (_currentConversation?.id != conversation.id) return false;
    _replaceWindow(page);
    await _preloadVisibleGroupData();
    notifyListeners();
    return _messages.isNotEmpty;
  }

  Future<bool> loadEndWindow() async {
    final conversation = _currentConversation;
    if (conversation == null) return false;
    final page = await _chatService.loadTimelinePage(
      conversation.id,
      limit: ChatService.defaultLoadedWindowMax,
    );
    // Discard the page if the conversation changed while loading.
    if (_currentConversation?.id != conversation.id) return false;
    _replaceWindow(page);
    await _preloadVisibleGroupData();
    notifyListeners();
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
    final requested = leadingContext * 2 + 1;
    final limit = requested
        .clamp(
          ChatService.defaultTimelineInitialSlots,
          ChatService.defaultLoadedWindowMax,
        )
        .toInt();
    final serial = ++_windowLoadSerial;
    _isLoadingWindow = true;
    try {
      final page = await _chatService.loadTimelinePage(
        conversation.id,
        aroundRevisionId: messageId,
        limit: limit,
      );
      // Discard the page if the conversation changed while loading.
      if (_currentConversation?.id != conversation.id) return false;
      if (page == null || page.slots.isEmpty) return false;
      _replaceWindow(page);
    } finally {
      if (serial == _windowLoadSerial) _isLoadingWindow = false;
    }
    await _preloadVisibleGroupData();
    notifyListeners();
    return _messages.any((message) => message.id == messageId);
  }

  Future<bool> refreshTimelineAfterMutation({
    Set<String> removedRevisionIds = const <String>{},
    Map<String, List<ChatMessage>>? survivingVersionsByGroup,
  }) async {
    final conversation = _currentConversation;
    if (conversation == null) return false;
    if (survivingVersionsByGroup != null &&
        _removeRevisionsFromWindow(
          removedRevisionIds,
          survivingVersionsByGroup,
        )) {
      await _preloadVisibleGroupData();
      if (_currentConversation?.id != conversation.id) return false;
      notifyListeners();
      return true;
    }
    String? anchorId;
    if (hasMoreAfter) {
      for (final message in _messages) {
        if (removedRevisionIds.contains(message.id)) continue;
        anchorId = message.id;
        break;
      }
    }
    final previousSlotIds = <String>{
      for (final message in _messages) message.groupId ?? message.id,
    };
    final page = await _chatService.loadTimelinePage(
      conversation.id,
      aroundRevisionId: anchorId,
      limit: ChatService.defaultLoadedWindowMax,
    );
    if (_currentConversation?.id != conversation.id) return false;
    _replaceWindow(_withoutBackfilledHead(page, previousSlotIds));
    await _preloadVisibleGroupData();
    notifyListeners();
    return page != null;
  }

  /// Applies a deletion to the loaded window in place instead of reloading it.
  ///
  /// A full reload rebuilds the window around a database anchor, which can
  /// reshape it (backfilled head, shifted indices); the list widget then loses
  /// track of which rows survived and has to drop every measured row height,
  /// making the viewport drift while everything is re-measured. Removing the
  /// deleted revisions from the loaded window directly keeps every surviving
  /// slot identity stable, so the list only sees "these slots disappeared".
  ///
  /// [survivingVersionsByGroup] must contain an entry for every group that
  /// lost at least one revision, holding the versions that remain (empty when
  /// the whole slot is gone). Returns false when the mutation cannot be
  /// expressed as an in-window edit — deleted revisions belonging to slots
  /// outside the loaded window, missing survivor data, or a window that would
  /// empty out — in which case the caller falls back to the full reload.
  bool _removeRevisionsFromWindow(
    Set<String> removedRevisionIds,
    Map<String, List<ChatMessage>> survivingVersionsByGroup,
  ) {
    if (removedRevisionIds.isEmpty || _messages.isEmpty) return false;
    final windowSlotIds = <String>{
      for (final message in _messages) message.groupId ?? message.id,
    };
    // A group outside the window changes slot counts in a region this method
    // does not track, so only a reload can resolve it.
    for (final groupId in survivingVersionsByGroup.keys) {
      if (!windowSlotIds.contains(groupId)) return false;
    }

    final next = <ChatMessage>[];
    final nextVersionCounts = Map<String, int>.of(_windowVersionCounts);
    var removedSlotCount = 0;
    for (final message in _messages) {
      final groupId = message.groupId ?? message.id;
      final survivors = survivingVersionsByGroup[groupId];
      if (survivors != null && survivors.isNotEmpty) {
        nextVersionCounts[groupId] = survivors.length;
      }
      if (!removedRevisionIds.contains(message.id)) {
        next.add(message);
        continue;
      }
      if (survivors == null) return false;
      if (survivors.isEmpty) {
        removedSlotCount++;
        nextVersionCounts.remove(groupId);
        continue;
      }
      final sorted = List<ChatMessage>.of(survivors)
        ..sort((left, right) => left.version.compareTo(right.version));
      final selection = _versionSelections[groupId];
      ChatMessage? selected;
      if (selection != null) {
        for (final candidate in sorted) {
          if (candidate.version == selection) {
            selected = candidate;
            break;
          }
        }
      }
      next.add(selected ?? sorted.last);
    }
    if (next.isEmpty) return false;

    _messages = next;
    _totalMessageCount = math.max(
      _loadedStartIndex + next.length,
      _totalMessageCount - removedSlotCount,
    );
    _windowVersionCounts = nextVersionCounts;
    invalidateCache();
    return true;
  }

  /// Drops slots a tail-anchored reload backfilled ahead of the old window.
  ///
  /// A reload without an anchor always fills a full-size window, so deleting
  /// the last message pulls one extra older message in at the head. The
  /// refreshed list then has the same length as before with every slot shifted
  /// by one; SuperSliverList reuses its children under the new indices and
  /// keeps their stale layout offsets, which parks the viewport above the real
  /// bottom with no way to scroll back down. Cutting the backfilled head makes
  /// the new window a prefix of the old one, so the list just loses its
  /// trailing child. The dropped history is paged back in by [loadMoreBefore].
  LoadedTimelinePage? _withoutBackfilledHead(
    LoadedTimelinePage? page,
    Set<String> previousSlotIds,
  ) {
    if (page == null || page.hasMoreAfter || previousSlotIds.isEmpty) {
      return page;
    }
    var cut = 0;
    while (cut < page.slots.length &&
        !previousSlotIds.contains(page.slots[cut].identity.slotId)) {
      cut++;
    }
    // cut == 0: nothing backfilled. cut == length: the window moved entirely
    // off the old one, so there is no shared head to preserve.
    if (cut == 0 || cut >= page.slots.length) return page;
    // A batch deletion leaves only a handful of the old slots in the reloaded
    // window, and trimming down to those would show a near-empty list that only
    // refills once the user scrolls. Reusing children is not worth that, so
    // below a screenful of survivors keep the full window instead.
    final remaining = page.slots.length - cut;
    if (remaining <
        math.min(
          ChatService.defaultTimelineInitialSlots,
          previousSlotIds.length,
        )) {
      return page;
    }
    return LoadedTimelinePage(
      conversationId: page.conversationId,
      stateRevision: page.stateRevision,
      contextStartRevisionId: page.contextStartRevisionId,
      slots: page.slots.sublist(cut),
      hasMoreBefore: true,
      hasMoreAfter: page.hasMoreAfter,
      totalSlotCount: page.totalSlotCount,
    );
  }

  int loadedWindowTruncateIndex() {
    final raw = _currentConversation?.truncateIndex ?? -1;
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

  /// Current loaded-window collapsed projection only — never walks the full
  /// conversation via [ChatService.getMessagesRange] / full order skeleton.
  List<ChatMessage> allCollapsedMessagesForCurrentConversation() {
    if (_currentConversation == null) return const <ChatMessage>[];
    return collapsedMessages;
  }

  Future<List<ChatMessage>>
  loadAllCollapsedMessagesForCurrentConversation() async {
    final conversation = _currentConversation;
    if (conversation == null) return const <ChatMessage>[];
    return _chatService.loadSelectedMessageProjections(conversation.id);
  }

  Future<List<MiniMapSearchHit>> searchMiniMapMatches(String query) {
    final conversation = _currentConversation;
    if (conversation == null) {
      return Future<List<MiniMapSearchHit>>.value(const <MiniMapSearchHit>[]);
    }
    return _chatService.searchMiniMapMatches(conversation.id, query);
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

  Future<List<ChatMessage>> messagesForGenerationContext(
    Conversation conversation, {
    required int maxMessages,
    String? throughRevisionId,
    bool includeFollowingAssistant = false,
  }) {
    return _chatService.loadSelectedContextMessages(
      conversation.id,
      truncateIndex: conversation.truncateIndex,
      limit: maxMessages,
      throughRevisionId: throughRevisionId,
      includeFollowingAssistant: includeFollowingAssistant,
    );
  }

  Conversation conversationForCompleteHistoryContext(
    Conversation conversation,
  ) {
    final current =
        _chatService.getConversation(conversation.id) ?? conversation;
    return current;
  }

  Future<void> _preloadVisibleGroupData() async {
    final conversation = _currentConversation;
    if (conversation == null || _messages.isEmpty) return;
    final groupIds = <String>{
      for (final message in _messages)
        if ((_windowVersionCounts[message.groupId ?? message.id] ?? 1) > 1 ||
            message.version > 0 ||
            _versionSelections.containsKey(message.groupId ?? message.id))
          message.groupId ?? message.id,
    };
    if (groupIds.isEmpty) return;
    await Future.wait([
      _chatService.loadMessagesForGroups(conversation.id, groupIds),
      _chatService.loadFirstMessageIndicesForGroups(conversation.id, groupIds),
    ]);
    invalidateCache();
  }

  // ============================================================================
  // Message Management
  // ============================================================================

  Future<ChatMessage> addMessage({
    required String role,
    required String content,
    String? modelId,
    String? providerId,
    bool isStreaming = false,
    String? groupId,
    int? version,
  }) async {
    final conversation = _currentConversation;
    if (conversation == null ||
        _chatService.getConversation(conversation.id) == null) {
      _clearCurrentConversationState();
      notifyListeners();
      throw StateError('No current conversation');
    }
    final message = await _chatService.addMessage(
      conversationId: conversation.id,
      role: role,
      content: content,
      modelId: modelId,
      providerId: providerId,
      isStreaming: isStreaming,
      groupId: groupId,
      version: version,
    );
    await appendPersistedTailMessage(message);
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

  /// Opens the logical window around an already-persisted revision mutation.
  ///
  /// Editing or selecting a version can target a slot far outside the tail
  /// window, so it must not reuse the append-to-tail navigation path. Set
  /// [truncateFollowingSlots] when persistence removed every logical slot
  /// after the target.
  Future<bool> openAroundPersistedMessage(
    ChatMessage message, {
    bool truncateFollowingSlots = false,
  }) async {
    final conversation = _currentConversation;
    if (conversation == null || message.conversationId != conversation.id) {
      return false;
    }

    final groupId = message.groupId ?? message.id;
    final visibleIndex = _messages.indexWhere(
      (candidate) => (candidate.groupId ?? candidate.id) == groupId,
    );
    if (visibleIndex >= 0) {
      // An edited revision belongs to the same logical timeline slot. Keep the
      // current bounded window intact so the list can preserve its visible
      // anchor while only this slot remeasures its extent. Preserve the current
      // visible-group snapshot until its asynchronous refresh completes so
      // unrelated version switchers do not briefly disappear.
      final visibleSnapshot = List<ChatMessage>.of(
        _messagesWithVisibleGroups(),
      );
      final groupInsertIndex = visibleSnapshot.indexWhere(
        (candidate) => (candidate.groupId ?? candidate.id) == groupId,
      );
      final groupMessages =
          visibleSnapshot
              .where(
                (candidate) => (candidate.groupId ?? candidate.id) == groupId,
              )
              .where((candidate) => candidate.id != message.id)
              .toList()
            ..add(message)
            ..sort((left, right) => left.version.compareTo(right.version));

      _messages[visibleIndex] = message;
      if (truncateFollowingSlots) {
        _messages.removeRange(visibleIndex + 1, _messages.length);
        _totalMessageCount = _loadedStartIndex + _messages.length;
      }
      invalidateCache();
      if (groupInsertIndex >= 0) {
        visibleSnapshot.removeWhere(
          (candidate) => (candidate.groupId ?? candidate.id) == groupId,
        );
        visibleSnapshot.insertAll(groupInsertIndex, groupMessages);
        if (truncateFollowingSlots) {
          visibleSnapshot.removeRange(
            groupInsertIndex + groupMessages.length,
            visibleSnapshot.length,
          );
        }
        _messagesWithVisibleGroupsCache = visibleSnapshot;
      }
      _loadVersionSelections();
      await _preloadVisibleGroupData();
      if (_currentConversation?.id != conversation.id) return false;
      notifyListeners();
      return true;
    }

    final opened = await loadWindowAroundMessage(
      message.id,
      leadingContext: ChatService.defaultHistoryPageSize,
    );
    return opened;
  }

  /// Publishes one atomic persistence result to the loaded tail as one UI
  /// mutation. A send begins with a user/assistant pair, so refreshing the
  /// persisted count between those two messages would briefly create a false
  /// gap and trigger an unnecessary window reload.
  ///
  /// Normal path appends the already-persisted messages straight into the
  /// loaded window with no timeline query; only a detected count gap falls
  /// back to the full window reload.
  Future<bool> appendPersistedTailMessages(List<ChatMessage> messages) async {
    if (messages.isEmpty) return false;
    final conversation = _currentConversation;
    if (conversation == null ||
        messages.any((message) => message.conversationId != conversation.id)) {
      return false;
    }

    if (_tryAppendPersistedTail(conversation.id, messages)) {
      invalidateCache();
      await _preloadVisibleGroupData();
      notifyListeners();
      return true;
    }

    // Fallback: the window does not provably cover the persisted tail, so
    // reload the whole tail window instead of appending blindly.
    final page = await _chatService.loadTimelinePage(
      conversation.id,
      limit: ChatService.defaultLoadedWindowMax,
    );
    if (_currentConversation?.id != conversation.id) return false;
    _replaceWindow(page);
    await _preloadVisibleGroupData();
    notifyListeners();
    return true;
  }

  /// Folds persisted tail messages into the loaded window without a timeline
  /// query. Returns false when contiguity cannot be proven, so the caller
  /// falls back to the full window reload.
  bool _tryAppendPersistedTail(
    String conversationId,
    List<ChatMessage> messages,
  ) {
    // The loaded window must currently reach the persisted tail.
    if (_loadedStartIndex + _messages.length != _totalMessageCount) {
      return false;
    }

    // Every incoming message must open a new slot. A new version of a loaded
    // group would change that slot's selection, which only a reload resolves.
    final knownGroups = <String>{
      for (final loaded in _messages) loaded.groupId ?? loaded.id,
    };
    final batchGroups = <String>{};
    for (final message in messages) {
      final groupId = message.groupId ?? message.id;
      if (knownGroups.contains(groupId) || !batchGroups.add(groupId)) {
        return false;
      }
    }

    // Gap detection compares persisted row (revision) indices only — never
    // the collapsed slot count, which multi-version conversations make
    // diverge from the row count. The batch must occupy the final rows
    // directly after the loaded tail; anything else means an unseen mutation
    // landed in between.
    // Unknown count (-1) fails `rowCount < messages.length` and conservatively
    // skips the fast append path (falls back to a full reload).
    final rowCount = _chatService.getMessageCount(conversationId);
    if (rowCount < messages.length) return false;
    final firstRowIndex = _chatService.getMessageIndex(
      conversationId,
      messages.first.id,
    );
    final lastRowIndex = _chatService.getMessageIndex(
      conversationId,
      messages.last.id,
    );
    if (firstRowIndex != rowCount - messages.length ||
        lastRowIndex != rowCount - 1) {
      return false;
    }
    if (_messages.isNotEmpty) {
      final tailRowIndex = _chatService.getMessageIndex(
        conversationId,
        _messages.last.id,
      );
      if (tailRowIndex != firstRowIndex - 1) return false;
    } else if (firstRowIndex != 0) {
      return false;
    }

    _messages.addAll(messages);
    _totalMessageCount += messages.length;
    if (_messages.length > ChatService.defaultLoadedWindowMax) {
      final removeCount = _messages.length - ChatService.defaultLoadedWindowMax;
      _messages.removeRange(0, removeCount);
      _loadedStartIndex += removeCount;
    }
    return true;
  }

  /// Update a message in the list.
  void updateMessageInList(String messageId, ChatMessage updatedMessage) {
    if (!replaceMessageSnapshot(updatedMessage)) return;
    publishGenerationState(
      updatedMessage.conversationId,
      isGenerating: updatedMessage.isStreaming,
    );
    notifyListeners();
  }

  /// Mirrors an in-memory message snapshot into the timeline window without
  /// publishing a full-window change. Streaming UI has its own narrow notifier.
  bool replaceMessageSnapshot(ChatMessage updatedMessage) {
    if (_currentConversation?.id != updatedMessage.conversationId) {
      return false;
    }
    final index = _messages.indexWhere(
      (message) => message.id == updatedMessage.id,
    );
    if (index < 0) return false;
    _messages[index] = updatedMessage;
    invalidateCache();
    return true;
  }

  bool publishGenerationStarted(ChatMessage message) {
    final streamingMessage = message.isStreaming
        ? message
        : message.copyWith(isStreaming: true);
    final replaced = replaceMessageSnapshot(streamingMessage);
    publishGenerationState(message.conversationId, isGenerating: true);
    return replaced;
  }

  bool publishGenerationState(
    String conversationId, {
    required bool isGenerating,
  }) {
    return _currentConversation?.id == conversationId;
  }

  /// Publishes a terminal generation snapshot and always closes the timeline's
  /// generation lifecycle, even when the message is outside the loaded window.
  bool publishTerminalMessage(ChatMessage message) {
    final terminalMessage = message.isStreaming
        ? message.copyWith(isStreaming: false)
        : message;
    final replaced = replaceMessageSnapshot(terminalMessage);
    publishGenerationState(message.conversationId, isGenerating: false);
    return replaced;
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

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final updatedMessage = _messages[index].copyWith(
        content: content ?? _messages[index].content,
        totalTokens: totalTokens ?? _messages[index].totalTokens,
        isStreaming: isStreaming ?? _messages[index].isStreaming,
      );
      replaceMessageSnapshot(updatedMessage);
      publishGenerationState(
        updatedMessage.conversationId,
        isGenerating: updatedMessage.isStreaming,
      );
      notifyListeners();
    }
  }

  // ============================================================================
  // Version Selection
  // ============================================================================

  /// Get the selected real version number for a message group.
  int getSelectedVersion(String groupId) {
    return _versionSelections[groupId] ?? -1;
  }

  /// Set the selected real version number for a message group.
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
      if (loading && _loadingConversationIds.length == 1) {
        ScreenWakelock.acquire();
      } else if (!loading && _loadingConversationIds.isEmpty) {
        ScreenWakelock.release();
      }
      if (!loading &&
          _currentConversation?.id == conversationId &&
          !_chatService.isConversationFullyCached(conversationId)) {
        // Resume an idle backfill that generation paused.
        _scheduleIdleCacheBackfill(conversationId);
      }
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
      ChatMessage? selected;
      if (sel != null) {
        for (final candidate in vers) {
          if (candidate.version == sel) {
            selected = candidate;
            break;
          }
        }
      }
      out.add(selected ?? vers.last);
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

    final windowMessagesById = {
      for (final message in _messages) message.id: message,
    };
    final visibleIds = windowMessagesById.keys;
    final byGroup = <String, List<ChatMessage>>{};
    for (final cachedMessage in visibleVersions) {
      final message = windowMessagesById[cachedMessage.id] ?? cachedMessage;
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
      versionCounts: {
        for (final entry in groupedMessages.entries)
          entry.key: entry.value.length,
      },
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
    cancelAllStreams();
    ScreenWakelock.releaseNow();
    super.dispose();
  }
}
