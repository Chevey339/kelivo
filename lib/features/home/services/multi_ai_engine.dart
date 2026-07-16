import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../features/model/widgets/model_select_sheet.dart'
    show ModelSelection;
import '../controllers/chat_controller.dart';
import '../controllers/stream_controller.dart' as stream_ctrl;
import '../services/ask_user_interaction_service.dart';
import '../services/message_generation_service.dart';
import '../services/message_pipeline.dart';
import '../services/tool_approval_service.dart';

/// Engine for multi-AI comparison mode.
///
/// Per-thread groupId semantics:
///   - User messages NEVER get a round groupId (they keep `groupId: null`).
///   - Each assistant thread uses its own `threadId` as both `groupId` (for
///     collapse/version) and `subgroupId` (for card grouping).
///   - Round membership ("which user message triggered which threads") is
///     tracked in _anchorThreads — a runtime-only map, not stored on messages.
// ignore_for_file: prefer_initializing_formals

class MultiAIEngine extends ChangeNotifier {
  MultiAIEngine({
    required ChatService chatService,
    required ChatController chatController,
    required MessageGenerationService messageGenerationService,
    required stream_ctrl.StreamController streamController,
    required MessagePipeline pipeline,
  }) : _chatService = chatService,
       _chatController = chatController,
       _messageGenerationService = messageGenerationService,
       _streamController = streamController,
       _pipeline = pipeline;

  final ChatService _chatService;
  final ChatController _chatController;
  final MessageGenerationService _messageGenerationService;
  final stream_ctrl.StreamController _streamController;
  final MessagePipeline _pipeline;

  bool _isActive = false;
  List<ModelSelection> _models = [];
  List<String> _threadIds = [];

  // ============================================================================
  // Getters — all round/anchorship is computed from message list order
  // ============================================================================

  bool get isActive => _isActive;
  List<ModelSelection> get models => List<ModelSelection>.unmodifiable(_models);
  Set<String> get threadIds => Set<String>.unmodifiable(_threadIds);

  Set<String> get subgroupActiveGroupIds =>
      _chatController.subgroupActiveGroupIds;

  /// Compute anchor user-message IDs → set of distinct subgroupIds across
  /// all rounds, filtered to only anchors with ≥ 2 distinct threads.
  static Map<String, Set<String>> _computeAnchors(List<ChatMessage> messages) {
    final anchors = <String, Set<String>>{};
    String? lastUser;
    for (final m in messages) {
      if (m.role == 'user') {
        lastUser = m.id;
      } else if (m.subgroupId != null && lastUser != null) {
        anchors.putIfAbsent(lastUser, () => <String>{}).add(m.subgroupId!);
      }
    }
    anchors.removeWhere((_, threads) => threads.length < 2);
    return anchors;
  }

  /// Scan the message list and return IDs of user messages that have ≥2
  /// different thread (subgroupId) responses following them.
  Set<String> get anchorMessageIds =>
      _computeAnchors(_chatController.messages).keys.toSet();

  /// The most recent (last in list order) anchor user-message ID, or null.
  String? get latestAnchorId {
    final anchors = _computeAnchors(_chatController.messages);
    return anchors.keys.isEmpty ? null : anchors.keys.last;
  }

  /// Collect all subgroup messages that belong to the round anchored by
  /// [anchorUserMsgId]. Reads forwards from the anchor until the next user
  /// message (or end of list), groups by subgroupId, and sorts by version
  /// within each group.
  Map<String, List<ChatMessage>> getMessagesForAnchor(String anchorUserMsgId) {
    bool collecting = false;
    final result = <String, List<ChatMessage>>{};
    for (final m in _chatController.messages) {
      if (m.role == 'user') {
        if (m.id == anchorUserMsgId) {
          collecting = true;
          continue;
        } else if (collecting) {
          break;
        }
      }
      if (collecting && m.subgroupId != null) {
        result.putIfAbsent(m.subgroupId!, () => []).add(m);
      }
    }
    for (final list in result.values) {
      list.sort((a, b) => a.version.compareTo(b.version));
    }
    return result;
  }

