import 'dart:async';
import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/database/bridge_delivery.dart';
import '../../../core/database/generation_run.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/api/stream/stream_chunk.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/ios_background_generation.dart';
import '../../../core/services/logging/flutter_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/assistant_regex.dart';
import '../../../core/models/assistant_regex.dart';
import '../services/ask_user_interaction_service.dart';
import '../services/message_generation_service.dart';
import '../services/tool_approval_service.dart';
import '../bridge/native_turn.dart';
import 'active_streaming_message_store.dart';
import 'chat_controller.dart';
import 'generation_controller.dart';
import 'home_view_model.dart';
import 'latest_wins_checkpoint_writer.dart';
import 'stream_controller.dart' as stream_ctrl;

/// Raised when the generation context carries audio the target model cannot
/// read. Its [toString] is the error code the UI localizes.
final class UnsupportedAudioAttachmentException implements Exception {
  const UnsupportedAudioAttachmentException();

  @override
  String toString() => 'audio_attachment_unsupported';
}

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

  factory ChatActionResult.inFlight() =>
      ChatActionResult(success: false, errorMessage: 'in_flight');
}

final class _ClaimedSendResult {
  const _ClaimedSendResult({required this.action, this.externalStart});

  final ChatActionResult action;
  final NativeTurnStartResult? externalStart;
}

final class _ExternalTurnAwaiter {
  const _ExternalTurnAwaiter({
    required this.userMessageId,
    required this.generationRunId,
    required this.completer,
  });

  final String userMessageId;
  final String generationRunId;
  final Completer<NativeTurnTerminalResult> completer;
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
class ChatActions implements NativeTurnActions {
  static bool shouldPhysicallyRemoveRegenerationTail({
    required bool deleteTrailingEnabled,
    required bool isTemporaryConversation,
  }) => deleteTrailingEnabled && isTemporaryConversation;

  /// Whether regenerate should append a new assistant reply instead of adding
  /// a version to an existing reply group.
  ///
  /// [targetGroupId] is null when the assistant is treated as a new reply, or
  /// when the anchor is a user message with no following assistant group
  /// (e.g. every generated version was deleted).
  @visibleForTesting
  static bool shouldBeginNewAssistantReply({
    required String role,
    required String? targetGroupId,
    required bool assistantAsNewReply,
  }) {
    if (assistantAsNewReply && role == 'assistant') return true;
    return targetGroupId == null && role == 'user';
  }

  ChatActions({
    required this.chatService,
    required this.chatController,
    required this.streamController,
    required this.generationController,
    required this.messageGenerationService,
    required this.contextProvider,
    required this.viewModel,
  }) {
    _current = this;
  }

  /// Latest live instance. Deletion entry points that sit outside the home
  /// controller graph (e.g. the drawer's conversation delete) reach the
  /// active generation state through it to uphold the "deleting implies
  /// stopping generation" invariant.
  static ChatActions? _current;

  /// Flush the latest in-memory generation snapshot before the app exits.
  static Future<void> flushActiveGenerationProgress() async {
    final actions = _current;
    if (actions == null) return;
    await actions.flushConversationProgress(
      actions.chatController.currentConversation,
    );
  }

  /// Whether any conversation is generating right now.
  ///
  /// Read by background maintenance that would rather wait than compete with
  /// a reply for disk and CPU.
  static bool get hasAnyActiveGeneration {
    final actions = _current;
    if (actions == null) return false;
    return actions._conversationStreams.isNotEmpty ||
        actions._activeAssistantMessages.isNotEmpty;
  }

  /// Stop any in-flight generation for [conversationId] before its rows are
  /// deleted, so streaming checkpoints cannot write to removed messages.
  static Future<void> cancelActiveGenerationFor(String conversationId) async {
    final actions = _current;
    if (actions == null || !actions._hasActiveGeneration(conversationId)) {
      return;
    }
    await actions.cancelStreamingById(conversationId);
  }

  /// Stop in-flight generations for every conversation owned by
  /// [assistantId]. Used by assistant deletion, which batch-deletes the
  /// assistant's conversations and must uphold the "deleting implies
  /// stopping generation" invariant for each of them.
  static Future<void> cancelActiveGenerationsForAssistant(
    String assistantId,
  ) async {
    final actions = _current;
    if (actions == null) return;
    final conversationIds = actions.chatService
        .getAllConversations()
        .where((c) => c.assistantId == assistantId)
        .map((c) => c.id)
        .toList();
    for (final id in conversationIds) {
      if (actions._hasActiveGeneration(id)) {
        await actions.cancelStreamingById(id);
      }
    }
  }

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

  /// Called once after a successful send pair is visible in the tail window.
  VoidCallback? onSendPairAppended;

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

  /// Called when streaming finishes for [conversationId].
  void Function(String conversationId)? onStreamFinished;

  /// Called when a successful assistant reply is finalized.
  void Function(ChatMessage message)? onAssistantMessageFinished;

  /// Called when file processing starts for the assistant message [messageId].
  void Function(String messageId)? onFileProcessingStarted;

  /// Called when file processing finishes. A null [messageId] clears whichever
  /// message currently owns the indicator (error/cancel cleanup paths).
  void Function(String? messageId)? onFileProcessingFinished;

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
  final Map<String, stream_ctrl.StreamingState> _streamingStates =
      <String, stream_ctrl.StreamingState>{};
  final Map<String, Future<void>> _cancelStreamingFutures =
      <String, Future<void>>{};
  final Map<String, _ExternalTurnAwaiter> _externalTurnAwaiters =
      <String, _ExternalTurnAwaiter>{};

  /// Per-conversation send/regenerate claim, taken synchronously before the
  /// first await so a re-entrant call loses before persisting anything. The
  /// claim is handed off to the loading guard once loading is set; the token
  /// prevents a stale finally from clearing a newer claim.
  final Map<String, int> _sendInFlightClaims = <String, int>{};
  var _sendInFlightClaimSerial = 0;

  /// Whether send/regenerate or cancellation teardown owns [conversationId].
  bool isSendInFlight(String conversationId) =>
      _sendInFlightClaims.containsKey(conversationId) ||
      isStopping(conversationId);

  bool isStopping(String conversationId) =>
      _cancelStreamingFutures.containsKey(conversationId);

  List<ChatMessage> get _messages => chatController.messages;
  Map<String, int> get _versionSelections => chatController.versionSelections;
  Set<String> get _loadingConversationIds =>
      chatController.loadingConversationIds;
  Map<String, StreamSubscription<dynamic>> get _conversationStreams =>
      chatController.conversationStreams;

  bool _hasActiveGeneration(String conversationId) =>
      _conversationStreams.containsKey(conversationId) ||
      _activeAssistantMessages[conversationId] != null ||
      isStopping(conversationId);

  /// Id of the assistant message an in-flight generation checkpoints into,
  /// or null when [conversationId] has no active generation.
  String? activeStreamingMessageId(String conversationId) =>
      _activeAssistantMessages[conversationId]?.id;

  static const Duration _streamCancelTimeout = Duration(seconds: 3);

