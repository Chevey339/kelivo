import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/compress_context_options.dart';
import '../../../core/models/conversation.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/model_override_payload_parser.dart';
import '../../../core/services/logging/flutter_logger.dart';
import '../../../core/services/memory/memory_pipeline.dart';
import '../../../core/services/memory/memory_trace.dart';
import '../../../utils/utf16_safe_cut.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/widgets/chat_message_widget.dart' show ToolUIPart;
import '../services/message_builder_service.dart';
import '../services/message_generation_service.dart';
import '../services/chat_suggestion_service.dart';
import '../utils/model_display_helper.dart';
import 'chat_actions.dart';
import 'file_processing_indicator_controller.dart';
import 'chat_controller.dart';
import 'generation_controller.dart';
import 'stream_controller.dart' as stream_ctrl;

export '../../../core/models/compress_context_options.dart';

enum BackgroundTaskKind { ocr, title, summary, suggestions, memory }

class BatchDeleteGroupPlan {
  const BatchDeleteGroupPlan({
    required this.groupId,
    required this.versionsBefore,
    required this.deletedMessageIds,
    required this.nextVersionSelection,
  });

  final String groupId;
  final List<ChatMessage> versionsBefore;
  final Set<String> deletedMessageIds;
  final int? nextVersionSelection;
}

class BatchDeletePlan {
  const BatchDeletePlan({
    required this.groups,
    required this.nextVersionSelections,
    required this.clearedVersionSelectionGroupIds,
  });

  static const empty = BatchDeletePlan(
    groups: <String, BatchDeleteGroupPlan>{},
    nextVersionSelections: <String, int>{},
    clearedVersionSelectionGroupIds: <String>{},
  );

  final Map<String, BatchDeleteGroupPlan> groups;
  final Map<String, int> nextVersionSelections;
  final Set<String> clearedVersionSelectionGroupIds;

  bool get isEmpty => groups.isEmpty;

  Set<String> get deletedMessageIds => {
    for (final group in groups.values) ...group.deletedMessageIds,
  };
}

/// Result of [HomeViewModel.prepareConversationSwitch]: everything needed to
/// commit a conversation switch atomically once the caller is ready.
class PreparedConversationSwitch {
  const PreparedConversationSwitch({
    required this.conversation,
    required this.window,
  });

  final Conversation conversation;
  final FetchedConversationWindow window;
}

