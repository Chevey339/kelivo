import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../database/app_database.dart';
import '../../database/chat_database_gateway.dart';
import '../../database/chat_database_repository.dart';
import '../../database/generation_run.dart';
import '../../database/message_graph_projector.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/app_directories.dart';

class ChatService extends ChangeNotifier {
  ChatService({ChatDatabaseGateway? databaseGateway})
    : _databaseGateway = databaseGateway ?? ChatDatabaseGateway.instance;

  static const int defaultInitialMessageMin = 2;
  static const int defaultInitialMessageMax = 240;
  static const int defaultInitialTextBudget = 20000;
  static const int defaultHistoryPageSize = 20;
  static const int defaultLoadedWindowMax = 360;

  late ChatDatabaseRepository _repo;
  late File _databaseFile;
  final ChatDatabaseGateway _databaseGateway;
  ChatDatabaseLease? _databaseLease;

  String? _currentConversationId;
  final Map<String, List<ChatMessage>> _messagesCache = {};
  final Map<String, Conversation> _conversationsCache = {};
  final Map<String, Conversation> _draftConversations = {};
  final Set<String> _temporaryConversationIds = <String>{};
  final Map<String, List<Map<String, dynamic>>> _temporaryToolEvents =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, String> _temporaryGeminiThoughtSigs = <String, String>{};
  final Map<String, List<Map<String, dynamic>>> _toolEventsCache = {};
  final Map<String, String> _geminiThoughtSigsCache = {};
  final Map<String, Map<String, int>> _firstGroupIndicesCache = {};
  final Map<String, int> _messageCounts = {};
  final Map<String, List<String>> _messageOrderIds = {};
  final Map<String, MessageGraphTimelineProjection> _messageGraphCache = {};
  final Map<String, Map<String, int>> _graphVersionSelections = {};
  final Map<String, int> _graphContextStartIndices = {};

  // Localized default title for new conversations; set by UI on startup.
  String _defaultConversationTitle = 'New Chat';
  void setDefaultConversationTitle(String title) {
    if (title.trim().isEmpty) return;
    _defaultConversationTitle = title.trim();
  }

  bool _initialized = false;
  Future<void>? _initFuture;
  bool get initialized => _initialized;

  String? get currentConversationId => _currentConversationId;

  bool isTemporaryConversation(String? id) {
    return id != null && _temporaryConversationIds.contains(id);
  }

  Future<void> init() {
    if (_initialized) return Future<void>.value();
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;
    final initialization = _initialize();
    _initFuture = initialization;
    return initialization.whenComplete(() {
      if (identical(_initFuture, initialization)) _initFuture = null;
    });
  }

  Future<void> _initialize() async {
    final appDataDir = await AppDirectories.getAppDataDirectory();
    if (!await appDataDir.exists()) {
      await appDataDir.create(recursive: true);
    }
    _databaseFile = File(p.join(appDataDir.path, AppDatabase.databaseFileName));
    final lease = await _databaseGateway.acquire(_databaseFile);
    _databaseLease = lease;
    _repo = lease.repository;
    try {
      // Versioned and transactional: normal launches return before scanning rows.
      await _migrateSandboxPaths();
      await _repo.backfillMissingMessageGraphs();
      await _loadConversationsCache();

      // Reset any stale isStreaming flags left over from a previous app crash or
      // force-quit. After a fresh launch no message can be actively streaming.
      await _resetStaleStreamingFlags();

      _initialized = true;
      notifyListeners();
    } catch (_) {
      _databaseLease = null;
      await lease.release();
      rethrow;
    }
  }

  Future<void> close() async {
    final initialization = _initFuture;
    if (initialization != null) {
      try {
        await initialization;
      } catch (_) {
        return;
      }
    }
    if (!_initialized) return;
    _initialized = false;
    final lease = _databaseLease;
    _databaseLease = null;
    await lease?.release();
  }

  @override
  void dispose() {
    if (_initialized || _initFuture != null) {
      unawaited(close());
    }
    super.dispose();
  }

