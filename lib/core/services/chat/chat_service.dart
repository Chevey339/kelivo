import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../database/app_database.dart';
import '../../database/chat_database_gateway.dart';
import '../../database/chat_database_repository.dart';
import '../../database/generation_run.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/app_directories.dart';
import '../backup/portable_ndjson_v2.dart';

final class LoadedTimelineSlot {
  const LoadedTimelineSlot({required this.identity, required this.message});

  final ActiveTimelineSlot identity;
  final ChatMessage message;
}

final class LoadedTimelinePage {
  LoadedTimelinePage({
    required this.conversationId,
    required this.stateRevision,
    required this.contextStartRevisionId,
    required List<LoadedTimelineSlot> slots,
    required this.hasMoreBefore,
    required this.hasMoreAfter,
    required this.totalSlotCount,
  }) : slots = List.unmodifiable(slots);

  final String conversationId;
  final int stateRevision;
  final String? contextStartRevisionId;
  final List<LoadedTimelineSlot> slots;
  final bool hasMoreBefore;
  final bool hasMoreAfter;
  final int totalSlotCount;

  String? get beforeRevisionId => hasMoreBefore && slots.isNotEmpty
      ? slots.first.identity.revisionId
      : null;
  String? get afterRevisionId =>
      hasMoreAfter && slots.isNotEmpty ? slots.last.identity.revisionId : null;
}

typedef AssetContentHash = Future<String> Function(File file);

class ChatService extends ChangeNotifier {
  ChatService({
    ChatDatabaseGateway? databaseGateway,
    AssetContentHash? assetContentHash,
  }) : _databaseGateway = databaseGateway ?? ChatDatabaseGateway.instance,
       _assetContentHash = assetContentHash ?? _hashAssetFile;

  static const int defaultInitialMessageMin = 2;
  static const int defaultInitialMessageMax = 240;
  static const int defaultTimelineInitialSlots = 40;
  static const int defaultInitialTextBudget = 20000;
  static const int defaultHistoryPageSize = 20;
  static const int defaultLoadedWindowMax = 360;
  static const int _messageCacheMaxEntries = 720;
  static const int _messageCacheMaxBytes = 8 * 1024 * 1024;
  static const int _assetReferenceBackfillVersion = 2;
  static const Duration _assetGcDelay = Duration(days: 7);

  late ChatDatabaseRepository _repo;
  late File _databaseFile;
  final ChatDatabaseGateway _databaseGateway;
  final AssetContentHash _assetContentHash;
  ChatDatabaseLease? _databaseLease;
  Future<void>? _assetReferenceMaintenanceFuture;
  Future<void>? _postStartupAssetMaintenanceFuture;

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
      await _loadConversationsCache();

      // Reset any stale isStreaming flags left over from a previous app crash or
      // force-quit. After a fresh launch no message can be actively streaming.
      await _resetStaleStreamingFlags();

      _initialized = true;
      notifyListeners();
      late final Future<void> postStartupMaintenance;
      postStartupMaintenance = _runAssetReferenceMaintenance(appDataDir)
          .then((_) => runAssetMaintenance())
          .catchError((Object error) {
            debugPrint('Post-startup asset maintenance failed: $error');
          })
          .whenComplete(() {
            if (identical(
              _postStartupAssetMaintenanceFuture,
              postStartupMaintenance,
            )) {
              _postStartupAssetMaintenanceFuture = null;
            }
          });
      _postStartupAssetMaintenanceFuture = postStartupMaintenance;
      unawaited(postStartupMaintenance);
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
    final postStartupMaintenance = _postStartupAssetMaintenanceFuture;
    if (postStartupMaintenance != null) {
      try {
        await postStartupMaintenance;
      } catch (_) {}
    }
    final assetMaintenance = _assetReferenceMaintenanceFuture;
    if (assetMaintenance != null) {
      try {
        await assetMaintenance;
      } catch (_) {}
    }
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