  /// A barrier cancel only completes once the generator leaves its current
  /// suspension point, which a dead connection can stall indefinitely even
  /// after `cancelRequest`; bound the wait and continue local cleanup.
  Future<void> _cancelSubscriptionWithTimeout(
    StreamSubscription<dynamic> subscription,
  ) async {
    try {
      await subscription.cancel().timeout(_streamCancelTimeout);
    } on TimeoutException {
      // Cancellation keeps running in the background.
    } catch (_) {
      // The HTTP request is already aborted; local terminal cleanup must still run.
    }
  }

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
    final details = streamController.reasoningDetails[messageId];
    final reasoningSegmentsJson = segments != null || details != null
        ? streamController.serializeReasoningSegmentsWithSplits(
            segments ?? const [],
            reasoningDetails: details,
          )
        : message.reasoningSegmentsJson;
    return message.copyWith(
      reasoningText: reasoning?.text,
      reasoningStartAt: reasoning?.startAt,
      reasoningFinishedAt: reasoning?.finishedAt,
      reasoningSegmentsJson: reasoningSegmentsJson,
    );
  }

  /// Elapsed milliseconds since [start], or null when unknown or when a
  /// device clock rollback made the difference negative (the message_rows
  /// CHECK constraint rejects negative durations).
  int? _elapsedMsFrom(DateTime? start) {
    if (start == null) return null;
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    return elapsed < 0 ? null : elapsed;
  }

  ChatMessage _streamingMessageSnapshot(stream_ctrl.StreamingState state) {
    final messageId = state.messageId;
    final index = _messages.indexWhere((message) => message.id == messageId);
    final base = _messageWithCurrentReasoning(
      index < 0 ? state.ctx.assistantMessage : _messages[index],
    );
    return base.copyWith(
      parts: _assistantPartsForState(state),
      totalTokens: state.totalTokens,
      promptTokens: state.usage?.promptTokens,
      completionTokens: state.usage?.completionTokens,
      cachedTokens: state.usage?.cachedTokens,
      // copyWith keeps base.durationMs when this resolves to null.
      durationMs: _elapsedMsFrom(state.streamStartedAt),
    );
  }

  void _scheduleStreamingCheckpoint(stream_ctrl.StreamingState state) {
    final writer = _checkpointWriters[state.messageId];
    if (writer == null || state.finishHandled) return;
    writer.add(() {
      final message = _streamingMessageSnapshot(state);
      _activeAssistantMessages.put(message);
      return _createStreamingCheckpoint(message);
    });
  }

  _StreamingCheckpoint _createStreamingCheckpoint(ChatMessage message) {
    final cursor = _generationCheckpointCursors[message.id];
    // While the run is still `preparing` the checkpoint CAS (which only
    // matches requesting/streaming/waiting_tool) would raise a conflict and,
    // through the writer, kill the just-started generation. Persist a plain
    // message snapshot without a run id/seq until the run reaches
    // `requesting`, mirroring _finalizeStreamingCheckpoint's preparing case.
    if (cursor == null || cursor.state == GenerationRunState.preparing) {
      return _StreamingCheckpoint(
        message: message,
        toolEvents: _copyToolEvents(message.id),
        generationRunId: null,
        checkpointSeq: null,
      );
    }
    final checkpointSeq = cursor.nextSeq;
    cursor.nextSeq += 1;
    return _StreamingCheckpoint(
      message: message,
      toolEvents: _copyToolEvents(message.id),
      generationRunId: cursor.runId,
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
      _completeExternalTurn(
        message,
        state: terminalState,
        errorCode: errorCode,
      );
    } catch (_) {
      _completeExternalTurn(
        message,
        state: GenerationRunState.failed,
        errorCode: 'terminal_persist_failed',
      );
      rethrow;
    } finally {
      if (committed) _clearGenerationRuntimeState(message);
    }
  }

  void _completeExternalTurn(
    ChatMessage message, {
    required GenerationRunState state,
    String? errorCode,
  }) {
    final awaiter = _externalTurnAwaiters.remove(message.id);
    if (awaiter == null || awaiter.completer.isCompleted) return;
    awaiter.completer.complete(
      NativeTurnTerminalResult(
        state: state,
        userMessageId: awaiter.userMessageId,
        assistantMessageId: message.id,
        generationRunId: awaiter.generationRunId,
        assistantMessage: message,
        errorCode: errorCode,
      ),
    );
  }

  void _clearGenerationRuntimeState(ChatMessage message) {
    _generationCheckpointCursors.remove(message.id);
    _streamingToolEvents.remove(message.id);
    _streamingStates.remove(message.id);
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
      if (chatController.publishTerminalMessage(message)) {
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
      events[index] = mergeStreamingToolEventRecord(events[index], record);
    }
  }

  @visibleForTesting
  static Map<String, dynamic> mergeStreamingToolEventRecord(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    for (final entry in incoming.entries) {
      if (entry.key == 'metadata') continue;
      if (_isEmptyToolOverlay(entry.value) &&
          !_isEmptyToolOverlay(merged[entry.key])) {
        continue;
      }
      merged[entry.key] = entry.value;
    }
    if (existing['server'] == true && incoming['server'] != false) {
      merged['server'] = true;
    }
    final incomingMetadata = incoming['metadata'];
    if (incomingMetadata is Map && incomingMetadata.isNotEmpty) {
      final existingMetadata = merged['metadata'];
      merged['metadata'] = <String, dynamic>{
        if (existingMetadata is Map)
          ...Map<String, dynamic>.from(existingMetadata),
        ...Map<String, dynamic>.from(incomingMetadata),
      };
    } else if (!merged.containsKey('metadata')) {
      final existingMetadata = existing['metadata'];
      if (existingMetadata is Map) {
        merged['metadata'] = Map<String, dynamic>.from(existingMetadata);
      }
    }
    return merged;
  }