  // ============================================================================
  // Lifecycle
  // ============================================================================

  void enter(List<ModelSelection> models, {List<String>? existingThreadIds}) {
    _isActive = true;
    _models = List<ModelSelection>.of(models);
    _threadIds =
        existingThreadIds ??
        List<String>.generate(models.length, (_) => const Uuid().v4());
    notifyListeners();
  }

  void exit() {
    _isActive = false;
    _models = [];
    _threadIds = [];
    _chatController.invalidateCache();
    notifyListeners();
  }

  // ============================================================================
  // Shared: execute threads (used by both startRound & startRoundFromHistory)
  // ============================================================================

  /// Execute streams for all active threads.
  Future<void> _executeThreads({
    required Conversation conversation,
    required SettingsProvider settings,
    required Assistant? assistant,
    required ToolApprovalService? approvalService,
    required AskUserInteractionService? askUserService,
    required List<ChatMessage> completeMessages,
    required String roundGroupId,
    ChatInputData? inputData,
    bool allowImagesApiRouting = true,
  }) async {
    final convId = conversation.id;
    var pending = _models.length;
    debugPrint(
      '[MultiAI][_executeThreads] models=${_models.length} roundGroupId=$roundGroupId',
    );

    final ctx = ModelExecutionContext(
      conversation: conversation,
      settings: settings,
      assistant: assistant,
      approvalService: approvalService,
      askUserService: askUserService,
      versionSelections: _chatController.versionSelections,
    );

    void onThreadDone() {
      pending--;
      debugPrint('[MultiAI][_executeThreads] pending=$pending');
      if (pending == 0) {
        debugPrint('[MultiAI][_executeThreads] all threads done');
      }
    }

    for (int i = 0; i < _models.length; i++) {
      final model = _models[i];
      final threadId = _threadIds[i];

      // Skip check: for startRoundFromHistory (inputData == null), skip
      // threads whose subgroupId already exists in the message list
      // (the trigger message was already tagged in handleMultiAIAction).
      // For startRound (inputData != null), threadIds are reused across
      // rounds so this check would incorrectly block follow-up questions.
      if (inputData == null &&
          _chatController.messages.any((m) => m.subgroupId == threadId)) {
        onThreadDone();
        continue;
      }

      ChatMessage assistantMessage;
      try {
        assistantMessage = await _messageGenerationService
            .createAssistantPlaceholder(
              conversationId: convId,
              modelId: model.modelId,
              providerKey: model.providerKey,
              groupId: roundGroupId,
              subgroupId: threadId,
              version: 0,
            );
      } catch (e) {
        debugPrint(
          '[MultiAI][_executeThreads] thread=$i placeholder creation failed: $e',
        );
        onThreadDone();
        continue;
      }

      debugPrint(
        '[MultiAI][_executeThreads] thread=$i model=${model.modelId} start',
      );
      _streamController.markStreamingStarted(assistantMessage.id);

      if (_chatController.appendPersistedTailMessage(assistantMessage)) {
        _chatController.notifyListeners();
      }
      _chatController.notifyListeners();

      _streamController.toolParts.remove(assistantMessage.id);

      // Filter context per thread: keep user/non-subgroup messages +
      // only this thread's own subgroup messages.
      final threadMessages = completeMessages.where((m) {
        if (m.subgroupId == null) return true;
        return m.subgroupId == threadId;
      }).toList();

      // Per-thread loading increment matches the decrement in _finishStreaming.
      _chatController.setConversationLoading(convId, true);

      await _pipeline.executeAssistantResponse(
        assistantMessage: assistantMessage,
        providerKey: model.providerKey,
        modelId: model.modelId,
        context: ctx,
        completeMessages: threadMessages,
        inputData: inputData,
        allowImagesApiRouting: allowImagesApiRouting,
        generateTitleOnFinish: i == 0,
        onStreamComplete: onThreadDone,
      );
    }

    _chatController.notifyListeners();
  }

