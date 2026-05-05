import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../utils/assistant_regex.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import '../services/message_generation_service.dart';
import '../services/tool_approval_service.dart';
import 'chat_controller.dart';
import 'generation_controller.dart';
import 'home_view_model.dart';
import 'stream_controller.dart' as stream_ctrl;

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

  /// Called to schedule inline image sanitization.
  void Function(String messageId, String content, {bool immediate})?
  onScheduleImageSanitize;

  /// Called when streaming finishes.
  VoidCallback? onStreamFinished;

  /// Called when file processing starts.
  VoidCallback? onFileProcessingStarted;

  /// Called when file processing finishes.
  VoidCallback? onFileProcessingFinished;

  // ============================================================================
  // Private Helpers
  // ============================================================================

  /// Track in-flight _finishStreaming futures so _handleStreamDone can await
  /// completion before removing notifiers or triggering rebuild.
  final Map<String, Future<void>> _finishStreamingFutures =
      <String, Future<void>>{};

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

  bool _isReasoningModel(String providerKey, String modelId) {
    return generationController.isReasoningModel(providerKey, modelId);
  }

  bool _isReasoningEnabled(int? budget) {
    return messageGenerationService.isReasoningEnabled(budget);
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
          currentConversation: conversation,
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
    try {
      approvalService = contextProvider.read<ToolApprovalService>();
    } catch (_) {}
    final modelConfig = messageGenerationService.getModelConfig(
      settings,
      assistant,
      conversation,
    );

    if (modelConfig.providerKey == null || modelConfig.modelId == null) {
      return ChatActionResult.noModel();
    }
    final providerKey = modelConfig.providerKey!;
    final modelId = modelConfig.modelId!;

    if (_hasUnsupportedAudioAttachments(
      messages: _messages,
      conversation: conversation,
      settings: settings,
      providerKey: providerKey,
      modelId: modelId,
      pendingInput: input,
    )) {
      return ChatActionResult.error('audio_attachment_unsupported');
    }

    // Create user message
    final userMessage = await messageGenerationService.createUserMessage(
      conversationId: conversation.id,
      input: input,
      assistant: assistant,
    );
    _messages.add(userMessage);
    onMessagesChanged?.call();

    _setConversationLoading(conversation.id, true);

    // Create assistant message placeholder
    final assistantMessage = await messageGenerationService
        .createAssistantPlaceholder(
          conversationId: conversation.id,
          modelId: modelId,
          providerKey: providerKey,
        );

    // Pre-create streaming notifier BEFORE adding message to list
    // so that MessageListView can detect it's streaming on first render
    streamController.markStreamingStarted(assistantMessage.id);

    _messages.add(assistantMessage);
    onMessagesChanged?.call();

    // Reset tool parts and initialize reasoning
    streamController.toolParts.remove(assistantMessage.id);
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning =
        supportsReasoning &&
        _isReasoningEnabled(
          assistant?.thinkingBudget ?? settings.thinkingBudget,
        );
    await messageGenerationService.initializeReasoningState(
      messageId: assistantMessage.id,
      enableReasoning: enableReasoning,
    );

    // Prepare API messages
    messageGenerationService.onFileProcessingStarted = onFileProcessingStarted;
    messageGenerationService.onFileProcessingFinished =
        onFileProcessingFinished;
    try {
      final prepared = await messageGenerationService
          .prepareApiMessagesWithInjections(
            messages: _messages,
            versionSelections: _versionSelections,
            currentConversation: conversation,
            settings: settings,
            assistant: assistant,
            assistantId: assistantId,
            providerKey: providerKey,
            modelId: modelId,
            approvalService: approvalService,
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
      );

      await _executeGeneration(ctx);
      return ChatActionResult.success(assistantMessage);
    } catch (e) {
      // Ensure file processing indicator is cleared on error
      onFileProcessingFinished?.call();
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
    try {
      regenApprovalService = contextProvider.read<ToolApprovalService>();
    } catch (_) {}

    await cancelStreaming(conversation);

    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx < 0) {
      return ChatActionResult.error('message_not_found');
    }

    // Calculate versioning using service
    final versioning = messageGenerationService.calculateRegenerationVersioning(
      message: message,
      messages: _messages,
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
      conversation,
    );

    if (modelConfig.providerKey == null || modelConfig.modelId == null) {
      return ChatActionResult.noModel();
    }
    final providerKey = modelConfig.providerKey!;
    final modelId = modelConfig.modelId!;

    final projectedMessages = ChatActions.projectMessagesForRegenerationContext(
      messages: _messages,
      lastKeep: versioning.lastKeep,
      targetGroupId: versioning.targetGroupId,
    );
    if (_hasUnsupportedAudioAttachments(
      messages: projectedMessages,
      conversation: conversation,
      settings: settings,
      providerKey: providerKey,
      modelId: modelId,
    )) {
      return ChatActionResult.error('audio_attachment_unsupported');
    }

    if (settings.regenerateDeleteTrailingMessages) {
      final removeIds = await messageGenerationService.removeTrailingMessages(
        messages: _messages,
        lastKeep: versioning.lastKeep,
        targetGroupId: versioning.targetGroupId,
      );
      if (removeIds.isNotEmpty) {
        _messages.removeWhere((message) => removeIds.contains(message.id));
        onMessagesChanged?.call();
      }
    }

    // Create assistant message placeholder (new version)
    final assistantMessage = await messageGenerationService
        .createAssistantPlaceholder(
          conversationId: conversation.id,
          modelId: modelId,
          providerKey: providerKey,
          groupId: versioning.targetGroupId,
          version: versioning.nextVersion,
        );

    // Pre-create streaming notifier BEFORE adding message to list
    // so that MessageListView can detect it's streaming on first render
    streamController.markStreamingStarted(assistantMessage.id);

    // Persist version selection
    final gid = assistantMessage.groupId ?? assistantMessage.id;
    _versionSelections[gid] = assistantMessage.version;
    await chatService.setSelectedVersion(
      conversation.id,
      gid,
      assistantMessage.version,
    );

    final regenerationMessages = ChatActions.buildRegenerationMessages(
      messages: _messages,
      lastKeep: versioning.lastKeep,
      targetGroupId: versioning.targetGroupId,
      assistantPlaceholder: assistantMessage,
    );

    _messages.add(assistantMessage);
    onMessagesChanged?.call();

    _setConversationLoading(conversation.id, true);

    // Initialize reasoning
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning =
        supportsReasoning &&
        _isReasoningEnabled(
          assistant?.thinkingBudget ?? settings.thinkingBudget,
        );
    await messageGenerationService.initializeReasoningState(
      messageId: assistantMessage.id,
      enableReasoning: enableReasoning,
    );

    // Prepare API messages
    final prepared = await messageGenerationService
        .prepareApiMessagesWithInjections(
          messages: regenerationMessages,
          versionSelections: _versionSelections,
          currentConversation: conversation,
          settings: settings,
          assistant: assistant,
          assistantId: assistantId,
          providerKey: providerKey,
          modelId: modelId,
          approvalService: regenApprovalService,
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
    );

    await _executeGeneration(ctx);
    return ChatActionResult.success(assistantMessage);
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

    // Reset file processing state on cancel
    onFileProcessingFinished?.call();

    // Cancel active stream for current conversation only
    final sub = _conversationStreams.remove(cid);
    await sub?.cancel();
    ChatApiService.cancelRequest(cid);

    // Find the latest assistant streaming message within current conversation and mark it finished
    ChatMessage? streaming;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.isStreaming) {
        streaming = m;
        break;
      }
    }
    if (streaming != null) {
      // Mark streaming as ended to allow UI rebuilds again
      streamController.markStreamingEnded(streaming.id);

      await chatService.updateMessage(
        streaming.id,
        content: streaming.content,
        isStreaming: false,
        totalTokens: streaming.totalTokens,
      );

      final idx = _messages.indexWhere((m) => m.id == streaming!.id);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(isStreaming: false);
        onMessagesChanged?.call();
      }
      _setConversationLoading(cid, false);

      // Use unified reasoning completion method
      await streamController.finishReasoningAndPersist(
        streaming.id,
        updateReasoningInDb:
            (
              String messageId, {
              String? reasoningText,
              DateTime? reasoningFinishedAt,
              String? reasoningSegmentsJson,
            }) async {
              await chatService.updateMessage(
                messageId,
                reasoningText: reasoningText,
                reasoningFinishedAt: reasoningFinishedAt,
                reasoningSegmentsJson: reasoningSegmentsJson,
              );
            },
      );

      // If streaming output included inline base64 images, sanitize them even on manual cancel
      onScheduleImageSanitize?.call(
        streaming.id,
        streaming.content,
        immediate: true,
      );
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

    // Mark this message as actively streaming to suppress UI rebuilds
    streamController.markStreamingStarted(state.messageId);

    try {
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
      );

      await _conversationStreams[conversationId]?.cancel();
      // Use a StreamSubscription that processes chunks sequentially.
      // With the default listen() + async callback, Dart does NOT await the
      // returned Future, so multiple chunks interleave at await points. This
      // causes later-resuming handlers to overwrite final content with stale
      // partial snapshots. By pausing/resuming the subscription around each
      // async handler, we ensure serial processing.
      late final StreamSubscription<ChatStreamChunk> sub;
      sub = stream.listen(
        (chunk) {
          sub.pause();
          _handleStreamChunk(chunk, state).whenComplete(() => sub.resume());
        },
        onError: (e) => _handleStreamError(e, state),
        onDone: () => _handleStreamDone(state),
        cancelOnError: true,
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
            // Use silent update during streaming to avoid UI rebuilds
            await chatService.updateMessageSilent(
              messageId,
              reasoningText: reasoningText,
              reasoningStartAt: reasoningStartAt,
              reasoningSegmentsJson: reasoningSegmentsJson,
            );
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
        // Use silent update during streaming to avoid UI rebuilds
        await chatService.updateMessageSilent(
          messageId,
          reasoningSegmentsJson: json,
        );
      },
      setToolEventsInDb:
          (String messageId, List<Map<String, dynamic>> events) async {
            await chatService.setToolEvents(messageId, events);
          },
      getToolEventsFromDb: (String messageId) =>
          chatService.getToolEvents(messageId),
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
            await chatService.upsertToolEvent(
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
      await chatService.updateMessageSilent(
        messageId,
        reasoningSegmentsJson: streamController
            .serializeReasoningSegmentsWithSplits(
              streamController.getReasoningSegments(messageId) ?? const [],
              contentSplitOffsets: state.contentSplitOffsets,
              reasoningCountAtSplit: state.reasoningCountAtSplit,
              toolCountAtSplit: state.toolCountAtSplit,
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
    // Use silent update to avoid triggering ChatService.notifyListeners()
    // which would cause side_drawer and other widgets to rebuild
    await chatService.updateMessageSilent(
      messageId,
      content: streamingProcessed,
      totalTokens: state.totalTokens,
    );

    // Re-check after await: _finishStreaming may have completed during the
    // DB write above and already set the definitive content on _messages[index].
    if (state.finishHandled) return;

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
            // Use silent update during streaming to avoid UI rebuilds
            await chatService.updateMessageSilent(
              messageId,
              reasoningText: reasoningText,
              reasoningFinishedAt: reasoningFinishedAt,
              reasoningSegmentsJson: reasoningSegmentsJson,
            );
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

    // Track the _finishStreaming future so _handleStreamDone can await it
    // if it fires concurrently (stream.onDone can fire while we're still
    // awaiting async work inside _finishStreaming).
    final finishFuture = _finishStreaming(state);
    _finishStreamingFutures[messageId] = finishFuture;
    await finishFuture;
    _finishStreamingFutures.remove(messageId);

    // Notify for background notification if needed
    onStreamFinished?.call();

    // Handle buffered reasoning for non-streaming mode
    if (!state.ctx.streamOutput && state.bufferedReasoning.isNotEmpty) {
      final now = DateTime.now();
      final startAt = state.reasoningStartAt ?? now;
      await chatService.updateMessage(
        messageId,
        reasoningText: state.bufferedReasoning,
        reasoningStartAt: startAt,
        reasoningFinishedAt: now,
      );
      streamController.reasoning[messageId] = stream_ctrl.ReasoningData()
        ..text = state.bufferedReasoning
        ..startAt = startAt
        ..finishedAt = now
        ..expanded = !(autoCollapseThinking ?? false);
    }

    await _conversationStreams.remove(conversationId)?.cancel();

    // Ensure reasoning is finished
    final r = streamController.reasoning[messageId];
    if (r != null && r.finishedAt == null) {
      r.finishedAt = DateTime.now();
      await chatService.updateMessage(
        messageId,
        reasoningText: r.text,
        reasoningFinishedAt: r.finishedAt,
      );
    }
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
    await chatService.updateMessage(
      messageId,
      content: sanitizedContent,
      totalTokens: state.totalTokens,
      isStreaming: false,
      promptTokens: finalPromptTokens,
      completionTokens: finalCompletionTokens,
      cachedTokens: finalCachedTokens,
      durationMs: finalDurationMs,
    );

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        content: sanitizedContent,
        totalTokens: state.totalTokens,
        isStreaming: false,
        promptTokens: finalPromptTokens,
        completionTokens: finalCompletionTokens,
        cachedTokens: finalCachedTokens,
        durationMs: finalDurationMs,
      );
      onMessagesChanged?.call();
    }

    // Remove notifier AFTER onMessagesChanged so the UI rebuild sees final content
    streamController.removeStreamingNotifier(messageId);

    _setConversationLoading(conversationId, false);

    // Use unified reasoning completion method
    await streamController.finishReasoningAndPersist(
      messageId,
      updateReasoningInDb:
          (
            String messageId, {
            String? reasoningText,
            DateTime? reasoningFinishedAt,
            String? reasoningSegmentsJson,
          }) async {
            await chatService.updateMessage(
              messageId,
              reasoningText: reasoningText,
              reasoningFinishedAt: reasoningFinishedAt,
              reasoningSegmentsJson: reasoningSegmentsJson,
            );
          },
    );

    if (shouldGenerateTitle) {
      onMaybeGenerateTitle?.call(conversationId);
    }

    // Trigger summary generation check (actual logic in HomeViewModel)
    onMaybeGenerateSummary?.call(conversationId);
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
    final rawContent = state.fullContentRaw.isNotEmpty
        ? state.fullContentRaw
        : errorText;
    final processed = _transformAssistantContent(state, rawContent);
    // Let UI provide the localized error message
    final displayContent = processed.isNotEmpty ? processed : errorText;
    await chatService.updateMessage(
      messageId,
      content: displayContent,
      totalTokens: state.totalTokens,
      isStreaming: false,
    );

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        content: displayContent,
        isStreaming: false,
        totalTokens: state.totalTokens,
      );
      onMessagesChanged?.call();
    }

    // Remove notifier AFTER onMessagesChanged so the UI rebuild sees final content
    streamController.removeStreamingNotifier(messageId);

    _setConversationLoading(conversationId, false);

    // Use unified reasoning completion method on error
    await streamController.finishReasoningAndPersist(
      messageId,
      updateReasoningInDb:
          (
            String messageId, {
            String? reasoningText,
            DateTime? reasoningFinishedAt,
            String? reasoningSegmentsJson,
          }) async {
            await chatService.updateMessage(
              messageId,
              reasoningText: reasoningText,
              reasoningFinishedAt: reasoningFinishedAt,
              reasoningSegmentsJson: reasoningSegmentsJson,
            );
          },
    );

    await _conversationStreams.remove(conversationId)?.cancel();
    onStreamError?.call(errorText);
    onStreamFinished?.call();
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
    String latestContent = streaming.content;
    // Also capture reasoning progress if tracked in-memory
    final r = streamController.reasoning[streaming.id];
    final segs = streamController.reasoningSegments[streaming.id];

    try {
      await chatService.updateMessage(
        streaming.id,
        content: latestContent,
        totalTokens: streaming.totalTokens,
        // Do not flip isStreaming here; just flush progress
      );
      if (r != null) {
        await chatService.updateMessage(
          streaming.id,
          reasoningText: r.text,
          reasoningStartAt: r.startAt ?? DateTime.now(),
          // keep finishedAt as-is (may be null while thinking)
        );
      }
      if (segs != null && segs.isNotEmpty) {
        await chatService.updateMessage(
          streaming.id,
          reasoningSegmentsJson: streamController
              .serializeReasoningSegmentsWithSplits(
                segs,
                contentSplitOffsets: streamController
                    .getContentSplitData(streaming.id)
                    ?.offsets,
                reasoningCountAtSplit: streamController
                    .getContentSplitData(streaming.id)
                    ?.reasoningCounts,
                toolCountAtSplit: streamController
                    .getContentSplitData(streaming.id)
                    ?.toolCounts,
              ),
        );
      } else if (streamController.getContentSplitData(streaming.id) != null) {
        final splits = streamController.getContentSplitData(streaming.id)!;
        await chatService.updateMessage(
          streaming.id,
          reasoningSegmentsJson: streamController
              .serializeReasoningSegmentsWithSplits(
                const [],
                contentSplitOffsets: splits.offsets,
                reasoningCountAtSplit: splits.reasoningCounts,
                toolCountAtSplit: splits.toolCounts,
              ),
        );
      }
      // Ensure any inline data URLs get converted even if the user navigates away mid-stream
      onScheduleImageSanitize?.call(
        streaming.id,
        latestContent,
        immediate: true,
      );
    } catch (_) {}
  }
}
