import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../database/kelivo_database.dart';
import '../../database/mappers/chat_message_mapper.dart';
import '../../database/mappers/conversation_mapper.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/app_directories.dart';

class ChatService extends ChangeNotifier {
  static const int defaultInitialMessageMin = 2;
  static const int defaultInitialMessageMax = 240;
  static const int defaultInitialTextBudget = 20000;
  static const int defaultHistoryPageSize = 20;
  static const int defaultLoadedWindowMax = 360;

  late KelivoDatabase _db;
  final Map<String, Conversation> _conversationsCache = {};

  String? _currentConversationId;
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, Conversation> _draftConversations = {};
  final Set<String> _temporaryConversationIds = <String>{};
  final Map<String, List<Map<String, dynamic>>> _temporaryToolEvents =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, String> _temporaryGeminiThoughtSigs = <String, String>{};
  final Map<String, List<Map<String, dynamic>>> _toolEventsCache =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, String?> _thoughtSigsCache = <String, String?>{};

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

  bool isDraft(String id) => _draftConversations.containsKey(id);

  Future<void> init() async {
    if (_initialized) return;

    _db = KelivoDatabase();

    // Preload all conversations into memory cache
    final rows = await _db.select(_db.conversations).get();
    for (final row in rows) {
      _conversationsCache[row.id] = conversationFromRow(row);
    }

    // Preload all messages into memory cache (grouped by conversation)
    final allMessageRows = await _db.select(_db.messages).get();
    final grouped = <String, List<ChatMessage>>{};
    for (final row in allMessageRows) {
      final msg = chatMessageFromRow(row);
      grouped.putIfAbsent(msg.conversationId, () => []).add(msg);
    }
    _messagesCache.addAll(grouped);

    // Migrate any persisted message content that references old iOS sandbox paths
    await _migrateSandboxPaths();

    // Preload tool events and Gemini thought signatures into memory
    final toolRows = await _db.select(_db.toolEvents).get();
    for (final row in toolRows) {
      try {
        _toolEventsCache[row.messageId] =
            (jsonDecode(row.data) as List<dynamic>)
                .cast<Map<String, dynamic>>();
      } catch (_) {
        _toolEventsCache[row.messageId] = const <Map<String, dynamic>>[];
      }
      _thoughtSigsCache[row.messageId] = row.geminiThoughtSig;
    }

    _initialized = true;
    notifyListeners();
  }

  List<Conversation> getAllConversations() {
    if (!_initialized) return [];
    final conversations = _conversationsCache.values.toList();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  List<Conversation> getPinnedConversations() {
    return getAllConversations().where((c) => c.isPinned).toList();
  }

  Conversation? getConversation(String id) {
    if (!_initialized) return null;
    return _conversationsCache[id] ?? _draftConversations[id];
  }

  Conversation? _conversationForMessages(String conversationId) {
    if (!_initialized) return _draftConversations[conversationId];
    return _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
  }

  int getMessageCount(String conversationId) {
    final conversation = _conversationForMessages(conversationId);
    return conversation?.messageIds.length ?? 0;
  }

  int getMessageIndex(String conversationId, String messageId) {
    final conversation = _conversationForMessages(conversationId);
    if (conversation == null) return -1;
    return conversation.messageIds.indexOf(messageId);
  }

  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final remaining = groupIds.where((id) => id.isNotEmpty).toSet();
    if (remaining.isEmpty) return const <String, int>{};

    final result = <String, int>{};
    final count = getMessageCount(conversationId);
    for (
      var start = 0;
      start < count && remaining.isNotEmpty;
      start += defaultLoadedWindowMax
    ) {
      final range = getMessagesRange(
        conversationId,
        start: start,
        limit: defaultLoadedWindowMax,
      );
      for (var offset = 0; offset < range.length; offset++) {
        final message = range[offset];
        final groupId = message.groupId ?? message.id;
        if (remaining.remove(groupId)) {
          result[groupId] = start + offset;
          if (remaining.isEmpty) break;
        }
      }
    }

    return result;
  }

  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final remaining = groupIds.where((id) => id.isNotEmpty).toSet();
    if (remaining.isEmpty) return const <ChatMessage>[];