  // ============================================================================
  // Round Operations
  // ============================================================================

  /// Start a new round from user input: create user message + N threads.
  Future<String> startRound({
    required ChatInputData input,
    required Conversation conversation,
    required SettingsProvider settings,
    required Assistant? assistant,
    ToolApprovalService? approvalService,
    AskUserInteractionService? askUserService,
  }) async {
    if (_models.length < 2) return '';

    final roundGroupId = const Uuid().v4();

    // Create user message first (no round groupId).
    final userMessage = await _messageGenerationService.createUserMessage(
      conversationId: conversation.id,
      input: input,
      assistant: assistant,
    );
    if (_chatController.appendPersistedTailMessage(userMessage)) {
      _chatController.notifyListeners();
    }
    _chatController.notifyListeners();

    // Capture complete history AFTER user message so it includes this round's
    // user input in the API context.
    final completeMessages = _chatController.messagesForCompleteHistoryContext(
      conversation,
    );

    await _executeThreads(
      conversation: conversation,
      settings: settings,
      assistant: assistant,
      approvalService: approvalService,
      askUserService: askUserService,
      completeMessages: completeMessages,
      roundGroupId: roundGroupId,
      inputData: input,
      allowImagesApiRouting: input.allowImagesApiRouting,
    );

    _chatController.notifyListeners();
    return userMessage.id;
  }

  /// Start a round from an existing assistant message ("也让其他AI回答").
  /// Finds the preceding user message as anchor, creates N new threads.
  Future<String> startRoundFromHistory({
    required ChatMessage triggerMessage,
    required Conversation conversation,
    required SettingsProvider settings,
    required Assistant? assistant,
    ToolApprovalService? approvalService,
    AskUserInteractionService? askUserService,
  }) async {
    if (_models.length < 2 || _threadIds.isEmpty) return '';

    final roundGroupId = const Uuid().v4();

    // Find preceding user message (walk backwards from trigger)
    final triggerIdx = _chatController.messages.indexWhere(
      (m) => m.id == triggerMessage.id,
    );
    if (triggerIdx < 0) return '';

    String? precedingUserId;
    for (int i = triggerIdx - 1; i >= 0; i--) {
      if (_chatController.messages[i].role == 'user') {
        precedingUserId = _chatController.messages[i].id;
        break;
      }
    }
    if (precedingUserId == null) return '';

    final completeMessages = _chatController.messagesForCompleteHistoryContext(
      conversation,
    );

    await _executeThreads(
      conversation: conversation,
      settings: settings,
      assistant: assistant,
      approvalService: approvalService,
      askUserService: askUserService,
      completeMessages: completeMessages,
      roundGroupId: roundGroupId,
    );

    _chatController.notifyListeners();
    return precedingUserId;
  }

  // ============================================================================
  // Recovery (from conversation history)
  // ============================================================================

  /// Recover engine state from persisted messages.
  /// Scans message list order to find anchors and reconstruct model/thread
  /// state for the latest active round.
  /// Returns number of models recovered (0 if no multi-AI state found).
  int recoverFromMessages(List<ChatMessage> messages) {
    final anchors = _computeAnchors(messages);

    debugPrint(
      '[MultiAI][recoverFromMessages] anchors=${anchors.length} totalMessages=${messages.length}',
    );

    if (anchors.isEmpty) {
      _isActive = false;
      _models = [];
      _threadIds = [];
      debugPrint('[MultiAI][recoverFromMessages] no anchors found');
      return 0;
    }

    // Rebuild _models and _threadIds from the latest (last key in insertion
    // order) valid anchor.
    final latestAnchor = anchors.keys.last;
    final latestThreadIds = anchors[latestAnchor]!;
    _threadIds = latestThreadIds.toList();
    _models = [];

    for (final tid in _threadIds) {
      ChatMessage? latest;
      for (final m in messages) {
        if (m.subgroupId == tid) {
          if (latest == null || m.timestamp.isAfter(latest.timestamp)) {
            latest = m;
          }
        }
      }
      if (latest != null &&
          latest.providerId != null &&
          latest.modelId != null) {
        _models.add(ModelSelection(latest.providerId!, latest.modelId!));
      }
    }

    _isActive = _models.length >= 2;
    debugPrint(
      '[MultiAI][recoverFromMessages] recovered=${_models.length} isActive=$_isActive threadIds=$_threadIds',
    );
    return _models.length;
  }