  static bool _isEmptyToolOverlay(Object? value) {
    if (value == null) return true;
    if (value is String) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    if (value is List) return value.isEmpty;
    return false;
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
  static String resolveStreamErrorContent({
    required String partialContent,
    required String errorText,
  }) => partialContent.isEmpty ? errorText : partialContent;

  /// Assemble the assistant part list after a stream error.
  ///
  /// When no visible text arrived, the error string is written through
  /// [ChatMessage.partsWithReplacedText] so reasoning / tool / image parts
  /// already accumulated stay in place.
  /// Truncate [parts] so joined [TextPart]s match the typewriter slice.
  ///
  /// Non-text cards stay in place. Text after the visible prefix is omitted
  /// so the consumer can keep using `content: parts == null ? display : null`.
  @visibleForTesting
  static List<MessagePart> assistantPartsForVisibleText({
    required List<MessagePart> parts,
    required String visibleText,
  }) {
    if (parts.isEmpty) return <MessagePart>[TextPart(visibleText)];
    var remaining = visibleText.length;
    final out = <MessagePart>[];
    for (final part in parts) {
      if (part is! TextPart) {
        out.add(part);
        continue;
      }
      if (remaining <= 0) continue;
      if (part.text.length <= remaining) {
        out.add(part);
        remaining -= part.text.length;
      } else {
        out.add(TextPart(part.text.substring(0, remaining)));
        remaining = 0;
      }
    }
    return out;
  }

  @visibleForTesting
  static List<MessagePart> assistantPartsForStreamError({
    required List<MessagePart> parts,
    required String partialContent,
    required String errorText,
  }) {
    final displayContent = resolveStreamErrorContent(
      partialContent: partialContent,
      errorText: errorText,
    );
    if (partialContent.isEmpty) {
      if (parts.any((part) => part is TextPart)) {
        return ChatMessage.partsWithReplacedText(parts, displayContent);
      }
      return [...parts, TextPart(displayContent)];
    }
    return List<MessagePart>.of(parts);
  }

  @visibleForTesting
  Future<void> debugFinishStreaming(stream_ctrl.StreamingState state) {
    return _finishStreaming(state);
  }

  @visibleForTesting
  Future<void> debugHandleStreamError(
    Object error,
    stream_ctrl.StreamingState state,
  ) {
    return _handleStreamError(error, state);
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
      try {
        await sourceSubscription.cancel();
      } finally {
        await drainFuture;
      }
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

  List<MessagePart> _assistantPartsForState(
    stream_ctrl.StreamingState state, {
    String? visibleText,
  }) {
    final parts = state.partsHandler.parts;
    if (parts.isEmpty) {
      return <MessagePart>[
        TextPart(visibleText ?? _transformAssistantContent(state)),
      ];
    }
    final transformed = [
      for (final part in parts)
        if (part is TextPart)
          TextPart(_transformAssistantContent(state, part.text))
        else if (part is! ImagePart || !isBlankImageUri(part.uri))
          part,
    ];
    if (visibleText == null) return transformed;
    return assistantPartsForVisibleText(
      parts: transformed,
      visibleText: visibleText,
    );
  }

  Future<List<MessagePart>> _sanitizeAssistantImageParts(
    List<MessagePart> parts,
  ) async {
    final out = <MessagePart>[];
    for (final part in parts) {
      if (part is! ImagePart || !part.uri.startsWith('data:')) {
        out.add(part);
        continue;
      }
      final comma = part.uri.indexOf(',');
      if (comma < 0) {
        out.add(part);
        continue;
      }
      final header = part.uri.substring(5, comma);
      final semi = header.indexOf(';');
      final mime = semi < 0 ? header : header.substring(0, semi);
      final saved = await AppDirectories.saveBase64Image(
        mime.isEmpty ? 'image/png' : mime,
        part.uri.substring(comma + 1),
      );
      if (saved == null || saved.isEmpty) {
        out.add(part);
        continue;
      }
      out.add(
        ImagePart(
          uri: SandboxPathResolver.canonicalize(saved),
          mime: part.mime ?? (mime.isEmpty ? 'image/png' : mime),
          assetId: part.assetId,
          unavailable: part.unavailable,
        ),
      );
    }
    return out;
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
  /// - Scrolling once to the newly appended tail
  /// - Haptic feedback
  Future<ChatActionResult> sendMessage({
    required ChatInputData input,
    required Conversation conversation,
  }) async {
    final claimToken = ++_sendInFlightClaimSerial;
    if (isSendInFlight(conversation.id)) {
      return ChatActionResult.inFlight();
    }
    _sendInFlightClaims[conversation.id] = claimToken;
    try {
      final result = await _sendMessageClaimed(
        input: input,
        conversation: conversation,
      );
      return result.action;
    } finally {
      if (_sendInFlightClaims[conversation.id] == claimToken) {
        _sendInFlightClaims.remove(conversation.id);
      }
    }
  }

  /// Starts an external room turn on the same live native send path as the UI.
  ///
  /// Unlike [sendMessage], the returned handle exposes the durable terminal
  /// completion. New work is never queued: an occupied conversation returns
  /// [NativeTurnStartStatus.busy] without persisting the room event.
  @override
  Future<NativeTurnStartResult> sendExternalTurn({
    required ChatInputData input,
    required Conversation conversation,
    required BridgeDeliveryClaim deliveryClaim,
  }) async {
    try {
      final existing = await chatService.getBridgeTurnSnapshot(
        originInstanceId: deliveryClaim.originInstanceId,
        idempotencyKey: deliveryClaim.idempotencyKey,
      );
      if (existing != null) {
        if (existing.delivery.requestFingerprint !=
            deliveryClaim.requestFingerprint) {
          return const NativeTurnStartResult(
            status: NativeTurnStartStatus.idempotencyConflict,
            errorCode: 'IDEMPOTENCY_CONFLICT',
          );
        }
        return NativeTurnStartResult(
          status: NativeTurnStartStatus.accepted,
          handle: _handleForPersistedBridgeTurn(
            delivery: existing.delivery,
            assistantMessage: existing.assistantMessage,
            run: existing.run,
          ),
        );
      }
    } catch (error) {
      return NativeTurnStartResult(
        status: NativeTurnStartStatus.rejected,
        errorCode: error.toString(),
      );
    }

    if (chatController.currentConversation?.id != conversation.id) {
      return const NativeTurnStartResult(
        status: NativeTurnStartStatus.rejected,
        errorCode: 'NOT_ACTIVE_CONVERSATION',
      );
    }
    if (chatService.isTemporaryConversation(conversation.id) ||
        !chatService.isPersistedConversation(conversation.id)) {
      return const NativeTurnStartResult(
        status: NativeTurnStartStatus.rejected,
        errorCode: 'UNSUPPORTED_TEMPORARY_CONVERSATION',
      );
    }
    if (_loadingConversationIds.contains(conversation.id) ||
        _hasActiveGeneration(conversation.id) ||
        isSendInFlight(conversation.id)) {
      return const NativeTurnStartResult(
        status: NativeTurnStartStatus.busy,
        errorCode: 'GENERATION_BUSY',
      );
    }

    final claimToken = ++_sendInFlightClaimSerial;
    _sendInFlightClaims[conversation.id] = claimToken;
    try {
      final result = await _sendMessageClaimed(
        input: input,
        conversation: conversation,
        deliveryClaim: deliveryClaim,
      );
      return result.externalStart ??
          NativeTurnStartResult(
            status: NativeTurnStartStatus.rejected,
            errorCode: result.action.errorMessage ?? 'NATIVE_SEND_REJECTED',
          );
    } finally {
      if (_sendInFlightClaims[conversation.id] == claimToken) {
        _sendInFlightClaims.remove(conversation.id);
      }
    }
  }

  NativeTurnHandle _handleForPersistedBridgeTurn({
    required BridgeDelivery delivery,
    required ChatMessage assistantMessage,
    required GenerationRun run,
  }) {
    final live = _externalTurnAwaiters[assistantMessage.id];
    final completion =
        live?.completer.future ??
        Future<NativeTurnTerminalResult>.value(
          NativeTurnTerminalResult(
            state: run.state.isTerminal
                ? run.state
                : GenerationRunState.interrupted,
            userMessageId: delivery.userRevisionId,
            assistantMessageId: delivery.assistantRevisionId,
            generationRunId: delivery.generationRunId,
            assistantMessage: assistantMessage,
            errorCode: run.state.isTerminal
                ? run.errorCode
                : 'RECOVERY_REQUIRED',
          ),
        );
    return NativeTurnHandle(
      userMessageId: delivery.userRevisionId,
      assistantMessageId: delivery.assistantRevisionId,
      generationRunId: delivery.generationRunId,
      deduplicated: true,
      completion: completion,
    );
  }

  Future<_ClaimedSendResult> _sendMessageClaimed({
    required ChatInputData input,
    required Conversation conversation,
    BridgeDeliveryClaim? deliveryClaim,
  }) async {
    final content = input.text.trim();
    if (content.isEmpty &&
        input.imagePaths.isEmpty &&
        input.documents.isEmpty) {
      return _ClaimedSendResult(action: ChatActionResult.error('empty_input'));
    }

    final settings = contextProvider.read<SettingsProvider>();
    final assistantProvider = contextProvider.read<AssistantProvider>();
    // Capture approval service reference before async gap
    ToolApprovalService? approvalService;
    AskUserInteractionService? askUserService;
    try {
      approvalService = contextProvider.read<ToolApprovalService>();
    } catch (_) {}
    try {
      askUserService = contextProvider.read<AskUserInteractionService>();
    } catch (_) {}
    try {
      await assistantProvider.loaded;
    } catch (e) {
      return _ClaimedSendResult(action: ChatActionResult.error(e.toString()));
    }
    final assistant = assistantProvider.currentAssistant;
    final assistantId = assistant?.id;
    final modelConfig = messageGenerationService.getModelConfig(
      settings,
      assistant,
      conversation: conversation,
    );

    if (modelConfig.providerKey == null || modelConfig.modelId == null) {
      return _ClaimedSendResult(action: ChatActionResult.noModel());
    }
    final providerKey = modelConfig.providerKey!;
    final modelId = modelConfig.modelId!;

    if (chatController.hasMoreAfter) {
      final loaded = await chatController.loadEndWindow();
      if (loaded) {
        viewModel.restoreMessageUiState();
      }
    }

    // Only the pending input is screened here: it needs no database read, so
    // the send pair still reaches the screen without waiting on the context
    // query. History is screened in [_runSendGeneration], where a failure
    // lands on the assistant message instead of rejecting the input.
    if (!_supportsAudioAttachmentsForProvider(
          settings,
          providerKey: providerKey,
          modelId: modelId,
        ) &&
        messageGenerationService.inputContainsAudioAttachments(input)) {
      return _ClaimedSendResult(
        action: ChatActionResult.error('audio_attachment_unsupported'),
      );
    }

    late final ChatMessage userMessage;
    late final ChatMessage assistantMessage;
    String? generationRunId;
    NativeTurnHandle? externalHandle;
    try {
      if (deliveryClaim == null) {
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
      } else {
        final begin = await messageGenerationService.beginBridgeSendGeneration(
          conversationId: conversation.id,
          input: input,
          assistant: assistant,
          modelId: modelId,
          providerKey: providerKey,
          deliveryClaim: deliveryClaim,
        );
        if (begin.disposition == BridgeGenerationBeginDisposition.conflict) {
          return _ClaimedSendResult(
            action: ChatActionResult.error('idempotency_conflict'),
            externalStart: const NativeTurnStartResult(
              status: NativeTurnStartStatus.idempotencyConflict,
              errorCode: 'IDEMPOTENCY_CONFLICT',
            ),
          );
        }
        if (begin.disposition == BridgeGenerationBeginDisposition.duplicate) {
          final snapshot = await chatService.getBridgeTurnSnapshot(
            originInstanceId: deliveryClaim.originInstanceId,
            idempotencyKey: deliveryClaim.idempotencyKey,
          );
          if (snapshot == null) {
            throw StateError('bridge_delivery_mapping_missing');
          }
          final handle = _handleForPersistedBridgeTurn(
            delivery: snapshot.delivery,
            assistantMessage: snapshot.assistantMessage,
            run: snapshot.run,
          );
          return _ClaimedSendResult(
            action: ChatActionResult.success(snapshot.assistantMessage),
            externalStart: NativeTurnStartResult(
              status: NativeTurnStartStatus.accepted,
              handle: handle,
            ),
          );
        }
        final generation = begin.generation!;
        userMessage = generation.userMessage!;
        assistantMessage = generation.assistantMessage;
        generationRunId = generation.run.id;
        final completer = Completer<NativeTurnTerminalResult>();
        _externalTurnAwaiters[assistantMessage.id] = _ExternalTurnAwaiter(
          userMessageId: userMessage.id,
          generationRunId: generationRunId,
          completer: completer,
        );
        externalHandle = NativeTurnHandle(
          userMessageId: userMessage.id,
          assistantMessageId: assistantMessage.id,
          generationRunId: generationRunId,
          deduplicated: false,
          completion: completer.future,
        );
      }
      _registerGenerationRun(assistantMessage.id, generationRunId);
    } catch (e) {
      return _ClaimedSendResult(action: ChatActionResult.error(e.toString()));
    }
    _activeAssistantMessages.put(assistantMessage);
    _setConversationLoading(conversation.id, true);
    // The loading guard now owns re-entry exclusion for this conversation.
    _sendInFlightClaims.remove(conversation.id);

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
    onSendPairAppended?.call();

    // The send pair is visible and owned by the loading guard from here on, so
    // the caller is released now: the composer must not keep its attachments
    // (or the keyboard) around for the whole generation. Failures past this
    // point surface through onStreamError and the message itself.
    unawaited(
      _runSendGeneration(
        input: input,
        conversation: conversation,
        settings: settings,
        assistant: assistant,
        assistantId: assistantId,
        providerKey: providerKey,
        modelId: modelId,
        userMessage: userMessage,
        assistantMessage: assistantMessage,
        generationRunId: generationRunId,
        approvalService: approvalService,
        askUserService: askUserService,
      ),
    );
    return _ClaimedSendResult(
      action: ChatActionResult.success(assistantMessage),
      externalStart: externalHandle == null
          ? null
          : NativeTurnStartResult(
              status: NativeTurnStartStatus.accepted,
              handle: externalHandle,
            ),
    );
  }

  Future<void> _runSendGeneration({
    required ChatInputData input,
    required Conversation conversation,
    required SettingsProvider settings,
    required Assistant? assistant,
    required String? assistantId,
    required String providerKey,
    required String modelId,
    required ChatMessage userMessage,
    required ChatMessage assistantMessage,
    required String? generationRunId,
    required ToolApprovalService? approvalService,
    required AskUserInteractionService? askUserService,
  }) async {
    // Nothing awaits this future, so every failure has to be caught here.
    try {
      // The context query is the slowest step of a send and nothing on screen
      // depends on it, so it runs after the pair is already visible. The pair
      // itself is persisted by now and comes back in this read — drop it here
      // and let the caller re-append it in generation order.
      final contextLimit = await _contextReadLimit(assistant, conversation);
      final persistedContext = await chatController
          .messagesForGenerationContext(
            conversation,
            maxMessages: contextLimit + 2,
          );
      final existingContextMessages = <ChatMessage>[
        for (final message in persistedContext)
          if (message.id != userMessage.id && message.id != assistantMessage.id)
            message,
      ];
      if (_hasUnsupportedAudioAttachments(
        messages: existingContextMessages,
        conversation: conversation,
        settings: settings,
        providerKey: providerKey,
        modelId: modelId,
        maxRawTruncateIndex: null,
      )) {
        throw const UnsupportedAudioAttachmentException();
      }

      // Reset tool parts and initialize reasoning
      streamController.toolParts.remove(assistantMessage.id);
      final supportsReasoning = _isReasoningModel(providerKey, modelId);
      final enableReasoning =
          supportsReasoning &&
          _isReasoningEnabled(
            assistant?.thinkingBudget ?? settings.thinkingBudget,
          );
      // Prepare API messages
      _bindFileProcessingCallbacks();
      await messageGenerationService.initializeReasoningState(
        messageId: assistantMessage.id,
        enableReasoning: enableReasoning,
      );
      final apiContextMessages = <ChatMessage>[
        ...existingContextMessages,
        userMessage,
        assistantMessage,
      ];
      final prepared = await messageGenerationService
          .prepareApiMessagesWithInjections(
            messages: apiContextMessages,
            versionSelections: _versionSelections,
            currentConversation: conversation.copyWith(truncateIndex: -1),
            settings: settings,
            assistant: assistant,
            assistantId: assistantId,
            providerKey: providerKey,
            modelId: modelId,
            approvalService: approvalService,
            askUserService: askUserService,
            processingMessageId: assistantMessage.id,
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
        return;
      }
      await _executeGeneration(ctx);
    } catch (e) {
      await handleSendGenerationFailure(
        error: e,
        conversationId: conversation.id,
        assistantMessage: assistantMessage,
      );
    }
  }

  /// Terminal handling for a send whose generation future nobody awaits.
  ///
  /// The caller already has its success result, so this is the only place the
  /// failure can reach the UI. The cleanup write is caught separately: if it
  /// throws too, the original error must still surface instead of becoming an
  /// unhandled async error behind a silent empty assistant message.
  @visibleForTesting
  Future<void> handleSendGenerationFailure({
    required Object error,
    required String conversationId,
    required ChatMessage assistantMessage,
  }) async {
    // Ensure file processing indicator is cleared on error
    onFileProcessingFinished?.call(assistantMessage.id);
    try {
      await _finishPreparingMessage(conversationId, assistantMessage);
    } catch (cleanupError, stackTrace) {
      FlutterLogger.log(
        '[ChatActions] finishPreparingMessage failed after send error: '
        '$cleanupError\n$stackTrace',
        tag: 'ChatActions',
      );
    }
    onStreamError?.call(error.toString());
  }

  void _bindFileProcessingCallbacks() {
    messageGenerationService.onFileProcessingStarted = onFileProcessingStarted;
    messageGenerationService.onFileProcessingFinished =
        onFileProcessingFinished;
  }

  Future<int> _contextReadLimit(
    Assistant? assistant,
    Conversation conversation,
  ) {
    return resolveContextReadLimit(
      assistant: assistant,
      resolvePersistedCount: () =>
          chatService.resolveMessageCount(conversation.id),
    );
  }

  /// Resolves the generation context window size.
  ///
  /// When the assistant limits context, [resolvePersistedCount] is not called.
  /// Otherwise the real persisted count is awaited so unknown (-1) never
  /// silently clamps to [Assistant.maxContextMessageSize].
  @visibleForTesting
  static Future<int> resolveContextReadLimit({
    required Assistant? assistant,
    required Future<int> Function() resolvePersistedCount,
  }) async {
    if ((assistant?.limitContextMessages ?? false) &&
        (assistant?.contextMessageSize ?? 0) > 0) {
      return contextReadLimit(assistant: assistant, persistedMessageCount: 0);
    }
    final count = await resolvePersistedCount();
    return contextReadLimit(assistant: assistant, persistedMessageCount: count);
  }

  @visibleForTesting
  static int contextReadLimit({
    required Assistant? assistant,
    required int persistedMessageCount,
  }) {
    assert(
      persistedMessageCount >= 0,
      'contextReadLimit requires a known message count; got '
      '$persistedMessageCount',
    );
    if ((assistant?.limitContextMessages ?? false) &&
        (assistant?.contextMessageSize ?? 0) > 0) {
      return assistant!.contextMessageSize.clamp(
        Assistant.minContextMessageSize,
        Assistant.maxContextMessageSize,
      );
    }
    return persistedMessageCount > 0
        ? persistedMessageCount
        : Assistant.maxContextMessageSize;
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
    final claimToken = ++_sendInFlightClaimSerial;
    if (isSendInFlight(conversation.id)) {
      return ChatActionResult.inFlight();
    }
    _sendInFlightClaims[conversation.id] = claimToken;
    try {
      return await _regenerateAtMessageClaimed(
        message: message,
        conversation: conversation,
        assistantAsNewReply: assistantAsNewReply,
        allowImagesApiRouting: allowImagesApiRouting,
      );
    } finally {
      if (_sendInFlightClaims[conversation.id] == claimToken) {
        _sendInFlightClaims.remove(conversation.id);
      }
    }
  }

  Future<ChatActionResult> _regenerateAtMessageClaimed({
    required ChatMessage message,
    required Conversation conversation,
    bool assistantAsNewReply = false,
    bool allowImagesApiRouting = true,
  }) async {
    // Avoid using BuildContext across async gaps (this class holds a BuildContext).
    final settings = contextProvider.read<SettingsProvider>();
    final truncateFuture = settings.regenerateDeleteTrailingMessages;
    final assistantProvider = contextProvider.read<AssistantProvider>();
    // Capture approval service reference before async gap
    ToolApprovalService? regenApprovalService;
    AskUserInteractionService? regenAskUserService;
    try {
      regenApprovalService = contextProvider.read<ToolApprovalService>();
    } catch (_) {}
    try {
      regenAskUserService = contextProvider.read<AskUserInteractionService>();
    } catch (_) {}
    try {
      await assistantProvider.loaded;
    } catch (e) {
      return ChatActionResult.error(e.toString());
    }
    final assistant = assistantProvider.currentAssistant;

    await cancelStreaming(conversation);

    final isTemporaryConversation = chatService.isTemporaryConversation(
      conversation.id,
    );
    final completeMessages = isTemporaryConversation
        ? await chatController.messagesForCompleteHistoryContext(conversation)
        : await chatController.messagesForGenerationContext(
            conversation,
            maxMessages: await _contextReadLimit(assistant, conversation),
            throughRevisionId: message.id,
            includeFollowingAssistant: true,
          );
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
      conversation: conversation,
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
      conversation: isTemporaryConversation
          ? conversation
          : conversation.copyWith(truncateIndex: -1),
      settings: settings,
      providerKey: providerKey,
      modelId: modelId,
      maxRawTruncateIndex: versioning.lastKeep,
    )) {
      return ChatActionResult.error('audio_attachment_unsupported');
    }

    if (shouldPhysicallyRemoveRegenerationTail(
      deleteTrailingEnabled: truncateFuture,
      isTemporaryConversation: isTemporaryConversation,
    )) {
      final removeIds = await messageGenerationService.removeTrailingMessages(
        messages: completeMessages,
        lastKeep: versioning.lastKeep,
        targetGroupId: versioning.targetGroupId,
      );
      if (removeIds.isNotEmpty) {
        await chatController.refreshTimelineAfterMutation(
          removedRevisionIds: removeIds.toSet(),
        );
        viewModel.restoreMessageUiState();
        onMessagesChanged?.call();
      }
    }

    late final ({ChatMessage assistantMessage, String? runId}) begin;
    final targetGroupId = versioning.targetGroupId;
    if (shouldBeginNewAssistantReply(
      role: message.role,
      targetGroupId: targetGroupId,
      assistantAsNewReply: assistantAsNewReply,
    )) {
      begin = await messageGenerationService.beginAssistantGeneration(
        conversationId: conversation.id,
        modelId: modelId,
        providerKey: providerKey,
        anchorGroupId: message.groupId ?? message.id,
        truncateFuture: truncateFuture,
      );
    } else {
      if (targetGroupId == null) {
        return ChatActionResult.error('invalid_versioning');
      }
      final nextVersion = isTemporaryConversation
          ? versioning.nextVersion
          : await chatService.getMaxMessageVersionForGroup(
                  conversation.id,
                  targetGroupId,
                ) +
                1;
      begin = await messageGenerationService.beginRegeneration(
        conversationId: conversation.id,
        modelId: modelId,
        providerKey: providerKey,
        groupId: targetGroupId,
        version: nextVersion,
        truncateFuture: truncateFuture,
      );
    }
    final assistantMessage = begin.assistantMessage;
    _registerGenerationRun(assistantMessage.id, begin.runId);
    _activeAssistantMessages.put(assistantMessage);

    // Pre-create streaming notifier BEFORE adding message to list
    // so that MessageListView can detect it's streaming on first render
    streamController.markStreamingStarted(assistantMessage.id);

    if (assistantMessage.groupId case final groupId?) {
      _versionSelections[groupId] = assistantMessage.version;
    }

    final regenerationMessages = ChatActions.buildRegenerationMessages(
      messages: completeMessages,
      lastKeep: versioning.lastKeep,
      targetGroupId: versioning.targetGroupId,
      assistantPlaceholder: assistantMessage,
    );

    // Keep the loaded window around the persisted generation message instead
    // of replacing a distant reading position with the conversation tail
    // (which can exclude this streaming revision in a long conversation).
    if (await chatController.openAroundPersistedMessage(
      assistantMessage,
      truncateFollowingSlots: !isTemporaryConversation && truncateFuture,
    )) {
      viewModel.restoreMessageUiState();
    }
    onMessagesChanged?.call();

    _setConversationLoading(conversation.id, true);
    // The loading guard now owns re-entry exclusion for this conversation.
    _sendInFlightClaims.remove(conversation.id);

    // Initialize reasoning
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning =
        supportsReasoning &&
        _isReasoningEnabled(
          assistant?.thinkingBudget ?? settings.thinkingBudget,
        );
    _bindFileProcessingCallbacks();
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
            currentConversation: isTemporaryConversation
                ? _conversationForMessageContext(
                    conversation,
                    regenerationMessages,
                    maxRawTruncateIndex: versioning.lastKeep,
                  )
                : conversation.copyWith(truncateIndex: -1),
            settings: settings,
            assistant: assistant,
            assistantId: assistantId,
            providerKey: providerKey,
            modelId: modelId,
            approvalService: regenApprovalService,
            askUserService: regenAskUserService,
            processingMessageId: assistantMessage.id,
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
    if (isSendInFlight(conversation.id)) {
      return ChatActionResult.inFlight();
    }

    final settings = contextProvider.read<SettingsProvider>();
    final assistantProvider = contextProvider.read<AssistantProvider>();
    ToolApprovalService? approvalService;
    AskUserInteractionService? askUserService;
    try {
      approvalService = contextProvider.read<ToolApprovalService>();
    } catch (_) {}
    try {
      askUserService = contextProvider.read<AskUserInteractionService>();
    } catch (_) {}
    try {
      await assistantProvider.loaded;
    } catch (e) {
      return ChatActionResult.error(e.toString());
    }
    final assistant = assistantProvider.currentAssistant;

    final visibleIndex = _messages.indexWhere(
      (candidate) => candidate.id == message.id,
    );
    if (visibleIndex < 0 || message.role != 'assistant') {
      return ChatActionResult.error('message_not_found');
    }
    final completeMessages = await chatController.messagesForGenerationContext(
      conversation,
      maxMessages: await _contextReadLimit(assistant, conversation),
      throughRevisionId: message.id,
    );
    final contextIndex = completeMessages.indexWhere(
      (candidate) => candidate.id == message.id,
    );
    if (contextIndex < 0) {
      return ChatActionResult.error('message_not_found');
    }

    final modelConfig = messageGenerationService.getModelConfig(
      settings,
      assistant,
      conversation: conversation,
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
    chatController.publishGenerationStarted(streamingMessage);
    await chatService.updateMessage(streamingMessage.id, isStreaming: true);
    onMessagesChanged?.call();
    _setConversationLoading(conversation.id, true);

    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning =
        supportsReasoning &&
        _isReasoningEnabled(
          assistant?.thinkingBudget ?? settings.thinkingBudget,
        );

    _bindFileProcessingCallbacks();
    try {
      final apiContextMessages = List<ChatMessage>.of(completeMessages);
      apiContextMessages[contextIndex] = streamingMessage.copyWith(content: '');
      final prepared = await messageGenerationService
          .prepareApiMessagesWithInjections(
            messages: apiContextMessages,
            versionSelections: _versionSelections,
            currentConversation: conversation.copyWith(truncateIndex: -1),
            settings: settings,
            assistant: assistant,
            assistantId: assistant?.id,
            providerKey: providerKey,
            modelId: modelId,
            approvalService: approvalService,
            askUserService: askUserService,
            processingMessageId: streamingMessage.id,
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
    await cancelStreamingById(cid);
  }

  /// Cancel the active streaming for the conversation with id [cid].
  Future<void> cancelStreamingById(String cid) {
    final existing = _cancelStreamingFutures[cid];
    if (existing != null) return existing;

    late final Future<void> operation;
    operation = Future<void>.microtask(() => _cancelStreamingByIdOnce(cid))
        .whenComplete(() {
          if (identical(_cancelStreamingFutures[cid], operation)) {
            _cancelStreamingFutures.remove(cid);
            _setConversationLoading(cid, false);
          }
        });
    _cancelStreamingFutures[cid] = operation;
    return operation;
  }

  Future<void> _cancelStreamingByIdOnce(String cid) async {
    // Cancel pending tool approval requests for this conversation to prevent
    // deadlock. Scoped by conversation id: the static deletion entry points
    // (cancelActiveGenerationFor / cancelActiveGenerationsForAssistant) may
    // cancel a background conversation while another one is streaming, and a
    // global cancelAll would deny that other conversation's pending approvals.
    try {
      contextProvider.read<ToolApprovalService>().cancelForConversation(cid);
    } catch (_) {
      // ToolApprovalService may not be registered yet
    }
    try {
      contextProvider.read<AskUserInteractionService>().cancelForConversation(
        cid,
      );
    } catch (_) {
      // AskUserInteractionService may not be registered yet
    }

    // Reset file processing state on cancel, for this conversation's message
    // only: a global reset would hide a bar another conversation still owns.
    final cancelIndicatorTarget = _activeAssistantMessages.cancellationTarget(
      cid,
      _messages,
    );
    if (cancelIndicatorTarget != null) {
      onFileProcessingFinished?.call(cancelIndicatorTarget.id);
    }

    // Abort the HTTP request before waiting on the subscription: the barrier
    // cancel only completes once the generator leaves its network await,
    // which a stalled connection would otherwise block indefinitely.
    ChatApiService.cancelRequest(cid);

    // Cancel active stream for current conversation only
    final sub = _conversationStreams.remove(cid);

    // End the visible streaming state immediately. The conversation remains
    // internally busy through [_cancelStreamingFutures] until teardown ends.
    final visibleStreaming = _activeAssistantMessages.cancellationTarget(
      cid,
      _messages,
    );
    if (visibleStreaming != null) {
      streamController.markStreamingEnded(visibleStreaming.id);
      streamController.cleanupTimers(visibleStreaming.id);
      final index = _messages.indexWhere((m) => m.id == visibleStreaming.id);
      final visibleMessage = index == -1 ? visibleStreaming : _messages[index];
      if (chatController.publishTerminalMessage(visibleMessage)) {
        onMessagesChanged?.call();
      }
      streamController.removeStreamingNotifier(visibleStreaming.id);
    } else {
      chatController.publishGenerationState(cid, isGenerating: false);
    }
    onLoadingChanged?.call(cid, false);

    if (sub != null) {
      await _cancelSubscriptionWithTimeout(sub);
    }

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
      var latestStreaming = idx == -1 ? streaming : _messages[idx];
      if (idx == -1) {
        final writer = _checkpointWriters[streaming.id];
        if (writer != null) {
          await writer.barrier();
          latestStreaming = _activeAssistantMessages[cid] ?? latestStreaming;
        }
      }

      streamController.finishReasoningIfNeeded(streaming.id);
      final state = _streamingStates[streaming.id];
      final assistantParts = await _sanitizeAssistantImageParts(
        state == null ? latestStreaming.parts : _assistantPartsForState(state),
      );
      final finalizedMessage =
          (state == null
                  ? _messageWithCurrentReasoning(latestStreaming)
                  : _streamingMessageSnapshot(state))
              .copyWith(parts: assistantParts, isStreaming: false);
      try {
        await _finalizeStreamingCheckpoint(
          finalizedMessage,
          terminalState: GenerationRunState.cancelled,
        );
      } finally {
        _clearGenerationRuntimeState(finalizedMessage);
        if (chatController.publishTerminalMessage(finalizedMessage)) {
          onMessagesChanged?.call();
        }
        streamController.removeStreamingNotifier(streaming.id);
      }

      // If streaming output included inline base64 images, sanitize them even on manual cancel
      onScheduleImageSanitize?.call(
        streaming.id,
        latestStreaming.content,
        immediate: true,
      );
      await _cancelIosBackgroundGeneration();
    } else {
      chatController.publishGenerationState(cid, isGenerating: false);
    }
  }

  // ============================================================================
  // Stream Execution
  // ============================================================================

  /// Execute generation with the given context.
  Future<void> _executeGeneration(stream_ctrl.GenerationContext ctx) async {
    final state = stream_ctrl.StreamingState(ctx);
    _streamingStates[state.messageId] = state;
    final assistant = ctx.assistant;
    final conversationId = state.conversationId;
    final existingSplit = streamController.getContentSplitData(state.messageId);
    if (existingSplit != null) {
      state.contentSplitOffsets = List<int>.of(existingSplit.offsets);
      state.reasoningCountAtSplit = List<int>.of(existingSplit.reasoningCounts);
      state.toolCountAtSplit = List<int>.of(existingSplit.toolCounts);
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
      final previousSub = _conversationStreams.remove(conversationId);
      if (previousSub != null) {
        ChatApiService.cancelRequest(conversationId);
        await _cancelSubscriptionWithTimeout(previousSub);
      }

      if (!ctx.streamOutput) {
        try {
          final result = await ChatApiService.generateMessage(
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
            requestId: conversationId,
            allowImagesApiRouting: ctx.allowImagesApiRouting,
            ocrActive: ctx.ocrActive,
          );
          state.streamStartedAt ??= DateTime.now();
          await _markGenerationStreaming(state);
          state.partsHandler.handleResult(result);
          state.fullContentRaw = [
            for (final part in state.partsHandler.parts)
              if (part is TextPart) part.text,
          ].join();
          state.bufferedReasoning = [
            for (final part in state.partsHandler.parts)
              if (part is ReasoningPart && part.text.isNotEmpty) part.text,
          ].join();
          if (result.usage != null) _applyUsage(state, result.usage!);
          if (result.reasoningDetails != null) {
            streamController.setReasoningDetails(
              state.messageId,
              result.reasoningDetails,
            );
          }
          await _handleStreamFinish(state);
        } catch (e) {
          await _handleStreamError(e, state);
        }
        return;
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
        requestId: conversationId,
        allowImagesApiRouting: ctx.allowImagesApiRouting,
        ocrActive: ctx.ocrActive,
      );

      final sub = listenSequentiallyToStream<StreamChunk>(
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
    StreamChunk chunk,
    stream_ctrl.StreamingState state,
  ) async {
    await _markGenerationStreaming(state);
    state.partsHandler.handle(chunk);
    switch (chunk) {
      case TextDelta(:final text):
        await _handleContentChunk(state, text);
        _scheduleStreamingCheckpoint(state);
      case ReasoningDelta(:final text, :final details):
        if (details != null) {
          streamController.setReasoningDetails(state.messageId, details);
        }
        if (text.isNotEmpty && state.ctx.supportsReasoning) {
          await _handleReasoningChunk(text, state);
        }
        _scheduleStreamingCheckpoint(state);
      case ToolCallStart(:final id, :final toolName):
        if (toolName.isNotEmpty) state.pendingToolNames[id] = toolName;
        await _handleToolCallsChunk(chunk, state);
        _scheduleStreamingCheckpoint(state);
      case ToolCallDelta(:final id, :final toolNameDelta):
        if (toolNameDelta.isNotEmpty) {
          state.pendingToolNames[id] =
              '${state.pendingToolNames[id] ?? ''}$toolNameDelta';
        }
      case ToolCallEnd():
        await _handleToolCallsChunk(chunk, state);
        _scheduleStreamingCheckpoint(state);
      case ServerToolStart(:final id, :final toolName):
        if (toolName.isNotEmpty) state.pendingToolNames[id] = toolName;
        await _handleToolCallsChunk(chunk, state);
        _scheduleStreamingCheckpoint(state);
      case ServerToolEnd() || ToolCallResult() || Annotations():
        await _handleToolResultsChunk(chunk, state);
        _scheduleStreamingCheckpoint(state);
      case Usage(:final usage):
        _applyUsage(state, usage);
      case ProviderArtifact(:final kind, :final payload):
        await chatService.setProviderArtifact(state.messageId, kind, payload);
      case Finish():
        await _handleStreamFinish(state);
      case ImageStart() ||
          ImageDelta() ||
          ImageSnapshot() ||
          ImageEnd() ||
          GeneratedFile():
        _publishAssistantParts(state);
        _scheduleStreamingCheckpoint(state);
      case TextStart() ||
          TextEnd() ||
          ReasoningStart() ||
          ReasoningEnd() ||
          ServerToolInputDelta() ||
          ServerToolInputEnd():
        break;
    }
  }

  void _applyUsage(stream_ctrl.StreamingState state, TokenUsage usage) {
    state.usage = (state.usage ?? const TokenUsage()).merge(usage);
    state.totalTokens = state.usage!.totalTokens;
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
    String reasoning,
    stream_ctrl.StreamingState state,
  ) async {
    await streamController.handleReasoningChunk(reasoning, state);
    _publishAssistantParts(state);
  }

  /// Handle tool calls chunk from stream.
  Future<void> _handleToolCallsChunk(
    StreamChunk chunk,
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
    _publishAssistantParts(state);
  }

  /// Handle tool results chunk from stream.
  Future<void> _handleToolResultsChunk(
    StreamChunk chunk,
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
    _publishAssistantParts(state);
  }

  void _publishAssistantParts(stream_ctrl.StreamingState state) {
    if (!state.ctx.streamOutput || state.finishHandled) return;
    streamController.streamingContentNotifier.getNotifier(state.messageId);
    streamController.streamingContentNotifier.updateContent(
      state.messageId,
      _transformAssistantContent(state),
      state.totalTokens,
      parts: _assistantPartsForState(state),
    );
  }

  /// Handle content chunk from stream (non-done).
  Future<void> _handleContentChunk(
    stream_ctrl.StreamingState state,
    String chunkContent,
  ) async {
    // Fast bail-out: if _finishStreaming already ran, don't touch state at all.
    if (state.finishHandled) return;

    final messageId = state.messageId;
    final conversationId = state.conversationId;

    _recordContent(state, chunkContent);
    state.streamStartedAt ??= DateTime.now();

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
        () => _transformAssistantContent(state),
        partsBuilder: (visibleText) =>
            _assistantPartsForState(state, visibleText: visibleText),
        totalTokens: state.totalTokens,
        promptTokens: state.usage?.promptTokens,
        completionTokens: state.usage?.completionTokens,
        cachedTokens: state.usage?.cachedTokens,
        durationMs: _elapsedMsFrom(state.streamStartedAt),
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
  Future<void> _handleStreamFinish(stream_ctrl.StreamingState state) async {
    final messageId = state.messageId;
    final conversationId = state.conversationId;
    final autoCollapseThinking =
        (!state.ctx.streamOutput && state.bufferedReasoning.isNotEmpty)
        ? contextProvider.read<SettingsProvider>().autoCollapseThinking
        : null;

    // Don't finish if tools are still loading
    final hasLoadingTool =
        (streamController.toolParts[messageId]?.any((p) => p.loading) ?? false);
    if (hasLoadingTool) {
      return;
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
      onStreamFinished?.call(conversationId);
    }

    // This finish handler runs inside the sequential drain, so awaiting the
    // barrier cancel here would wait on this very drain and never complete.
    // The source stream is finishing on its own (a done chunk arrived);
    // onDone performs the remaining cleanup, so only drop the map entry.
    _conversationStreams.remove(conversationId);
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

    // Let the smoothing buffer catch up first: cleanupTimers publishes the
    // whole remaining backlog at once, which a bottom-pinned timeline shows as
    // a single large jump just before the reply ends.
    await streamController.drainSmoothStream(messageId);

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
    final finalDurationMs = _elapsedMsFrom(state.streamStartedAt);
    final finalPromptTokens = state.usage?.promptTokens;
    final finalCompletionTokens = state.usage?.completionTokens;
    final finalCachedTokens = state.usage?.cachedTokens;

    // Flush final content to the streaming notifier before async operations.
    // This ensures any intermediate rebuild (e.g., from isProcessingFiles change
    // or onDone firing concurrently) still shows the correct content via the
    // notifier-based streaming path.
    final assistantParts = await _sanitizeAssistantImageParts(
      _assistantPartsForState(state),
    );
    streamController.streamingContentNotifier.updateContent(
      messageId,
      processedContent,
      state.totalTokens,
      parts: assistantParts,
      promptTokens: finalPromptTokens,
      completionTokens: finalCompletionTokens,
      cachedTokens: finalCachedTokens,
      durationMs: finalDurationMs,
    );

    final finalizedMessage = _streamingMessageSnapshot(state).copyWith(
      parts: assistantParts,
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
      state.terminalPersisted = true;

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
      if (chatController.publishTerminalMessage(finalizedMessage)) {
        onMessagesChanged?.call();
      }
      streamController.removeStreamingNotifier(messageId);
      _setConversationLoading(conversationId, false);
      // Terminal widgets are usually taller than the streaming ones; pin
      // once more after isGenerating becomes false so layout-phase follow
      // does not miss that height change.
      onStreamFinished?.call(conversationId);
    }
  }

  /// Handle stream error.
  Future<void> _handleStreamError(
    dynamic e,
    stream_ctrl.StreamingState state,
  ) async {
    if (state.terminalPersisted) return;
    state.finishHandled = true;
    final messageId = state.messageId;
    final conversationId = state.conversationId;
    final errorText = e.toString();

    // Reset file processing state on error, scoped to this message so a
    // background conversation's indicator survives.
    onFileProcessingFinished?.call(messageId);

    // Mark streaming as ended to allow UI rebuilds again
    streamController.markStreamingEnded(messageId);

    streamController.cleanupTimers(messageId);
    streamController.finishReasoningIfNeeded(messageId);
    final partialContent = state.fullContentRaw.isEmpty
        ? ''
        : _transformAssistantContent(state, state.fullContentRaw);
    final errorParts = await _sanitizeAssistantImageParts(
      assistantPartsForStreamError(
        parts: _assistantPartsForState(state),
        partialContent: partialContent,
        errorText: errorText,
      ),
    );
    final errorMessage = _streamingMessageSnapshot(state).copyWith(
      parts: errorParts,
      totalTokens: state.totalTokens,
      isStreaming: false,
    );
    try {
      await _finalizeStreamingCheckpoint(
        errorMessage,
        terminalState: GenerationRunState.failed,
        errorCode: 'generation_failed',
      );
      state.terminalPersisted = true;
    } finally {
      _clearGenerationRuntimeState(errorMessage);
      if (chatController.publishTerminalMessage(errorMessage)) {
        onMessagesChanged?.call();
      }
      streamController.removeStreamingNotifier(messageId);
      _setConversationLoading(conversationId, false);
      // The sequential stream drain owns source cancellation after this error
      // handler returns. Re-entering its barrier cancel here would wait on this
      // handler itself and prevent the UI error callback below from firing.
      _conversationStreams.remove(conversationId);
      onStreamError?.call(errorText);
      onStreamFinished?.call(conversationId);
      await _finishIosBackgroundGeneration(success: false, detail: errorText);
    }
  }

  /// Handle stream done callback.
  Future<void> _handleStreamDone(stream_ctrl.StreamingState state) async {
    final conversationId = state.conversationId;
    final messageId = state.messageId;

    // Reset file processing state on done (just in case), scoped to this
    // message so a background conversation's indicator survives.
    onFileProcessingFinished?.call(messageId);

    // Ensure streaming is marked as ended
    streamController.markStreamingEnded(messageId);

    // Same reason as in _finishStreaming: drain the smoothing buffer through
    // its own tick instead of dumping it into one frame.
    await streamController.drainSmoothStream(messageId);

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
    onStreamFinished?.call(conversationId);
    // The source stream is already done and this handler runs inside the
    // sequential drain; awaiting the barrier cancel here would wait on this
    // very drain and never complete, so only drop the map entry.
    _conversationStreams.remove(conversationId);
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

    // Prefer the full accumulated stream text over the typewriter prefix that
    // may still be sitting on the in-memory message widget.
    final latestContent =
        streamController.getPendingStreamContent(streaming.id) ??
        streaming.content;
    // Also capture reasoning progress if tracked in-memory
    final r = streamController.reasoning[streaming.id];
    final segs = streamController.reasoningSegments[streaming.id];

    final details = streamController.reasoningDetails[streaming.id];
    final reasoningSegmentsJson = segs != null || details != null
        ? streamController.serializeReasoningSegmentsWithSplits(
            segs ?? const [],
            reasoningDetails: details,
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
      writer.add(() => _createStreamingCheckpoint(snapshot));
      await writer.barrier();
    }
    // Ensure any inline data URLs get converted even if the user navigates away mid-stream
    onScheduleImageSanitize?.call(streaming.id, latestContent, immediate: true);
  }

  void _recordContent(stream_ctrl.StreamingState state, String chunkContent) {
    if (chunkContent.isNotEmpty) {
      state.fullContentRaw += chunkContent;
    }
  }
}