/// ViewModel for the home page, combining actions + services.
///
/// This ViewModel:
/// - Holds all page state (conversation, messages, loading, etc.)
/// - Calls ChatActions for business operations
/// - Notifies UI of state changes via ChangeNotifier
/// - Handles conversation switching/creation
///
/// UI layer only needs to:
/// - Listen to this ViewModel
/// - Call simple methods like sendMessage(), regenerate(), etc.
/// - Handle UI-specific concerns (snackbars, scrolling, animations)
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this._chatService,
    required this._messageBuilderService,
    required this._messageGenerationService,
    required this._generationController,
    required this._streamController,
    required this._chatController,
    required this._contextProvider,
    required this.getTitleForLocale,
  }) {
    // Initialize ChatActions
    _chatActions = ChatActions(
      chatService: _chatService,
      chatController: _chatController,
      streamController: _streamController,
      generationController: _generationController,
      messageGenerationService: _messageGenerationService,
      contextProvider: _contextProvider,
      viewModel: this,
    );

    // Wire up callbacks
    _chatActions.onMessagesChanged = _onMessagesChanged;
    _chatActions.onSendPairAppended = () => onScrollToBottom?.call();
    _chatActions.onLoadingChanged = _onLoadingChanged;
    _chatActions.onContentUpdated = _onContentUpdated;
    _chatActions.onStreamError = _onStreamError;
    _chatActions.onMaybeGenerateTitle = _onMaybeGenerateTitle;
    _chatActions.onMaybeGenerateSummary = _onMaybeGenerateSummary;
    _chatActions.onMaybeGenerateSuggestions = _onMaybeGenerateSuggestions;
    _chatActions.onStreamFinished = _onStreamFinished;
    _chatActions.onAssistantMessageFinished = _onAssistantMessageFinished;
    _chatActions.onFileProcessingStarted = _onFileProcessingStarted;
    _chatActions.onFileProcessingFinished = _onFileProcessingFinished;
  }

  // ============================================================================
  // Dependencies
  // ============================================================================

  final ChatService _chatService;
  // ignore: unused_field - Reserved for future use (direct message building)
  final MessageBuilderService _messageBuilderService;
  // ignore: unused_field - Reserved for future use (direct generation control)
  final MessageGenerationService _messageGenerationService;
  final GenerationController _generationController;
  final stream_ctrl.StreamController _streamController;
  final ChatController _chatController;
  final BuildContext _contextProvider;
  final ChatSuggestionService _suggestionService =
      const ChatSuggestionService();
  late final ChatActions _chatActions;

  @visibleForTesting
  ChatActions get debugChatActions => _chatActions;
  QueuedChatInput? _queuedInput;
  bool _isDrainingQueuedInput = false;

  /// Function to get localized title
  final String Function(BuildContext context) getTitleForLocale;

  // ============================================================================
  // Callbacks for UI (set by HomePage)
  // ============================================================================

  /// Called when an error occurs (UI should show snackbar).
  void Function(String error)? onError;

  /// Called when a non-blocking background model task fails.
  void Function(BackgroundTaskKind task, Object error)? onBackgroundTaskError;

  /// Called when a warning occurs (UI should show snackbar).
  void Function(String warning)? onWarning;

  /// Called when streaming finishes (UI may show notification).
  void Function(String conversationId)? onStreamFinished;

  /// Called when a successful assistant reply is finalized.
  void Function(ChatMessage message)? onAssistantMessageFinished;

  /// Called to schedule inline image sanitization.
  void Function(String messageId, String content, {bool immediate})?
  onScheduleImageSanitize;

  /// Called when scrolling to bottom is needed.
  VoidCallback? onScrollToBottom;

  /// Called for haptic feedback.
  VoidCallback? onHapticFeedback;

  /// Called when conversation is successfully switched (for animations).
  VoidCallback? onConversationSwitched;

  // ============================================================================
  // State Getters (delegate to ChatController)
  // ============================================================================

  Conversation? get currentConversation => _chatController.currentConversation;
  List<ChatMessage> get messages => _chatController.messages;
  Map<String, int> get versionSelections => _chatController.versionSelections;
  Set<String> get loadingConversationIds => <String>{
    for (final id in _chatController.loadingConversationIds)
      if (!_chatActions.isStopping(id)) id,
  };

  /// Whether send/regenerate or cancellation teardown owns [conversationId].
  bool isConversationSendInFlight(String conversationId) =>
      _chatActions.isSendInFlight(conversationId);
  Map<String, StreamSubscription<dynamic>> get conversationStreams =>
      _chatController.conversationStreams;

  /// StreamController state getters
  Map<String, stream_ctrl.ReasoningData> get reasoning =>
      _streamController.reasoning;
  Map<String, List<stream_ctrl.ReasoningSegmentData>> get reasoningSegments =>
      _streamController.reasoningSegments;
  Map<String, stream_ctrl.ContentSplitData> get contentSplits =>
      _streamController.contentSplits;
  Map<String, List<ToolUIPart>> get toolParts => _streamController.toolParts;

  /// Whether the current conversation should show the generating state.
  bool get isCurrentConversationLoading {
    final cid = currentConversation?.id;
    if (cid == null) return false;
    return _chatController.isConversationLoading(cid) &&
        !_chatActions.isStopping(cid);
  }

  QueuedChatInput? get currentQueuedInput {
    final cid = currentConversation?.id;
    final queued = _queuedInput;
    if (cid == null || queued == null || queued.conversationId != cid) {
      return null;
    }
    return queued;
  }

  final FileProcessingIndicatorController _fileProcessingIndicator =
      FileProcessingIndicatorController();

  /// Id of the assistant message whose attachments are being parsed, or null.
  /// Scoped to a single message so the indicator never appears on every reply.
  ValueNotifier<String?> get processingFilesMessageId =>
      _fileProcessingIndicator.messageId;

  // ============================================================================
  // Internal Callbacks
  // ============================================================================

  void _onMessagesChanged() {
    _chatController.invalidateCache();
    notifyListeners();
  }

  void _onLoadingChanged(String conversationId, bool loading) {
    notifyListeners();
    if (!loading) {
      unawaited(_drainQueuedInputIfReady(conversationId));
    }
  }

  void _onContentUpdated(String messageId, String content, int totalTokens) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _chatController.replaceMessageSnapshot(
        messages[index].copyWith(content: content, totalTokens: totalTokens),
      );
      // NOTE: Do NOT call notifyListeners() here!
      // Streaming content updates are now handled by StreamingContentNotifier
      // via ValueListenableBuilder, which only rebuilds the streaming message widget.
      // Calling notifyListeners() here would trigger a full page rebuild and cause lag.
    }
  }

  void _onStreamError(String error) {
    onError?.call(error);
  }

  void _onMaybeGenerateTitle(String conversationId) {
    _runBackgroundTask(
      BackgroundTaskKind.title,
      _maybeGenerateTitleFor(conversationId),
    );
  }

  void _onMaybeGenerateSummary(String conversationId) {
    _runBackgroundTask(
      BackgroundTaskKind.summary,
      _maybeGenerateSummaryFor(conversationId),
    );
  }

  void _onMaybeGenerateSuggestions(String conversationId) {
    _runBackgroundTask(
      BackgroundTaskKind.suggestions,
      _maybeGenerateSuggestionsFor(conversationId),
    );
  }

  void _runBackgroundTask(BackgroundTaskKind task, Future<void> future) {
    unawaited(
      future.onError((error, stackTrace) {
        final reportedError = error ?? 'unknown error';
        FlutterLogger.log(
          '[BackgroundTask:$task] failed: $reportedError\n$stackTrace',
          tag: 'HomeViewModel',
        );
        onBackgroundTaskError?.call(task, reportedError);
      }),
    );
  }

  void _onStreamFinished(String conversationId) {
    onStreamFinished?.call(conversationId);
  }

  void _onAssistantMessageFinished(ChatMessage message) {
    onAssistantMessageFinished?.call(message);
    _onMaybeOrganizeMemory(message.conversationId);
  }

  /// Schedule background memory organize after a successful finalize (§12.1).
  /// Never awaited; failures must not surface as chat errors.
  void _onMaybeOrganizeMemory(String conversationId) {
    try {
      final settings = _contextProvider.read<SettingsProvider>();
      if (settings.legacyMemoryMode) return;
      final convo = _chatService.getConversation(conversationId);
      if (convo == null) return;
      final assistantProvider = _contextProvider.read<AssistantProvider>();
      final assistant = convo.assistantId != null
          ? assistantProvider.getById(convo.assistantId!)
          : assistantProvider.currentAssistant;
      if (assistant == null || !assistant.enableMemory) return;
      if (!assistant.autoOrganizeMemory) return;
      final pipeline = _contextProvider.read<MemoryPipelineService>();
      pipeline.scheduleIfNeeded(
        conversationId: conversationId,
        assistantId: assistant.id,
        onError: (error) =>
            onBackgroundTaskError?.call(BackgroundTaskKind.memory, error),
      );
    } catch (e, st) {
      FlutterLogger.log(
        '[MemoryPipeline] schedule failed: $e\n$st',
        tag: 'HomeViewModel',
      );
    }
  }

  /// Drops the indicator immediately, ignoring the minimum-visible hold. Used
  /// when the conversation the indicator belonged to is no longer on screen.
  void resetFileProcessingIndicator() => _fileProcessingIndicator.reset();

  void _onFileProcessingStarted(String messageId) =>
      _fileProcessingIndicator.start(messageId);

  void _onFileProcessingFinished(String? messageId) =>
      _fileProcessingIndicator.finish(messageId);

  // ============================================================================
  // Public Methods - Message Actions
  // ============================================================================

  /// Send a new message or queue it if the current conversation is busy.
  Future<ChatInputSubmissionResult> sendMessage(ChatInputData input) async {
    final content = input.text.trim();
    if (content.isEmpty &&
        input.imagePaths.isEmpty &&
        input.documents.isEmpty) {
      return ChatInputSubmissionResult.rejected;
    }

    final conversation = currentConversation;
    if (conversation == null) {
      // Create new conversation first
      await createNewConversation();
    }

    if (currentConversation == null) {
      onError?.call('no_conversation');
      return ChatInputSubmissionResult.rejected;
    }

    final activeConversation = currentConversation!;
    if (_chatController.isConversationLoading(activeConversation.id)) {
      if (_queuedInput != null) {
        return ChatInputSubmissionResult.rejected;
      }
      _queuedInput = QueuedChatInput(
        conversationId: activeConversation.id,
        input: _cloneInput(input),
      );
      notifyListeners();
      return ChatInputSubmissionResult.queued;
    }

    final success = await _sendMessageToConversation(input, activeConversation);
    return success
        ? ChatInputSubmissionResult.sent
        : ChatInputSubmissionResult.rejected;
  }

  ChatInputData? cancelCurrentQueuedInput() {
    final queued = currentQueuedInput;
    if (queued == null || _isDrainingQueuedInput) return null;
    _queuedInput = null;
    notifyListeners();
    return _cloneInput(queued.input);
  }

  Future<bool> _sendMessageToConversation(
    ChatInputData input,
    Conversation conversation,
  ) async {
    final content = input.text.trim();
    if (content.isEmpty &&
        input.imagePaths.isEmpty &&
        input.documents.isEmpty) {
      return false;
    }

    _chatActions.onScheduleImageSanitize = onScheduleImageSanitize;

    await _clearSuggestionsFor(conversation.id);

    onHapticFeedback?.call();

    // The indicator is raised by the generation itself, once the assistant
    // message it belongs to exists — nothing to raise or leak here.
    final result = await _chatActions.sendMessage(
      input: input,
      conversation: conversation,
    );

    if (!result.success) {
      // A concurrent send already owns this conversation; it owns the UI
      // state too, so the loser exits silently.
      if (result.errorMessage == 'in_flight') return false;
      if (result.errorMessage == 'no_model') {
        onWarning?.call('no_model');
      } else if (result.errorMessage != 'empty_input') {
        onError?.call(result.errorMessage ?? 'unknown_error');
      }
      return false;
    }

    return true;
  }

  ChatInputData _cloneInput(ChatInputData input) {
    return ChatInputData(
      text: input.text,
      imagePaths: List<String>.of(input.imagePaths),
      documents: List<DocumentAttachment>.of(input.documents),
      allowImagesApiRouting: input.allowImagesApiRouting,
    );
  }

  Future<void> _drainQueuedInputIfReady(String conversationId) async {
    if (_isDrainingQueuedInput) return;
    final queued = _queuedInput;
    final conversation = currentConversation;
    if (queued == null || conversation == null) return;
    if (queued.conversationId != conversationId ||
        conversation.id != conversationId) {
      return;
    }
    if (_chatController.isConversationLoading(conversationId)) return;

    _isDrainingQueuedInput = true;
    _queuedInput = null;
    notifyListeners();

    final input = queued.input;
    final success = await _sendMessageToConversation(input, conversation);
    if (!success) {
      _queuedInput = queued;
    }

    _isDrainingQueuedInput = false;
    notifyListeners();
  }

  /// Regenerate response at a specific message.
  Future<bool> regenerateAtMessage(
    ChatMessage message, {
    bool assistantAsNewReply = false,
    bool allowImagesApiRouting = true,
  }) async {
    final conversation = currentConversation;
    if (conversation == null) {
      return false;
    }

    // Set up image sanitization callback before regenerating
    _chatActions.onScheduleImageSanitize = onScheduleImageSanitize;

    onHapticFeedback?.call();
    await _clearSuggestionsFor(conversation.id);

    final result = await _chatActions.regenerateAtMessage(
      message: message,
      conversation: conversation,
      assistantAsNewReply: assistantAsNewReply,
      allowImagesApiRouting: allowImagesApiRouting,
    );

    if (!result.success) {
      // A concurrent send/regenerate already owns this conversation.
      if (result.errorMessage == 'in_flight') return false;
      if (result.errorMessage == 'no_model') {
        onWarning?.call('no_model');
      } else {
        onError?.call(result.errorMessage ?? 'unknown_error');
      }
      return false;
    }

    return true;
  }

  Future<bool> continueAssistantMessageAfterToolAnswer(
    ChatMessage message, {
    bool allowImagesApiRouting = true,
  }) async {
    final conversation = currentConversation;
    if (conversation == null) {
      return false;
    }

    _chatActions.onScheduleImageSanitize = onScheduleImageSanitize;
    await _clearSuggestionsFor(conversation.id);

    final result = await _chatActions.continueAssistantMessageAfterToolAnswer(
      message: message,
      conversation: conversation,
      allowImagesApiRouting: allowImagesApiRouting,
    );

    if (!result.success) {
      if (result.errorMessage == 'in_flight') return false;
      if (result.errorMessage == 'no_model') {
        onWarning?.call('no_model');
      } else {
        onError?.call(result.errorMessage ?? 'unknown_error');
      }
      return false;
    }

    return true;
  }

  /// Cancel the active streaming.
  Future<void> cancelStreaming() async {
    await _chatActions.cancelStreaming(currentConversation);
  }

  /// Delete a message and adjust version selections.
  ///
  /// Returns the list of message IDs to clean up UI state for.
  /// The UI layer should handle confirmation dialog before calling this.
  Future<void> deleteMessage({
    required ChatMessage message,
    required Map<String, List<ChatMessage>> byGroup,
  }) async {
    final gid = (message.groupId ?? message.id);
    final versBefore = List<ChatMessage>.of(
      byGroup[gid] ?? const <ChatMessage>[],
    )..sort((a, b) => a.version.compareTo(b.version));
    await _deleteMessageVersions(
      gid: gid,
      versionsBefore: versBefore,
      deletedMessageIds: <String>{message.id},
    );
  }

  Future<void> deleteAllMessageVersions({
    required ChatMessage message,
    required Map<String, List<ChatMessage>> byGroup,
  }) async {
    final gid = (message.groupId ?? message.id);
    final versBefore = List<ChatMessage>.of(
      byGroup[gid] ?? const <ChatMessage>[],
    )..sort((a, b) => a.version.compareTo(b.version));
    await _deleteMessageVersions(
      gid: gid,
      versionsBefore: versBefore,
      deletedMessageIds: versBefore.map((m) => m.id).toSet(),
    );
  }

  @visibleForTesting
  static int? computeNextVersionSelection({
    required List<ChatMessage> versionsBefore,
    required Set<String> deletedMessageIds,
    required int? oldSelection,
  }) {
    final sorted = List<ChatMessage>.of(versionsBefore)
      ..sort((a, b) => a.version.compareTo(b.version));
    if (sorted.isEmpty) return null;

    final remainingVersions =
        sorted
            .where((message) => !deletedMessageIds.contains(message.id))
            .map((message) => message.version)
            .toSet()
            .toList()
          ..sort();
    if (remainingVersions.isEmpty) return null;

    final newSelection = oldSelection ?? sorted.last.version;
    final selectedVersionWasDeleted = sorted.any(
      (message) =>
          deletedMessageIds.contains(message.id) &&
          message.version == newSelection,
    );
    if (!selectedVersionWasDeleted) return newSelection;

    for (final version in remainingVersions.reversed) {
      if (version < newSelection) return version;
    }
    return remainingVersions.first;
  }

  @visibleForTesting
  static BatchDeletePlan buildBatchDeletePlan({
    required List<ChatMessage> messages,
    required Set<String> selectedMessageIds,
    required Map<String, int> versionSelections,
    bool deleteAllVersions = false,
  }) {
    if (selectedMessageIds.isEmpty || messages.isEmpty) {
      return BatchDeletePlan.empty;
    }

    final byGroup = <String, List<ChatMessage>>{};
    final deletedByGroup = <String, Set<String>>{};
    for (final message in messages) {
      final groupId = message.groupId ?? message.id;
      byGroup.putIfAbsent(groupId, () => <ChatMessage>[]).add(message);
      if (selectedMessageIds.contains(message.id)) {
        deletedByGroup.putIfAbsent(groupId, () => <String>{});
        if (!deleteAllVersions) {
          deletedByGroup[groupId]!.add(message.id);
        }
      }
    }

    if (deletedByGroup.isEmpty) return BatchDeletePlan.empty;

    final groups = <String, BatchDeleteGroupPlan>{};
    final nextVersionSelections = <String, int>{};
    final clearedVersionSelectionGroupIds = <String>{};

    for (final entry in deletedByGroup.entries) {
      final groupId = entry.key;
      final versionsBefore = List<ChatMessage>.of(
        byGroup[groupId] ?? const <ChatMessage>[],
      )..sort((a, b) => a.version.compareTo(b.version));
      final deletedMessageIds = deleteAllVersions
          ? versionsBefore.map((message) => message.id).toSet()
          : Set<String>.of(entry.value);
      final oldSelection =
          versionSelections[groupId] ??
          (versionsBefore.isNotEmpty ? versionsBefore.last.version : 0);
      final nextVersionSelection = computeNextVersionSelection(
        versionsBefore: versionsBefore,
        deletedMessageIds: deletedMessageIds,
        oldSelection: oldSelection,
      );

      groups[groupId] = BatchDeleteGroupPlan(
        groupId: groupId,
        versionsBefore: versionsBefore,
        deletedMessageIds: deletedMessageIds,
        nextVersionSelection: nextVersionSelection,
      );

      if (nextVersionSelection == null) {
        clearedVersionSelectionGroupIds.add(groupId);
      } else {
        nextVersionSelections[groupId] = nextVersionSelection;
      }
    }

    return BatchDeletePlan(
      groups: groups,
      nextVersionSelections: nextVersionSelections,
      clearedVersionSelectionGroupIds: clearedVersionSelectionGroupIds,
    );
  }

  Future<void> deleteMessages({
    required Set<String> messageIds,
    bool deleteAllVersions = false,
  }) async {
    if (messageIds.isEmpty) return;

    // Only the selected groups matter for the plan; resolve their group ids
    // from the selected revisions, then load just those groups' versions.
    final selected = await _chatService.loadMessagesByIds(
      messageIds.toList(growable: false),
    );
    if (selected.isEmpty) return;
    // The confirmation dialog and the projection loads run before this, so
    // the user may have switched conversations since selecting. The loaded
    // revisions know which conversation they belong to; deleting against the
    // current one would silently no-op.
    final conversationId = selected.first.conversationId;
    bool isCurrentConversation() => currentConversation?.id == conversationId;
    final groupIds = selected
        .map((message) => message.groupId ?? message.id)
        .toSet();
    final scopedMessages = await _chatService.loadMessagesForGroups(
      conversationId,
      groupIds,
    );
    Map<String, int> selections = const <String, int>{};
    if (isCurrentConversation()) {
      selections = _chatController.versionSelections;
    } else {
      try {
        selections = _chatService.getVersionSelections(conversationId);
      } catch (_) {}
    }
    final plan = buildBatchDeletePlan(
      messages: scopedMessages,
      selectedMessageIds: messageIds,
      versionSelections: selections,
      deleteAllVersions: deleteAllVersions,
    );
    if (plan.isEmpty) return;

    // Deleting the row an active generation checkpoints into would make the
    // next streaming write hit a foreign key on deleted messages; stop the
    // generation first.
    final streamingMessageId = _chatActions.activeStreamingMessageId(
      conversationId,
    );
    if (streamingMessageId != null &&
        plan.deletedMessageIds.contains(streamingMessageId)) {
      await _chatActions.cancelStreaming(
        _chatService.getConversation(conversationId),
      );
    }

    final deletedMessageIds = await _chatService.deleteMessages(
      conversationId: conversationId,
      messageIds: plan.deletedMessageIds,
      versionSelectionChanges: {
        for (final groupId in plan.clearedVersionSelectionGroupIds)
          groupId: null,
        ...plan.nextVersionSelections,
      },
    );
    for (final id in deletedMessageIds) {
      _streamController.clearMessageState(id);
    }
    if (isCurrentConversation()) {
      _chatController.loadVersionSelections();
      _chatController.updateCurrentConversation(
        _chatService.getConversation(conversationId),
      );

      // scopedMessages holds every pre-deletion version of every affected
      // group, so the per-group survivors are complete.
      final survivingVersionsByGroup = <String, List<ChatMessage>>{};
      for (final message in scopedMessages) {
        final groupId = message.groupId ?? message.id;
        final survivors = survivingVersionsByGroup.putIfAbsent(
          groupId,
          () => <ChatMessage>[],
        );
        if (!deletedMessageIds.contains(message.id)) survivors.add(message);
      }
      await _chatController.refreshTimelineAfterMutation(
        removedRevisionIds: deletedMessageIds,
        survivingVersionsByGroup: survivingVersionsByGroup,
      );
    }
    notifyListeners();
  }

  Future<void> _deleteMessageVersions({
    required String gid,
    required List<ChatMessage> versionsBefore,
    required Set<String> deletedMessageIds,
  }) async {
    if (deletedMessageIds.isEmpty) return;

    // The animated delete flow awaits the removal animation before calling
    // this, so the user may have switched conversations in the meantime.
    // Deleting against whichever conversation is current would silently
    // no-op (the ids belong to another conversation), so target the
    // conversation the revisions belong to and only touch the loaded
    // timeline while it is still the current one.
    final targetConversationId = versionsBefore.isNotEmpty
        ? versionsBefore.first.conversationId
        : currentConversation?.id;
    final conversation = targetConversationId == currentConversation?.id
        ? currentConversation
        : (targetConversationId == null
              ? null
              : _chatService.getConversation(targetConversationId));
    bool isCurrentConversation() =>
        conversation != null && conversation.id == currentConversation?.id;

    Map<String, int> selections = const <String, int>{};
    if (isCurrentConversation()) {
      selections = versionSelections;
    } else if (conversation != null) {
      try {
        selections = _chatService.getVersionSelections(conversation.id);
      } catch (_) {}
    }
    final oldSel =
        selections[gid] ??
        (versionsBefore.isNotEmpty ? versionsBefore.last.version : 0);
    final newSel = computeNextVersionSelection(
      versionsBefore: versionsBefore,
      deletedMessageIds: deletedMessageIds,
      oldSelection: oldSel,
    );

    var removedRevisionIds = deletedMessageIds;
    if (conversation != null) {
      // Deleting the row an active generation checkpoints into would make the
      // next streaming write hit a foreign key on deleted messages; stop the
      // generation first.
      final streamingMessageId = _chatActions.activeStreamingMessageId(
        conversation.id,
      );
      if (streamingMessageId != null &&
          deletedMessageIds.contains(streamingMessageId)) {
        await _chatActions.cancelStreaming(conversation);
      }
      removedRevisionIds = await _chatService.deleteMessages(
        conversationId: conversation.id,
        messageIds: deletedMessageIds,
        versionSelectionChanges: {gid: newSel},
      );
      if (isCurrentConversation()) {
        _chatController.updateCurrentConversation(
          _chatService.getConversation(conversation.id),
        );
      }
    }
    for (final id in removedRevisionIds) {
      _streamController.clearMessageState(id);
    }
    if (isCurrentConversation()) {
      _chatController.loadVersionSelections();
      await _chatController.refreshTimelineAfterMutation(
        removedRevisionIds: removedRevisionIds,
        survivingVersionsByGroup: {
          gid: [
            for (final candidate in versionsBefore)
              if (!removedRevisionIds.contains(candidate.id)) candidate,
          ],
        },
      );
    }
    notifyListeners();
  }

  // ============================================================================
  // Public Methods - Conversation Management
  // ============================================================================

  /// Switch to an existing conversation.
  ///
  /// The caller flushes the current conversation's progress before invoking
  /// this; do not flush here again.
  Future<void> switchConversation(String id) async {
    final assistantProvider = _contextProvider.read<AssistantProvider>();

    // Reset processing state on switch
    resetFileProcessingIndicator();

    if (currentConversation?.id == id) return;

    _chatService.setCurrentConversation(id);
    final convo = _chatService.getConversation(id);
    if (convo != null) {
      // Assistant preference persistence runs concurrently with the window
      // load; setCurrentAssistant notifies before its disk write completes.
      final assistantSwitch = _assistantSwitchFor(
        assistantProvider,
        convo.assistantId,
      );
      await Future.wait([
        _chatController.setCurrentConversationAndLoad(convo),
        if (assistantSwitch != null) assistantSwitch,
      ]);
      // Arm the new list's initial position before listeners can paint it with
      // the previous conversation's scroll offset.
      onConversationSwitched?.call();
      notifyListeners();
      unawaited(_drainQueuedInputIfReady(id));
    }
  }

  /// Fetch phase of an animated conversation switch: loads the target
  /// conversation's initial window without committing any state, so the
  /// caller can keep the previous list covered until it is ready to commit
  /// via [commitConversationSwitch]. Returns null when the switch is a no-op
  /// or the conversation is gone.
  Future<PreparedConversationSwitch?> prepareConversationSwitch(
    String id,
  ) async {
    // Reset processing state on switch
    resetFileProcessingIndicator();

    if (currentConversation?.id == id) return null;

    final convo = _chatService.getConversation(id);
    if (convo == null) return null;

    // The assistant switch is deferred to commitConversationSwitch: it
    // notifies listeners and rewrites the global currentAssistantId, so
    // running it here would leak the side effect when this preparation is
    // superseded and discarded before commit.
    final window = await _chatController.fetchConversationWindow(convo);
    return PreparedConversationSwitch(conversation: convo, window: window);
  }

  /// Commit phase of an animated conversation switch: installs a snapshot
  /// previously fetched by [prepareConversationSwitch].
  void commitConversationSwitch(PreparedConversationSwitch prepared) {
    final id = prepared.conversation.id;
    _chatService.setCurrentConversation(id);
    _chatController.commitConversationWindow(
      prepared.window,
      onDeferredGroupDataLoaded: notifyListeners,
    );
    // Same concurrency as switchConversation: the assistant change notifies
    // before its disk write completes.
    final assistantProvider = _contextProvider.read<AssistantProvider>();
    final assistantSwitch = _assistantSwitchFor(
      assistantProvider,
      prepared.conversation.assistantId,
    );
    if (assistantSwitch != null) unawaited(assistantSwitch);
    // Arm the new list's initial position before listeners can paint it with
    // the previous conversation's scroll offset.
    onConversationSwitched?.call();
    notifyListeners();
    unawaited(_drainQueuedInputIfReady(id));
  }

  /// Starts persisting the assistant preference for a switch, or null when
  /// the assistant does not change.
  Future<void>? _assistantSwitchFor(
    AssistantProvider assistantProvider,
    String? convoAssistantId,
  ) {
    if (convoAssistantId == null ||
        assistantProvider.currentAssistantId == convoAssistantId ||
        assistantProvider.getById(convoAssistantId) == null) {
      return null;
    }
    return assistantProvider.setCurrentAssistant(convoAssistantId);
  }

  /// Create a new conversation.
  Future<void> createNewConversation() async {
    // Flush current conversation progress before creating new
    await _chatActions.flushConversationProgress(currentConversation);
    if (!_contextProvider.mounted) return;

    // Reset processing state on create
    resetFileProcessingIndicator();

    final ap = _contextProvider.read<AssistantProvider>();
    try {
      await ap.loaded;
    } catch (e) {
      onError?.call(e.toString());
      return;
    }
    if (!_contextProvider.mounted) return;
    final assistantId = ap.currentAssistantId;
    final a = ap.currentAssistant;

    final conversation = await _chatService.createDraftConversation(
      title: getTitleForLocale(_contextProvider),
      assistantId: assistantId,
    );

    _chatController.setDraftConversation(conversation);
    _streamController.clearAllState();
    notifyListeners();

    // Inject assistant preset messages into new conversation (ordered)
    try {
      final presets = ap.getPresetMessagesForAssistant(a?.id);
      if (presets.isNotEmpty && currentConversation != null) {
        final injected = <ChatMessage>[];
        for (final pm in presets) {
          final role = (pm['role'] == 'assistant') ? 'assistant' : 'user';
          final content = (pm['content'] ?? '').trim();
          if (content.isEmpty) continue;
          injected.add(
            await _chatService.addMessage(
              conversationId: currentConversation!.id,
              role: role,
              content: content,
            ),
          );
        }
        // One batch append publishes the whole preset block with a single
        // notify instead of one per message.
        if (injected.isNotEmpty) {
          await _chatController.appendPersistedTailMessages(injected);
        }
      }
    } catch (_) {}

    onScrollToBottom?.call();
  }

  Future<void> toggleTemporaryConversation() async {
    final convo = currentConversation;
    if (convo == null || messages.isNotEmpty) return;

    await _chatActions.flushConversationProgress(currentConversation);
    if (!_contextProvider.mounted) return;

    resetFileProcessingIndicator();

    if (_chatService.isTemporaryConversation(convo.id)) {
      await createNewConversation();
      return;
    }

    final ap = _contextProvider.read<AssistantProvider>();
    try {
      await ap.loaded;
    } catch (e) {
      onError?.call(e.toString());
      return;
    }
    if (!_contextProvider.mounted) return;
    final conversation = await _chatService.createDraftConversation(
      title: AppLocalizations.of(_contextProvider)!.temporaryChatTitle,
      assistantId: ap.currentAssistantId,
      temporary: true,
    );

    _chatController.setDraftConversation(conversation);
    _streamController.clearAllState();
    notifyListeners();
    onScrollToBottom?.call();
  }

  /// Fork conversation at a specific message.
  Future<void> forkConversation(ChatMessage message) async {
    final title = getTitleForLocale(_contextProvider);
    final sourceConversation = currentConversation;
    if (sourceConversation == null) return;
    final newConvo = await _chatService.forkConversationAtRevision(
      sourceConversationId: sourceConversation.id,
      sourceRevisionId: message.id,
      title: title,
      preserveVersions: _contextProvider
          .read<SettingsProvider>()
          .forkKeepMessageVersions,
    );

    // Switch to the new conversation
    _chatService.setCurrentConversation(newConvo.id);
    await _chatController.setCurrentConversationAndLoad(newConvo);
    _restoreMessageUiState();
    onConversationSwitched?.call();
    notifyListeners();
    onScrollToBottom?.call();
  }

  /// Clear context (toggle truncate at tail).
  /// Sets or clears the current conversation's model override.
  ///
  /// Passing null for both makes the conversation follow the assistant again.
  Future<void> setConversationModel({
    String? providerKey,
    String? modelId,
  }) async {
    final convo = currentConversation;
    if (convo == null) return;
    final updated = await _chatService.setConversationModel(
      convo.id,
      providerKey: providerKey,
      modelId: modelId,
    );
    if (updated != null) {
      _chatController.updateCurrentConversation(updated);
      notifyListeners();
    }
  }

  Future<void> clearContext() async {
    final convo = currentConversation;
    if (convo == null) return;

    final defaultTitle = getTitleForLocale(_contextProvider);
    await _clearSuggestionsFor(convo.id);
    final updated = await _chatService.toggleTruncateAtTail(
      convo.id,
      defaultTitle: defaultTitle,
    );
    if (updated != null) {
      _chatController.updateCurrentConversation(updated);
      notifyListeners();
    }
  }

  /// Compress context: summarize messages via LLM, create new conversation with summary.
  /// Returns null on success, or an error key string on failure.
  Future<String?> compressContext({
    required CompressContextOptions options,
  }) async {
    final convo = currentConversation;
    if (convo == null) return 'no_conversation';

    final locale = Localizations.localeOf(_contextProvider).toLanguageTag();
    final settings = _contextProvider.read<SettingsProvider>();
    final ap = _contextProvider.read<AssistantProvider>();
    final assistant = convo.assistantId != null
        ? ap.getById(convo.assistantId!)
        : ap.currentAssistant;

    // Get messages and collapse to selected versions
    final allMsgs = await _chatController
        .allMessagesForCurrentConversationContext();
    final collapsed = collapseVersions(allMsgs);
    if (collapsed.isEmpty) return 'no_messages';

    List<ChatMessage>? keptMessages;
    var summarizeInput = collapsed;
    if (options.mode == CompressContextLimitMode.keepRecent) {
      final keepN =
          options.keepUserMessages ??
          CompressContextOptions.defaultKeepUserMessages;
      keptMessages = selectKeepRecentMessages(collapsed, keepN);
      if (keptMessages.length >= collapsed.length) return 'no_messages';
      summarizeInput = collapsed.sublist(
        0,
        collapsed.length - keptMessages.length,
      );
    }

    // Resolve model first so the chunk budget can follow its context window.
    final resolvedModel = resolveCompressContextModel(
      compressProvider: settings.compressModelProvider,
      compressModelId: settings.compressModelId,
      summaryProvider: settings.summaryModelProvider,
      summaryModelId: settings.summaryModelId,
      titleProvider: settings.titleModelProvider,
      titleModelId: settings.titleModelId,
      assistantProvider: assistant?.chatModelProvider,
      assistantModelId: assistant?.chatModelId,
      currentProvider: settings.currentModelProvider,
      currentModelId: settings.currentModelId,
    );
    final provKey = resolvedModel.providerKey;
    final mdlId = resolvedModel.modelId;
    if (provKey == null || mdlId == null) return 'no_model';

    final cfg = settings.getProviderConfig(provKey);
    final budget = settings.compressGenerationThinkingBudgetFor(
      assistant?.thinkingBudget,
    );

    var stage = 'prepare';
    var inputLength = summarizeInput.fold<int>(
      0,
      (sum, message) => sum + message.content.length,
    );

    Future<String> summarizeContent(String content, String label) async {
      return summarizeWithContextRetry(
        content,
        summarize: (text) async {
          stage = label;
          inputLength = text.length;
          final prompt = settings.compressPrompt
              .replaceAll('{content}', text)
              .replaceAll('{locale}', locale);
          return (await ChatApiService.generateText(
            config: cfg,
            modelId: mdlId,
            prompt: prompt,
            thinkingBudget: budget,
            skipImageParsing: true,
          )).trim();
        },
        onSplitRetry: (e, st, text) {
          FlutterLogger.log(
            '[CompressContext] context-length split-retry at $stage '
            '(inputChars=${text.length}): $e\n$st',
            tag: 'HomeViewModel',
          );
        },
      );
    }

    try {
      stage = 'prepare';
      final requestChars = compressRequestCharBudget(
        contextWindowTokens: readModelContextWindowTokens(
          ModelOverridePayloadParser.modelOverride(cfg.modelOverrides, mdlId),
        ),
      );
      stage = 'chunk';
      final chunks = buildCompressRequestContents(
        summarizeInput,
        options,
        safeRequestChars: requestChars,
      );
      if (chunks.isEmpty) return 'no_messages';
      inputLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);

      String summary;
      if (chunks.length == 1) {
        summary = await summarizeContent(chunks.single, 'generate');
      } else {
        final partials = <String>[];
        for (var i = 0; i < chunks.length; i++) {
          final part = await summarizeContent(
            chunks[i],
            'chunk ${i + 1}/${chunks.length}',
          );
          if (part.isEmpty) return 'empty_summary';
          partials.add(part);
        }
        var pending = partials;
        var mergeRound = 0;
        const maxMergeRounds = 8;
        while (pending.length > 1 && mergeRound < maxMergeRounds) {
          mergeRound++;
          final packed = chunkPlainTexts(pending, maxChars: requestChars);
          final next = <String>[];
          for (var i = 0; i < packed.length; i++) {
            final part = await summarizeContent(
              packed[i],
              'merge $mergeRound (${i + 1}/${packed.length})',
            );
            if (part.isEmpty) return 'empty_summary';
            next.add(part);
          }
          pending = next;
        }
        if (pending.length > 1) {
          summary = await summarizeContent(
            truncateHeadUtf16Safe(pending.join('\n\n'), requestChars),
            'merge-truncate',
          );
        } else {
          summary = pending.single;
        }
      }

      if (summary.isEmpty) return 'empty_summary';

      if (keptMessages != null) {
        final summaryMsg = ChatMessage(
          role: 'user',
          content: summary,
          timestamp: DateTime.now(),
          conversationId: convo.id,
        );
        final newConvo = await _chatService.forkConversationFromMessages(
          title: convo.title,
          assistantId: convo.assistantId,
          sourceMessages: [summaryMsg, ...keptMessages],
        );

        _chatService.setCurrentConversation(newConvo.id);
        await _chatController.setCurrentConversationAndLoad(
          _chatService.getConversation(newConvo.id) ?? newConvo,
        );
        _restoreMessageUiState();
        _streamController.clearAllState();
        onConversationSwitched?.call();
        notifyListeners();
        onScrollToBottom?.call();

        return null; // success
      }

      // Create new conversation with the summary as first user message
      final newConvo = await _chatService.createDraftConversation(
        title: convo.title,
        assistantId: convo.assistantId,
      );

      await _chatService.addMessage(
        conversationId: newConvo.id,
        role: 'user',
        content: summary,
      );

      // Switch to the new conversation
      _chatService.setCurrentConversation(newConvo.id);
      await _chatController.setCurrentConversationAndLoad(
        _chatService.getConversation(newConvo.id) ?? newConvo,
      );
      _streamController.clearAllState();
      onConversationSwitched?.call();
      notifyListeners();
      onScrollToBottom?.call();

      return null; // success
    } catch (e, st) {
      FlutterLogger.log(
        '[CompressContext] failed at $stage (inputChars=$inputLength): $e\n$st',
        tag: 'HomeViewModel',
      );
      return e.toString();
    }
  }

  /// Update current conversation reference.
  void updateCurrentConversation(Conversation? conversation) {
    _chatController.updateCurrentConversation(conversation);
    notifyListeners();
  }

  Future<bool> loadMoreBefore() async {
    final loaded = await _chatController.loadMoreBefore();
    if (!loaded) return false;
    _restoreMessageUiState();
    notifyListeners();
    return true;
  }

  Future<bool> loadMoreAfter() async {
    final loaded = await _chatController.loadMoreAfter();
    if (!loaded) return false;
    _restoreMessageUiState();
    notifyListeners();
    return true;
  }

  Future<bool> loadUntilMessageVisible(String messageId) async {
    final loaded = await _chatController.loadUntilMessageVisible(messageId);
    if (!loaded) return false;
    _restoreMessageUiState();
    notifyListeners();
    return true;
  }

  /// Set selected version for a message group.
  Future<void> setSelectedVersion(String groupId, int version) async {
    final cid = currentConversation?.id;
    if (cid != null) {
      await _clearSuggestionsFor(cid);
    }
    await _chatController.setSelectedVersion(groupId, version);
    notifyListeners();
  }

  // ============================================================================
  // Public Methods - UI State
  // ============================================================================

  /// Restore per-message UI states after switching conversations.
  void restoreMessageUiState() {
    _restoreMessageUiState();
    notifyListeners();
  }

  void _restoreMessageUiState() {
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.role == 'assistant') {
        _streamController.restoreMessageUiState(
          m,
          getToolEventsFromDb: (id) => _chatService.getToolEvents(id),
        );

        final cleanedContent = _chatService.migrateLegacyGeminiThoughtSignature(
          m.content,
          m.id,
        );
        if (cleanedContent != m.content) {
          final updated = m.copyWith(content: cleanedContent);
          _chatController.replaceMessageSnapshot(updated);
          unawaited(_chatService.updateMessage(m.id, content: cleanedContent));
        }

        // Clean up any inline base64 images persisted from earlier runs
        onScheduleImageSanitize?.call(
          m.id,
          messages[i].content,
          immediate: true,
        );
      }
    }
  }

  /// Serialize reasoning segments to JSON string.
  String serializeReasoningSegments(
    List<stream_ctrl.ReasoningSegmentData> segments,
  ) {
    return _streamController.serializeReasoningSegments(segments);
  }

  /// Collapse message versions to show only selected version per group.
  List<ChatMessage> collapseVersions(List<ChatMessage> items) {
    return _chatController.collapseVersions(items);
  }

  /// Group messages by their groupId.
  Map<String, List<ChatMessage>> groupMessagesByGroup() {
    return _chatController.groupMessagesByGroup();
  }

  /// Get clear context label based on current state.
  String getClearContextLabel(
    String Function(String, String) withCountFormatter,
    String defaultLabel,
  ) {
    final assistant = _contextProvider
        .read<AssistantProvider>()
        .currentAssistant;
    final configured = (assistant?.limitContextMessages ?? false)
        ? (assistant?.contextMessageSize ?? 0)
        : 0;
    // Timeline totals and truncateIndex both use logical message slots.
    final remaining = computeClearContextRemainingMessageCount(
      totalMessages: _chatController.totalMessageCount,
      truncateIndex: currentConversation == null
          ? -1
          : _chatService.getContextStartIndex(currentConversation!.id),
    );
    if (configured > 0) {
      final actual = remaining > configured ? configured : remaining;
      return withCountFormatter(actual.toString(), configured.toString());
    }
    return defaultLabel;
  }

  /// Test entry for [_maybeGenerateSummaryFor].
  @visibleForTesting
  Future<void> debugMaybeGenerateSummaryFor(String conversationId) =>
      _maybeGenerateSummaryFor(conversationId);

  /// Test entry for [_maybeGenerateTitleFor].
  @visibleForTesting
  Future<void> debugMaybeGenerateTitleFor(
    String conversationId, {
    bool force = false,
  }) => _maybeGenerateTitleFor(conversationId, force: force);

  @visibleForTesting
  static int computeClearContextRemainingMessageCount({
    required int totalMessages,
    required int truncateIndex,
  }) {
    final safeTruncateIndex =
        (truncateIndex < 0 || truncateIndex > totalMessages)
        ? 0
        : truncateIndex;
    return totalMessages - safeTruncateIndex;
  }

  // ============================================================================
  // Title Generation
  // ============================================================================

  /// Generate title for a conversation if needed.
  Future<void> _maybeGenerateTitleFor(
    String conversationId, {
    bool force = false,
  }) async {
    final convo = _chatService.getConversation(conversationId);
    if (convo == null) return;
    if (!force &&
        convo.title.isNotEmpty &&
        convo.title != getTitleForLocale(_contextProvider)) {
      return;
    }

    final settings = _contextProvider.read<SettingsProvider>();
    if (!settings.isTitleGenerationEnabled) return;

    final assistantProvider = _contextProvider.read<AssistantProvider>();

    // Get assistant for this conversation
    final assistant = convo.assistantId != null
        ? assistantProvider.getById(convo.assistantId!)
        : assistantProvider.currentAssistant;
    final chatModel = resolveChatModel(
      settings,
      conversation: convo,
      assistant: assistant,
    );
    final provKey = settings.titleModelProvider ?? chatModel.providerKey;
    final mdlId = settings.titleModelId ?? chatModel.modelId;
    if (provKey == null || mdlId == null) return;
    final cfg = settings.getProviderConfig(provKey);
    final budget = settings.titleGenerationThinkingBudgetFor(
      assistant?.thinkingBudget,
    );
    final locale = Localizations.localeOf(_contextProvider).toLanguageTag();

    // Build content from messages (shared with the side drawer title path;
    // both cache and paging paths collect the same ~3000-char tail window)
    final content = await _chatService.generateTitleSource(convo.id);

    String prompt = settings.titlePrompt
        .replaceAll('{locale}', locale)
        .replaceAll('{content}', content);

    try {
      final title = (await ChatApiService.generateText(
        config: cfg,
        modelId: mdlId,
        prompt: prompt,
        thinkingBudget: budget,
        skipImageParsing: true,
      )).trim();
      if (title.isNotEmpty) {
        await _chatService.renameConversation(convo.id, title);
        if (currentConversation?.id == convo.id) {
          _chatController.updateCurrentConversation(
            _chatService.getConversation(convo.id),
          );
          notifyListeners();
        }
      } else {
        onBackgroundTaskError?.call(BackgroundTaskKind.title, 'empty_response');
      }
    } catch (e) {
      FlutterLogger.log(
        '[TitleGen] Generation failed: $e',
        tag: 'HomeViewModel',
      );
      onBackgroundTaskError?.call(BackgroundTaskKind.title, e);
    }
  }

  /// Force generate title for the current conversation.
  Future<void> generateTitle({bool force = false}) async {
    final cid = currentConversation?.id;
    if (cid != null) {
      await _maybeGenerateTitleFor(cid, force: force);
    }
  }

  // ============================================================================
  // Summary Generation
  // ============================================================================

  /// Generate summary for a conversation if conditions are met.
  /// Triggers after the configured number of new messages since last summary.
  Future<void> _maybeGenerateSummaryFor(String conversationId) async {
    final convo = _chatService.getConversation(conversationId);
    if (convo == null) return;
    // Summaries only feed past-conversation search; temporary chats are never searchable.
    if (_chatService.isTemporaryConversation(convo.id)) return;

    final settings = _contextProvider.read<SettingsProvider>();
    if (!_chatService.isMessageCountKnown(conversationId)) return;
    final msgCount = _chatService.getMessageCount(conversationId);
    final assistantProvider = _contextProvider.read<AssistantProvider>();

    // Get assistant for this conversation
    final assistant = convo.assistantId != null
        ? assistantProvider.getById(convo.assistantId!)
        : assistantProvider.currentAssistant;

    final budget = settings.summaryGenerationThinkingBudgetFor(
      assistant?.thinkingBudget,
    );

    final legacy = settings.legacyMemoryMode;
    if (legacy) {
      if (assistant?.allowPastConversationRecall != true) return;
    } else if (!MemoryPipelineService.shouldGenerateConversationSummary(
      allowPastConversationRecall:
          assistant?.allowPastConversationRecall == true,
      generateConversationSummary:
          assistant?.generateConversationSummary == true,
    )) {
      return;
    }

    final triggerMessageCount =
        assistant?.recentChatsSummaryMessageCount ??
        Assistant.defaultRecentChatsSummaryMessageCount;
    if (msgCount == 0 ||
        msgCount - convo.lastSummarizedMessageCount < triggerMessageCount) {
      return;
    }

    // Use summary model if configured, else fall back to title model, then current model
    final provKey =
        settings.summaryModelProvider ??
        settings.titleModelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final mdlId =
        settings.summaryModelId ??
        settings.titleModelId ??
        assistant?.chatModelId ??
        settings.currentModelId;
    if (provKey == null || mdlId == null) return;

    final cfg = settings.getProviderConfig(provKey);

    // Get all messages and filter user messages
    final msgs = await _chatService.loadMessages(convo.id);
    final allUserMsgs = msgs
        .where((m) => m.role == 'user' && m.content.trim().isNotEmpty)
        .toList();

    if (allUserMsgs.isEmpty) return;

    // Get previous summary (empty string if first time)
    final previousSummary = (convo.summary ?? '').trim();

    // Get only the recent user messages since last summarization
    // Calculate how many user messages were in the last summarized state
    final lastSummarizedMsgCount = (convo.lastSummarizedMessageCount < 0)
        ? 0
        : convo.lastSummarizedMessageCount;
    final msgsAtLastSummary = msgs.take(lastSummarizedMsgCount).toList();
    final userMsgsAtLastSummary = msgsAtLastSummary
        .where((m) => m.role == 'user' && m.content.trim().isNotEmpty)
        .length;

    // Get new user messages since last summary
    final newUserMsgs = allUserMsgs.skip(userMsgsAtLastSummary).toList();
    if (newUserMsgs.isEmpty) return;

    final recentMessages = newUserMsgs
        .map((m) => m.content.trim())
        .join('\n\n');

    // Truncate if too long
    final content = recentMessages.length > 2000
        ? recentMessages.substring(0, 2000)
        : recentMessages;

    final prompt = settings.summaryPrompt
        .replaceAll('{previous_summary}', previousSummary)
        .replaceAll('{user_messages}', content);

    final traceHandle = legacy ? null : _beginSummaryTrace(convo, assistant);
    final traceStep = traceHandle?.beginStep(
      MemoryTraceStepKind.conversationSummary,
    );
    traceStep?.appendPrompt(prompt);

    try {
      final summary = (await ChatApiService.generateText(
        config: cfg,
        modelId: mdlId,
        prompt: prompt,
        thinkingBudget: budget,
        skipImageParsing: true,
      )).trim();
      traceStep?.appendResponse(summary);

      if (summary.isNotEmpty) {
        await _chatService.updateConversationSummary(
          convo.id,
          summary,
          msgCount,
        );
        traceStep?.addMutation(
          MemoryTraceMutation(
            kind: MemoryTraceMutationKind.conversationSummaryWritten,
            targetId: convo.id,
            before: previousSummary.isEmpty ? null : previousSummary,
            after: summary,
          ),
        );
      }
      traceStep?.finish(MemoryTraceStepStatus.success);
      traceHandle?.commit(advanced: summary.isNotEmpty);
      if (summary.isNotEmpty) {
        if (currentConversation?.id == convo.id) {
          _chatController.updateCurrentConversation(
            _chatService.getConversation(convo.id),
          );
          notifyListeners();
        }
      } else {
        onBackgroundTaskError?.call(
          BackgroundTaskKind.summary,
          'empty_response',
        );
      }
    } catch (e) {
      // Keep the old summary when background generation fails.
      traceStep?.finish(MemoryTraceStepStatus.failed, error: e.toString());
      traceHandle?.commit(error: e.toString());
      onBackgroundTaskError?.call(BackgroundTaskKind.summary, e);
    }
  }

  /// Open a trace for background summary generation (feeds past-conversation
  /// recall). Never throws.
  MemoryTraceHandle? _beginSummaryTrace(
    Conversation convo,
    Assistant? assistant,
  ) {
    // Temporary chats are discarded on exit; keep their traces out of the UI.
    if (_chatService.isTemporaryConversation(convo.id)) {
      return null;
    }
    try {
      return MemoryTraceRecorder.instance.begin(
        trigger: MemoryTraceTrigger.conversationSummary,
        scope: assistant == null
            ? MemoryTraceScope.global
            : memoryTraceScopeOf(assistant.memoryWriteScope),
        conversationId: convo.id,
        conversationTitle: convo.title,
        assistantId: assistant?.id,
        assistantName: assistant?.name,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // Chat Suggestions
  // ============================================================================

  Future<void> _clearSuggestionsFor(String conversationId) async {
    final convo = _chatService.getConversation(conversationId);
    if (convo == null || convo.chatSuggestions.isEmpty) return;
    await _chatService.clearConversationSuggestions(conversationId);
    if (currentConversation?.id == conversationId) {
      _chatController.updateCurrentConversation(
        _chatService.getConversation(conversationId),
      );
      notifyListeners();
    }
  }

  Future<void> _maybeGenerateSuggestionsFor(String conversationId) async {
    final convo = _chatService.getConversation(conversationId);
    if (convo == null) return;

    final settings = _contextProvider.read<SettingsProvider>();
    if (!settings.isSuggestionGenerationEnabled) return;

    // Read context-dependent inputs before the async gap below.
    final assistantProvider = _contextProvider.read<AssistantProvider>();
    final assistant = convo.assistantId != null
        ? assistantProvider.getById(convo.assistantId!)
        : assistantProvider.currentAssistant;
    final chatModel = resolveChatModel(
      settings,
      conversation: convo,
      assistant: assistant,
    );
    final provKey = settings.suggestionModelProvider ?? chatModel.providerKey;
    final mdlId = settings.suggestionModelId ?? chatModel.modelId;
    if (provKey == null || mdlId == null) return;
    final locale = Localizations.localeOf(_contextProvider).toLanguageTag();
    final budget = settings.suggestionGenerationThinkingBudgetFor(
      assistant?.thinkingBudget,
    );

    final loadedMessages = await _chatService.loadMessages(convo.id);
    // Raw revision count snapshot for the post-generation freshness check:
    // getMessageCount counts every revision, the collapsed list does not.
    final loadedMessageCount = loadedMessages.length;
    final msgs = collapseVersions(loadedMessages);
    final lastAssistant = msgs.cast<ChatMessage?>().lastWhere(
      (m) =>
          m != null &&
          m.role == 'assistant' &&
          !m.isStreaming &&
          m.content.trim().isNotEmpty,
      orElse: () => null,
    );
    if (lastAssistant == null) return;

    try {
      await _chatService.clearConversationSuggestions(conversationId);
      final suggestions = await _suggestionService.generate(
        settings: settings,
        providerKey: provKey,
        modelId: mdlId,
        messages: msgs,
        truncateIndex: _chatService.getContextStartIndex(conversationId),
        locale: locale,
        thinkingBudget: budget,
      );
      if (suggestions.isEmpty) {
        onBackgroundTaskError?.call(
          BackgroundTaskKind.suggestions,
          'empty_response',
        );
        return;
      }

      final latest = _chatService.getConversation(conversationId);
      // loadMessages above populates the count; unknown (-1) ≠ loaded length
      // and correctly aborts publishing stale suggestions.
      if (latest == null ||
          _chatService.getMessageCount(latest.id) != loadedMessageCount) {
        return;
      }

      await _chatService.updateConversationSuggestions(
        conversationId,
        suggestions,
      );
      if (currentConversation?.id == conversationId) {
        _chatController.updateCurrentConversation(
          _chatService.getConversation(conversationId),
        );
        notifyListeners();
      }
    } catch (e) {
      FlutterLogger.log(
        '[SuggestionGen] Generation failed: $e',
        tag: 'HomeViewModel',
      );
      onBackgroundTaskError?.call(BackgroundTaskKind.suggestions, e);
    }
  }

  // ============================================================================
  // Model Capability Checks
  // ============================================================================

  bool isReasoningModel(String providerKey, String modelId) {
    return _generationController.isReasoningModel(providerKey, modelId);
  }

  bool isToolModel(String providerKey, String modelId) {
    return _generationController.isToolModel(providerKey, modelId);
  }

  bool isReasoningEnabled(int? budget) {
    return _generationController.isReasoningEnabled(budget);
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Flush current conversation progress (for switching/creating).
  Future<void> flushCurrentConversationProgress() async {
    await _chatActions.flushConversationProgress(currentConversation);
  }

  /// Clean up message state (reasoning, tools, etc.) for removed messages.
  void cleanupMessageState(List<String> messageIds) {
    for (final id in messageIds) {
      _streamController.clearMessageState(id);
    }
  }
}