  /// Remove a model+thread pair (called when thread is dropped by user).
  /// Returns the remaining thread count after removal.
  int removeThread(String threadId) {
    final idx = _threadIds.indexOf(threadId);
    debugPrint(
      '[MultiAI][removeThread] threadId=$threadId idx=$idx _threadIds=$_threadIds',
    );
    if (idx < 0) return _threadIds.length;
    _threadIds.removeAt(idx);
    if (idx < _models.length) _models.removeAt(idx);
    return _threadIds.length;
  }

  /// Retry a single thread: add a new version of the latest message for this
  /// thread in the round anchored by [anchorUserMsgId], then re-execute the
  /// stream. Context is truncated at the anchor user message.
  Future<void> retryThread({
    required String threadId,
    required String anchorUserMsgId,
    required Conversation conversation,
    required SettingsProvider settings,
    required Assistant? assistant,
    ToolApprovalService? approvalService,
    AskUserInteractionService? askUserService,
  }) async {
    debugPrint(
      '[MultiAI][retryThread] threadId=$threadId anchor=$anchorUserMsgId',
    );
    final msgs = getMessagesForAnchor(anchorUserMsgId);
    final versions = msgs[threadId] ?? [];
    if (versions.isEmpty) return;

    final modelIdx = _threadIds.indexOf(threadId);
    if (modelIdx < 0) return;
    final model = _models[modelIdx];
    final latest = versions.last;
    final nextVersion = latest.version + 1;

    final newMessage = await _messageGenerationService
        .createAssistantPlaceholder(
          conversationId: conversation.id,
          modelId: model.modelId,
          providerKey: model.providerKey,
          groupId: latest.groupId ?? latest.id,
          subgroupId: threadId,
          version: nextVersion,
        );

    final insertAfterIdx = _chatController.messages.indexWhere(
      (m) => m.id == latest.id,
    );
    if (insertAfterIdx < 0) return;
    _chatController.messages.insert(insertAfterIdx + 1, newMessage);

    _streamController.markStreamingStarted(newMessage.id);
    _chatController.notifyListeners();
    _streamController.toolParts.remove(newMessage.id);

    final completeMessages = _chatController.messagesForCompleteHistoryContext(
      conversation,
    );

    final threadMessages = completeMessages.where((m) {
      if (m.subgroupId == null) return true;
      return m.subgroupId == threadId;
    }).toList();

    final ctx = ModelExecutionContext(
      conversation: conversation,
      settings: settings,
      assistant: assistant,
      approvalService: approvalService,
      askUserService: askUserService,
      versionSelections: _chatController.versionSelections,
    );

    await _pipeline.executeAssistantResponse(
      assistantMessage: newMessage,
      providerKey: model.providerKey,
      modelId: model.modelId,
      context: ctx,
      completeMessages: threadMessages,
      allowImagesApiRouting: true,
      generateTitleOnFinish: false,
    );

    _chatController.notifyListeners();
  }

