import 'dart:async';
import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/database/generation_run.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/ios_background_generation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/assistant_regex.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import '../services/ask_user_interaction_service.dart';
import '../services/message_generation_service.dart';
import '../services/tool_approval_service.dart';
import 'active_streaming_message_store.dart';
import 'chat_controller.dart';
import 'generation_controller.dart';
import 'home_view_model.dart';
import 'latest_wins_checkpoint_writer.dart';
import 'stream_controller.dart' as stream_ctrl;

final class _BarrierStreamSubscription<T> implements StreamSubscription<T> {
  _BarrierStreamSubscription(this._delegate, this._cancelWithBarrier);

  final StreamSubscription<T> _delegate;
  final Future<void> Function() _cancelWithBarrier;

  @override
  Future<void> cancel() => _cancelWithBarrier();

  @override
  void onData(void Function(T data)? handleData) =>
      _delegate.onData(handleData);

  @override
  void onError(Function? handleError) => _delegate.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _delegate.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _delegate.pause(resumeSignal);

  @override
  void resume() => _delegate.resume();

  @override
  bool get isPaused => _delegate.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _delegate.asFuture(futureValue);
}

class _StreamingCheckpoint {
  const _StreamingCheckpoint({
    required this.message,
    required this.toolEvents,
    this.generationRunId,
    this.checkpointSeq,
  });

  final ChatMessage message;
  final List<Map<String, dynamic>> toolEvents;
  final String? generationRunId;
  final int? checkpointSeq;
}

class _GenerationCheckpointCursor {
  _GenerationCheckpointCursor({
    required this.runId,
    required this.state,
    required this.stateRevision,
    required this.nextSeq,
  });

  final String runId;
  GenerationRunState state;
  int stateRevision;
  int nextSeq;
}

/// Result of a send/regenerate action.
class ChatActionResult {
  final bool success;
  final String? errorMessage;
  final ChatMessage? assistantMessage;

  ChatActionResult({
    required this.success,
    this.errorMessage,
    this.assistantMessage,
  });

  factory ChatActionResult.success(ChatMessage assistantMessage) =>
      ChatActionResult(success: true, assistantMessage: assistantMessage);

  factory ChatActionResult.error(String message) =>
      ChatActionResult(success: false, errorMessage: message);

  factory ChatActionResult.noModel() =>
      ChatActionResult(success: false, errorMessage: 'no_model');
}

/// Actions class for chat operations (send, regenerate, cancel, streaming).
///
/// This class contains ONLY business logic, NO UI operations.
/// It operates on messages, calls services/streams, and returns results.
/// UI layer is responsible for handling snackbars, scrolling, animations, etc.
///
/// Key responsibilities:
/// - Send new messages
/// - Regenerate existing messages
/// - Cancel streaming
/// - Handle stream chunks (reasoning, tools, content)
/// - Manage streaming state
class ChatActions {
  ChatActions({
    required this.chatService,
    required this.chatController,
    required this.streamController,
    required this.generationController,
    required this.messageGenerationService,
    required this.contextProvider,
    required this.viewModel,
  });

  final HomeViewModel viewModel;
  final ChatService chatService;
  final ChatController chatController;
  final stream_ctrl.StreamController streamController;
  final GenerationController generationController;
  final MessageGenerationService messageGenerationService;
  final BuildContext contextProvider;

  // ============================================================================
  // Callbacks for UI updates (set by HomeViewModel)
  // ============================================================================

  /// Called when messages list is updated.
  VoidCallback? onMessagesChanged;

  /// Called when conversation loading state changes.
  void Function(String conversationId, bool loading)? onLoadingChanged;

  /// Called when stream content is updated (for throttled updates).
  void Function(String messageId, String content, int totalTokens)?
  onContentUpdated;

  /// Called when an error occurs during streaming.
  void Function(String error)? onStreamError;

  /// Called when stream finishes and title may need to be generated.
  void Function(String conversationId)? onMaybeGenerateTitle;

  /// Called when summary may need to be generated (every N messages).
  void Function(String conversationId)? onMaybeGenerateSummary;

  /// Called when chat suggestions may need to be generated.
  void Function(String conversationId)? onMaybeGenerateSuggestions;

  /// Called to schedule inline image sanitization.
  void Function(String messageId, String content, {bool immediate})?
  onScheduleImageSanitize;

  /// Called when streaming finishes.
  VoidCallback? onStreamFinished;

  /// Called when a successful assistant reply is finalized.
  void Function(ChatMessage message)? onAssistantMessageFinished;

  /// Called when file processing starts.
  VoidCallback? onFileProcessingStarted;

  /// Called when file processing finishes.
  VoidCallback? onFileProcessingFinished;

  // ============================================================================
  // Private Helpers
  // ============================================================================

  AppLocalizations? get _l10n => AppLocalizations.of(contextProvider);

  void _logIosBackgroundGenerationFailure(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('[IosBackgroundGeneration] $operation failed: $error');
    debugPrint('$stackTrace');
  }

  Future<void> _startIosBackgroundGeneration(
    stream_ctrl.GenerationContext ctx,
  ) async {
    final settings = ctx.settings;
    final l10n = _l10n;
    if (l10n == null) return;
    try {
      await IosBackgroundGenerationService.instance.start(
        enabled: settings.iosBackgroundGenerationEnabled,
        liveActivityEnabled: settings.iosLiveActivityEnabled,
        notificationsEnabled: settings.iosBackgroundNotificationsEnabled,
        refreshEnabled: settings.iosBackgroundTaskRefreshEnabled,
        title: l10n.iosBackgroundGenerationActiveTitle,
        detail: l10n.iosBackgroundGenerationActiveDetail,
        tokenLabel: l10n.iosBackgroundGenerationTokenCount(0),
      );
    } catch (error, stackTrace) {
      _logIosBackgroundGenerationFailure('start', error, stackTrace);
    }
  }

  void _scheduleIosBackgroundGenerationUpdate(
    stream_ctrl.StreamingState state,
  ) {
    final l10n = _l10n;
    if (l10n == null) return;
    IosBackgroundGenerationService.instance.scheduleUpdate(
      detail: l10n.iosBackgroundGenerationStreamingDetail,
      tokenLabel: l10n.iosBackgroundGenerationTokenCount(state.totalTokens),
      tokenCount: state.totalTokens,
      onError: (error, stackTrace) =>
          _logIosBackgroundGenerationFailure('update', error, stackTrace),
    );
  }

  Future<void> _finishIosBackgroundGeneration({
    required bool success,
    String? detail,
  }) async {
    final l10n = _l10n;
    if (l10n == null) return;
    try {
      await IosBackgroundGenerationService.instance.finish(
        title: success
            ? l10n.iosBackgroundGenerationCompleteTitle
            : l10n.iosBackgroundGenerationInterruptedTitle,
        detail:
            detail ??
            (success
                ? l10n.iosBackgroundGenerationCompleteDetail
                : l10n.iosBackgroundGenerationInterruptedDetail),
        success: success,
      );
    } catch (error, stackTrace) {
      _logIosBackgroundGenerationFailure('finish', error, stackTrace);
    }
  }

  Future<void> _cancelIosBackgroundGeneration() async {
    final l10n = _l10n;
    try {
      await IosBackgroundGenerationService.instance.cancel(
        detail: l10n?.iosBackgroundGenerationCancelledDetail,
      );
    } catch (error, stackTrace) {
      _logIosBackgroundGenerationFailure('cancel', error, stackTrace);
    }
  }

