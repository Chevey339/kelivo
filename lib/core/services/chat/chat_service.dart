import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../database/app_database.dart';
import '../../database/chat_database_repository.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/app_directories.dart';

class ChatService extends ChangeNotifier {
  static const int defaultInitialMessageMin = 2;
  static const int defaultInitialMessageMax = 240;
  static const int defaultInitialTextBudget = 20000;
  static const int defaultHistoryPageSize = 20;
  static const int defaultLoadedWindowMax = 360;

  late ChatDatabaseRepository _repo;

  String? _currentConversationId;
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, Conversation> _conversationsCache = {};
  final Map<String, Conversation> _draftConversations = {};
  final Set<String> _temporaryConversationIds = <String>{};
  final Map<String, List<Map<String, dynamic>>> _temporaryToolEvents =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, String> _temporaryGeminiThoughtSigs = <String, String>{};

  // Localized default title for new conversations; set by UI on startup.
  String _defaultConversationTitle = 'New Chat';
  void setDefaultConversationTitle(String title) {
    if (title.trim().isEmpty) return;
    _defaultConversationTitle = title.trim();
  }

  bool _initialized = false;
  bool get initialized => _initialized;

  String? get currentConversationId => _currentConversationId;

  bool isTemporaryConversation(String? id) {
    return id != null && _temporaryConversationIds.contains(id);
  }

  Future<void> init() async {
    if (_initialized) return;

    final appDataDir = await AppDirectories.getAppDataDirectory();
    if (!await appDataDir.exists()) {
      await appDataDir.create(recursive: true);
    }
    _repo = ChatDatabaseRepository.open(
      file: File(p.join(appDataDir.path, AppDatabase.databaseFileName)),
    );
    await _repo.ensureReady();
    await _loadConversationsCache();

    // Migrate any persisted message content that references old iOS sandbox paths
    await _migrateSandboxPaths();

    // Reset any stale isStreaming flags left over from a previous app crash or
    // force-quit.  After a fresh launch no message can be actively streaming.
    await _resetStaleStreamingFlags();

    _initialized = true;
    notifyListeners();
  }

  Future<void> close() async {
    if (!_initialized) return;
    await _repo.close();
    _initialized = false;
  }

  @override
  void dispose() {
    if (_initialized) {
      unawaited(_repo.close());
    }
    super.dispose();
  }

  Future<void> _loadConversationsCache() async {
    _conversationsCache
      ..clear()
      ..addEntries(
        _repo.getAllConversationsSync().map(
          (conversation) => MapEntry(conversation.id, conversation),
        ),
      );
  }