  /// Retry all threads in the round anchored by [anchorUserMsgId]: create a
  /// version+1 for every thread and re-execute each stream.
  Future<void> retryRound({
    required String anchorUserMsgId,
    required Conversation conversation,
    required SettingsProvider settings,
    required Assistant? assistant,
    ToolApprovalService? approvalService,
    AskUserInteractionService? askUserService,
  }) async {
    debugPrint('[MultiAI][retryRound] anchor=$anchorUserMsgId');
    final msgs = getMessagesForAnchor(anchorUserMsgId);
    if (msgs.isEmpty) return;

    final ctx = ModelExecutionContext(
      conversation: conversation,
      settings: settings,
      assistant: assistant,
      approvalService: approvalService,
      askUserService: askUserService,
      versionSelections: _chatController.versionSelections,
    );

    final newMessages = <ChatMessage>[];
    final newMsgByThread = <String, ChatMessage>{};

    for (final entry in msgs.entries) {
      final threadId = entry.key;
      final versions = entry.value;
      final latest = versions.last;
      final nextVersion = latest.version + 1;
      final modelIdx = _threadIds.indexOf(threadId);
      if (modelIdx < 0) continue;
      final model = _models[modelIdx];

      final newMsg = await _messageGenerationService.createAssistantPlaceholder(
        conversationId: conversation.id,
        modelId: model.modelId,
        providerKey: model.providerKey,
        groupId: latest.groupId ?? latest.id,
        subgroupId: threadId,
        version: nextVersion,
      );

      final insertAfterIdx = _chatController.messages.indexWhere(
        (m) => m.id == latest.id,
      );
      if (insertAfterIdx < 0) continue;
      _chatController.messages.insert(
        insertAfterIdx + 1 + newMessages.length,
        newMsg,
      );
      newMessages.add(newMsg);
      newMsgByThread[threadId] = newMsg;
    }

    if (newMessages.isEmpty) return;

    _chatController.notifyListeners();

    // Execute streams for all new messages — iterate by _threadIds to ensure
    // model/thread association is consistent regardless of Map iteration order.
    for (int i = 0; i < _threadIds.length; i++) {
      final threadId = _threadIds[i];
      final newMsg = newMsgByThread[threadId];
      if (newMsg == null) continue;
      final model = _models[i];

      _streamController.markStreamingStarted(newMsg.id);
      _streamController.toolParts.remove(newMsg.id);

      final completeMessages = _chatController
          .messagesForCompleteHistoryContext(conversation);

      final threadMessages = completeMessages.where((m) {
        if (m.subgroupId == null) return true;
        return m.subgroupId == threadId;
      }).toList();

      await _pipeline.executeAssistantResponse(
        assistantMessage: newMsg,
        providerKey: model.providerKey,
        modelId: model.modelId,
        context: ctx,
        completeMessages: threadMessages,
        allowImagesApiRouting: true,
        generateTitleOnFinish: false,
      );
    }

    _chatController.notifyListeners();
  }

  // ============================================================================
  // Thread Operations
  // ============================================================================