  Future<void> _loadConversationsCache() async {
    final conversations = await _repo.getAllConversationSummaries();
    final messageCounts = await _repo.getMessageCountsByConversation();
    _toolEventsCache.clear();
    _geminiThoughtSigsCache.clear();
    _messageGraphCache.clear();
    _graphVersionSelections.clear();
    _graphContextStartIndices.clear();
    _messageOrderIds.clear();
    _messageCounts
      ..clear()
      ..addAll(messageCounts);
    _conversationsCache
      ..clear()
      ..addEntries(
        conversations.map(
          (conversation) => MapEntry(conversation.id, conversation),
        ),
      );
  }

  Future<List<String>> _loadMessageOrder(String conversationId) async {
    final cached = _messageOrderIds[conversationId];
    if (cached != null) return cached;
    final ids = (await _repo.getMessageIds(
      conversationId,
    )).toList(growable: true);
    _messageOrderIds[conversationId] = ids;
    _messageCounts[conversationId] = ids.length;
    return ids;
  }

  Future<MessageGraphTimelineProjection?> loadMessageGraphTimeline(
    String conversationId, {
    bool force = false,
  }) async {
    if (!_initialized && _initFuture == null) return null;
    if (!force) {
      final cached = _messageGraphCache[conversationId];
      if (cached != null) return cached;
    }
    final timeline = await _repo.projectMessageGraphTimeline(
      conversationId: conversationId,
    );
    if (timeline == null) return null;
    _messageGraphCache[conversationId] = timeline;

    final selectedIds = [
      for (final entry in timeline.selectedRevisionBySlot.entries)
        if ((timeline.revisionsBySlot[entry.key]?.length ?? 0) > 1) entry.value,
    ];
    final selectedMessages = await _repo.getMessagesByIds(selectedIds);
    _graphVersionSelections[conversationId] = {
      for (final message in selectedMessages)
        message.groupId ?? message.id: message.version,
    };

    final boundaryId = timeline.contextStartRevisionId;
    if (boundaryId == null) {
      _graphContextStartIndices.remove(conversationId);
    } else {
      final boundary = await _repo.getMessage(boundaryId);
      if (boundary != null) {
        final groupId = boundary.groupId ?? boundary.id;
        final indices = await _repo.getFirstMessageIndicesForGroups(
          conversationId,
          [groupId],
        );
        final index = indices[groupId];
        if (index != null) _graphContextStartIndices[conversationId] = index;
      }
    }
    return timeline;
  }

  int getContextStartIndex(String conversationId) =>
      _graphContextStartIndices[conversationId] ?? -1;

  String? getContextStartRevisionId(String conversationId) =>
      _messageGraphCache[conversationId]?.contextStartRevisionId;

  Future<void> _cacheMessageArtifacts(Iterable<ChatMessage> messages) async {
    final ids = messages.map((message) => message.id).toSet();
    if (ids.isEmpty) return;
    final results = await Future.wait([
      _repo.getToolEventsForMessages(ids),
      _repo.getGeminiThoughtSignaturesForMessages(ids),
    ]);
    for (final id in ids) {
      _toolEventsCache.remove(id);
      _geminiThoughtSigsCache.remove(id);
    }
    _toolEventsCache.addAll(
      results[0] as Map<String, List<Map<String, dynamic>>>,
    );
    _geminiThoughtSigsCache.addAll(results[1] as Map<String, String>);
  }

  void _cacheLoadedMessages(
    String conversationId,
    Iterable<ChatMessage> messages,
  ) {
    if (_conversationForMessages(conversationId) == null) return;
    final byId = <String, ChatMessage>{
      for (final message in _messagesCache[conversationId] ?? const [])
        message.id: message,
      for (final message in messages) message.id: message,
    };
    _messagesCache[conversationId] = [
      for (final id in _messageOrderIds[conversationId] ?? const <String>[])
        if (byId[id] != null) byId[id]!,
    ];
  }