  /// Track in-flight _finishStreaming futures so _handleStreamDone can await
  /// completion before removing notifiers or triggering rebuild.
  final Map<String, Future<void>> _finishStreamingFutures =
      <String, Future<void>>{};
  final Map<String, LatestWinsCheckpointWriter<_StreamingCheckpoint>>
  _checkpointWriters =
      <String, LatestWinsCheckpointWriter<_StreamingCheckpoint>>{};
  final Map<String, List<Map<String, dynamic>>> _streamingToolEvents =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, _GenerationCheckpointCursor> _generationCheckpointCursors =
      <String, _GenerationCheckpointCursor>{};
  final ActiveStreamingMessageStore _activeAssistantMessages =
      ActiveStreamingMessageStore();

  List<ChatMessage> get _messages => chatController.messages;
  Map<String, int> get _versionSelections => chatController.versionSelections;
  Conversation? get _currentConversation => chatController.currentConversation;
  Set<String> get _loadingConversationIds =>
      chatController.loadingConversationIds;
  Map<String, StreamSubscription<dynamic>> get _conversationStreams =>
      chatController.conversationStreams;

  void _setConversationLoading(String conversationId, bool loading) {
    chatController.setConversationLoading(conversationId, loading);
    onLoadingChanged?.call(conversationId, loading);
  }

  List<Map<String, dynamic>> _copyToolEvents(String messageId) {
    return (_streamingToolEvents[messageId] ?? const <Map<String, dynamic>>[])
        .map((event) => Map<String, dynamic>.from(event))
        .toList(growable: false);
  }

  ChatMessage _messageWithCurrentReasoning(ChatMessage message) {
    final messageId = message.id;
    final reasoning = streamController.reasoning[messageId];
    final segments = streamController.reasoningSegments[messageId];
    final splits = streamController.getContentSplitData(messageId);
    final reasoningSegmentsJson = segments != null || splits != null
        ? streamController.serializeReasoningSegmentsWithSplits(
            segments ?? const [],
            contentSplitOffsets: splits?.offsets,
            reasoningCountAtSplit: splits?.reasoningCounts,
            toolCountAtSplit: splits?.toolCounts,
          )
        : message.reasoningSegmentsJson;
    return message.copyWith(
      reasoningText: reasoning?.text,
      reasoningStartAt: reasoning?.startAt,
      reasoningFinishedAt: reasoning?.finishedAt,
      reasoningSegmentsJson: reasoningSegmentsJson,
    );
  }

  ChatMessage _streamingMessageSnapshot(stream_ctrl.StreamingState state) {
    final messageId = state.messageId;
    final index = _messages.indexWhere((message) => message.id == messageId);
    final base = _messageWithCurrentReasoning(
      index < 0 ? state.ctx.assistantMessage : _messages[index],
    );
    return base.copyWith(
      content: _transformAssistantContent(state),
      totalTokens: state.totalTokens,
      promptTokens: state.usage?.promptTokens,
      completionTokens: state.usage?.completionTokens,
      cachedTokens: state.usage?.cachedTokens,
      durationMs: state.streamStartedAt == null
          ? base.durationMs
          : DateTime.now().difference(state.streamStartedAt!).inMilliseconds,
    );
  }

  void _scheduleStreamingCheckpoint(stream_ctrl.StreamingState state) {
    final writer = _checkpointWriters[state.messageId];
    if (writer == null || state.finishHandled) return;
    final message = _streamingMessageSnapshot(state);
    _activeAssistantMessages.put(message);
    writer.add(_createStreamingCheckpoint(message));
  }

  _StreamingCheckpoint _createStreamingCheckpoint(ChatMessage message) {
    final cursor = _generationCheckpointCursors[message.id];
    final checkpointSeq = cursor?.nextSeq;
    if (cursor != null) cursor.nextSeq += 1;
    return _StreamingCheckpoint(
      message: message,
      toolEvents: _copyToolEvents(message.id),
      generationRunId: cursor?.runId,
      checkpointSeq: checkpointSeq,
    );
  }

  void _registerGenerationRun(String messageId, String? runId) {
    if (runId == null) return;
    _generationCheckpointCursors[messageId] = _GenerationCheckpointCursor(
      runId: runId,
      state: GenerationRunState.preparing,
      stateRevision: 0,
      nextSeq: 1,
    );
  }

  Future<void> _finalizeStreamingCheckpoint(
    ChatMessage message, {
    required GenerationRunState terminalState,
    String? errorCode,
  }) async {
    final writer = _checkpointWriters.remove(message.id);
    final cursor = _generationCheckpointCursors[message.id];
    final checkpointSeq =
        cursor == null || cursor.state == GenerationRunState.preparing
        ? null
        : cursor.nextSeq++;
    final toolEvents = _copyToolEvents(message.id);
    Future<void> writeFinal() async {
      await chatService.finalizeGenerationRunSilent(
        message: message,
        toolEvents: toolEvents,
        generationRunId: cursor?.runId,
        expectedState: cursor?.state,
        expectedStateRevision: cursor?.stateRevision,
        terminalState: terminalState,
        checkpointSeq: checkpointSeq,
        errorCode: errorCode,
      );
    }

    var committed = false;
    try {
      if (writer == null) {
        await writeFinal();
      } else {
        await writer.finalize(writeFinal);
      }
      committed = true;
    } finally {
      if (committed) _clearGenerationRuntimeState(message);
    }
  }

  void _clearGenerationRuntimeState(ChatMessage message) {
    _generationCheckpointCursors.remove(message.id);
    _streamingToolEvents.remove(message.id);
    _activeAssistantMessages.removeIfMatches(message);
  }

  Future<void> _finishPreparingMessage(
    String conversationId,
    ChatMessage fallback,
  ) async {
    final active = _activeAssistantMessages[conversationId];
    final message = _messageWithCurrentReasoning(
      active?.id == fallback.id ? active! : fallback,
    ).copyWith(isStreaming: false);
    streamController.markStreamingEnded(message.id);
    streamController.cleanupTimers(message.id);
    streamController.removeStreamingNotifier(message.id);
    try {
      await _finalizeStreamingCheckpoint(
        message,
        terminalState: GenerationRunState.failed,
        errorCode: 'preparation_failed',
      );
    } finally {
      _clearGenerationRuntimeState(message);
      final index = _messages.indexWhere((item) => item.id == message.id);
      if (index >= 0) {
        _messages[index] = message;
        onMessagesChanged?.call();
      }
      _setConversationLoading(conversationId, false);
    }
  }

  void _upsertStreamingToolEvent(
    String messageId, {
    required String id,
    required String name,
    required Map<String, dynamic> arguments,
    String? content,
    Map<String, dynamic>? metadata,
  }) {
    final events = _streamingToolEvents.putIfAbsent(
      messageId,
      () => <Map<String, dynamic>>[],
    );
    var index = id.isEmpty
        ? -1
        : events.indexWhere((event) => '${event['id'] ?? ''}' == id);
    if (index < 0) {
      index = events.indexWhere(
        (event) =>
            '${event['name'] ?? ''}' == name &&
            (event['content'] == null || '${event['content']}'.isEmpty),
      );
    }
    final record = <String, dynamic>{
      'id': id,
      'name': name,
      'arguments': arguments,
      'content': content,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };
    if (index < 0) {
      events.add(record);
    } else {
      final existingMetadata = events[index]['metadata'];
      if (!record.containsKey('metadata') && existingMetadata is Map) {
        record['metadata'] = Map<String, dynamic>.from(existingMetadata);
      }
      events[index] = record;
    }
  }

  bool _isReasoningModel(String providerKey, String modelId) {
    return generationController.isReasoningModel(providerKey, modelId);
  }

  bool _isReasoningEnabled(int? budget) {
    return messageGenerationService.isReasoningEnabled(budget);
  }

  Conversation _conversationForMessageContext(
    Conversation conversation,
    List<ChatMessage> messages, {
    int? maxRawTruncateIndex,
  }) {
    final completeConversation = chatController
        .conversationForCompleteHistoryContext(conversation);
    return conversationForMessageContext(
      conversation: completeConversation,
      messages: messages,
      maxRawTruncateIndex: maxRawTruncateIndex,
    );
  }