  /// Resolve (adopt) a thread: clear subgroupId on ALL messages across ALL
  /// rounds, renumber versions per round groupId, set version selection for
  /// the adopted round, then exit multi-AI mode.
  Future<void> resolveThread({
    required String anchorId,
    required String threadId,
    required int version,
  }) async {
    // Collect ALL messages that share groupIds with subgroup messages, across
    // all rounds. This includes dropped-thread messages (subgroupId == null but
    // same groupId) so they get renumbered alongside active threads, preventing
    // version collisions after resolve.
    final allSubgroup = <ChatMessage>[];
    final roundGroupIds = <String>{};
    for (final m in _chatController.messages) {
      if (m.subgroupId != null) {
        allSubgroup.add(m);
        roundGroupIds.add(m.groupId ?? m.id);
      }
    }
    // Include dropped messages that share groupIds with active subgroup messages.
    if (roundGroupIds.isNotEmpty) {
      for (final m in _chatController.messages) {
        if (m.subgroupId != null) continue; // already collected
        final gid = m.groupId;
        if (gid != null && roundGroupIds.contains(gid)) {
          allSubgroup.add(m);
        }
      }
    }
    debugPrint(
      '[MultiAI][resolveThread] anchorId=$anchorId threadId=$threadId version=$version total=${allSubgroup.length}',
    );
    if (allSubgroup.isEmpty) return;

    // Determine the roundGroupId of the adopted thread (needed for
    // version selection later).
    String? roundGroupId;
    int adoptedFinalVersion = 0;

    // Group by groupId for per-round version renumbering.
    final byGid = <String, List<ChatMessage>>{};
    for (final m in allSubgroup) {
      final gid = m.groupId ?? m.id;
      byGid.putIfAbsent(gid, () => []).add(m);
      if (m.subgroupId == threadId && roundGroupId == null) {
        roundGroupId = gid;
      }
    }

    for (final entry in byGid.entries) {
      final gid = entry.key;
      final msgs = entry.value;
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (int i = 0; i < msgs.length; i++) {
        final msg = msgs[i];
        final isAdopted = msg.subgroupId == threadId && msg.version == version;
        final updated = msg.copyWith(subgroupId: null, version: i);
        _chatController.replaceMessage(updated);
        await _chatService.updateMessage(
          msg.id,
          subgroupId: null,
          content: updated.content,
          totalTokens: updated.totalTokens,
          isStreaming: updated.isStreaming,
          version: updated.version,
        );
        // Only record adoptedFinalVersion from the round that matches
        // roundGroupId — otherwise later rounds with different message
        // counts (e.g. after a model was dropped) can overwrite it.
        if (isAdopted && gid == roundGroupId) adoptedFinalVersion = i;
      }
    }

    // Persist version selection for the adopted round.
    final convId = _chatController.currentConversation?.id;
    if (convId != null && roundGroupId != null) {
      _chatController.versionSelections[roundGroupId] = adoptedFinalVersion;
      await _chatService.setSelectedVersion(
        convId,
        roundGroupId,
        adoptedFinalVersion,
      );
    }

    // If no more subgroup messages remain, exit entirely.
    final anyRemaining = _chatController.messages.any(
      (m) => m.subgroupId != null,
    );
    if (!anyRemaining) {
      exit();
    } else {
      _chatController.invalidateCache();
      notifyListeners();
    }
  }

  /// Drop a thread: clear subgroupId on ALL its messages across all rounds.
  Future<void> dropThread(String threadId) async {
    var matchCount = 0;
    final totalSubgroup = _chatController.messages
        .where((m) => m.subgroupId != null)
        .length;
    debugPrint(
      '[MultiAI][dropThread] threadId=$threadId totalSubgroup=$totalSubgroup',
    );
    for (final msg in List<ChatMessage>.of(_chatController.messages)) {
      if (msg.subgroupId != threadId) continue;
      matchCount++;
      final updated = msg.copyWith(subgroupId: null);
      _chatController.replaceMessage(updated);
      await _chatService.updateMessage(
        msg.id,
        subgroupId: null,
        content: updated.content,
        totalTokens: updated.totalTokens,
        isStreaming: updated.isStreaming,
      );
    }

    debugPrint('[MultiAI][dropThread] cleared matchCount=$matchCount');
    final remaining = removeThread(threadId);

    if (remaining == 1) {
      // Auto-adopt: resolve the remaining thread.
      final remainingTid = _threadIds[0];
      final anchor = latestAnchorId;
      debugPrint(
        '[MultiAI][dropThread] auto-adopt remainingTid=$remainingTid anchor=$anchor',
      );
      if (anchor != null) {
        final msgs = getMessagesForAnchor(anchor);
        final threadMsgs = msgs[remainingTid] ?? [];
        if (threadMsgs.isNotEmpty) {
          await resolveThread(
            anchorId: anchor,
            threadId: remainingTid,
            version: threadMsgs.last.version,
          );
          return; // resolveThread handles exit + notify
        }
      }
      exit();
    } else if (remaining < 1) {
      exit();
    } else {
      _chatController.invalidateCache();
      notifyListeners();
    }
  }
}