  List<Conversation> getAllConversations() {
    if (!_initialized) return [];
    final conversations = _conversationsCache.values.toList();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  List<Conversation> getAllCompleteConversations() {
    if (!_initialized) return [];
    final conversations = _repo.getAllCompleteConversationsSync();
    return conversations;
  }

  List<Conversation> getPinnedConversations() {
    return getAllConversations().where((c) => c.isPinned).toList();
  }

  Conversation? getConversation(String id) {
    if (!_initialized) return null;
    return _conversationsCache[id] ?? _draftConversations[id];
  }

  Conversation? getCompleteConversation(String id) {
    if (!_initialized) return null;
    final draft = _draftConversations[id];
    if (draft != null) return draft;
    final conversation = _repo.getConversationSync(id, includeMessageIds: true);
    if (conversation == null) {
      _conversationsCache.remove(id);
      return null;
    }
    return conversation;
  }

  Conversation? _conversationForMessages(String conversationId) {
    if (!_initialized) return _draftConversations[conversationId];
    return _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
  }

  int getMessageCount(String conversationId) {
    if (_temporaryConversationIds.contains(conversationId)) {
      return _messagesCache[conversationId]?.length ?? 0;
    }
    if (!_initialized) return 0;
    if (_conversationsCache.containsKey(conversationId)) {
      return _repo.getMessageCountSync(conversationId);
    }
    final conversation = _conversationForMessages(conversationId);
    return conversation?.messageIds.length ?? 0;
  }

  int getMessageIndex(String conversationId, String messageId) {
    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId];
      if (messages == null) return -1;
      return messages.indexWhere((message) => message.id == messageId);
    }
    if (_initialized && _conversationsCache.containsKey(conversationId)) {
      return _repo.getMessageIndexSync(conversationId, messageId);
    }
    if (_draftConversations.containsKey(conversationId)) {
      return _draftConversations[conversationId]!.messageIds.indexOf(messageId);
    }
    return -1;
  }

  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    if (!_initialized) return const <String, int>{};
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      final remaining = groupIds.where((id) => id.isNotEmpty).toSet();
      if (remaining.isEmpty) return const <String, int>{};
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      final result = <String, int>{};
      for (var i = 0; i < messages.length && remaining.isNotEmpty; i++) {
        final groupId = messages[i].groupId ?? messages[i].id;
        if (remaining.remove(groupId)) result[groupId] = i;
      }
      return result;
    }
    return _repo.getFirstMessageIndicesForGroupsSync(conversationId, groupIds);
  }

  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    if (!_initialized) return const <ChatMessage>[];
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      final remaining = groupIds.where((id) => id.isNotEmpty).toSet();
      if (remaining.isEmpty) return const <ChatMessage>[];
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      return messages
          .where((message) {
            final groupId = message.groupId ?? message.id;
            return remaining.contains(groupId);
          })
          .toList(growable: false);
    }
    return _repo.getMessagesForGroupsSync(conversationId, groupIds);
  }

  List<ConversationSearchMatch> searchConversationMatches({
    required List<String> tokens,
    int limit = 200,
  }) {
    if (!_initialized) return const <ConversationSearchMatch>[];
    return _repo.searchConversationMatchesSync(tokens: tokens, limit: limit);
  }

  List<ChatMessage> getMessages(String conversationId) {
    if (!_initialized) return [];

    // Check cache first
    if (_messagesCache.containsKey(conversationId)) {
      return _messagesCache[conversationId]!;
    }

    // Load from storage
    final conversation =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
    if (conversation == null) return [];

    final messages = _temporaryConversationIds.contains(conversationId)
        ? (_messagesCache[conversationId] ?? const <ChatMessage>[])
        : _repo.getMessagesRangeSync(
            conversationId,
            start: 0,
            limit: _repo.getMessageCountSync(conversationId),
          );

    // Cache the result
    _messagesCache[conversationId] = List.of(messages);
    return messages;
  }

  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    if (!_initialized || limit <= 0) return const <ChatMessage>[];

    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      final safeStart = start.clamp(0, messages.length).toInt();
      final end = (safeStart + limit).clamp(safeStart, messages.length).toInt();
      return safeStart >= end
          ? const <ChatMessage>[]
          : messages.sublist(safeStart, end);
    }

    final conversation = _conversationForMessages(conversationId);
    if (conversation == null) {
      return const <ChatMessage>[];
    }

    return _repo.getMessagesRangeSync(
      conversationId,
      start: start,
      limit: limit,
    );
  }

  List<ChatMessage> getRecentMessages(
    String conversationId, {
    int minMessages = defaultInitialMessageMin,
    int textBudget = defaultInitialTextBudget,
    int maxMessages = defaultInitialMessageMax,
  }) {
    if (!_initialized) return const <ChatMessage>[];

    final conversation = _conversationForMessages(conversationId);
    if (conversation == null) {
      return const <ChatMessage>[];
    }

    final total = getMessageCount(conversationId);
    if (total == 0) return const <ChatMessage>[];
    final minCount = minMessages.clamp(1, total).toInt();
    final maxCount = maxMessages < minCount ? minCount : maxMessages;
    final budget = textBudget <= 0 ? defaultInitialTextBudget : textBudget;

    var start = total;
    var loaded = 0;
    var weight = 0;
    final selected = <ChatMessage>[];
    while (start > 0 && loaded < maxCount) {
      final batchStart = (start - defaultHistoryPageSize)
          .clamp(0, start)
          .toInt();
      final batch = getMessagesRange(
        conversationId,
        start: batchStart,
        limit: start - batchStart,
      );
      for (var i = batch.length - 1; i >= 0 && loaded < maxCount; i--) {
        final message = batch[i];
        selected.insert(0, message);
        loaded++;
        weight += _estimateInitialLoadWeight(message);
        if (loaded >= minCount && weight >= budget) break;
      }
      start = batchStart;
      if (loaded >= minCount && weight >= budget) break;
    }

    if (selected.isNotEmpty && selected.length.isOdd && start > 0) {
      final previous = getMessagesRange(
        conversationId,
        start: start - 1,
        limit: 1,
      );
      if (previous.isNotEmpty) {
        selected.insert(0, previous.first);
        start--;
      }
    }

    return selected;
  }

  int _estimateInitialLoadWeight(ChatMessage message) {
    final len = message.content.length;
    if (message.role == 'user') return len < 200 ? 200 : len;
    if (message.role == 'assistant') return (len * 0.8).round();
    return len;
  }

  Future<Conversation> createConversation({
    String? title,
    String? assistantId,
  }) async {
    if (!_initialized) await init();
    _discardTemporaryConversation(_currentConversationId);

    final conversation = Conversation(
      title: title ?? _defaultConversationTitle,
      assistantId: assistantId,
    );

    await _saveConversation(conversation);
    _currentConversationId = conversation.id;
    notifyListeners();
    return conversation;
  }

  Future<void> _saveConversation(Conversation conversation) async {
    if (_temporaryConversationIds.contains(conversation.id)) {
      _draftConversations[conversation.id] = conversation;
      return;
    }
    await _repo.putConversation(conversation);
    _conversationsCache[conversation.id] = conversation;
  }

  Future<void> _refreshConversation(String conversationId) async {
    if (_temporaryConversationIds.contains(conversationId)) return;
    final conversation = _repo.getConversationSync(
      conversationId,
      includeMessageIds:
          _conversationsCache[conversationId]?.messageIds.isNotEmpty == true,
    );
    if (conversation == null) {
      _conversationsCache.remove(conversationId);
    } else {
      _conversationsCache[conversationId] = conversation;
    }
  }

  // Create a draft conversation that is not persisted until first message arrives.
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
    bool temporary = false,
  }) async {
    if (!_initialized) await init();
    _discardTemporaryConversation(_currentConversationId);
    final conversation = Conversation(
      title: title ?? _defaultConversationTitle,
      assistantId: assistantId,
    );
    _draftConversations[conversation.id] = conversation;
    if (temporary) {
      _temporaryConversationIds.add(conversation.id);
      _messagesCache[conversation.id] = <ChatMessage>[];
    }
    _currentConversationId = conversation.id;
    notifyListeners();
    return conversation;
  }

  void _discardTemporaryConversation(String? id) {
    if (id == null || !_temporaryConversationIds.remove(id)) return;
    final messages = _messagesCache[id] ?? const <ChatMessage>[];
    for (final message in messages) {
      _temporaryToolEvents.remove(message.id);
      _temporaryGeminiThoughtSigs.remove(message.id);
    }
    _draftConversations.remove(id);
    _messagesCache.remove(id);
    if (_currentConversationId == id) {
      _currentConversationId = null;
    }
  }

  Future<void> deleteConversation(String id) async {
    if (!_initialized) return;

    final deleted =
        await _deleteDraftConversation(id) ||
        await _deletePersistedConversation(id);
    if (!deleted) return;

    // Delete orphaned files (not referenced by any remaining conversation)
    await _cleanupOrphanUploads();

    notifyListeners();
  }

  Future<bool> _deleteDraftConversation(String id) async {
    if (!_draftConversations.containsKey(id)) return false;

    _draftConversations.remove(id);
    _temporaryConversationIds.remove(id);
    final messages = _messagesCache[id] ?? const <ChatMessage>[];
    for (final message in messages) {
      _temporaryToolEvents.remove(message.id);
      _temporaryGeminiThoughtSigs.remove(message.id);
    }
    _messagesCache.remove(id);
    if (_currentConversationId == id) {
      _currentConversationId = null;
    }
    return true;
  }

  Future<bool> _deletePersistedConversation(String id) async {
    final conversation = _conversationsCache[id];
    if (conversation == null) return false;

    await _repo.deleteConversation(id);
    _conversationsCache.remove(id);
    _messagesCache.remove(id);

    if (_currentConversationId == id) {
      _currentConversationId = null;
    }
    return true;
  }

  Future<void> deleteConversationsForAssistant(String assistantId) async {
    if (!_initialized) await init();

    final targetId = assistantId.trim();
    if (targetId.isEmpty) return;

    final persistedConversationIds = _conversationsCache.values
        .where((conversation) => conversation.assistantId == targetId)
        .map((conversation) => conversation.id)
        .toList(growable: false);
    final draftConversationIds = _draftConversations.values
        .where((conversation) => conversation.assistantId == targetId)
        .map((conversation) => conversation.id)
        .toList(growable: false);

    var deleted = false;
    for (final conversationId in draftConversationIds) {
      deleted = await _deleteDraftConversation(conversationId) || deleted;
    }
    for (final conversationId in persistedConversationIds) {
      deleted = await _deletePersistedConversation(conversationId) || deleted;
    }

    if (!deleted) return;
    await _cleanupOrphanUploads();
    notifyListeners();
  }

  Set<String> _extractAttachmentPaths(String content) {
    final out = <String>{};
    final imgRe = RegExp(r"\[image:(.+?)\]");
    for (final m in imgRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null &&
          pth.isNotEmpty &&
          !pth.startsWith('http') &&
          !pth.startsWith('data:')) {
        out.add(SandboxPathResolver.fix(pth));
      }
    }
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    for (final m in fileRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null &&
          pth.isNotEmpty &&
          !pth.startsWith('http') &&
          !pth.startsWith('data:')) {
        out.add(SandboxPathResolver.fix(pth));
      }
    }
    return out;
  }

  Future<void> _migrateSandboxPaths() async {
    try {
      // No-op if empty
      final count = getMessageCount(_currentConversationId ?? '');
      if (count == 0 && _conversationsCache.isEmpty) return;
      final imgRe = RegExp(r"\[image:(.+?)\]");
      final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");

      for (final conversation in _conversationsCache.values) {
        final total = getMessageCount(conversation.id);
        for (var start = 0; start < total; start += defaultLoadedWindowMax) {
          final messages = getMessagesRange(
            conversation.id,
            start: start,
            limit: defaultLoadedWindowMax,
          );
          for (final msg in messages) {
            final content = msg.content;
            String updated = content;
            bool changed = false;

            // Rewrite image paths
            updated = updated.replaceAllMapped(imgRe, (m) {
              final raw = (m.group(1) ?? '').trim();
              final fixed = SandboxPathResolver.fix(raw);
              if (fixed != raw) changed = true;
              return '[image:$fixed]';
            });

            // Rewrite file attachment paths
            updated = updated.replaceAllMapped(fileRe, (m) {
              final raw = (m.group(1) ?? '').trim();
              final name = (m.group(2) ?? '').trim();
              final mime = (m.group(3) ?? '').trim();
              final fixed = SandboxPathResolver.fix(raw);
              if (fixed != raw) changed = true;
              return '[file:$fixed|$name|$mime]';
            });

            if (changed && updated != content) {
              final newMsg = msg.copyWith(content: updated);
              await _repo.updateMessage(newMsg);
              _replaceCachedMessage(newMsg);
            }
          }
        }
      }
    } catch (_) {
      // best-effort migration; ignore errors
    }
  }

  /// Reset stale isStreaming flags left over from a previous app crash or
  /// force-quit.  After a fresh launch no message can be actively streaming,
  /// so any persisted `isStreaming: true` is stale and must be cleared to
  /// avoid stuck loading indicators.
  ///
  /// Uses a tracked set of streaming message IDs for O(1) lookup instead of
  /// scanning every message in the box.
  Future<void> _resetStaleStreamingFlags() async {
    try {
      final ids = await _repo.getActiveStreamingIds();
      if (ids.isEmpty) return;
      for (final id in ids) {
        final msg = _repo.getMessageSync(id);
        if (msg != null && msg.isStreaming) {
          await _repo.updateMessage(msg.copyWith(isStreaming: false));
        }
      }
      await _repo.clearActiveStreamingIds();
    } catch (_) {
      // best-effort; ignore errors
    }
  }

  /// Record a message ID as actively streaming.
  void _trackStreamingId(String messageId) {
    try {
      final ids = _repo.getActiveStreamingIds().then((value) => value.toList());
      ids.then((list) {
        if (!list.contains(messageId)) {
          list.add(messageId);
          _repo.setActiveStreamingIds(list);
        }
      });
    } catch (_) {}
  }

  /// Remove a message ID from the active streaming set.
  void _untrackStreamingId(String messageId) {
    try {
      _repo.untrackActiveStreamingId(messageId);
    } catch (_) {}
  }

  Future<void> _cleanupOrphanUploads() async {
    try {
      final uploadDir = await AppDirectories.getUploadDirectory();
      if (!await uploadDir.exists()) return;

      // Build the set of all referenced paths across all messages
      String canon(String pth) {
        // Normalize separators and resolve redundant segments to enable
        // reliable equality checks across platforms (esp. Windows).
        final normalized = p.normalize(pth);
        // On Windows, paths are case-insensitive; compare in lowercase.
        return Platform.isWindows ? normalized.toLowerCase() : normalized;
      }

      final referenced = <String>{};
      for (final conversation in _conversationsCache.values) {
        final total = getMessageCount(conversation.id);
        for (var start = 0; start < total; start += defaultLoadedWindowMax) {
          final messages = getMessagesRange(
            conversation.id,
            start: start,
            limit: defaultLoadedWindowMax,
          );
          for (final m in messages) {
            for (final pth in _extractAttachmentPaths(m.content)) {
              referenced.add(canon(pth));
            }
          }
        }
      }

      // Walk upload directory recursively to consider all files
      final entries = uploadDir.listSync(recursive: true, followLinks: false);
      for (final ent in entries) {
        if (ent is File) {
          final filePath = canon(ent.path);
          if (!referenced.contains(filePath)) {
            try {
              await ent.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> restoreConversation(
    Conversation conversation,
    List<ChatMessage> messages,
  ) async {
    if (!_initialized) await init();
    // Ensure messageIds are in the same order
    final ids = messages.map((m) => m.id).toList();
    final restored = Conversation(
      id: conversation.id,
      title: conversation.title,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
      messageIds: ids,
      isPinned: conversation.isPinned,
      mcpServerIds: List.of(conversation.mcpServerIds),
      truncateIndex: conversation.truncateIndex,
      assistantId: conversation.assistantId,
      versionSelections: Map<String, int>.from(conversation.versionSelections),
      summary: conversation.summary,
      lastSummarizedMessageCount: conversation.lastSummarizedMessageCount,
      chatSuggestions: List<String>.of(conversation.chatSuggestions),
    );
    await _saveConversation(restored);
    for (var i = 0; i < messages.length; i++) {
      await _repo.putMessage(messages[i], messageOrder: i);
    }
    await _refreshConversation(restored.id);

    // Update caches
    _messagesCache[restored.id] = List.of(messages);

    notifyListeners();
  }

  // Add a message directly to an existing conversation (for merge mode)
  Future<void> addMessageDirectly(
    String conversationId,
    ChatMessage message,
  ) async {
    if (!_initialized) await init();

    // Update conversation
    final conversation = _conversationsCache[conversationId];
    if (conversation != null) {
      if (!conversation.messageIds.contains(message.id)) {
        conversation.messageIds.add(message.id);
        // Keep original updatedAt during restore
        await _saveConversation(conversation);
      }
    }
    await _repo.putMessage(
      message,
      messageOrder: conversation?.messageIds.indexOf(message.id),
    );
    await _refreshConversation(conversationId);

    // Update cache
    if (_messagesCache.containsKey(conversationId)) {
      if (!_messagesCache[conversationId]!.any((m) => m.id == message.id)) {
        _messagesCache[conversationId]!.add(message);
      }
    }

    notifyListeners();
  }

  // Conversation-scoped MCP servers selection
  List<String> getConversationMcpServers(String conversationId) {
    if (!_initialized) return const <String>[];
    final c =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
    return c?.mcpServerIds ?? const <String>[];
  }

  Future<void> setConversationMcpServers(
    String conversationId,
    List<String> serverIds,
  ) async {
    if (!_initialized) await init();
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.mcpServerIds = List.of(serverIds);
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    final c = _conversationsCache[conversationId];
    if (c == null) return;
    c.mcpServerIds = List.of(serverIds);
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    notifyListeners();
  }

  Future<void> toggleConversationMcpServer(
    String conversationId,
    String serverId,
    bool enabled,
  ) async {
    final current = getConversationMcpServers(conversationId);
    final set = current.toSet();
    if (enabled) {
      set.add(serverId);
    } else {
      set.remove(serverId);
    }
    await setConversationMcpServers(conversationId, set.toList());
  }

  Future<void> renameConversation(String id, String newTitle) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.title = newTitle;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    final conversation = _conversationsCache[id];
    if (conversation == null) return;

    conversation.title = newTitle;
    conversation.updatedAt = DateTime.now();
    await _saveConversation(conversation);
    notifyListeners();
  }

  /// Updates the conversation summary generated by LLM.
  Future<void> updateConversationSummary(
    String id,
    String summary,
    int messageCount,
  ) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.summary = summary;
      draft.lastSummarizedMessageCount = messageCount;
      notifyListeners();
      return;
    }

    final conversation = _conversationsCache[id];
    if (conversation == null) return;

    conversation.summary = summary;
    conversation.lastSummarizedMessageCount = messageCount;
    await _saveConversation(conversation);
    notifyListeners();
  }

  /// Gets all conversations with non-empty summaries for a specific assistant.
  List<Conversation> getConversationsWithSummaryForAssistant(
    String assistantId,
  ) {
    if (!_initialized) return [];
    return getAllConversations()
        .where(
          (c) =>
              c.assistantId == assistantId &&
              c.summary != null &&
              c.summary!.trim().isNotEmpty,
        )
        .toList();
  }

  /// Clears the summary of a specific conversation.
  Future<void> clearConversationSummary(String conversationId) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.summary = null;
      draft.lastSummarizedMessageCount = 0;
      notifyListeners();
      return;
    }

    final conversation = _conversationsCache[conversationId];
    if (conversation == null) return;

    conversation.summary = null;
    conversation.lastSummarizedMessageCount = 0;
    await _saveConversation(conversation);
    notifyListeners();
  }

  Future<void> updateConversationSuggestions(
    String conversationId,
    List<String> suggestions,
  ) async {
    if (!_initialized) return;

    final clean = suggestions
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();

    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.chatSuggestions = clean;
      notifyListeners();
      return;
    }

    final conversation = _conversationsCache[conversationId];
    if (conversation == null) return;

    conversation.chatSuggestions = clean;
    await _saveConversation(conversation);
    notifyListeners();
  }

  Future<void> clearConversationSuggestions(String conversationId) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      if (draft.chatSuggestions.isEmpty) return;
      draft.chatSuggestions = <String>[];
      notifyListeners();
      return;
    }

    final conversation = _conversationsCache[conversationId];
    if (conversation == null || conversation.chatSuggestions.isEmpty) return;

    conversation.chatSuggestions = <String>[];
    await _saveConversation(conversation);
    notifyListeners();
  }

  Future<void> togglePinConversation(String id) async {
    if (!_initialized) return;

    if (_draftConversations.containsKey(id)) {
      final draft = _draftConversations[id]!;
      draft.isPinned = !draft.isPinned;
      notifyListeners();
      return;
    }
    final conversation = _conversationsCache[id];
    if (conversation == null) return;

    conversation.isPinned = !conversation.isPinned;
    await _saveConversation(conversation);
    notifyListeners();
  }

  Future<ChatMessage> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? modelId,
    String? providerId,
    int? totalTokens,
    bool isStreaming = false,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? groupId,
    int? version,
  }) async {
    if (!_initialized) await init();

    var conversation = _conversationsCache[conversationId];
    final temporary = _temporaryConversationIds.contains(conversationId);
    // If conversation doesn't exist yet, persist draft (if any)
    if (conversation == null) {
      final draft = temporary
          ? _draftConversations[conversationId]
          : _draftConversations.remove(conversationId);
      if (draft != null) {
        if (!temporary) {
          await _saveConversation(draft);
        }
        conversation = draft;
      } else {
        // Create a new one on the fly as a fallback
        conversation = Conversation(
          id: conversationId,
          title: _defaultConversationTitle,
        );
        if (!temporary) {
          await _saveConversation(conversation);
        } else {
          _draftConversations[conversationId] = conversation;
        }
      }
    }

    final message = ChatMessage(
      role: role,
      content: content,
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerId,
      totalTokens: totalTokens,
      isStreaming: isStreaming,
      reasoningText: reasoningText,
      reasoningStartAt: reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt,
      groupId: groupId,
      version: version,
    );

    if (!temporary) {
      await _repo.putMessage(
        message,
        messageOrder: getMessageCount(conversationId),
      );
    }

    // Track streaming state for crash-recovery cleanup
    if (isStreaming && !temporary) {
      _trackStreamingId(message.id);
    }

    conversation.messageIds.add(message.id);
    conversation.updatedAt = DateTime.now();
    if (temporary) {
      _messagesCache.putIfAbsent(conversationId, () => <ChatMessage>[]);
    } else {
      await _saveConversation(conversation);
    }

    // Update cache
    if (_messagesCache.containsKey(conversationId)) {
      _messagesCache[conversationId]!.add(message);
    }

    notifyListeners();
    return message;
  }

  ChatMessage? _cachedTemporaryMessage(String messageId) {
    for (final entry in _messagesCache.entries) {
      if (!_temporaryConversationIds.contains(entry.key)) continue;
      for (final message in entry.value) {
        if (message.id == messageId) return message;
      }
    }
    return null;
  }

  bool _isTemporaryMessageId(String messageId) {
    return _cachedTemporaryMessage(messageId) != null;
  }

  void _replaceCachedMessage(ChatMessage updatedMessage) {
    final messages = _messagesCache[updatedMessage.conversationId];
    if (messages == null) return;
    final index = messages.indexWhere((m) => m.id == updatedMessage.id);
    if (index >= 0) {
      messages[index] = updatedMessage;
    }
  }

  Future<void> updateMessage(
    String messageId, {
    String? content,
    int? totalTokens,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
  }) async {
    if (!_initialized) return;

    final message =
        _repo.getMessageSync(messageId) ?? _cachedTemporaryMessage(messageId);
    if (message == null) return;

    final updatedMessage = message.copyWith(
      content: content ?? message.content,
      totalTokens: totalTokens ?? message.totalTokens,
      isStreaming: isStreaming ?? message.isStreaming,
      reasoningText: reasoningText ?? message.reasoningText,
      reasoningStartAt: reasoningStartAt ?? message.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? message.reasoningFinishedAt,
      translation: translation,
      reasoningSegmentsJson:
          reasoningSegmentsJson ?? message.reasoningSegmentsJson,
      promptTokens: promptTokens ?? message.promptTokens,
      completionTokens: completionTokens ?? message.completionTokens,
      cachedTokens: cachedTokens ?? message.cachedTokens,
      durationMs: durationMs ?? message.durationMs,
    );

    if (isTemporaryConversation(message.conversationId)) {
      _replaceCachedMessage(updatedMessage);
      notifyListeners();
      return;
    }

    await _repo.updateMessage(updatedMessage);

    // Update streaming tracking for crash-recovery
    if (isStreaming == false) {
      _untrackStreamingId(messageId);
    }

    // Update cache
    final conversationId = message.conversationId;
    if (_messagesCache.containsKey(conversationId)) {
      final messages = _messagesCache[conversationId]!;
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = updatedMessage;
      }
    }

    notifyListeners();
  }

  /// Update message content during streaming without triggering notifyListeners.
  /// This is used for streaming updates to avoid unnecessary rebuilds of
  /// widgets watching ChatService (e.g., side_drawer).
  Future<void> updateMessageSilent(
    String messageId, {
    String? content,
    int? totalTokens,
    bool? isStreaming,
    String? reasoningText,
    DateTime? reasoningStartAt,
    DateTime? reasoningFinishedAt,
    String? translation,
    String? reasoningSegmentsJson,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    int? durationMs,
  }) async {
    if (!_initialized) return;

    final message =
        _repo.getMessageSync(messageId) ?? _cachedTemporaryMessage(messageId);
    if (message == null) return;

    final updatedMessage = message.copyWith(
      content: content ?? message.content,
      totalTokens: totalTokens ?? message.totalTokens,
      isStreaming: isStreaming ?? message.isStreaming,
      reasoningText: reasoningText ?? message.reasoningText,
      reasoningStartAt: reasoningStartAt ?? message.reasoningStartAt,
      reasoningFinishedAt: reasoningFinishedAt ?? message.reasoningFinishedAt,
      translation: translation,
      reasoningSegmentsJson:
          reasoningSegmentsJson ?? message.reasoningSegmentsJson,
      promptTokens: promptTokens ?? message.promptTokens,
      completionTokens: completionTokens ?? message.completionTokens,
      cachedTokens: cachedTokens ?? message.cachedTokens,
      durationMs: durationMs ?? message.durationMs,
    );

    if (isTemporaryConversation(message.conversationId)) {
      _replaceCachedMessage(updatedMessage);
      return;
    }

    await _repo.updateMessage(updatedMessage);

    // Update streaming tracking for crash-recovery
    if (isStreaming == false) {
      _untrackStreamingId(messageId);
    }

    // Update cache
    final conversationId = message.conversationId;
    if (_messagesCache.containsKey(conversationId)) {
      final messages = _messagesCache[conversationId]!;
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = updatedMessage;
      }
    }
    // NOTE: Do NOT call notifyListeners() here to avoid UI rebuilds during streaming
  }

  // Tool events persistence (per assistant message)
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    if (!_initialized) return const <Map<String, dynamic>>[];
    final temporary = _temporaryToolEvents[assistantMessageId];
    if (temporary != null) return List<Map<String, dynamic>>.of(temporary);
    return _repo.getToolEventsSync(assistantMessageId);
  }

  Future<void> setToolEvents(
    String assistantMessageId,
    List<Map<String, dynamic>> events,
  ) async {
    if (!_initialized) await init();
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryToolEvents[assistantMessageId] = List<Map<String, dynamic>>.of(
        events,
      );
      notifyListeners();
      return;
    }
    await _repo.setToolEvents(assistantMessageId, events);
    notifyListeners();
  }

  Future<void> upsertToolEvent(
    String assistantMessageId, {
    required String id,
    required String name,
    required Map<String, dynamic> arguments,
    String? content,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) await init();
    final list = List<Map<String, dynamic>>.of(
      getToolEvents(assistantMessageId),
    );
    final cleanId = (id).toString();

    int idx = -1;
    // Prefer matching by a non-empty id
    if (cleanId.isNotEmpty) {
      idx = list.indexWhere((e) => (e['id']?.toString() ?? '') == cleanId);
    }
    // If no id or not found, match the first placeholder (no content) with same name
    if (idx < 0) {
      idx = list.indexWhere(
        (e) =>
            (e['name']?.toString() ?? '') == name &&
            (e['content'] == null ||
                (e['content']?.toString().isEmpty ?? true)),
      );
    }

    final record = <String, dynamic>{
      'id': cleanId,
      'name': name,
      'arguments': arguments,
      'content': content,
    };
    final existingMetadata = idx >= 0 ? list[idx]['metadata'] : null;
    if (metadata != null && metadata.isNotEmpty) {
      record['metadata'] = metadata;
    } else if (existingMetadata is Map && existingMetadata.isNotEmpty) {
      record['metadata'] = existingMetadata.cast<String, dynamic>();
    }
    if (idx >= 0) {
      list[idx] = record;
    } else {
      list.add(record);
    }
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryToolEvents[assistantMessageId] = list;
      notifyListeners();
      return;
    }
    await _repo.setToolEvents(assistantMessageId, list);
    notifyListeners();
  }

  // Gemini thought signature persistence (per assistant message)
  String? getGeminiThoughtSignature(String assistantMessageId) {
    if (!_initialized) return null;
    final temporary = _temporaryGeminiThoughtSigs[assistantMessageId];
    if (temporary != null && temporary.trim().isNotEmpty) return temporary;
    return _repo.getGeminiThoughtSignatureSync(assistantMessageId);
  }

  Future<void> setGeminiThoughtSignature(
    String assistantMessageId,
    String signature,
  ) async {
    if (!_initialized) await init();
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryGeminiThoughtSigs[assistantMessageId] = signature;
      notifyListeners();
      return;
    }
    await _repo.setGeminiThoughtSignature(assistantMessageId, signature);
    notifyListeners();
  }

  Future<void> removeGeminiThoughtSignature(String assistantMessageId) async {
    if (!_initialized) await init();
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryGeminiThoughtSigs.remove(assistantMessageId);
      return;
    }
    try {
      await _repo.deleteGeminiThoughtSignature(assistantMessageId);
    } catch (_) {}
  }

  Future<Conversation> forkConversation({
    required String title,
    required String? assistantId,
    required List<ChatMessage> sourceMessages,
  }) async {
    if (!_initialized) await init();
    // Create new conversation first
    final convo = await createConversation(
      title: title,
      assistantId: assistantId,
    );
    final ids = <String>[];
    final clones = <ChatMessage>[];
    for (final src in sourceMessages) {
      final clone = ChatMessage(
        role: src.role,
        content: src.content,
        timestamp: src.timestamp,
        modelId: src.modelId,
        providerId: src.providerId,
        totalTokens: src.totalTokens,
        conversationId: convo.id,
        isStreaming: false,
        reasoningText: src.reasoningText,
        reasoningStartAt: src.reasoningStartAt,
        reasoningFinishedAt: src.reasoningFinishedAt,
        translation: src.translation,
        reasoningSegmentsJson: src.reasoningSegmentsJson,
      );
      await _repo.putMessage(clone, messageOrder: ids.length);
      ids.add(clone.id);
      clones.add(clone);
    }
    // Attach to conversation in storage
    final c = _conversationsCache[convo.id];
    if (c != null) {
      c.messageIds
        ..clear()
        ..addAll(ids);
      c.versionSelections = <String, int>{};
      c.updatedAt = DateTime.now();
      await _saveConversation(c);
    }
    // Cache
    _messagesCache[convo.id] = clones;
    notifyListeners();
    return _conversationsCache[convo.id]!;
  }

  Future<ChatMessage?> appendMessageVersion({
    required String messageId,
    required String content,
  }) async {
    if (!_initialized) await init();
    final original = _repo.getMessageSync(messageId);
    if (original == null) return null;

    final cid = original.conversationId;
    final convo = _conversationsCache[cid] ?? _draftConversations[cid];
    if (convo == null) return null;

    final gid = (original.groupId ?? original.id);
    // Find current max version within this group in this conversation
    int maxVersion = -1;
    final groupMessages = getMessagesForGroups(cid, [gid]);
    for (final m in groupMessages) {
      final mg = (m.groupId ?? m.id);
      if (mg == gid) {
        if (m.version > maxVersion) maxVersion = m.version;
      }
    }
    final nextVersion = maxVersion + 1;

    final newMsg = ChatMessage(
      role: original.role,
      content: content,
      conversationId: cid,
      modelId: original.modelId,
      providerId: original.providerId,
      totalTokens: null,
      isStreaming: false,
      groupId: gid,
      version: nextVersion,
    );
    // Append to conversation order at the end (we'll group when rendering)
    if (_draftConversations.containsKey(cid)) {
      final draft = _draftConversations[cid]!;
      draft.messageIds.add(newMsg.id);
      draft.updatedAt = DateTime.now();
      draft.versionSelections[gid] = nextVersion;
    } else {
      final c = _conversationsCache[cid];
      if (c != null) {
        await _repo.putMessage(newMsg, messageOrder: getMessageCount(cid));
        c.messageIds.add(newMsg.id);
        c.updatedAt = DateTime.now();
        // Persist selection of latest version for this group
        c.versionSelections[gid] = nextVersion;
        await _saveConversation(c);
      }
    }
    // Update caches
    final arr = _messagesCache[cid];
    if (arr != null) arr.add(newMsg);
    notifyListeners();
    return newMsg;
  }

  Map<String, int> getVersionSelections(String conversationId) {
    final c =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
    return Map<String, int>.from(c?.versionSelections ?? const <String, int>{});
  }

  Future<void> setSelectedVersion(
    String conversationId,
    String groupId,
    int version,
  ) async {
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.versionSelections[groupId] = version;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    final c = _conversationsCache[conversationId];
    if (c == null) return;
    c.versionSelections[groupId] = version;
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    notifyListeners();
  }

  Future<void> clearSelectedVersion(
    String conversationId,
    String groupId,
  ) async {
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.versionSelections.remove(groupId);
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    final c = _conversationsCache[conversationId];
    if (c == null) return;
    c.versionSelections.remove(groupId);
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    notifyListeners();
  }

  Future<Conversation?> toggleTruncateAtTail(
    String conversationId, {
    String? defaultTitle,
  }) async {
    if (!_initialized) await init();
    // Draft case
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      final lastIndexPlusOne = draft.messageIds.length; // last index + 1
      final newValue = (draft.truncateIndex == lastIndexPlusOne)
          ? -1
          : lastIndexPlusOne;
      draft.truncateIndex = newValue;
      if ((defaultTitle ?? '').isNotEmpty) draft.title = defaultTitle!;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return draft;
    }
    // Persisted case
    final c = _conversationsCache[conversationId];
    if (c == null) return null;
    final lastIndexPlusOne = getMessageCount(conversationId);
    final newValue = (c.truncateIndex == lastIndexPlusOne)
        ? -1
        : lastIndexPlusOne;
    c.truncateIndex = newValue;
    if ((defaultTitle ?? '').isNotEmpty) c.title = defaultTitle!;
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    notifyListeners();
    return c;
  }

  Future<void> deleteMessage(String messageId) async {
    if (!_initialized) return;

    final message =
        _repo.getMessageSync(messageId) ?? _cachedTemporaryMessage(messageId);
    if (message == null) return;

    if (isTemporaryConversation(message.conversationId)) {
      final conversation = _draftConversations[message.conversationId];
      conversation?.messageIds.remove(messageId);
      final messages = _messagesCache[message.conversationId];
      messages?.removeWhere((m) => m.id == messageId);
      _temporaryToolEvents.remove(messageId);
      _temporaryGeminiThoughtSigs.remove(messageId);
      notifyListeners();
      return;
    }

    final conversation = getCompleteConversation(message.conversationId);
    if (conversation != null) {
      final gid = message.groupId ?? message.id;
      final ids = conversation.messageIds;

      // Find the earliest position of this message group before removal so we
      // can keep the group anchored when deleting one of its versions.
      int anchorIndex = -1;
      for (int i = 0; i < ids.length; i++) {
        final mid = ids[i];
        final m = _repo.getMessageSync(mid);
        if (m == null) continue;
        final mgid = m.groupId ?? m.id;
        if (mgid == gid) {
          anchorIndex = i;
          break;
        }
      }

      ids.remove(messageId);

      // If we removed the earliest version but other versions remain, move the
      // earliest remaining one back to the original anchor index to preserve
      // the group's relative order in the conversation.
      if (anchorIndex >= 0) {
        int? earliestRemaining;
        for (int i = 0; i < ids.length; i++) {
          final mid = ids[i];
          final m = _repo.getMessageSync(mid);
          if (m == null) continue;
          final mgid = m.groupId ?? m.id;
          if (mgid == gid) {
            earliestRemaining = i;
            break;
          }
        }

        if (earliestRemaining != null && earliestRemaining > anchorIndex) {
          final replacementId = ids.removeAt(earliestRemaining);
          final insertAt = anchorIndex <= ids.length ? anchorIndex : ids.length;
          ids.insert(insertAt, replacementId);
        }
      }

      await _saveConversation(conversation);
      await _repo.updateMessageOrder(conversation.id, ids);
    }

    await _repo.deleteMessage(messageId);
    await _refreshConversation(message.conversationId);
    // Remove any tool events linked to this assistant message
    if (message.role == 'assistant') {
      try {
        await _repo.deleteToolEvents(message.id);
        await _repo.deleteGeminiThoughtSignature(message.id);
      } catch (_) {}
    }

    // Update cache: clear this conversation so that next getMessages()
    // reloads messages in the updated order from conversation.messageIds.
    _messagesCache.remove(message.conversationId);

    // Clean up orphaned upload files that are no longer referenced by any message
    await _cleanupOrphanUploads();

    notifyListeners();
  }

  void setCurrentConversation(String? id) {
    if (id != _currentConversationId) {
      _discardTemporaryConversation(_currentConversationId);
    }
    _currentConversationId = id;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    if (!_initialized) return;

    await _repo.clearAllData();
    _messagesCache.clear();
    _conversationsCache.clear();
    _draftConversations.clear();
    _temporaryConversationIds.clear();
    _temporaryToolEvents.clear();
    _temporaryGeminiThoughtSigs.clear();
    _currentConversationId = null;
    // Remove uploads directory completely
    try {
      final uploadDir = await AppDirectories.getUploadDirectory();
      if (await uploadDir.exists()) {
        await uploadDir.delete(recursive: true);
      }
    } catch (_) {}
    notifyListeners();
  }

  // Uploads stats: count and total size of files under app documents/upload
  Future<UploadStats> getUploadStats() async {
    try {
      final uploadDir = await AppDirectories.getUploadDirectory();
      if (!await uploadDir.exists()) {
        return const UploadStats(fileCount: 0, totalBytes: 0);
      }
      int count = 0;
      int bytes = 0;
      final entries = uploadDir.listSync(recursive: true, followLinks: false);
      for (final ent in entries) {
        if (ent is File) {
          count += 1;
          try {
            bytes += await ent.length();
          } catch (_) {}
        }
      }
      return UploadStats(fileCount: count, totalBytes: bytes);
    } catch (_) {
      return const UploadStats(fileCount: 0, totalBytes: 0);
    }
  }

  // Move an existing conversation to a different assistant.
  // If the conversation is still a draft, update it in memory;
  // otherwise persist the assistantId change and updatedAt.
  Future<void> moveConversationToAssistant({
    required String conversationId,
    required String assistantId,
  }) async {
    if (!_initialized) await init();

    // Draft conversation case
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.assistantId = assistantId;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }

    final c = _conversationsCache[conversationId];
    if (c == null) return;
    c.assistantId = assistantId;
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    notifyListeners();
  }
}

class UploadStats {
  final int fileCount;
  final int totalBytes;
  const UploadStats({required this.fileCount, required this.totalBytes});
}