  @visibleForTesting
  static Conversation conversationForMessageContext({
    required Conversation conversation,
    required List<ChatMessage> messages,
    int? maxRawTruncateIndex,
  }) {
    final rawTruncateIndex = conversation.truncateIndex;
    if (maxRawTruncateIndex != null && rawTruncateIndex > maxRawTruncateIndex) {
      return conversation.copyWith(truncateIndex: -1);
    }
    if (rawTruncateIndex < 0 || rawTruncateIndex <= messages.length) {
      return conversation;
    }
    return conversation.copyWith(truncateIndex: -1);
  }

  @visibleForTesting
  static StreamSubscription<T> listenSequentiallyToStream<T>({
    required Stream<T> stream,
    required Future<void> Function(T chunk) onData,
    required Future<void> Function(Object error, StackTrace stackTrace) onError,
    required Future<void> Function() onDone,
  }) {
    final events =
        Queue<({T? data, Object? error, StackTrace? stackTrace, bool done})>();
    late final StreamSubscription<T> sourceSubscription;
    Future<void>? drainFuture;
    var terminalQueued = false;

    Future<void> reportError(Object error, StackTrace stackTrace) async {
      try {
        await onError(error, stackTrace);
      } catch (secondaryError, secondaryStackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: secondaryError,
            stack: secondaryStackTrace,
            context: ErrorDescription(
              'while handling a sequential stream terminal error',
            ),
          ),
        );
      }
    }

    Future<void> drain() async {
      try {
        while (events.isNotEmpty) {
          final event = events.removeFirst();
          final error = event.error;
          if (error != null) {
            await reportError(error, event.stackTrace ?? StackTrace.current);
            await sourceSubscription.cancel();
            events.clear();
            return;
          }
          if (event.done) {
            await onDone();
            return;
          }
          await onData(event.data as T);
        }
      } catch (error, stackTrace) {
        terminalQueued = true;
        events.clear();
        await reportError(error, stackTrace);
        await sourceSubscription.cancel();
      }
    }

    late final void Function() scheduleDrain;
    scheduleDrain = () {
      drainFuture ??= drain().whenComplete(() {
        drainFuture = null;
        if (events.isNotEmpty) scheduleDrain();
      });
    };

    void enqueue(
      ({T? data, Object? error, StackTrace? stackTrace, bool done}) event,
    ) {
      events.add(event);
      scheduleDrain();
    }

    sourceSubscription = stream.listen(
      (chunk) {
        if (terminalQueued) return;
        enqueue((data: chunk, error: null, stackTrace: null, done: false));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (terminalQueued) return;
        terminalQueued = true;
        enqueue((
          data: null,
          error: error,
          stackTrace: stackTrace,
          done: false,
        ));
      },
      onDone: () {
        if (terminalQueued) return;
        terminalQueued = true;
        enqueue((data: null, error: null, stackTrace: null, done: true));
      },
      cancelOnError: true,
    );
    return _BarrierStreamSubscription<T>(sourceSubscription, () async {
      terminalQueued = true;
      events.clear();
      await sourceSubscription.cancel();
      await drainFuture;
    });
  }

  bool _supportsAudioAttachmentsForProvider(
    SettingsProvider settings, {
    required String providerKey,
    required String modelId,
  }) {
    return messageGenerationService.supportsAudioAttachmentsForProvider(
      settings,
      providerKey: providerKey,
      modelId: modelId,
    );
  }

  bool _hasUnsupportedAudioAttachments({
    required List<ChatMessage> messages,
    required Conversation conversation,
    required SettingsProvider settings,
    required String providerKey,
    required String modelId,
    ChatInputData? pendingInput,
    int? maxRawTruncateIndex,
  }) {
    if (_supportsAudioAttachmentsForProvider(
      settings,
      providerKey: providerKey,
      modelId: modelId,
    )) {
      return false;
    }

    if (pendingInput != null &&
        messageGenerationService.inputContainsAudioAttachments(pendingInput)) {
      return true;
    }

    final apiMessages = messageGenerationService.messageBuilderService
        .buildApiMessages(
          messages: messages,
          versionSelections: _versionSelections,
          currentConversation: _conversationForMessageContext(
            conversation,
            messages,
            maxRawTruncateIndex: maxRawTruncateIndex,
          ),
        );
    return messageGenerationService.apiMessagesContainAudioAttachments(
      apiMessages,
    );
  }

  @visibleForTesting
  static List<ChatMessage> projectMessagesForRegenerationContext({
    required List<ChatMessage> messages,
    required int lastKeep,
    required String? targetGroupId,
  }) {
    if (lastKeep >= messages.length - 1) {
      return List<ChatMessage>.of(messages);
    }

    final keepGroups = <String>{};
    for (int i = 0; i <= lastKeep && i < messages.length; i++) {
      keepGroups.add(messages[i].groupId ?? messages[i].id);
    }
    if (targetGroupId != null) keepGroups.add(targetGroupId);

    final projected = <ChatMessage>[];
    for (int i = 0; i < messages.length; i++) {
      if (i <= lastKeep) {
        projected.add(messages[i]);
        continue;
      }
      final gid = messages[i].groupId ?? messages[i].id;
      if (keepGroups.contains(gid)) {
        projected.add(messages[i]);
      }
    }
    return projected;
  }

  @visibleForTesting
  static List<ChatMessage> buildRegenerationMessages({
    required List<ChatMessage> messages,
    required int lastKeep,
    required String? targetGroupId,
    required ChatMessage assistantPlaceholder,
  }) {
    return <ChatMessage>[
      ...projectMessagesForRegenerationContext(
        messages: messages,
        lastKeep: lastKeep,
        targetGroupId: targetGroupId,
      ),
      assistantPlaceholder,
    ];
  }

  /// Transform raw content using assistant regexes.
  String _transformAssistantContent(
    stream_ctrl.StreamingState state, [
    String? raw,
  ]) {
    return applyAssistantRegexes(
      raw ?? state.fullContentRaw,
      assistant: state.ctx.assistant,
      scope: AssistantRegexScope.assistant,
      target: AssistantRegexTransformTarget.persist,
    );
  }

  // ============================================================================
  // Send Message
  // ============================================================================

  /// Send a new message and start generating assistant response.
  ///
  /// Returns [ChatActionResult] with success status and the assistant message.
  /// UI is responsible for:
  /// - Adding messages to the list (user + assistant)
  /// - Showing snackbars on errors
  /// - Scrolling to bottom
  /// - Haptic feedback
  Future<ChatActionResult> sendMessage({
    required ChatInputData input,
    required Conversation conversation,
  }) async {
    final content = input.text.trim();
    if (content.isEmpty &&
        input.imagePaths.isEmpty &&
        input.documents.isEmpty) {
      return ChatActionResult.error('empty_input');
    }

    final settings = contextProvider.read<SettingsProvider>();
    final assistant = contextProvider
        .read<AssistantProvider>()
        .currentAssistant;
    final assistantId = assistant?.id;
    // Capture approval service reference before async gap
    ToolApprovalService? approvalService;
    AskUserInteractionService? askUserService;
    try {
      approvalService = contextProvider.read<ToolApprovalService>();
    } catch (_) {}
    try {
      askUserService = contextProvider.read<AskUserInteractionService>();
    } catch (_) {}
    final modelConfig = messageGenerationService.getModelConfig(
      settings,
      assistant,
    );

    if (modelConfig.providerKey == null || modelConfig.modelId == null) {
      return ChatActionResult.noModel();
    }
    final providerKey = modelConfig.providerKey!;
    final modelId = modelConfig.modelId!;

    if (chatController.hasMoreAfter) {
      final loaded = await chatController.loadEndWindow();
      if (loaded) {
        viewModel.restoreMessageUiState();
      }
    }

    final existingContextMessages = await chatController
        .messagesForCompleteHistoryContext(conversation);
    if (_hasUnsupportedAudioAttachments(
      messages: existingContextMessages,
      conversation: conversation,
      settings: settings,
      providerKey: providerKey,
      modelId: modelId,
      pendingInput: input,
      maxRawTruncateIndex: null,
    )) {
      return ChatActionResult.error('audio_attachment_unsupported');
    }

    late final ChatMessage userMessage;
    late final ChatMessage assistantMessage;
    String? generationRunId;
    try {
      final begin = await messageGenerationService.beginSendGeneration(
        conversationId: conversation.id,
        input: input,
        assistant: assistant,
        modelId: modelId,
        providerKey: providerKey,
      );
      userMessage = begin.userMessage;
      assistantMessage = begin.assistantMessage;
      generationRunId = begin.runId;
      _registerGenerationRun(assistantMessage.id, generationRunId);
    } catch (e) {
      return ChatActionResult.error(e.toString());
    }
    _activeAssistantMessages.put(assistantMessage);
    _setConversationLoading(conversation.id, true);

    // Pre-create streaming notifier BEFORE adding message to list
    // so that MessageListView can detect it's streaming on first render
    streamController.markStreamingStarted(assistantMessage.id);

    if (await chatController.appendPersistedTailMessages([
      userMessage,
      assistantMessage,
    ])) {
      viewModel.restoreMessageUiState();
    }
    onMessagesChanged?.call();

    // Reset tool parts and initialize reasoning
    streamController.toolParts.remove(assistantMessage.id);
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning =
        supportsReasoning &&
        _isReasoningEnabled(
          assistant?.thinkingBudget ?? settings.thinkingBudget,
        );
    // Prepare API messages
    messageGenerationService.onFileProcessingStarted = onFileProcessingStarted;
    messageGenerationService.onFileProcessingFinished =
        onFileProcessingFinished;
    try {
      await messageGenerationService.initializeReasoningState(
        messageId: assistantMessage.id,
        enableReasoning: enableReasoning,
      );
      final apiContextMessages = await chatController
          .messagesForCompleteHistoryContext(conversation);
      final prepared = await messageGenerationService
          .prepareApiMessagesWithInjections(
            messages: apiContextMessages,
            versionSelections: _versionSelections,
            currentConversation: _conversationForMessageContext(
              conversation,
              apiContextMessages,
            ),
            settings: settings,
            assistant: assistant,
            assistantId: assistantId,
            providerKey: providerKey,
            modelId: modelId,
            approvalService: approvalService,
            askUserService: askUserService,
          );

      // Build user image paths
      final userImagePaths = messageGenerationService.buildUserImagePaths(
        input: input,
        lastUserImagePaths: prepared.lastUserImagePaths,
        settings: settings,
        providerKey: providerKey,
        modelId: modelId,
      );

      // Execute generation
      final ctx = messageGenerationService.buildGenerationContext(
        assistantMessage: assistantMessage,
        prepared: prepared,
        userImagePaths: userImagePaths,
        allowImagesApiRouting: input.allowImagesApiRouting,
        providerKey: providerKey,
        modelId: modelId,
        assistant: assistant,
        settings: settings,
        supportsReasoning: supportsReasoning,
        enableReasoning: enableReasoning,
        generateTitleOnFinish: true,
        generationRunId: generationRunId,
      );

      if (!_activeAssistantMessages.isActive(assistantMessage)) {
        return ChatActionResult.success(assistantMessage);
      }
      await _executeGeneration(ctx);
      return ChatActionResult.success(assistantMessage);
    } catch (e) {
      // Ensure file processing indicator is cleared on error
      onFileProcessingFinished?.call();
      await _finishPreparingMessage(conversation.id, assistantMessage);
      return ChatActionResult.error(e.toString());
    }
  }

  // ============================================================================
  // Regenerate Message
  // ============================================================================

  /// Regenerate response at a specific message.
  ///
  /// Returns [ChatActionResult] with success status and the new assistant message.
  /// UI is responsible for:
  /// - Adding new assistant placeholder
  /// - Showing snackbars on errors
  /// - Haptic feedback
  Future<ChatActionResult> regenerateAtMessage({
    required ChatMessage message,
    required Conversation conversation,
    bool assistantAsNewReply = false,
    bool allowImagesApiRouting = true,
  }) async {
    // Avoid using BuildContext across async gaps (this class holds a BuildContext).
    final settings = contextProvider.read<SettingsProvider>();
    final assistant = contextProvider
        .read<AssistantProvider>()
        .currentAssistant;
    // Capture approval service reference before async gap
    ToolApprovalService? regenApprovalService;
    AskUserInteractionService? regenAskUserService;
    try {
      regenApprovalService = contextProvider.read<ToolApprovalService>();
    } catch (_) {}
    try {
      regenAskUserService = contextProvider.read<AskUserInteractionService>();
    } catch (_) {}

    await cancelStreaming(conversation);

    final completeMessages = await chatController
        .messagesForCompleteHistoryContext(conversation);
    final idx = completeMessages.indexWhere((m) => m.id == message.id);
    if (idx < 0) {
      return ChatActionResult.error('message_not_found');
    }

    // Calculate versioning using service
    final versioning = messageGenerationService.calculateRegenerationVersioning(
      message: message,
      messages: completeMessages,
      assistantAsNewReply: assistantAsNewReply,
    );
    if (versioning.lastKeep < 0) {
      return ChatActionResult.error('invalid_versioning');
    }

    // Get model config
    final assistantId = assistant?.id;
    final modelConfig = messageGenerationService.getModelConfig(
      settings,
      assistant,
    );

    if (modelConfig.providerKey == null || modelConfig.modelId == null) {
      return ChatActionResult.noModel();
    }
    final providerKey = modelConfig.providerKey!;
    final modelId = modelConfig.modelId!;

    final projectedMessages = ChatActions.projectMessagesForRegenerationContext(
      messages: completeMessages,
      lastKeep: versioning.lastKeep,
      targetGroupId: versioning.targetGroupId,
    );
    if (_hasUnsupportedAudioAttachments(
      messages: projectedMessages,
      conversation: conversation,
      settings: settings,
      providerKey: providerKey,
      modelId: modelId,
      maxRawTruncateIndex: versioning.lastKeep,
    )) {
      return ChatActionResult.error('audio_attachment_unsupported');
    }

    if (settings.regenerateDeleteTrailingMessages) {
      final removeIds = await messageGenerationService.removeTrailingMessages(
        messages: completeMessages,
        lastKeep: versioning.lastKeep,
        targetGroupId: versioning.targetGroupId,
      );
      if (removeIds.isNotEmpty) {
        await chatController.reloadMessages();
        viewModel.restoreMessageUiState();
        onMessagesChanged?.call();
      }
    }

    final targetGroupId = versioning.targetGroupId;
    if (targetGroupId == null) {
      return ChatActionResult.error('invalid_versioning');
    }
    final begin = await messageGenerationService.beginRegeneration(
      conversationId: conversation.id,
      modelId: modelId,
      providerKey: providerKey,
      groupId: targetGroupId,
      version: versioning.nextVersion,
    );
    final assistantMessage = begin.assistantMessage;
    _registerGenerationRun(assistantMessage.id, begin.runId);
    _activeAssistantMessages.put(assistantMessage);

    // Pre-create streaming notifier BEFORE adding message to list
    // so that MessageListView can detect it's streaming on first render
    streamController.markStreamingStarted(assistantMessage.id);

    final gid = assistantMessage.groupId ?? assistantMessage.id;
    _versionSelections[gid] = assistantMessage.version;

    final regenerationMessages = ChatActions.buildRegenerationMessages(
      messages: completeMessages,
      lastKeep: versioning.lastKeep,
      targetGroupId: versioning.targetGroupId,
      assistantPlaceholder: assistantMessage,
    );

    if (await chatController.appendPersistedTailMessage(assistantMessage)) {
      viewModel.restoreMessageUiState();
    }
    onMessagesChanged?.call();

    _setConversationLoading(conversation.id, true);

    // Initialize reasoning
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning =
        supportsReasoning &&
        _isReasoningEnabled(
          assistant?.thinkingBudget ?? settings.thinkingBudget,
        );
    try {
      await messageGenerationService.initializeReasoningState(
        messageId: assistantMessage.id,
        enableReasoning: enableReasoning,
      );

      // Prepare API messages
      final prepared = await messageGenerationService
          .prepareApiMessagesWithInjections(
            messages: regenerationMessages,
            versionSelections: _versionSelections,
            currentConversation: _conversationForMessageContext(
              conversation,
              regenerationMessages,
              maxRawTruncateIndex: versioning.lastKeep,
            ),
            settings: settings,
            assistant: assistant,
            assistantId: assistantId,
            providerKey: providerKey,
            modelId: modelId,
            approvalService: regenApprovalService,
            askUserService: regenAskUserService,
          );

      // Build user image paths
      final userImagePaths = messageGenerationService.buildUserImagePaths(
        input: null,
        lastUserImagePaths: prepared.lastUserImagePaths,
        settings: settings,
        providerKey: providerKey,
        modelId: modelId,
      );

      // Execute generation
      final ctx = messageGenerationService.buildGenerationContext(
        assistantMessage: assistantMessage,
        prepared: prepared,
        userImagePaths: userImagePaths,
        allowImagesApiRouting: allowImagesApiRouting,
        providerKey: providerKey,
        modelId: modelId,
        assistant: assistant,
        settings: settings,
        supportsReasoning: supportsReasoning,
        enableReasoning: enableReasoning,
        generateTitleOnFinish: false,
        generationRunId: begin.runId,
      );

      if (!_activeAssistantMessages.isActive(assistantMessage)) {
        return ChatActionResult.success(assistantMessage);
      }
      await _executeGeneration(ctx);
      return ChatActionResult.success(assistantMessage);
    } catch (e) {
      await _finishPreparingMessage(conversation.id, assistantMessage);
      return ChatActionResult.error(e.toString());
    }
  }

  Future<ChatActionResult> continueAssistantMessageAfterToolAnswer({
    required ChatMessage message,
    required Conversation conversation,
    bool allowImagesApiRouting = true,
  }) async {
    final settings = contextProvider.read<SettingsProvider>();
    final assistant = contextProvider
        .read<AssistantProvider>()
        .currentAssistant;
    ToolApprovalService? approvalService;
    AskUserInteractionService? askUserService;
    try {
      approvalService = contextProvider.read<ToolApprovalService>();
    } catch (_) {}
    try {
      askUserService = contextProvider.read<AskUserInteractionService>();
    } catch (_) {}

    final visibleIndex = _messages.indexWhere(
      (candidate) => candidate.id == message.id,
    );
    if (visibleIndex < 0 || message.role != 'assistant') {
      return ChatActionResult.error('message_not_found');
    }
    final completeMessages = await chatController
        .messagesForCompleteHistoryContext(conversation);
    final contextIndex = completeMessages.indexWhere(
      (candidate) => candidate.id == message.id,
    );
    if (contextIndex < 0) {
      return ChatActionResult.error('message_not_found');
    }

    final modelConfig = messageGenerationService.getModelConfig(
      settings,
      assistant,
    );
    if (modelConfig.providerKey == null || modelConfig.modelId == null) {
      return ChatActionResult.noModel();
    }
    final providerKey = modelConfig.providerKey!;
    final modelId = modelConfig.modelId!;

    final streamingMessage = _messages[visibleIndex].copyWith(
      isStreaming: true,
    );
    _activeAssistantMessages.put(streamingMessage);
    _messages[visibleIndex] = streamingMessage;
    await chatService.updateMessage(streamingMessage.id, isStreaming: true);
    onMessagesChanged?.call();
    _setConversationLoading(conversation.id, true);

    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning =
        supportsReasoning &&
        _isReasoningEnabled(
          assistant?.thinkingBudget ?? settings.thinkingBudget,
        );

    try {
      final apiContextMessages = List<ChatMessage>.of(completeMessages);
      apiContextMessages[contextIndex] = streamingMessage.copyWith(content: '');
      final prepared = await messageGenerationService
          .prepareApiMessagesWithInjections(
            messages: apiContextMessages,
            versionSelections: _versionSelections,
            currentConversation: _conversationForMessageContext(
              conversation,
              apiContextMessages,
            ),
            settings: settings,
            assistant: assistant,
            assistantId: assistant?.id,
            providerKey: providerKey,
            modelId: modelId,
            approvalService: approvalService,
            askUserService: askUserService,
          );

      final userImagePaths = messageGenerationService.buildUserImagePaths(
        input: null,
        lastUserImagePaths: prepared.lastUserImagePaths,
        settings: settings,
        providerKey: providerKey,
        modelId: modelId,
      );

      final ctx = messageGenerationService.buildGenerationContext(
        assistantMessage: streamingMessage,
        prepared: prepared,
        userImagePaths: userImagePaths,
        allowImagesApiRouting: allowImagesApiRouting,
        providerKey: providerKey,
        modelId: modelId,
        assistant: assistant,
        settings: settings,
        supportsReasoning: supportsReasoning,
        enableReasoning: enableReasoning,
        generateTitleOnFinish: false,
      );

      if (!_activeAssistantMessages.isActive(streamingMessage)) {
        return ChatActionResult.success(streamingMessage);
      }
      await _executeGeneration(ctx);
      return ChatActionResult.success(streamingMessage);
    } catch (e) {
      await _finishPreparingMessage(conversation.id, streamingMessage);
      return ChatActionResult.error(e.toString());
    }
  }

  // ============================================================================
  // Cancel Streaming
  // ============================================================================

  /// Cancel the active streaming for the current conversation.
  Future<void> cancelStreaming(Conversation? conversation) async {
    final cid = conversation?.id;
    if (cid == null) return;

    // Cancel any pending tool approval requests to prevent deadlock
    try {
      contextProvider.read<ToolApprovalService>().cancelAll();
    } catch (_) {
      // ToolApprovalService may not be registered yet
    }
    try {
      contextProvider.read<AskUserInteractionService>().cancelAll();
    } catch (_) {
      // AskUserInteractionService may not be registered yet
    }

    // Reset file processing state on cancel
    onFileProcessingFinished?.call();

    // Cancel active stream for current conversation only
    final sub = _conversationStreams.remove(cid);
    await sub?.cancel();
    ChatApiService.cancelRequest(cid);

    // The active identity is independent from the currently loaded window.
    final streaming = _activeAssistantMessages.cancellationTarget(
      cid,
      _messages,
    );
    if (streaming != null) {
      // Mark streaming as ended to allow UI rebuilds again
      streamController.markStreamingEnded(streaming.id);
      streamController.cleanupTimers(streaming.id);

      final idx = _messages.indexWhere((m) => m.id == streaming.id);
      final latestStreaming = idx == -1 ? streaming : _messages[idx];

      streamController.finishReasoningIfNeeded(streaming.id);
      final finalizedMessage = _messageWithCurrentReasoning(
        latestStreaming,
      ).copyWith(isStreaming: false);
      try {
        await _finalizeStreamingCheckpoint(
          finalizedMessage,
          terminalState: GenerationRunState.cancelled,
        );
      } finally {
        _clearGenerationRuntimeState(finalizedMessage);
        if (idx != -1) {
          _messages[idx] = finalizedMessage;
          onMessagesChanged?.call();
        }
        streamController.removeStreamingNotifier(streaming.id);
        _setConversationLoading(cid, false);
      }

      // If streaming output included inline base64 images, sanitize them even on manual cancel
      onScheduleImageSanitize?.call(
        streaming.id,
        latestStreaming.content,
        immediate: true,
      );
      await _cancelIosBackgroundGeneration();
    } else {
      _setConversationLoading(cid, false);
    }
  }

  // ============================================================================
  // Stream Execution
  // ============================================================================

  /// Execute generation with the given context.
  Future<void> _executeGeneration(stream_ctrl.GenerationContext ctx) async {
    final state = stream_ctrl.StreamingState(ctx);
    final assistant = ctx.assistant;
    final conversationId = state.conversationId;
    final existingSplit = streamController.getContentSplitData(state.messageId);
    if (existingSplit != null) {
      state.contentSplitOffsets = List<int>.of(existingSplit.offsets);
      state.reasoningCountAtSplit = List<int>.of(existingSplit.reasoningCounts);
      state.toolCountAtSplit = List<int>.of(existingSplit.toolCounts);
    }
    if (streamController.getToolPartsCount(state.messageId) > 0) {
      state.hadThinkingBlock = true;
    }

    // Mark this message as actively streaming to suppress UI rebuilds
    streamController.markStreamingStarted(state.messageId);
    _activeAssistantMessages.put(state.ctx.assistantMessage);
    _streamingToolEvents[state.messageId] = chatService
        .getToolEvents(state.messageId)
        .map((event) => Map<String, dynamic>.from(event))
        .toList();
    _checkpointWriters[state.messageId] =
        LatestWinsCheckpointWriter<_StreamingCheckpoint>(
          write: (checkpoint) => chatService.updateStreamingCheckpointSilent(
            checkpoint.message,
            checkpoint.toolEvents,
            generationRunId: checkpoint.generationRunId,
            checkpointSeq: checkpoint.checkpointSeq,
          ),
          onError: (error, stackTrace) {
            debugPrint('[StreamingCheckpoint] write failed: $error');
            debugPrint('$stackTrace');
          },
        );

    try {
      await _startIosBackgroundGeneration(ctx);
      if (!_activeAssistantMessages.isActive(ctx.assistantMessage)) {
        await _cancelIosBackgroundGeneration();
        return;
      }
      final runId = ctx.generationRunId;
      if (runId != null) {
        final cursor = _generationCheckpointCursors[state.messageId];
        if (cursor == null) {
          throw StateError('generation_run_cursor_missing');
        }
        final run = await chatService.transitionGenerationRun(
          id: runId,
          expectedState: cursor.state,
          expectedStateRevision: cursor.stateRevision,
          nextState: GenerationRunState.requesting,
        );
        state.generationStateRevision = run.stateRevision;
        cursor
          ..state = run.state
          ..stateRevision = run.stateRevision
          ..nextSeq = run.checkpointSeq + 1;
      }
      final stream = ChatApiService.sendMessageStream(
        config: ctx.config,
        modelId: ctx.modelId,
        messages: ctx.apiMessages,
        userImagePaths: ctx.userImagePaths,
        thinkingBudget:
            assistant?.thinkingBudget ?? ctx.settings.thinkingBudget,
        temperature: assistant?.temperature,
        topP: assistant?.topP,
        maxTokens: assistant?.maxTokens,
        tools: ctx.toolDefs.isEmpty ? null : ctx.toolDefs,
        onToolCall: ctx.onToolCall,
        extraHeaders: ctx.extraHeaders,
        extraBody: ctx.extraBody,
        stream: ctx.streamOutput,
        requestId: conversationId,
        allowImagesApiRouting: ctx.allowImagesApiRouting,
        ocrActive: ctx.ocrActive,
      );

      await _conversationStreams[conversationId]?.cancel();
      final sub = listenSequentiallyToStream<ChatStreamChunk>(
        stream: stream,
        onData: (chunk) => _handleStreamChunk(chunk, state),
        onError: (error, stackTrace) => _handleStreamError(error, state),
        onDone: () => _handleStreamDone(state),
      );
      _conversationStreams[conversationId] = sub;
    } catch (e) {
      await _handleStreamError(e, state);
    }
  }

  // ============================================================================
  // Stream Chunk Handlers
  // ============================================================================

  /// Dispatch stream chunk to appropriate handler.
  Future<void> _handleStreamChunk(
    ChatStreamChunk chunk,
    stream_ctrl.StreamingState state,
  ) async {
    await _markGenerationStreaming(state);
    final chunkContent = chunk.content.isNotEmpty
        ? streamController.captureGeminiThoughtSignature(
            chunk.content,
            state.messageId,
          )
        : '';

    // Handle reasoning
    if ((chunk.reasoning ?? '').isNotEmpty && state.ctx.supportsReasoning) {
      await _handleReasoningChunk(chunk, state);
    }

    // Handle tool calls
    if ((chunk.toolCalls ?? const []).isNotEmpty) {
      await _handleToolCallsChunk(chunk, state);
    }

    // Handle tool results
    if ((chunk.toolResults ?? const []).isNotEmpty) {
      await _handleToolResultsChunk(chunk, state);
    }

    // Handle finish or content
    if (chunk.isDone) {
      await _handleStreamFinish(chunk, state, chunkContent);
    } else {
      await _handleContentChunk(chunk, state, chunkContent);
      _scheduleStreamingCheckpoint(state);
    }
  }

  Future<void> _markGenerationStreaming(
    stream_ctrl.StreamingState state,
  ) async {
    final runId = state.ctx.generationRunId;
    final expectedRevision = state.generationStateRevision;
    if (runId == null ||
        expectedRevision == null ||
        state.generationStreamingStarted) {
      return;
    }
    final run = await chatService.transitionGenerationRun(
      id: runId,
      expectedState: GenerationRunState.requesting,
      expectedStateRevision: expectedRevision,
      nextState: GenerationRunState.streaming,
    );
    state
      ..generationStateRevision = run.stateRevision
      ..generationStreamingStarted = true;
    final cursor = _generationCheckpointCursors[state.messageId];
    if (cursor != null) {
      cursor
        ..state = run.state
        ..stateRevision = run.stateRevision;
    }
  }

  /// Handle reasoning chunk from stream.
  Future<void> _handleReasoningChunk(
    ChatStreamChunk chunk,
    stream_ctrl.StreamingState state,
  ) async {
    await streamController.handleReasoningChunk(
      chunk,
      state,
      updateReasoningInDb:
          (
            String messageId, {
            String? reasoningText,
            DateTime? reasoningStartAt,
            String? reasoningSegmentsJson,
          }) async {
            // The complete reasoning snapshot is coalesced after this chunk.
          },
    );
  }

  /// Handle tool calls chunk from stream.
  Future<void> _handleToolCallsChunk(
    ChatStreamChunk chunk,
    stream_ctrl.StreamingState state,
  ) async {
    await streamController.handleToolCallsChunk(
      chunk,
      state,
      updateReasoningSegmentsInDb: (String messageId, String json) async {
        // The complete reasoning snapshot is coalesced after this chunk.
      },
      setToolEventsInDb:
          (String messageId, List<Map<String, dynamic>> events) async {
            _streamingToolEvents[messageId] = events
                .map((event) => Map<String, dynamic>.from(event))
                .toList();
          },
      getToolEventsFromDb: _copyToolEvents,
    );
  }

  /// Handle tool results chunk from stream.
  Future<void> _handleToolResultsChunk(
    ChatStreamChunk chunk,
    stream_ctrl.StreamingState state,
  ) async {
    await streamController.handleToolResultsChunk(
      chunk,
      state,
      upsertToolEventInDb:
          (
            String messageId, {
            required String id,
            required String name,
            required Map<String, dynamic> arguments,
            String? content,
            Map<String, dynamic>? metadata,
          }) async {
            _upsertStreamingToolEvent(
              messageId,
              id: id,
              name: name,
              arguments: arguments,
              content: content,
              metadata: metadata,
            );
          },
    );
  }

  /// Handle content chunk from stream (non-done).
  Future<void> _handleContentChunk(
    ChatStreamChunk chunk,
    stream_ctrl.StreamingState state,
    String chunkContent,
  ) async {
    // Fast bail-out: if _finishStreaming already ran, don't touch state at all.
    if (state.finishHandled) return;

    final messageId = state.messageId;
    final conversationId = state.conversationId;

    if (state.hadThinkingBlock && chunkContent.isNotEmpty) {
      state.contentSplitOffsets.add(state.fullContentRaw.length);
      state.reasoningCountAtSplit.add(
        streamController.getReasoningSegmentCount(messageId),
      );
      state.toolCountAtSplit.add(streamController.getToolPartsCount(messageId));
      state.hadThinkingBlock = false;
      streamController.setContentSplitData(
        messageId,
        stream_ctrl.ContentSplitData(
          offsets: List<int>.of(state.contentSplitOffsets),
          reasoningCounts: List<int>.of(state.reasoningCountAtSplit),
          toolCounts: List<int>.of(state.toolCountAtSplit),
        ),
      );
    }

    state.fullContentRaw += chunkContent;
    state.streamStartedAt ??= DateTime.now();
    if (chunk.totalTokens > 0) {
      state.totalTokens = chunk.totalTokens;
    }
    if (chunk.usage != null) {
      state.usage = (state.usage ?? const TokenUsage()).merge(chunk.usage!);
      state.totalTokens = state.usage!.totalTokens;
    }

    String streamingProcessed = _transformAssistantContent(state);
    if (streamingProcessed.contains('data:image') &&
        streamingProcessed.contains('base64,')) {
      try {
        final sanitized =
            await MarkdownMediaSanitizer.replaceInlineBase64Images(
              streamingProcessed,
            );
        if (sanitized != streamingProcessed) {
          streamingProcessed = sanitized;
          state.fullContentRaw = sanitized;
        }
      } catch (e) {
        // ignore
      }
    }

    // After any await point, _finishStreaming may have already run and
    // updated _messages[index] with the FULL final content. If we continue
    // with this stale streamingProcessed we would overwrite the final content
    // with a partial snapshot. Bail out early to prevent that.
    if (state.finishHandled) return;

    onScheduleImageSanitize?.call(
      messageId,
      streamingProcessed,
      immediate: true,
    );
    if (state.ctx.streamOutput && _currentConversation?.id == conversationId) {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: streamingProcessed,
          totalTokens: state.totalTokens,
        );
      }
    }

    // End reasoning when content starts
    if (state.ctx.streamOutput && chunkContent.isNotEmpty) {
      await _finishReasoningOnContent(state);
    }

    _scheduleIosBackgroundGenerationUpdate(state);

    // Re-check before scheduling timer — timer creation after _finishStreaming
    // would create a new timer that periodically overwrites _messages[index]
    // with stale partial content.
    if (state.finishHandled) return;

    // Schedule throttled UI update via StreamController
    if (state.ctx.streamOutput) {
      streamController.scheduleThrottledUpdate(
        messageId,
        conversationId,
        streamingProcessed,
        totalTokens: state.totalTokens,
        contentSplitOffsets: state.contentSplitOffsets,
        reasoningCountAtSplit: state.reasoningCountAtSplit,
        toolCountAtSplit: state.toolCountAtSplit,
        promptTokens: state.usage?.promptTokens,
        completionTokens: state.usage?.completionTokens,
        cachedTokens: state.usage?.cachedTokens,
        durationMs: state.streamStartedAt != null
            ? DateTime.now().difference(state.streamStartedAt!).inMilliseconds
            : null,
        updateMessageInList: (id, content, tokens) {
          onContentUpdated?.call(id, content, tokens);
        },
      );
    }
  }

  /// Finish reasoning segment when content starts arriving.
  Future<void> _finishReasoningOnContent(
    stream_ctrl.StreamingState state,
  ) async {
    await streamController.finishReasoningAndPersist(
      state.messageId,
      updateReasoningInDb:
          (
            String messageId, {
            String? reasoningText,
            DateTime? reasoningFinishedAt,
            String? reasoningSegmentsJson,
          }) async {
            // The complete reasoning snapshot is coalesced after this chunk.
          },
    );
  }

  /// Handle stream finish (isDone == true).
  Future<void> _handleStreamFinish(
    ChatStreamChunk chunk,
    stream_ctrl.StreamingState state,
    String chunkContent,
  ) async {
    final messageId = state.messageId;
    final conversationId = state.conversationId;
    final autoCollapseThinking =
        (!state.ctx.streamOutput && state.bufferedReasoning.isNotEmpty)
        ? contextProvider.read<SettingsProvider>().autoCollapseThinking
        : null;

    if (state.hadThinkingBlock && chunkContent.isNotEmpty) {
      state.contentSplitOffsets.add(state.fullContentRaw.length);
      state.reasoningCountAtSplit.add(
        streamController.getReasoningSegmentCount(messageId),
      );
      state.toolCountAtSplit.add(streamController.getToolPartsCount(messageId));
      state.hadThinkingBlock = false;
      streamController.setContentSplitData(
        messageId,
        stream_ctrl.ContentSplitData(
          offsets: List<int>.of(state.contentSplitOffsets),
          reasoningCounts: List<int>.of(state.reasoningCountAtSplit),
          toolCounts: List<int>.of(state.toolCountAtSplit),
        ),
      );
    }

    if (chunkContent.isNotEmpty) {
      state.fullContentRaw += chunkContent;
    }

    // Don't finish if tools are still loading
    final hasLoadingTool =
        (streamController.toolParts[messageId]?.any((p) => p.loading) ?? false);
    if (hasLoadingTool) {
      return;
    }

    if (chunk.totalTokens > 0) {
      state.totalTokens = chunk.totalTokens;
    }
    if (chunk.usage != null) {
      state.usage = (state.usage ?? const TokenUsage()).merge(chunk.usage!);
      state.totalTokens = state.usage!.totalTokens;
    }

    // Materialize buffered reasoning before the final checkpoint.
    if (!state.ctx.streamOutput && state.bufferedReasoning.isNotEmpty) {
      final now = DateTime.now();
      final startAt = state.reasoningStartAt ?? now;
      streamController.reasoning[messageId] = stream_ctrl.ReasoningData()
        ..text = state.bufferedReasoning
        ..startAt = startAt
        ..finishedAt = now
        ..expanded = !(autoCollapseThinking ?? false);
    }

    // Track the _finishStreaming future so _handleStreamDone can await it
    // if it fires concurrently (stream.onDone can fire while we're still
    // awaiting async work inside _finishStreaming).
    final finishFuture = _finishStreaming(state);
    _finishStreamingFutures[messageId] = finishFuture;
    await finishFuture;
    _finishStreamingFutures.remove(messageId);

    // Notify for background notification if needed
    if (!state.finishHandled) {
      onStreamFinished?.call();
    }

    await _conversationStreams.remove(conversationId)?.cancel();
  }

  /// Finish streaming and persist final state.
  Future<void> _finishStreaming(
    stream_ctrl.StreamingState state, {
    bool generateTitle = true,
  }) async {
    final messageId = state.messageId;
    final conversationId = state.conversationId;

    // Mark streaming as ended to allow UI rebuilds again
    streamController.markStreamingEnded(messageId);

    // Clean up stream throttle timer and flush final content
    streamController.cleanupTimers(messageId);

    final shouldGenerateTitle =
        generateTitle && state.ctx.generateTitleOnFinish && !state.titleQueued;
    if (state.finishHandled) {
      if (shouldGenerateTitle) {
        state.titleQueued = true;
        onMaybeGenerateTitle?.call(conversationId);
      }
      return;
    }
    state.finishHandled = true;
    if (shouldGenerateTitle) {
      state.titleQueued = true;
    }
    streamController.finishReasoningIfNeeded(messageId);

    // Replace extremely long inline base64 images with local files to avoid jank
    final processedContent = _transformAssistantContent(state);

    // Compute final duration
    final finalDurationMs = state.streamStartedAt != null
        ? DateTime.now().difference(state.streamStartedAt!).inMilliseconds
        : null;
    final finalPromptTokens = state.usage?.promptTokens;
    final finalCompletionTokens = state.usage?.completionTokens;
    final finalCachedTokens = state.usage?.cachedTokens;

    // Flush final content to the streaming notifier before async operations.
    // This ensures any intermediate rebuild (e.g., from isProcessingFiles change
    // or onDone firing concurrently) still shows the correct content via the
    // notifier-based streaming path.
    streamController.streamingContentNotifier.updateContent(
      messageId,
      processedContent,
      state.totalTokens,
      contentSplitOffsets: state.contentSplitOffsets,
      reasoningCountAtSplit: state.reasoningCountAtSplit,
      toolCountAtSplit: state.toolCountAtSplit,
      promptTokens: finalPromptTokens,
      completionTokens: finalCompletionTokens,
      cachedTokens: finalCachedTokens,
      durationMs: finalDurationMs,
    );

    final sanitizedContent =
        await MarkdownMediaSanitizer.replaceInlineBase64Images(
          processedContent,
        );
    final finalizedMessage = _streamingMessageSnapshot(state).copyWith(
      content: sanitizedContent,
      totalTokens: state.totalTokens,
      isStreaming: false,
      promptTokens: finalPromptTokens,
      completionTokens: finalCompletionTokens,
      cachedTokens: finalCachedTokens,
      durationMs: finalDurationMs,
    );
    try {
      await _finalizeStreamingCheckpoint(
        finalizedMessage,
        terminalState: GenerationRunState.completed,
      );

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = finalizedMessage;
        onMessagesChanged?.call();
      }
      onAssistantMessageFinished?.call(finalizedMessage);

      if (shouldGenerateTitle) {
        onMaybeGenerateTitle?.call(conversationId);
      }

      // Trigger summary generation check (actual logic in HomeViewModel)
      onMaybeGenerateSummary?.call(conversationId);

      // Trigger follow-up suggestions after the final assistant reply is stored.
      onMaybeGenerateSuggestions?.call(conversationId);
      await _finishIosBackgroundGeneration(success: true);
    } finally {
      // UI lifecycle cleanup is independent from terminal persistence success.
      streamController.removeStreamingNotifier(messageId);
      _setConversationLoading(conversationId, false);
    }
  }

  /// Handle stream error.
  Future<void> _handleStreamError(
    dynamic e,
    stream_ctrl.StreamingState state,
  ) async {
    final messageId = state.messageId;
    final conversationId = state.conversationId;
    final errorText = e.toString();

    // Reset file processing state on error
    onFileProcessingFinished?.call();

    // Mark streaming as ended to allow UI rebuilds again
    streamController.markStreamingEnded(messageId);

    streamController.cleanupTimers(messageId);
    streamController.finishReasoningIfNeeded(messageId);
    final displayContent = state.fullContentRaw.isEmpty
        ? ''
        : _transformAssistantContent(state, state.fullContentRaw);
    final currentIndex = _messages.indexWhere((m) => m.id == messageId);
    final errorMessage = _streamingMessageSnapshot(state).copyWith(
      content: displayContent,
      totalTokens: state.totalTokens,
      isStreaming: false,
    );
    try {
      await _finalizeStreamingCheckpoint(
        errorMessage,
        terminalState: GenerationRunState.failed,
        errorCode: 'generation_failed',
      );

      final index = currentIndex;
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: displayContent,
          isStreaming: false,
          totalTokens: state.totalTokens,
        );
        onMessagesChanged?.call();
      }
    } finally {
      _clearGenerationRuntimeState(errorMessage);
      streamController.removeStreamingNotifier(messageId);
      _setConversationLoading(conversationId, false);
      await _conversationStreams.remove(conversationId)?.cancel();
      onStreamError?.call(errorText);
      onStreamFinished?.call();
      await _finishIosBackgroundGeneration(success: false, detail: errorText);
    }
  }

  /// Handle stream done callback.
  Future<void> _handleStreamDone(stream_ctrl.StreamingState state) async {
    // Reset file processing state on done (just in case)
    onFileProcessingFinished?.call();

    final conversationId = state.conversationId;
    final messageId = state.messageId;

    // Ensure streaming is marked as ended
    streamController.markStreamingEnded(messageId);

    streamController.cleanupTimers(messageId);

    // If _finishStreaming is already in-flight (started by _handleStreamFinish),
    // wait for it to complete before removing notifiers or triggering rebuild.
    // This prevents a race where the notifier is removed and a rebuild is
    // triggered while _finishStreaming hasn't yet updated _messages[index].
    final inFlight = _finishStreamingFutures[messageId];
    if (inFlight != null) {
      await inFlight;
    } else if (_loadingConversationIds.contains(conversationId)) {
      await _finishStreaming(
        state,
        generateTitle: state.ctx.generateTitleOnFinish,
      );
    }
    // Idempotent: ensure notifier is removed even if _finishStreaming was skipped
    streamController.removeStreamingNotifier(messageId);
    onStreamFinished?.call();
    await _conversationStreams.remove(conversationId)?.cancel();
  }

  // ============================================================================
  // Flush Progress (for switching conversations)
  // ============================================================================

  /// Persist latest in-flight assistant message content and reasoning.
  Future<void> flushConversationProgress(Conversation? conversation) async {
    final cid = conversation?.id;
    if (cid == null || _messages.isEmpty) return;

    // Find the latest streaming assistant message in the current conversation
    ChatMessage? streaming;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.isStreaming && m.conversationId == cid) {
        streaming = m;
        break;
      }
    }
    if (streaming == null) return;

    // Use the UI-side content snapshot (may be ahead of last persisted chunk)
    final latestContent = streaming.content;
    // Also capture reasoning progress if tracked in-memory
    final r = streamController.reasoning[streaming.id];
    final segs = streamController.reasoningSegments[streaming.id];

    final splits = streamController.getContentSplitData(streaming.id);
    final reasoningSegmentsJson = segs != null || splits != null
        ? streamController.serializeReasoningSegmentsWithSplits(
            segs ?? const [],
            contentSplitOffsets: splits?.offsets,
            reasoningCountAtSplit: splits?.reasoningCounts,
            toolCountAtSplit: splits?.toolCounts,
          )
        : streaming.reasoningSegmentsJson;
    final snapshot = streaming.copyWith(
      content: latestContent,
      reasoningText: r?.text,
      reasoningStartAt: r?.startAt,
      reasoningFinishedAt: r?.finishedAt,
      reasoningSegmentsJson: reasoningSegmentsJson,
    );
    final writer = _checkpointWriters[streaming.id];
    if (writer == null) {
      await chatService.updateStreamingCheckpointSilent(
        snapshot,
        _copyToolEvents(streaming.id),
      );
    } else {
      writer.add(_createStreamingCheckpoint(snapshot));
      await writer.barrier();
    }
    // Ensure any inline data URLs get converted even if the user navigates away mid-stream
    onScheduleImageSanitize?.call(streaming.id, latestContent, immediate: true);
  }
}