    final result = <ChatMessage>[];
    final count = getMessageCount(conversationId);
    for (var start = 0; start < count; start += defaultLoadedWindowMax) {
      final range = getMessagesRange(
        conversationId,
        start: start,
        limit: defaultLoadedWindowMax,
      );
      for (final message in range) {
        final groupId = message.groupId ?? message.id;
        if (remaining.contains(groupId)) {
          result.add(message);
        }
      }
    }

    return result;
  }

  ChatMessage? _messageForConversation(
    String conversationId,
    String messageId,
  ) {
    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId];
      if (messages == null) return null;
      for (final message in messages) {
        if (message.id == messageId) return message;
      }
      return null;
    }
    final messages = _messagesCache[conversationId];
    if (messages == null) return null;
    for (final message in messages) {
      if (message.id == messageId) return message;
    }

    return null;
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

    final messages = <ChatMessage>[];
    for (final messageId in conversation.messageIds) {
      final message = _messageForConversation(conversationId, messageId);
      if (message != null) {
        messages.add(message);
      }
    }

    // Cache the result
    _messagesCache[conversationId] = messages;
    return messages;
  }

  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    if (!_initialized || limit <= 0) return const <ChatMessage>[];

    final conversation = _conversationForMessages(conversationId);
    if (conversation == null || conversation.messageIds.isEmpty) {
      return const <ChatMessage>[];
    }

    final ids = conversation.messageIds;
    final safeStart = start.clamp(0, ids.length).toInt();
    final end = (safeStart + limit).clamp(safeStart, ids.length).toInt();
    if (safeStart >= end) return const <ChatMessage>[];

    final messages = <ChatMessage>[];
    for (var i = safeStart; i < end; i++) {
      final message = _messageForConversation(conversationId, ids[i]);
      if (message != null) messages.add(message);
    }
    return messages;
  }

  List<ChatMessage> getRecentMessages(
    String conversationId, {
    int minMessages = defaultInitialMessageMin,
    int textBudget = defaultInitialTextBudget,
    int maxMessages = defaultInitialMessageMax,
  }) {
    if (!_initialized) return const <ChatMessage>[];

    final conversation = _conversationForMessages(conversationId);
    if (conversation == null || conversation.messageIds.isEmpty) {
      return const <ChatMessage>[];
    }

    final ids = conversation.messageIds;
    final minCount = minMessages.clamp(1, ids.length).toInt();
    final maxCount = maxMessages < minCount ? minCount : maxMessages;
    final budget = textBudget <= 0 ? defaultInitialTextBudget : textBudget;

    var start = ids.length;
    var loaded = 0;
    var weight = 0;
    while (start > 0 && loaded < maxCount) {
      start--;
      final message = _messageForConversation(conversationId, ids[start]);
      if (message == null) continue;
      loaded++;
      weight += _estimateInitialLoadWeight(message);
      if (loaded >= minCount && weight >= budget) break;
    }

    if (loaded.isOdd && start > 0 && loaded < maxCount) {
      start--;
    }

    return getMessagesRange(
      conversationId,
      start: start,
      limit: ids.length - start,
    );
  }

  Future<void> ensureMessagesLoaded(String conversationId) async {
    // no-op: all messages are preloaded at init
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

    _conversationsCache[conversation.id] = conversation;
    await _db
        .into(_db.conversations)
        .insert(conversationToCompanion(conversation));
    _currentConversationId = conversation.id;
    notifyListeners();
    return conversation;
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
      _toolEventsCache.remove(message.id);
      _thoughtSigsCache.remove(message.id);
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
      _toolEventsCache.remove(message.id);
      _thoughtSigsCache.remove(message.id);
    }
    _messagesCache.remove(id);
    _conversationsCache.remove(id);
    if (_currentConversationId == id) {
      _currentConversationId = null;
    }
    return true;
  }

  Future<bool> _deletePersistedConversation(String id) async {
    if (!_conversationsCache.containsKey(id)) return false;

    // Cascade delete via SQLite foreign key handles messages + tool_events
    await (_db.delete(_db.conversations)..where((t) => t.id.equals(id))).go();

    _conversationsCache.remove(id);
    final msgs = _messagesCache.remove(id);
    if (msgs != null) {
      for (final m in msgs) {
        _toolEventsCache.remove(m.id);
        _thoughtSigsCache.remove(m.id);
      }
    }

    if (_currentConversationId == id) {
      _currentConversationId = null;
    }
    return true;
  }

  Future<void> deleteConversationsForAssistant(String assistantId) async {
    if (!_initialized) await init();

    final targetId = assistantId.trim();
    if (targetId.isEmpty) return;

    final persistedIds = _conversationsCache.values
        .where((c) => c.assistantId == targetId)
        .map((c) => c.id)
        .toList(growable: false);
    final draftIds = _draftConversations.values
        .where((c) => c.assistantId == targetId)
        .map((c) => c.id)
        .toList(growable: false);

    var deleted = false;
    for (final conversationId in draftIds) {
      deleted = await _deleteDraftConversation(conversationId) || deleted;
    }
    for (final conversationId in persistedIds) {
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
      final rows = await _db.select(_db.messages).get();
      if (rows.isEmpty) return;
      final imgRe = RegExp(r"\[image:(.+?)\]");
      final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");

      for (final row in rows) {
        final msg = chatMessageFromRow(row);
        final content = msg.content;
        String updated = content;
        bool changed = false;

        updated = updated.replaceAllMapped(imgRe, (m) {
          final raw = (m.group(1) ?? '').trim();
          final fixed = SandboxPathResolver.fix(raw);
          if (fixed != raw) changed = true;
          return '[image:$fixed]';
        });

        updated = updated.replaceAllMapped(fileRe, (m) {
          final raw = (m.group(1) ?? '').trim();
          final name = (m.group(2) ?? '').trim();
          final mime = (m.group(3) ?? '').trim();
          final fixed = SandboxPathResolver.fix(raw);
          if (fixed != raw) changed = true;
          return '[file:$fixed|$name|$mime]';
        });

        if (changed && updated != content) {
          await _db
              .update(_db.messages)
              .replace(chatMessageToCompanion(msg.copyWith(content: updated)));
        }
      }
    } catch (_) {
      // best-effort migration; ignore errors
    }
  }

  Future<void> _cleanupOrphanUploads() async {
    try {
      final uploadDir = await AppDirectories.getUploadDirectory();
      if (!await uploadDir.exists()) return;

      String canon(String pth) {
        final normalized = p.normalize(pth);
        return Platform.isWindows ? normalized.toLowerCase() : normalized;
      }

      final referenced = <String>{};
      final msgRows = await _db.select(_db.messages).get();
      for (final row in msgRows) {
        final msg = chatMessageFromRow(row);
        for (final pth in _extractAttachmentPaths(msg.content)) {
          referenced.add(canon(pth));
        }
      }

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
    _conversationsCache[restored.id] = restored;
    await _db
        .into(_db.conversations)
        .insert(conversationToCompanion(restored), mode: InsertMode.replace);
    for (final m in messages) {
      await _db
          .into(_db.messages)
          .insert(chatMessageToCompanion(m), mode: InsertMode.replace);
    }
    _messagesCache[restored.id] = List.of(messages);
    notifyListeners();
  }

  // Add a message directly to an existing conversation (for merge mode)
  Future<void> addMessageDirectly(
    String conversationId,
    ChatMessage message,
  ) async {
    if (!_initialized) await init();

    await _db
        .into(_db.messages)
        .insert(chatMessageToCompanion(message), mode: InsertMode.replace);

    final conversation = _conversationsCache[conversationId];
    if (conversation != null) {
      if (!conversation.messageIds.contains(message.id)) {
        conversation.messageIds.add(message.id);
        await _saveConversation(conversation);
      }
    }

    // Update cache
    final cache = _messagesCache.putIfAbsent(
      conversationId,
      () => <ChatMessage>[],
    );
    if (!cache.any((m) => m.id == message.id)) {
      cache.add(message);
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
    final c = _conversationsCache[id];
    if (c == null) return;
    c.title = newTitle;
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    notifyListeners();
  }

  Future<void> setConversationSummary(
    String conversationId,
    String summary,
  ) async {
    if (!_initialized) return;
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.summary = summary;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    final c = _conversationsCache[conversationId];
    if (c == null) return;
    c.summary = summary;
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    notifyListeners();
  }

  List<String> getChatSuggestions(String conversationId) {
    if (!_initialized) return const <String>[];
    final c =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
    return List<String>.of(c?.chatSuggestions ?? const <String>[]);
  }

  Future<void> setChatSuggestions(
    String conversationId,
    List<String> suggestions,
  ) async {
    if (!_initialized) return;
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.chatSuggestions = List.of(suggestions);
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return;
    }
    final c = _conversationsCache[conversationId];
    if (c == null) return;
    c.chatSuggestions = List.of(suggestions);
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    notifyListeners();
  }

  Future<void> clearChatSuggestions(String conversationId) async {
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
    final c = _conversationsCache[id];
    if (c == null) return;
    c.summary = summary;
    c.lastSummarizedMessageCount = messageCount;
    await _saveConversation(c);
    notifyListeners();
  }

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

  Future<void> clearConversationSummary(String conversationId) async {
    if (!_initialized) return;
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      draft.summary = null;
      draft.lastSummarizedMessageCount = 0;
      notifyListeners();
      return;
    }
    final c = _conversationsCache[conversationId];
    if (c == null) return;
    c.summary = null;
    c.lastSummarizedMessageCount = 0;
    await _saveConversation(c);
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
    final c = _conversationsCache[conversationId];
    if (c == null) return;
    c.chatSuggestions = clean;
    await _saveConversation(c);
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
    final c = _conversationsCache[conversationId];
    if (c == null || c.chatSuggestions.isEmpty) return;
    c.chatSuggestions = <String>[];
    await _saveConversation(c);
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
    if (conversation == null) {
      final draft = temporary
          ? _draftConversations[conversationId]
          : _draftConversations.remove(conversationId);
      if (draft != null) {
        if (!temporary) {
          _conversationsCache[draft.id] = draft;
          await _db
              .into(_db.conversations)
              .insert(conversationToCompanion(draft));
        }
        conversation = draft;
      } else {
        conversation = Conversation(
          id: conversationId,
          title: _defaultConversationTitle,
        );
        if (!temporary) {
          _conversationsCache[conversationId] = conversation;
          await _db
              .into(_db.conversations)
              .insert(conversationToCompanion(conversation));
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
      await _db.into(_db.messages).insert(chatMessageToCompanion(message));
    }

    conversation.messageIds.add(message.id);
    conversation.updatedAt = DateTime.now();
    if (temporary) {
      _messagesCache.putIfAbsent(conversationId, () => <ChatMessage>[]);
    } else {
      await _saveConversation(conversation);
    }

    // Update cache
    _messagesCache
        .putIfAbsent(conversationId, () => <ChatMessage>[])
        .add(message);

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
        _cachedTemporaryMessage(messageId) ?? await _messageFromDb(messageId);
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

    await _db
        .update(_db.messages)
        .replace(chatMessageToCompanion(updatedMessage));

    // Update cache
    final convId = message.conversationId;
    if (_messagesCache.containsKey(convId)) {
      final messages = _messagesCache[convId]!;
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = updatedMessage;
      }
    }

    notifyListeners();
  }

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
        _cachedTemporaryMessage(messageId) ?? await _messageFromDb(messageId);
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

    await _db
        .update(_db.messages)
        .replace(chatMessageToCompanion(updatedMessage));

    // Update cache
    final convId = message.conversationId;
    if (_messagesCache.containsKey(convId)) {
      final messages = _messagesCache[convId]!;
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = updatedMessage;
      }
    }
    // NOTE: Do NOT call notifyListeners() here to avoid UI rebuilds during streaming
  }

  Future<ChatMessage?> _messageFromDb(String messageId) async {
    // Check cache first
    for (final entry in _messagesCache.entries) {
      for (final m in entry.value) {
        if (m.id == messageId) return m;
      }
    }
    // Fallback to PK query
    final row = await (_db.select(
      _db.messages,
    )..where((t) => t.id.equals(messageId))).getSingleOrNull();
    if (row == null) return null;
    return chatMessageFromRow(row);
  }

  // Tool events persistence (per assistant message)
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    if (!_initialized) return const <Map<String, dynamic>>[];
    final temporary = _temporaryToolEvents[assistantMessageId];
    if (temporary != null) return List<Map<String, dynamic>>.of(temporary);
    final cached = _toolEventsCache[assistantMessageId];
    if (cached != null) return List<Map<String, dynamic>>.of(cached);
    return const <Map<String, dynamic>>[];
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
    final jsonStr = jsonEncode(events);
    await _db
        .into(_db.toolEvents)
        .insert(
          ToolEventsCompanion.insert(
            messageId: assistantMessageId,
            data: jsonStr,
          ),
          mode: InsertMode.replace,
        );
    _toolEventsCache[assistantMessageId] = List<Map<String, dynamic>>.of(
      events,
    );
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
    if (cleanId.isNotEmpty) {
      idx = list.indexWhere((e) => (e['id']?.toString() ?? '') == cleanId);
    }
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
    final jsonStr = jsonEncode(list);
    await _db
        .into(_db.toolEvents)
        .insert(
          ToolEventsCompanion.insert(
            messageId: assistantMessageId,
            data: jsonStr,
          ),
          mode: InsertMode.replace,
        );
    _toolEventsCache[assistantMessageId] = list;
    notifyListeners();
  }

  // Gemini thought signature persistence (per assistant message)
  String? getGeminiThoughtSignature(String assistantMessageId) {
    if (!_initialized) return null;
    final temporary = _temporaryGeminiThoughtSigs[assistantMessageId];
    if (temporary != null && temporary.trim().isNotEmpty) return temporary;
    final cached = _thoughtSigsCache[assistantMessageId];
    if (cached != null && cached.trim().isNotEmpty) return cached;
    return null;
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
    // Store in tool_events table's gemini_thought_sig column
    await _db
        .into(_db.toolEvents)
        .insert(
          ToolEventsCompanion.insert(
            messageId: assistantMessageId,
            data: '[]',
            geminiThoughtSig: Value(signature),
          ),
          mode: InsertMode.replace,
        );
    _thoughtSigsCache[assistantMessageId] = signature;
    notifyListeners();
  }

  Future<void> removeGeminiThoughtSignature(String assistantMessageId) async {
    if (!_initialized) await init();
    if (_isTemporaryMessageId(assistantMessageId)) {
      _temporaryGeminiThoughtSigs.remove(assistantMessageId);
      return;
    }
    await (_db.update(_db.toolEvents)
          ..where((t) => t.messageId.equals(assistantMessageId)))
        .write(const ToolEventsCompanion(geminiThoughtSig: Value(null)));
    _thoughtSigsCache.remove(assistantMessageId);
  }

  Future<Conversation> forkConversation({
    required String title,
    required String? assistantId,
    required List<ChatMessage> sourceMessages,
    Map<String, int>? versionSelections,
  }) async {
    if (!_initialized) await init();
    final convo = await createConversation(
      title: title,
      assistantId: assistantId,
    );
    final ids = <String>[];
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
        groupId: src.groupId,
        version: src.version,
      );
      await _db.into(_db.messages).insert(chatMessageToCompanion(clone));
      ids.add(clone.id);
    }
    final c = _conversationsCache[convo.id];
    if (c != null) {
      c.messageIds
        ..clear()
        ..addAll(ids);
      c.versionSelections = Map<String, int>.from(
        versionSelections ?? const <String, int>{},
      );
      c.updatedAt = DateTime.now();
      await _saveConversation(c);
    }
    final loadedMessages = <ChatMessage>[];
    for (final id in ids) {
      final row = await (_db.select(
        _db.messages,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) loadedMessages.add(chatMessageFromRow(row));
    }
    _messagesCache[convo.id] = loadedMessages;
    notifyListeners();
    return _conversationsCache[convo.id]!;
  }

  Future<ChatMessage?> appendMessageVersion({
    required String messageId,
    required String content,
  }) async {
    if (!_initialized) await init();
    final original = await _messageFromDb(messageId);
    if (original == null) return null;

    final cid = original.conversationId;
    final convo = _conversationsCache[cid] ?? _draftConversations[cid];
    if (convo == null) return null;

    final gid = (original.groupId ?? original.id);
    int maxVersion = -1;
    for (final mid in convo.messageIds) {
      final m = await _messageFromDb(mid);
      if (m == null) continue;
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
    await _db.into(_db.messages).insert(chatMessageToCompanion(newMsg));
    if (_draftConversations.containsKey(cid)) {
      final draft = _draftConversations[cid]!;
      draft.messageIds.add(newMsg.id);
      draft.updatedAt = DateTime.now();
      draft.versionSelections[gid] = nextVersion;
    } else {
      final c = _conversationsCache[cid];
      if (c != null) {
        c.messageIds.add(newMsg.id);
        c.updatedAt = DateTime.now();
        c.versionSelections[gid] = nextVersion;
        await _saveConversation(c);
      }
    }
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
    if (_draftConversations.containsKey(conversationId)) {
      final draft = _draftConversations[conversationId]!;
      final lastIndexPlusOne = draft.messageIds.length;
      final newValue = (draft.truncateIndex == lastIndexPlusOne)
          ? -1
          : lastIndexPlusOne;
      draft.truncateIndex = newValue;
      if ((defaultTitle ?? '').isNotEmpty) draft.title = defaultTitle!;
      draft.updatedAt = DateTime.now();
      notifyListeners();
      return draft;
    }
    final c = _conversationsCache[conversationId];
    if (c == null) return null;
    final lastIndexPlusOne = c.messageIds.length;
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
        await _messageFromDb(messageId) ?? _cachedTemporaryMessage(messageId);
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

    final conversation = _conversationsCache[message.conversationId];
    if (conversation != null) {
      final gid = message.groupId ?? message.id;
      final ids = conversation.messageIds;

      int anchorIndex = -1;
      for (int i = 0; i < ids.length; i++) {
        final mid = ids[i];
        final m = await _messageFromDb(mid);
        if (m == null) continue;
        final mgid = m.groupId ?? m.id;
        if (mgid == gid) {
          anchorIndex = i;
          break;
        }
      }

      ids.remove(messageId);

      if (anchorIndex >= 0) {
        int? earliestRemaining;
        for (int i = 0; i < ids.length; i++) {
          final mid = ids[i];
          final m = await _messageFromDb(mid);
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
    }

    // Delete message + cascade tool_events via FK
    await (_db.delete(_db.messages)..where((t) => t.id.equals(messageId))).go();

    _messagesCache.remove(message.conversationId);

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

    await _db.delete(_db.messages).go();
    await _db.delete(_db.conversations).go();
    await _db.delete(_db.toolEvents).go();
    _messagesCache.clear();
    _conversationsCache.clear();
    _draftConversations.clear();
    _temporaryConversationIds.clear();
    _temporaryToolEvents.clear();
    _temporaryGeminiThoughtSigs.clear();
    _toolEventsCache.clear();
    _thoughtSigsCache.clear();
    _currentConversationId = null;
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

  // ── helpers ──────────────────────────────────────────────

  Future<void> _saveConversation(Conversation c) async {
    if (isDraft(c.id)) return;
    await _db.update(_db.conversations).replace(conversationToCompanion(c));
    _conversationsCache[c.id] = c;
  }

  Future<void> close() async {
    if (!_initialized) return;
    await _db.close();
    _initialized = false;
  }
}

class UploadStats {
  final int fileCount;
  final int totalBytes;
  const UploadStats({required this.fileCount, required this.totalBytes});
}