  List<Conversation> getAllConversations() {
    if (!_initialized) return [];
    final conversations = _conversationsCache.values.toList();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  List<Conversation> getAllCompleteConversations() {
    return getAllConversations();
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
    return _conversationsCache[id];
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
    return _messageCounts[conversationId] ?? 0;
  }

  int getMessageIndex(String conversationId, String messageId) {
    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId];
      if (messages == null) return -1;
      return messages.indexWhere((message) => message.id == messageId);
    }
    return _messageOrderIds[conversationId]?.indexOf(messageId) ?? -1;
  }

  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    if (!_initialized) return const <String, int>{};
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const <String, int>{};
    final cached = _firstGroupIndicesCache[conversationId] ?? const {};
    return {
      for (final id in ids)
        if (cached[id] != null) id: cached[id]!,
    };
  }

  Future<Map<String, int>> loadFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async {
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const {};
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      final result = <String, int>{};
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      for (var i = 0; i < messages.length; i++) {
        final groupId = messages[i].groupId ?? messages[i].id;
        if (ids.contains(groupId)) result.putIfAbsent(groupId, () => i);
      }
      return result;
    }
    final loaded = await _repo.getFirstMessageIndicesForGroups(
      conversationId,
      ids,
    );
    _firstGroupIndicesCache
        .putIfAbsent(conversationId, () => {})
        .addAll(loaded);
    return loaded;
  }

  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    if (!_initialized) return const <ChatMessage>[];
    final ids = groupIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const <ChatMessage>[];
    final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
    return messages
        .where((message) => ids.contains(message.groupId ?? message.id))
        .toList(growable: false);
  }

  Future<List<ChatMessage>> loadMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async {
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      return getMessagesForGroups(conversationId, groupIds);
    }
    await _loadMessageOrder(conversationId);
    final messages = await _repo.getMessagesForGroups(conversationId, groupIds);
    _cacheLoadedMessages(conversationId, messages);
    await _cacheMessageArtifacts(messages);
    return messages;
  }

  Future<List<ConversationSearchMatch>> searchConversationMatches({
    required List<String> tokens,
    int limit = 200,
  }) async {
    if (!_initialized) return const <ConversationSearchMatch>[];
    return _repo.searchConversationMatches(tokens: tokens, limit: limit);
  }

  List<ChatMessage> getMessages(String conversationId) {
    if (!_initialized) return const [];
    return _messagesCache[conversationId] ?? const [];
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    if (!_initialized) return const [];
    final cached = _messagesCache[conversationId];
    if (cached != null && cached.length == getMessageCount(conversationId)) {
      return cached;
    }
    final conversation =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId];
    if (conversation == null) return [];

    final messages = _temporaryConversationIds.contains(conversationId)
        ? (_messagesCache[conversationId] ?? const <ChatMessage>[])
        : await _repo.getMessagesRange(
            conversationId,
            start: 0,
            limit: getMessageCount(conversationId),
          );

    if (!_temporaryConversationIds.contains(conversationId)) {
      await _cacheMessageArtifacts(messages);
    }

    // Cache the result
    _messagesCache[conversationId] = List.of(messages);
    return messages;
  }

  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    if (!_initialized || limit <= 0) return const [];
    if (_temporaryConversationIds.contains(conversationId)) {
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      final safeStart = start.clamp(0, messages.length).toInt();
      final end = (safeStart + limit).clamp(safeStart, messages.length).toInt();
      return messages.sublist(safeStart, end);
    }
    if (_conversationForMessages(conversationId) == null) return const [];
    final ids = _messageOrderIds[conversationId] ?? const <String>[];
    final safeStart = start.clamp(0, ids.length).toInt();
    final end = (safeStart + limit).clamp(safeStart, ids.length).toInt();
    final byId = {
      for (final message in _messagesCache[conversationId] ?? const [])
        message.id: message,
    };
    return [
      for (final id in ids.sublist(safeStart, end))
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<ChatMessage>> loadMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) async {
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

    await _loadMessageOrder(conversationId);

    final messages = await _repo.getMessagesRange(
      conversationId,
      start: start,
      limit: limit,
    );
    _cacheLoadedMessages(conversationId, messages);
    await _cacheMessageArtifacts(messages);
    return messages;
  }

  List<ChatMessage> getRecentMessages(
    String conversationId, {
    int minMessages = defaultInitialMessageMin,
    int textBudget = defaultInitialTextBudget,
    int maxMessages = defaultInitialMessageMax,
  }) {
    final cached = _messagesCache[conversationId] ?? const <ChatMessage>[];
    if (cached.length <= maxMessages) return List.of(cached);
    return cached.sublist(cached.length - maxMessages);
  }

  Future<List<ChatMessage>> loadRecentMessages(
    String conversationId, {
    int minMessages = defaultInitialMessageMin,
    int textBudget = defaultInitialTextBudget,
    int maxMessages = defaultInitialMessageMax,
  }) async {
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
      final batch = await loadMessagesRange(
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
      final previous = await loadMessagesRange(
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
    final conversation = await _repo.getConversation(conversationId);
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
    if (SandboxPathResolver.docsDir == null) {
      await SandboxPathResolver.init();
    }
    final targetRoot = SandboxPathResolver.docsDir;
    if (targetRoot == null || targetRoot.isEmpty) {
      throw StateError('sandbox_path_resolver_not_ready');
    }
    final imgRe = RegExp(r"\[image:(.+?)\]");
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    await _repo.migrateSandboxPaths(
      targetVersion: 1,
      targetRoot: targetRoot,
      rewriteContent: (content) {
        var updated = content.replaceAllMapped(imgRe, (match) {
          final raw = (match.group(1) ?? '').trim();
          return '[image:${SandboxPathResolver.fix(raw)}]';
        });
        updated = updated.replaceAllMapped(fileRe, (match) {
          final raw = (match.group(1) ?? '').trim();
          final name = (match.group(2) ?? '').trim();
          final mime = (match.group(3) ?? '').trim();
          return '[file:${SandboxPathResolver.fix(raw)}|$name|$mime]';
        });
        return updated;
      },
    );
  }

  /// Reset stale isStreaming flags left over from a previous app crash or
  /// force-quit.  After a fresh launch no message can be actively streaming,
  /// so any persisted `isStreaming: true` is stale and must be cleared to
  /// avoid stuck loading indicators.
  ///
  Future<void> _resetStaleStreamingFlags() async {
    await _repo.resetStaleStreamingState();
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
          final messages = await loadMessagesRange(
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
    await _repo.putMigrationBatch(
      conversations: [restored],
      messages: [
        for (final (index, message) in messages.indexed)
          (message: message, messageOrder: index),
      ],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await _repo.backfillMissingMessageGraphs();
    await _refreshConversation(restored.id);

    // Update caches
    _messagesCache[restored.id] = List.of(messages);
    _messageOrderIds[restored.id] = messages
        .map((message) => message.id)
        .toList(growable: true);
    _messageCounts[restored.id] = messages.length;
    await loadMessageGraphTimeline(restored.id, force: true);

    notifyListeners();
  }

  Future<void> replaceAllDataFromBackup({
    required List<Conversation> conversations,
    required List<ChatMessage> messages,
    required Map<String, List<Map<String, dynamic>>> toolEventsByMessageId,
    required Map<String, String> geminiSignaturesByMessageId,
  }) async {
    if (!_initialized) await init();

    final nextOrderByConversation = <String, int>{};
    final orderedMessages = <({ChatMessage message, int messageOrder})>[];
    for (final message in messages) {
      final messageOrder = nextOrderByConversation.update(
        message.conversationId,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      orderedMessages.add((message: message, messageOrder: messageOrder));
    }

    await _repo.replaceBackupData(
      conversations: conversations,
      messages: orderedMessages,
      toolEventsByMessageId: toolEventsByMessageId,
      geminiSignaturesByMessageId: geminiSignaturesByMessageId,
    );

    await _resetAfterOverwriteRestore();
  }

  Future<ChatDatabaseSnapshotInfo> createBackupDatabaseSnapshot(
    File destinationFile,
  ) async {
    if (!_initialized) await init();
    final sourcePath = _databaseFile.path;
    final destinationPath = destinationFile.path;
    return Isolate.run(
      () => ChatDatabaseRepository.createConsistentSnapshot(
        sourceFile: File(sourcePath),
        destinationFile: File(destinationPath),
      ),
    );
  }

  Future<void> restoreDatabaseSnapshot(File snapshotFile) async {
    if (!_initialized) await init();
    await _repo.replaceBackupSnapshot(snapshotFile);
    await _resetAfterOverwriteRestore();
  }

  Future<BackupMergeReport> mergeDatabaseSnapshot(File snapshotFile) async {
    if (!_initialized) await init();
    final report = await _repo.mergeBackupSnapshot(snapshotFile);
    _messagesCache.clear();
    await _repo.backfillMissingMessageGraphs();
    await _loadConversationsCache();
    notifyListeners();
    return report;
  }

  Future<void> _resetAfterOverwriteRestore() async {
    _messagesCache.clear();
    _draftConversations.clear();
    _temporaryConversationIds.clear();
    _temporaryToolEvents.clear();
    _temporaryGeminiThoughtSigs.clear();
    _toolEventsCache.clear();
    _geminiThoughtSigsCache.clear();
    _messageCounts.clear();
    _messageOrderIds.clear();
    _messageGraphCache.clear();
    _graphVersionSelections.clear();
    _graphContextStartIndices.clear();
    _currentConversationId = null;
    await _repo.backfillMissingMessageGraphs();
    await _loadConversationsCache();
    notifyListeners();
  }

  // Add a message directly to an existing conversation (for merge mode)
  Future<void> addMessageDirectly(
    String conversationId,
    ChatMessage message,
  ) async {
    if (!_initialized) await init();

    final conversation = _conversationsCache[conversationId];
    if (conversation == null) return;
    final order = await _loadMessageOrder(conversationId);
    if (order.contains(message.id)) return;
    final persisted = await _repo.appendGraphMessageToConversation(
      conversation: conversation,
      message: message,
      touchUpdatedAt: false,
    );
    _conversationsCache[conversationId] = persisted;
    order.add(message.id);
    _messageCounts[conversationId] = order.length;
    await loadMessageGraphTimeline(conversationId, force: true);

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
    bool selectVersion = false,
  }) async {
    if (!_initialized) await init();

    var conversation = _conversationsCache[conversationId];
    final temporary = _temporaryConversationIds.contains(conversationId);
    if (conversation == null) {
      final draft = temporary
          ? _draftConversations[conversationId]
          : _draftConversations[conversationId];
      if (draft != null) {
        conversation = draft;
      } else {
        conversation = Conversation(
          id: conversationId,
          title: _defaultConversationTitle,
        );
        if (temporary) {
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

    if (temporary) {
      conversation.messageIds.add(message.id);
      conversation.updatedAt = DateTime.now();
      if (selectVersion) {
        conversation.versionSelections[message.groupId ?? message.id] =
            message.version;
      }
      _messagesCache.putIfAbsent(conversationId, () => <ChatMessage>[]);
    } else {
      if (_conversationsCache.containsKey(conversationId)) {
        await _loadMessageOrder(conversationId);
      }
      final persisted = await _repo.appendGraphMessageToConversation(
        conversation: conversation,
        message: message,
        selectVersion: selectVersion,
      );
      _draftConversations.remove(conversationId);
      _conversationsCache[conversationId] = persisted;
      conversation = persisted;
      final order = _messageOrderIds.putIfAbsent(
        conversationId,
        () => <String>[],
      );
      if (!order.contains(message.id)) order.add(message.id);
      _messageCounts[conversationId] = order.length;
      await loadMessageGraphTimeline(conversationId, force: true);
    }

    // Update cache
    if (_messagesCache.containsKey(conversationId)) {
      _messagesCache[conversationId]!.add(message);
    }

    notifyListeners();
    return message;
  }

  Future<GenerationBeginResult> beginSendGeneration({
    required String conversationId,
    required String userContent,
    required String modelId,
    required String providerId,
  }) async {
    if (!_initialized) await init();
    if (isTemporaryConversation(conversationId)) {
      throw StateError('temporary_generation_is_not_persisted');
    }
    final conversation =
        _conversationsCache[conversationId] ??
        _draftConversations[conversationId] ??
        Conversation(id: conversationId, title: _defaultConversationTitle);
    if (_conversationsCache.containsKey(conversationId)) {
      await _loadMessageOrder(conversationId);
    }
    final userMessage = ChatMessage(
      role: 'user',
      content: userContent,
      conversationId: conversationId,
    );
    final assistantMessage = ChatMessage(
      role: 'assistant',
      content: '',
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerId,
      isStreaming: true,
    );
    final result = await _repo.beginSendGeneration(
      conversation: conversation,
      userMessage: userMessage,
      assistantMessage: assistantMessage,
      runId: const Uuid().v4(),
    );
    await _publishGenerationBegin(result);
    return result;
  }

  Future<GenerationBeginResult> beginRegeneration({
    required String conversationId,
    required String modelId,
    required String providerId,
    required String groupId,
    required int version,
  }) async {
    if (!_initialized) await init();
    if (isTemporaryConversation(conversationId)) {
      throw StateError('temporary_generation_is_not_persisted');
    }
    final conversation = _conversationsCache[conversationId];
    if (conversation == null) throw StateError('conversation_missing');
    await _loadMessageOrder(conversationId);
    final assistantMessage = ChatMessage(
      role: 'assistant',
      content: '',
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerId,
      isStreaming: true,
      groupId: groupId,
      version: version,
    );
    final result = await _repo.beginRegeneration(
      conversation: conversation,
      assistantMessage: assistantMessage,
      runId: const Uuid().v4(),
    );
    await _publishGenerationBegin(result);
    return result;
  }

  Future<void> _publishGenerationBegin(GenerationBeginResult result) async {
    final conversationId = result.conversation.id;
    _draftConversations.remove(conversationId);
    _conversationsCache[conversationId] = result.conversation;
    final messages = [
      if (result.userMessage case final userMessage?) userMessage,
      result.assistantMessage,
    ];
    final order = _messageOrderIds.putIfAbsent(
      conversationId,
      () => <String>[],
    );
    for (final message in messages) {
      if (!order.contains(message.id)) order.add(message.id);
    }
    _messageCounts[conversationId] = order.length;
    if (_messagesCache.containsKey(conversationId)) {
      _messagesCache[conversationId]!.addAll(messages);
    }
    await loadMessageGraphTimeline(conversationId, force: true);
    notifyListeners();
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
        await _repo.getMessage(messageId) ?? _cachedTemporaryMessage(messageId);
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

    await _repo.updateMessageAndStreamingState(
      updatedMessage,
      untrackStreaming: isStreaming == false,
    );

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
        await _repo.getMessage(messageId) ?? _cachedTemporaryMessage(messageId);
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

    await _repo.updateMessageAndStreamingState(
      updatedMessage,
      untrackStreaming: isStreaming == false,
    );

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

  /// Persists one complete streaming snapshot without a read-before-write.
  Future<void> updateStreamingCheckpointSilent(
    ChatMessage message,
    List<Map<String, dynamic>> toolEvents, {
    String? generationRunId,
    int? checkpointSeq,
  }) async {
    if (!_initialized) return;

    if (isTemporaryConversation(message.conversationId)) {
      _replaceCachedMessage(message);
      _temporaryToolEvents[message.id] = List<Map<String, dynamic>>.of(
        toolEvents,
      );
      return;
    }

    await _repo.updateStreamingCheckpoint(
      message,
      toolEvents,
      generationRunId: generationRunId,
      checkpointSeq: checkpointSeq,
    );
    _replaceCachedMessage(message);
    _toolEventsCache[message.id] = List<Map<String, dynamic>>.of(toolEvents);
  }

  Future<GenerationRun> transitionGenerationRun({
    required String id,
    required GenerationRunState expectedState,
    required int expectedStateRevision,
    required GenerationRunState nextState,
    String? errorCode,
  }) => _repo.transitionGenerationRun(
    id: id,
    expectedState: expectedState,
    expectedStateRevision: expectedStateRevision,
    nextState: nextState,
    updatedAt: DateTime.now().toUtc(),
    errorCode: errorCode,
  );

  Future<GenerationRun?> finalizeGenerationRunSilent({
    required ChatMessage message,
    required List<Map<String, dynamic>> toolEvents,
    required String? generationRunId,
    required GenerationRunState? expectedState,
    required int? expectedStateRevision,
    required GenerationRunState terminalState,
    int? checkpointSeq,
    String? errorCode,
  }) async {
    if (!_initialized) return null;
    if (isTemporaryConversation(message.conversationId) ||
        generationRunId == null) {
      await updateStreamingCheckpointSilent(message, toolEvents);
      return null;
    }
    if (expectedState == null || expectedStateRevision == null) {
      throw StateError('generation_run_cursor_missing');
    }
    final run = await _repo.finalizeGenerationRun(
      message: message,
      toolEvents: toolEvents,
      generationRunId: generationRunId,
      expectedState: expectedState,
      expectedStateRevision: expectedStateRevision,
      terminalState: terminalState,
      checkpointSeq: checkpointSeq,
      errorCode: errorCode,
      geminiThoughtSignature: _geminiThoughtSigsCache[message.id],
    );
    _replaceCachedMessage(message);
    _toolEventsCache[message.id] = List<Map<String, dynamic>>.of(toolEvents);
    return run;
  }

  // Tool events persistence (per assistant message)
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    if (!_initialized) return const <Map<String, dynamic>>[];
    final temporary = _temporaryToolEvents[assistantMessageId];
    if (temporary != null) return List<Map<String, dynamic>>.of(temporary);
    return List<Map<String, dynamic>>.of(
      _toolEventsCache[assistantMessageId] ?? const [],
    );
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
    _toolEventsCache[assistantMessageId] = list;
    notifyListeners();
  }

  // Gemini thought signature persistence (per assistant message)
  String? getGeminiThoughtSignature(String assistantMessageId) {
    if (!_initialized) return null;
    final temporary = _temporaryGeminiThoughtSigs[assistantMessageId];
    if (temporary != null && temporary.trim().isNotEmpty) return temporary;
    return _geminiThoughtSigsCache[assistantMessageId];
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
    _geminiThoughtSigsCache[assistantMessageId] = signature;
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
      _geminiThoughtSigsCache.remove(assistantMessageId);
    } catch (_) {}
  }

  Future<Conversation> forkConversationAtRevision({
    required String sourceConversationId,
    required String sourceRevisionId,
    required String title,
  }) async {
    if (!_initialized) await init();
    final timeline = await loadMessageGraphTimeline(sourceConversationId);
    if (timeline?.branchId == null ||
        !timeline!.activeRevisions.any(
          (revision) => revision.revisionId == sourceRevisionId,
        )) {
      throw StateError('message_graph_target_not_on_branch');
    }
    final target = Conversation(title: title);
    await _repo.forkMessageGraphConversationWithShadow(
      sourceConversationId: sourceConversationId,
      sourceBranchId: timeline.branchId!,
      sourceRevisionId: sourceRevisionId,
      targetConversationId: target.id,
      title: title,
    );
    final persisted = await _repo.getConversation(target.id);
    if (persisted == null) throw StateError('message_graph_fork_missing');
    _conversationsCache[persisted.id] = persisted;
    final messages = await _repo.getMessagesRange(
      persisted.id,
      start: 0,
      limit: await _repo.getMessageCount(persisted.id),
    );
    _messagesCache[persisted.id] = messages;
    _messageOrderIds[persisted.id] = messages
        .map((message) => message.id)
        .toList(growable: true);
    _messageCounts[persisted.id] = messages.length;
    await loadMessageGraphTimeline(persisted.id, force: true);
    _currentConversationId = persisted.id;
    notifyListeners();
    return persisted;
  }

  Future<ChatMessage?> appendMessageVersion({
    required String messageId,
    required String content,
  }) async {
    if (!_initialized) await init();
    final original = await _repo.getMessage(messageId);
    if (original != null) await _loadMessageOrder(original.conversationId);
    final result = await _repo.appendMessageVersion(
      messageId: messageId,
      content: content,
    );
    if (result == null) return null;
    final newMsg = result.message;
    final cid = newMsg.conversationId;
    _conversationsCache[cid] = result.conversation;
    final order = _messageOrderIds.putIfAbsent(cid, () => <String>[]);
    if (!order.contains(newMsg.id)) order.add(newMsg.id);
    _messageCounts[cid] = order.length;
    await loadMessageGraphTimeline(cid, force: true);
    // Update caches
    final arr = _messagesCache[cid];
    if (arr != null) arr.add(newMsg);
    notifyListeners();
    return newMsg;
  }

  Map<String, int> getVersionSelections(String conversationId) {
    if (_draftConversations.containsKey(conversationId)) {
      return Map<String, int>.from(
        _draftConversations[conversationId]!.versionSelections,
      );
    }
    return Map<String, int>.from(
      _graphVersionSelections[conversationId] ?? const <String, int>{},
    );
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
    final candidates = await _repo.getMessagesForGroups(conversationId, [
      groupId,
    ]);
    ChatMessage? target;
    for (final candidate in candidates) {
      if (candidate.version == version) {
        target = candidate;
        break;
      }
    }
    if (target == null) throw StateError('message_graph_revision_missing');
    await selectMessageRevision(conversationId, target.id);
  }

  Future<void> selectMessageRevision(
    String conversationId,
    String revisionId,
  ) async {
    await _repo.selectMessageGraphRevision(
      conversationId: conversationId,
      revisionId: revisionId,
    );
    await loadMessageGraphTimeline(conversationId, force: true);
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
    // A graph path always selects exactly one revision for every visible slot.
    // Clearing a legacy JSON override therefore means refreshing the derived
    // selection rather than writing an absent ordinal.
    await loadMessageGraphTimeline(conversationId, force: true);
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
    final timeline = await loadMessageGraphTimeline(conversationId);
    if (timeline == null || timeline.activeRevisions.isEmpty) return c;
    final currentBoundary = timeline.contextStartRevisionId;
    final tailRevisionId = timeline.activeRevisions.last.revisionId;
    await _repo.setMessageGraphContextBoundary(
      conversationId: conversationId,
      revisionId: currentBoundary == tailRevisionId ? null : tailRevisionId,
      expectedStateRevision: timeline.stateRevision,
    );
    if ((defaultTitle ?? '').isNotEmpty) c.title = defaultTitle!;
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
    await loadMessageGraphTimeline(conversationId, force: true);
    notifyListeners();
    return c;
  }

  Future<void> deleteMessage(String messageId) async {
    if (!_initialized) return;

    final message =
        await _repo.getMessage(messageId) ?? _cachedTemporaryMessage(messageId);
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
    if (conversation == null) return;
    await deleteMessages(
      conversationId: conversation.id,
      messageIds: {messageId},
      versionSelectionChanges: const {},
    );
  }

  Future<void> deleteMessages({
    required String conversationId,
    required Set<String> messageIds,
    required Map<String, int?> versionSelectionChanges,
  }) async {
    if (!_initialized || messageIds.isEmpty) return;
    final result = await _repo.deleteGraphMessages(
      conversationId: conversationId,
      revisionIds: messageIds,
    );
    if (result == null) return;

    _conversationsCache[conversationId] = result.conversation;
    for (final message in result.messages) {
      _toolEventsCache.remove(message.id);
      _geminiThoughtSigsCache.remove(message.id);
    }
    _messagesCache.remove(conversationId);
    _messageOrderIds.remove(conversationId);
    _messageCounts[conversationId] = await _repo.getMessageCount(
      conversationId,
    );
    _messageGraphCache.remove(conversationId);
    _graphVersionSelections.remove(conversationId);
    _graphContextStartIndices.remove(conversationId);
    await loadMessageGraphTimeline(conversationId, force: true);
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

  Future<void> clearAllData({bool deleteUploads = true}) async {
    if (!_initialized) await init();

    await _repo.clearAllData();
    _messagesCache.clear();
    _conversationsCache.clear();
    _draftConversations.clear();
    _temporaryConversationIds.clear();
    _temporaryToolEvents.clear();
    _temporaryGeminiThoughtSigs.clear();
    _toolEventsCache.clear();
    _geminiThoughtSigsCache.clear();
    _messageCounts.clear();
    _messageOrderIds.clear();
    _messageGraphCache.clear();
    _graphVersionSelections.clear();
    _graphContextStartIndices.clear();
    _currentConversationId = null;
    if (deleteUploads) {
      final uploadDir = await AppDirectories.getUploadDirectory();
      if (await uploadDir.exists()) {
        await uploadDir.delete(recursive: true);
      }
    }
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