  Future<List<ChatMessage>> loadActiveTimelineMessages(
    String conversationId,
  ) async {
    if (!_initialized) return const <ChatMessage>[];
    if (_temporaryConversationIds.contains(conversationId)) {
      return List<ChatMessage>.of(
        _messagesCache[conversationId] ?? const <ChatMessage>[],
      );
    }
    final probe = await _repo.loadLinearMessageWindow(
      conversationId: conversationId,
      fromStart: true,
      limit: 1,
    );
    if (probe.totalSlotCount == 0) return const <ChatMessage>[];
    final timeline = await _repo.loadLinearMessageWindow(
      conversationId: conversationId,
      fromStart: true,
      limit: probe.totalSlotCount,
    );
    final revisionIds = timeline.slots
        .map((slot) => slot.revisionId)
        .toList(growable: false);
    final messages = await _repo.getMessagesByIds(revisionIds);
    final byId = {for (final message in messages) message.id: message};
    return List<ChatMessage>.unmodifiable([
      for (final revisionId in revisionIds)
        if (byId[revisionId] != null) byId[revisionId]!,
    ]);
  }

  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    if (!_initialized || limit <= 0) return null;
    if (_temporaryConversationIds.contains(conversationId)) {
      return _loadTemporaryTimelinePage(
        conversationId,
        beforeRevisionId: beforeRevisionId,
        afterRevisionId: afterRevisionId,
        aroundRevisionId: aroundRevisionId,
        fromStart: fromStart,
        limit: limit,
      );
    }
    final page = await _repo.loadLinearMessageWindow(
      conversationId: conversationId,
      beforeRevisionId: beforeRevisionId,
      afterRevisionId: afterRevisionId,
      aroundRevisionId: aroundRevisionId,
      fromStart: fromStart,
      limit: limit,
    );
    final revisionIds = page.slots
        .map((slot) => slot.revisionId)
        .toList(growable: false);
    final messages = await _repo.getMessagesByIds(revisionIds);
    final byId = {for (final message in messages) message.id: message};
    String? parentRevisionId;
    final loadedSlots = <LoadedTimelineSlot>[];
    for (final slot in page.slots) {
      final message = byId[slot.revisionId];
      if (message == null) continue;
      loadedSlots.add(
        LoadedTimelineSlot(
          identity: ActiveTimelineSlot(
            slotId: slot.groupId,
            revisionId: slot.revisionId,
            parentRevisionId: parentRevisionId,
            role: message.role,
            createdAt: message.timestamp,
            updatedAt: message.timestamp,
            finalizedAt: message.isStreaming ? null : message.timestamp,
            versionCount: slot.versionCount,
            logicalIndex: slot.logicalIndex,
          ),
          message: message,
        ),
      );
      parentRevisionId = message.id;
    }
    if (loadedSlots.length != page.slots.length) {
      throw StateError('timeline_selected_revision_shadow_missing');
    }
    _cacheLoadedMessages(conversationId, messages);
    await _cacheMessageArtifacts(messages);
    return LoadedTimelinePage(
      conversationId: conversationId,
      stateRevision:
          _conversationsCache[conversationId]
              ?.updatedAt
              .microsecondsSinceEpoch ??
          0,
      contextStartRevisionId: null,
      slots: loadedSlots,
      hasMoreBefore: page.hasMoreBefore,
      hasMoreAfter: page.hasMoreAfter,
      totalSlotCount: page.totalSlotCount,
    );
  }

  LoadedTimelinePage? _loadTemporaryTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    required bool fromStart,
    required int limit,
  }) {
    final cursorCount = <String?>[
      beforeRevisionId,
      afterRevisionId,
      aroundRevisionId,
    ].where((cursor) => cursor != null).length;
    if (cursorCount > 1 || (fromStart && cursorCount != 0)) {
      throw ArgumentError('Only one timeline cursor may be supplied.');
    }
    final conversation = _draftConversations[conversationId];
    if (conversation == null) return null;
    final allMessages = _messagesCache[conversationId] ?? const <ChatMessage>[];
    final groups = <String, List<ChatMessage>>{};
    for (final message in allMessages) {
      groups.putIfAbsent(message.groupId ?? message.id, () => []).add(message);
    }
    final activeMessages = <ChatMessage>[];
    final versionCounts = <String, int>{};
    for (final entry in groups.entries) {
      final revisions = entry.value;
      versionCounts[entry.key] = revisions.length;
      final selection = conversation.versionSelections[entry.key];
      ChatMessage? selected;
      if (selection != null) {
        for (final revision in revisions) {
          if (revision.version == selection) {
            selected = revision;
            break;
          }
        }
      }
      activeMessages.add(selected ?? revisions.last);
    }

    var start = 0;
    var end = activeMessages.length;
    if (fromStart) {
      end = limit.clamp(0, activeMessages.length).toInt();
    } else if (aroundRevisionId != null) {
      final targetIndex = activeMessages.indexWhere(
        (message) => message.id == aroundRevisionId,
      );
      if (targetIndex < 0) return null;
      start = (targetIndex - (limit ~/ 2))
          .clamp(0, activeMessages.length)
          .toInt();
      end = (start + limit).clamp(start, activeMessages.length).toInt();
      start = (end - limit).clamp(0, end).toInt();
    } else if (beforeRevisionId != null) {
      end = activeMessages.indexWhere(
        (message) => message.id == beforeRevisionId,
      );
      if (end < 0) return null;
      start = (end - limit).clamp(0, end).toInt();
    } else if (afterRevisionId != null) {
      final cursorIndex = activeMessages.indexWhere(
        (message) => message.id == afterRevisionId,
      );
      if (cursorIndex < 0) return null;
      start = cursorIndex + 1;
      end = (start + limit).clamp(start, activeMessages.length).toInt();
    } else {
      start = (activeMessages.length - limit)
          .clamp(0, activeMessages.length)
          .toInt();
    }

    String? parentRevisionId = start == 0 ? null : activeMessages[start - 1].id;
    final slots = <LoadedTimelineSlot>[];
    for (var index = start; index < end; index++) {
      final message = activeMessages[index];
      final groupId = message.groupId ?? message.id;
      slots.add(
        LoadedTimelineSlot(
          identity: ActiveTimelineSlot(
            slotId: groupId,
            revisionId: message.id,
            parentRevisionId: parentRevisionId,
            role: message.role,
            createdAt: message.timestamp,
            updatedAt: message.timestamp,
            finalizedAt: message.isStreaming ? null : message.timestamp,
            versionCount: versionCounts[groupId] ?? 1,
            logicalIndex: index,
          ),
          message: message,
        ),
      );
      parentRevisionId = message.id;
    }
    return LoadedTimelinePage(
      conversationId: conversationId,
      stateRevision: conversation.updatedAt.microsecondsSinceEpoch,
      contextStartRevisionId: null,
      slots: slots,
      hasMoreBefore: start > 0,
      hasMoreAfter: end < activeMessages.length,
      totalSlotCount: activeMessages.length,
    );
  }

  void retainTimelineWindow(
    String conversationId,
    Iterable<String> revisionIds,
  ) {
    // Temporary chats have no database shadow from which evicted rows can be
    // reloaded. Their service-owned data stays complete while the coordinator
    // still exposes only its bounded visible window.
    if (_temporaryConversationIds.contains(conversationId)) return;
    final retained = revisionIds.toSet();
    final messages = _messagesCache[conversationId];
    if (messages != null) {
      final removedIds = messages
          .where((message) => !retained.contains(message.id))
          .map((message) => message.id)
          .toList(growable: false);
      _messagesCache[conversationId] = messages
          .where((message) => retained.contains(message.id))
          .toList(growable: true);
      for (final id in removedIds) {
        _toolEventsCache.remove(id);
        _geminiThoughtSigsCache.remove(id);
      }
    }
  }

  int getContextStartIndex(String conversationId) =>
      _conversationsCache[conversationId]?.truncateIndex ?? -1;

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
    _touchMessageCache(conversationId);
    _enforceMessageCacheLimits();
  }

  void _touchMessageCache(String conversationId) {
    final messages = _messagesCache.remove(conversationId);
    if (messages != null) _messagesCache[conversationId] = messages;
  }

  void _enforceMessageCacheLimits() {
    var entries = 0;
    var bytes = 0;
    for (final entry in _messagesCache.entries) {
      if (entry.key == _currentConversationId ||
          _temporaryConversationIds.contains(entry.key)) {
        continue;
      }
      entries += entry.value.length;
      bytes += entry.value.fold<int>(0, (sum, message) {
        return sum +
            message.content.length * 2 +
            (message.reasoningText?.length ?? 0) * 2 +
            (message.translation?.length ?? 0) * 2;
      });
    }
    while ((entries > _messageCacheMaxEntries ||
            bytes > _messageCacheMaxBytes) &&
        _messagesCache.isNotEmpty) {
      final candidate = _messagesCache.entries.firstWhere(
        (entry) =>
            entry.key != _currentConversationId &&
            !_temporaryConversationIds.contains(entry.key),
        orElse: () => const MapEntry('', <ChatMessage>[]),
      );
      if (candidate.key.isEmpty) break;
      _messagesCache.remove(candidate.key);
      entries -= candidate.value.length;
      bytes -= candidate.value.fold<int>(0, (sum, message) {
        return sum +
            message.content.length * 2 +
            (message.reasoningText?.length ?? 0) * 2 +
            (message.translation?.length ?? 0) * 2;
      });
      for (final message in candidate.value) {
        _toolEventsCache.remove(message.id);
        _geminiThoughtSigsCache.remove(message.id);
      }
    }
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
    bool includeAllRevisions = false,
  }) async {
    if (!_initialized) return const <ConversationSearchMatch>[];
    return _repo.searchConversationMatches(
      tokens: tokens,
      limit: limit,
      includeAllRevisions: includeAllRevisions,
    );
  }

  Future<ChatStatsAggregate> loadStatsAggregate({
    required DateTime? rangeStart,
    required DateTime? rangeEndExclusive,
    required DateTime heatmapStart,
    required DateTime trendStart,
    required DateTime trendEndExclusive,
  }) async {
    if (!_initialized) await init();
    return _repo.queryStatsAggregate(
      rangeStart: rangeStart,
      rangeEndExclusive: rangeEndExclusive,
      heatmapStart: heatmapStart,
      trendStart: trendStart,
      trendEndExclusive: trendEndExclusive,
    );
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
    _touchMessageCache(conversationId);
    _enforceMessageCacheLimits();
    return messages;
  }

  Future<List<ChatMessage>> loadSelectedContextMessages(
    String conversationId, {
    required int truncateIndex,
    required int limit,
    String? throughRevisionId,
    bool includeFollowingAssistant = false,
  }) async {
    if (!_initialized || limit <= 0) return const <ChatMessage>[];
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      final messages = _messagesCache[conversationId] ?? const <ChatMessage>[];
      final groups = <String, List<ChatMessage>>{};
      final order = <String>[];
      for (final message in messages) {
        final groupId = message.groupId ?? message.id;
        if (!groups.containsKey(groupId)) order.add(groupId);
        groups.putIfAbsent(groupId, () => <ChatMessage>[]).add(message);
      }
      final selections = getVersionSelections(conversationId);
      final selected = <ChatMessage>[];
      for (final groupId in order) {
        final versions = groups[groupId]!
          ..sort((a, b) => a.version.compareTo(b.version));
        final version = selections[groupId];
        selected.add(
          versions.cast<ChatMessage?>().firstWhere(
                (message) => message!.version == version,
                orElse: () => null,
              ) ??
              versions.last,
        );
      }
      var end = selected.length;
      if (throughRevisionId != null) {
        final target = selected.indexWhere(
          (message) => message.id == throughRevisionId,
        );
        if (target < 0) return const <ChatMessage>[];
        end = target + 1;
        if (includeFollowingAssistant && selected[target].role == 'user') {
          final assistant = selected.indexWhere(
            (message) => message.role == 'assistant',
            target + 1,
          );
          if (assistant >= 0) end = assistant + 1;
        }
      }
      final start = truncateIndex >= 0 && truncateIndex <= end
          ? truncateIndex
          : 0;
      final available = end - start;
      final boundedStart = start + (available - limit).clamp(0, available);
      return selected.sublist(boundedStart, end);
    }
    final messages = await _repo.getSelectedContextMessages(
      conversationId,
      truncateIndex: truncateIndex,
      limit: limit,
      throughRevisionId: throughRevisionId,
      includeFollowingAssistant: includeFollowingAssistant,
    );
    await _cacheMessageArtifacts(messages);
    return messages;
  }

  Future<int> getMaxMessageVersionForGroup(
    String conversationId,
    String groupId,
  ) {
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      final versions = (_messagesCache[conversationId] ?? const <ChatMessage>[])
          .where((message) => (message.groupId ?? message.id) == groupId)
          .map((message) => message.version);
      return Future<int>.value(
        versions.isEmpty ? -1 : versions.reduce((a, b) => a > b ? a : b),
      );
    }
    return _repo.getMaxMessageVersionForGroup(conversationId, groupId);
  }

  Future<List<ChatMessage>> loadSelectedMessageProjections(
    String conversationId,
  ) async {
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      return loadSelectedContextMessages(
        conversationId,
        truncateIndex: -1,
        limit: _messagesCache[conversationId]?.length ?? 0,
      );
    }
    return _repo.getSelectedMessageProjections(conversationId);
  }

  Future<List<ChatMessage>> loadMessagesByIds(List<String> ids) async {
    if (ids.isEmpty) return const <ChatMessage>[];
    final temporaryById = <String, ChatMessage>{
      for (final conversationId in _temporaryConversationIds)
        for (final message
            in _messagesCache[conversationId] ?? const <ChatMessage>[])
          message.id: message,
    };
    if (ids.every(temporaryById.containsKey)) {
      return [for (final id in ids) temporaryById[id]!];
    }
    final messages = await _repo.getMessagesByIds(ids);
    await _cacheMessageArtifacts(messages);
    return messages;
  }

  Future<Set<String>> loadMessageIdsForGroups(
    String conversationId,
    Set<String> groupIds,
  ) {
    if (_temporaryConversationIds.contains(conversationId) ||
        _draftConversations.containsKey(conversationId)) {
      return Future<Set<String>>.value({
        for (final message
            in _messagesCache[conversationId] ?? const <ChatMessage>[])
          if (groupIds.contains(message.groupId ?? message.id)) message.id,
      });
    }
    return _repo.getMessageIdsForGroups(conversationId, groupIds);
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
    _enforceMessageCacheLimits();
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
    _enforceMessageCacheLimits();
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

  List<({String path, String kind})> _extractLocalAttachments(String content) {
    final out = <String, ({String path, String kind})>{};
    final imgRe = RegExp(r"\[image:(.+?)\]");
    for (final m in imgRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null &&
          pth.isNotEmpty &&
          !pth.startsWith('http') &&
          !pth.startsWith('data:')) {
        final fixed = SandboxPathResolver.fix(pth);
        out['image:$fixed'] = (path: fixed, kind: 'image');
      }
    }
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    for (final m in fileRe.allMatches(content)) {
      final pth = m.group(1)?.trim();
      if (pth != null &&
          pth.isNotEmpty &&
          !pth.startsWith('http') &&
          !pth.startsWith('data:')) {
        final fixed = SandboxPathResolver.fix(pth);
        out['file:$fixed'] = (path: fixed, kind: 'file');
      }
    }
    return List.unmodifiable(out.values);
  }

  bool _messageCanOwnAssets(ChatMessage message) =>
      message.content.contains('[image:') || message.content.contains('[file:');

  Future<void> _backfillAssetReferences(Directory appDataDir) async {
    final targetRoot = p.normalize(appDataDir.absolute.path);
    final includeLegacyCandidates = await _repo.needsAssetReferenceBackfill(
      version: _assetReferenceBackfillVersion,
      targetRoot: targetRoot,
    );
    if (!includeLegacyCandidates &&
        !await _repo.hasPendingAssetReferenceSync()) {
      return;
    }
    var cursor = '';
    while (true) {
      final messages = await _repo.getMessagesForAssetReferenceBackfill(
        afterMessageId: cursor,
        includeLegacyCandidates: includeLegacyCandidates,
      );
      if (messages.isEmpty) break;
      for (final message in messages) {
        try {
          await _synchronizeMessageAssets(message);
        } catch (error) {
          debugPrint('Asset reference backfill skipped ${message.id}: $error');
        }
        cursor = message.id;
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (includeLegacyCandidates) {
      await _repo.markAssetReferenceBackfillComplete(
        version: _assetReferenceBackfillVersion,
        targetRoot: targetRoot,
      );
    }
  }

  Future<void> runAssetReferenceMaintenance() async {
    if (!_initialized) await init();
    return _runAssetReferenceMaintenance(
      await AppDirectories.getAppDataDirectory(),
    );
  }

  Future<void> _runAssetReferenceMaintenance(Directory appDataDir) {
    final inFlight = _assetReferenceMaintenanceFuture;
    if (inFlight != null) return inFlight;
    late final Future<void> tracked;
    tracked = _backfillAssetReferences(appDataDir).whenComplete(() {
      if (identical(_assetReferenceMaintenanceFuture, tracked)) {
        _assetReferenceMaintenanceFuture = null;
      }
    });
    _assetReferenceMaintenanceFuture = tracked;
    return tracked;
  }

  Future<void> _backfillAssetReferencesForCurrentRoot() async {
    await runAssetReferenceMaintenance();
  }

  Future<void> _synchronizeMessageAssets(ChatMessage message) async {
    if (isTemporaryConversation(message.conversationId)) return;
    final appDataDir = await AppDirectories.getAppDataDirectory();
    final allowedRoots = [
      p.normalize(p.join(appDataDir.absolute.path, 'upload')),
      p.normalize(p.join(appDataDir.absolute.path, 'images')),
    ];
    final registrations = <MessageAssetRegistration>[];
    for (final attachment in _extractLocalAttachments(message.content)) {
      final normalizedPath = p.normalize(File(attachment.path).absolute.path);
      if (!allowedRoots.any((root) => p.isWithin(root, normalizedPath))) {
        continue;
      }
      final file = File(normalizedPath);
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        await _repo.markMessageAssetReferencesDirty(message.id);
        throw StateError('asset_file_unavailable');
      }
      final contentHash = await _assetContentHash(file);
      registrations.add(
        MessageAssetRegistration(
          assetId: 'asset_$contentHash',
          contentHash: contentHash,
          path: normalizedPath,
          byteSize: await file.length(),
          kind: attachment.kind,
        ),
      );
    }
    await _repo.replaceMessageAssetReferences(
      conversationId: message.conversationId,
      revisionId: message.id,
      assets: registrations,
    );
  }

  static Future<String> _hashAssetFile(File file) {
    final path = file.path;
    return Isolate.run(
      () async => (await sha256.bind(File(path).openRead()).first).toString(),
    );
  }

  Future<void> _synchronizeMessageAssetsBestEffort(ChatMessage message) async {
    try {
      await _synchronizeMessageAssets(message);
    } catch (error) {
      // Message persistence is authoritative. The message transaction queues
      // relevant revisions first, so a failed asset-index update is retried by
      // the bounded startup backfill instead of failing the send.
      debugPrint('Message asset synchronization failed: $error');
    }
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

  Future<void> runAssetMaintenance({DateTime? now}) async {
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    try {
      await _repo.scheduleUnreferencedAssetGc(
        notBefore: effectiveNow.add(_assetGcDelay),
      );
      final candidates = await _repo.claimAssetGc(now: effectiveNow);
      final appDataDir = await AppDirectories.getAppDataDirectory();
      final allowedRoots = [
        p.normalize(p.join(appDataDir.absolute.path, 'upload')),
        p.normalize(p.join(appDataDir.absolute.path, 'images')),
      ];
      for (final candidate in candidates) {
        final paths = [
          candidate.path,
          candidate.thumbnailPath,
        ].whereType<String>();
        final regularFiles = <File>[];
        var safe = true;
        for (final candidatePath in paths) {
          final normalized = p.normalize(File(candidatePath).absolute.path);
          if (!allowedRoots.any((root) => p.isWithin(root, normalized))) {
            safe = false;
            break;
          }
          final type = await FileSystemEntity.type(
            normalized,
            followLinks: false,
          );
          if (type == FileSystemEntityType.file) {
            regularFiles.add(File(normalized));
          } else if (type != FileSystemEntityType.notFound) {
            safe = false;
            break;
          }
        }
        if (!safe) continue;
        if (!await _repo.isAssetGcClaimStillValid(candidate)) continue;
        final quarantined = <({File original, File quarantine})>[];
        try {
          for (final file in regularFiles) {
            final quarantine = File(
              '${file.path}.kelivo-gc-${candidate.assetId}-'
              '${candidate.generation}',
            );
            if (await quarantine.exists()) {
              safe = false;
              break;
            }
            await file.rename(quarantine.path);
            quarantined.add((original: file, quarantine: quarantine));
          }
          if (!safe) continue;
          final completed = await _repo.completeAssetGc(
            assetId: candidate.assetId,
            expectedGeneration: candidate.generation,
          );
          if (!completed) continue;
          for (final moved in quarantined) {
            await moved.quarantine.delete();
          }
          quarantined.clear();
        } finally {
          for (final moved in quarantined.reversed) {
            if (!await moved.original.exists() &&
                await moved.quarantine.exists()) {
              await moved.quarantine.rename(moved.original.path);
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Asset maintenance failed: $error');
    }
  }

  Future<void> _cleanupOrphanUploads() => runAssetMaintenance();

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
    await _backfillAssetReferencesForCurrentRoot();
    await _refreshConversation(restored.id);

    // Update caches
    _messagesCache[restored.id] = List.of(messages);
    _messageOrderIds[restored.id] = messages
        .map((message) => message.id)
        .toList(growable: true);
    _messageCounts[restored.id] = messages.length;
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
    await _backfillAssetReferencesForCurrentRoot();
    await _loadConversationsCache();
    notifyListeners();
    return report;
  }

  Future<PortableChatExportResult> exportPortableChats(
    File destination, {
    PortableChatScope scope = PortableChatScope.selectedVersionsCompleted,
  }) async {
    if (!_initialized) await init();
    return PortableNdjsonV2.exportToFile(
      repository: _repo,
      destination: destination,
      scope: scope,
    );
  }

  Future<BackupMergeReport> importPortableChats(File source) async {
    if (!_initialized) await init();
    final report = await PortableNdjsonV2.importFromFile(
      target: _repo,
      source: source,
    );
    _messagesCache.clear();
    await _backfillAssetReferencesForCurrentRoot();
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
    _currentConversationId = null;
    await _backfillAssetReferencesForCurrentRoot();
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
    final persisted = await _repo.appendLinearMessageToConversation(
      conversation: conversation,
      message: message,
      touchUpdatedAt: false,
    );
    if (_messageCanOwnAssets(message)) {
      await _synchronizeMessageAssetsBestEffort(message);
    }
    _conversationsCache[conversationId] = persisted;
    order.add(message.id);
    _messageCounts[conversationId] = order.length;

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
      final persisted = await _repo.appendLinearMessageToConversation(
        conversation: conversation,
        message: message,
        selectVersion: selectVersion,
      );
      if (_messageCanOwnAssets(message)) {
        await _synchronizeMessageAssetsBestEffort(message);
      }
      _draftConversations.remove(conversationId);
      _conversationsCache[conversationId] = persisted;
      conversation = persisted;
      final order = _messageOrderIds.putIfAbsent(
        conversationId,
        () => <String>[],
      );
      if (!order.contains(message.id)) order.add(message.id);
      _messageCounts[conversationId] = order.length;
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
    required bool truncateFuture,
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
      truncateFuture: truncateFuture,
    );
    if (truncateFuture) {
      _messagesCache.remove(conversationId);
      _messageOrderIds.remove(conversationId);
      await _loadMessageOrder(conversationId);
    }
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
    if (result.userMessage case final userMessage?
        when _messageCanOwnAssets(userMessage)) {
      await _synchronizeMessageAssetsBestEffort(userMessage);
    }
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

    if (content != null) {
      await _repo.markMessageAssetReferencesDirty(updatedMessage.id);
    }

    await _repo.updateMessageAndStreamingState(
      updatedMessage,
      untrackStreaming: isStreaming == false,
    );
    if (content != null) {
      await _synchronizeMessageAssetsBestEffort(updatedMessage);
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
    if (_messageCanOwnAssets(message)) {
      await _synchronizeMessageAssetsBestEffort(message);
    }
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
    final source = _conversationsCache[sourceConversationId];
    if (source == null) throw StateError('conversation_missing');
    final targetMessage = await _repo.getMessage(sourceRevisionId);
    if (targetMessage == null ||
        targetMessage.conversationId != sourceConversationId) {
      throw StateError('linear_fork_target_missing');
    }
    final targetGroupId = targetMessage.groupId ?? targetMessage.id;
    final probe = await _repo.loadLinearMessageWindow(
      conversationId: sourceConversationId,
      fromStart: true,
      limit: 1,
    );
    final window = await _repo.loadLinearMessageWindow(
      conversationId: sourceConversationId,
      fromStart: true,
      limit: probe.totalSlotCount,
    );
    final targetIndex = window.slots.indexWhere(
      (slot) => slot.groupId == targetGroupId,
    );
    if (targetIndex < 0) throw StateError('linear_fork_target_not_visible');
    final sourceMessages = await _repo.getMessagesByIds([
      for (final slot in window.slots.take(targetIndex + 1)) slot.revisionId,
    ]);
    final persisted = await createConversation(
      title: source.title,
      assistantId: source.assistantId,
    );
    _messagesCache[persisted.id] = <ChatMessage>[];
    _messageOrderIds[persisted.id] = <String>[];
    _messageCounts[persisted.id] = 0;
    for (final message in sourceMessages) {
      await addMessageDirectly(
        persisted.id,
        ChatMessage(
          role: message.role,
          content: message.content,
          timestamp: message.timestamp,
          modelId: message.modelId,
          providerId: message.providerId,
          totalTokens: message.totalTokens,
          conversationId: persisted.id,
          isStreaming: false,
          reasoningText: message.reasoningText,
          reasoningStartAt: message.reasoningStartAt,
          reasoningFinishedAt: message.reasoningFinishedAt,
          translation: message.translation,
          reasoningSegmentsJson: message.reasoningSegmentsJson,
          promptTokens: message.promptTokens,
          completionTokens: message.completionTokens,
          cachedTokens: message.cachedTokens,
          durationMs: message.durationMs,
        ),
      );
    }
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
    if (_messageCanOwnAssets(newMsg)) {
      await _synchronizeMessageAssetsBestEffort(newMsg);
    }
    final cid = newMsg.conversationId;
    _conversationsCache[cid] = result.conversation;
    final order = _messageOrderIds.putIfAbsent(cid, () => <String>[]);
    if (!order.contains(newMsg.id)) order.add(newMsg.id);
    _messageCounts[cid] = order.length;
    // Update caches
    final arr = _messagesCache[cid];
    if (arr != null) arr.add(newMsg);
    notifyListeners();
    return newMsg;
  }

  Map<String, int> getVersionSelections(String conversationId) {
    return Map<String, int>.from(
      (_draftConversations[conversationId] ??
                  _conversationsCache[conversationId])
              ?.versionSelections ??
          const <String, int>{},
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
    if (target == null) throw StateError('message_version_missing');
    final conversation = await _repo.setSelectedVersion(
      conversationId: conversationId,
      groupId: groupId,
      version: version,
    );
    if (conversation == null) return;
    _conversationsCache[conversationId] = conversation;
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
    final conversation = await _repo.setSelectedVersion(
      conversationId: conversationId,
      groupId: groupId,
      version: null,
    );
    if (conversation == null) return;
    _conversationsCache[conversationId] = conversation;
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
    final probe = await _repo.loadLinearMessageWindow(
      conversationId: conversationId,
      fromStart: true,
      limit: 1,
    );
    if (probe.totalSlotCount == 0) return c;
    c.truncateIndex = c.truncateIndex == probe.totalSlotCount
        ? -1
        : probe.totalSlotCount;
    if ((defaultTitle ?? '').isNotEmpty) c.title = defaultTitle!;
    c.updatedAt = DateTime.now();
    await _saveConversation(c);
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

  Future<Set<String>> deleteMessages({
    required String conversationId,
    required Set<String> messageIds,
    required Map<String, int?> versionSelectionChanges,
  }) async {
    if (!_initialized || messageIds.isEmpty) return const <String>{};
    if (_temporaryConversationIds.contains(conversationId)) {
      final conversation = _draftConversations[conversationId];
      final messages = _messagesCache[conversationId];
      if (conversation == null || messages == null) return const <String>{};
      final deletedIds = messages
          .where((message) => messageIds.contains(message.id))
          .map((message) => message.id)
          .toSet();
      if (deletedIds.isEmpty) return const <String>{};
      messages.removeWhere((message) => deletedIds.contains(message.id));
      conversation.messageIds.removeWhere(deletedIds.contains);
      for (final entry in versionSelectionChanges.entries) {
        final version = entry.value;
        if (version == null) {
          conversation.versionSelections.remove(entry.key);
        } else {
          conversation.versionSelections[entry.key] = version;
        }
      }
      conversation.updatedAt = DateTime.now();
      for (final id in deletedIds) {
        _temporaryToolEvents.remove(id);
        _temporaryGeminiThoughtSigs.remove(id);
      }
      notifyListeners();
      return Set<String>.unmodifiable(deletedIds);
    }
    final result = await _repo.deleteMessages(
      conversationId: conversationId,
      messageIds: messageIds,
      versionSelectionChanges: versionSelectionChanges,
    );
    if (result == null) return const <String>{};

    _conversationsCache[conversationId] = result.conversation;
    final deletedIds = <String>{};
    for (final message in result.messages) {
      deletedIds.add(message.id);
      _toolEventsCache.remove(message.id);
      _geminiThoughtSigsCache.remove(message.id);
    }
    _messagesCache.remove(conversationId);
    _messageOrderIds.remove(conversationId);
    _messageCounts[conversationId] = await _repo.getMessageCount(
      conversationId,
    );
    await _cleanupOrphanUploads();
    notifyListeners();
    return Set<String>.unmodifiable(deletedIds);
  }

  void setCurrentConversation(String? id) {
    if (id != _currentConversationId) {
      _discardTemporaryConversation(_currentConversationId);
    }
    _currentConversationId = id;
    _enforceMessageCacheLimits();
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

final class ActiveTimelineSlot {
  const ActiveTimelineSlot({
    required this.slotId,
    required this.revisionId,
    required this.parentRevisionId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.finalizedAt,
    required this.versionCount,
    required this.logicalIndex,
  });

  final String slotId;
  final String revisionId;
  final String? parentRevisionId;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;
  final int versionCount;
  final int logicalIndex;
}
