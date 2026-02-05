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

  /// Transform raw content using assistant regexes.
  String _transformAssistantContent(stream_ctrl.StreamingState state,
      [String? raw]) {
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
    final assistant = contextProvider.read<AssistantProvider>().currentAssistant;
    final assistantId = assistant?.id;
    final modelConfig =
        messageGenerationService.getModelConfig(settings, assistant);

    if (modelConfig.providerKey == null || modelConfig.modelId == null) {
      return ChatActionResult.noModel();
    }
    final providerKey = modelConfig.providerKey!;
    final modelId = modelConfig.modelId!;

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
    final assistantMessage =
        await messageGenerationService.createAssistantPlaceholder(
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
    final enableReasoning = supportsReasoning &&
        _isReasoningEnabled(assistant?.thinkingBudget ?? settings.thinkingBudget);
    await messageGenerationService.initializeReasoningState(
        messageId: assistantMessage.id, enableReasoning: enableReasoning);

    // Prepare API messages
    messageGenerationService.onFileProcessingStarted = onFileProcessingStarted;
    messageGenerationService.onFileProcessingFinished = onFileProcessingFinished;
    try {
      final prepared =
          await messageGenerationService.prepareApiMessagesWithInjections(
        messages: _messages,
        versionSelections: _versionSelections,
        currentConversation: conversation,
        settings: settings,
        assistant: assistant,
        assistantId: assistantId,
        providerKey: providerKey,
        modelId: modelId,
      );

      // Build user image paths
      final userImagePaths = messageGenerationService.buildUserImagePaths(
        input: input,
        lastUserImagePaths: prepared.lastUserImagePaths,
        settings: settings,
      );

      // Execute generation
      final ctx = messageGenerationService.buildGenerationContext(
        assistantMessage: assistantMessage,
        prepared: prepared,
        userImagePaths: userImagePaths,
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
  /// - Removing trailing messages from the list
  /// - Adding new assistant placeholder
  /// - Showing snackbars on errors
  /// - Haptic feedback
  Future<ChatActionResult> regenerateAtMessage({
    required ChatMessage message,
    required Conversation conversation,
    bool assistantAsNewReply = false,
  }) async {
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

    // Remove trailing messages - returns list of removed IDs for UI cleanup
    final removeIds = await messageGenerationService.removeTrailingMessages(
      messages: _messages,
      lastKeep: versioning.lastKeep,
      targetGroupId: versioning.targetGroupId,
    );
    if (removeIds.isNotEmpty) {
      _messages.removeWhere((m) => removeIds.contains(m.id));
      onMessagesChanged?.call();
    }

    // Get model config
    final settings = contextProvider.read<SettingsProvider>();
    final assistant = contextProvider.read<AssistantProvider>().currentAssistant;
    final assistantId = assistant?.id;
    final modelConfig =
        messageGenerationService.getModelConfig(settings, assistant);

    if (modelConfig.providerKey == null || modelConfig.modelId == null) {
      return ChatActionResult.noModel();
    }
    final providerKey = modelConfig.providerKey!;
    final modelId = modelConfig.modelId!;

    // Create assistant message placeholder (new version)
    final assistantMessage =
        await messageGenerationService.createAssistantPlaceholder(
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
        conversation.id, gid, assistantMessage.version);

    _messages.add(assistantMessage);
    onMessagesChanged?.call();

    _setConversationLoading(conversation.id, true);

    // Initialize reasoning
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning = supportsReasoning &&
        _isReasoningEnabled(assistant?.thinkingBudget ?? settings.thinkingBudget);
    await messageGenerationService.initializeReasoningState(
        messageId: assistantMessage.id, enableReasoning: enableReasoning);

    // Prepare API messages
    final prepared =
        await messageGenerationService.prepareApiMessagesWithInjections(
      messages: _messages,
      versionSelections: _versionSelections,
      currentConversation: conversation,
      settings: settings,
      assistant: assistant,
      assistantId: assistantId,
      providerKey: providerKey,
      modelId: modelId,
    );

    // Build user image paths
    final userImagePaths = messageGenerationService.buildUserImagePaths(
      input: null,
      lastUserImagePaths: prepared.lastUserImagePaths,
      settings: settings,
    );

    // Execute generation
    final ctx = messageGenerationService.buildGenerationContext(
      assistantMessage: assistantMessage,
      prepared: prepared,
      userImagePaths: userImagePaths,
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
        updateReasoningInDb: (
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
      onScheduleImageSanitize?.call(streaming.id, streaming.content,
          immediate: true);
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
        thinkingBudget: assistant?.thinkingBudget ?? ctx.settings.thinkingBudget,
        temperature: assistant?.temperature,
        topP: assistant?.topP,
        maxTokens: assistant?.maxTokens,
        tools: ctx.toolDefs.isEmpty ? null : ctx.toolDefs,
        onToolCall: ctx.onToolCall,
        extraHeaders: ctx.extraHeaders,
        extraBody: ctx.extraBody,
        stream: ctx.streamOutput,
        requestId: conversationId,
      );

      await _conversationStreams[conversationId]?.cancel();
      final sub = stream.listen(
        (chunk) => _handleStreamChunk(chunk, state),
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
      ChatStreamChunk chunk, stream_ctrl.StreamingState state) async {
    final chunkContent = chunk.content.isNotEmpty
        ? streamController.captureGeminiThoughtSignature(
            chunk.content, state.messageId)
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
      ChatStreamChunk chunk, stream_ctrl.StreamingState state) async {
    await streamController.handleReasoningChunk(
      chunk,
      state,
      updateReasoningInDb: (
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
      ChatStreamChunk chunk, stream_ctrl.StreamingState state) async {
    await streamController.handleToolCallsChunk(
      chunk,
      state,
      updateReasoningSegmentsInDb: (String messageId, String json) async {
        // Use silent update during streaming to avoid UI rebuilds
        await chatService.updateMessageSilent(messageId, reasoningSegmentsJson: json);
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
      ChatStreamChunk chunk, stream_ctrl.StreamingState state) async {
    await streamController.handleToolResultsChunk(
      chunk,
      state,
      upsertToolEventInDb: (
        String messageId, {
        required String id,
        required String name,
        required Map<String, dynamic> arguments,
        String? content,
      }) async {
        await chatService.upsertToolEvent(
          messageId,
          id: id,
          name: name,
          arguments: arguments,
          content: content,
        );
      },
    );
  }

  /// Handle content chunk from stream (non-done).
  Future<void> _handleContentChunk(ChatStreamChunk chunk,
      stream_ctrl.StreamingState state, String chunkContent) async {
    final messageId = state.messageId;
    final conversationId = state.conversationId;

    state.fullContentRaw += chunkContent;
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
        final sanitized = await MarkdownMediaSanitizer.replaceInlineBase64Images(
            streamingProcessed);
        if (sanitized != streamingProcessed) {
          streamingProcessed = sanitized;
          state.fullContentRaw = sanitized;
        }
      } catch (e) {
        // ignore
      }
    }
    onScheduleImageSanitize?.call(messageId, streamingProcessed,
        immediate: true);
    // Use silent update to avoid triggering ChatService.notifyListeners()
    // which would cause side_drawer and other widgets to rebuild
    await chatService.updateMessageSilent(
      messageId,
      content: streamingProcessed,
      totalTokens: state.totalTokens,
    );

    if (state.ctx.streamOutput &&
        _currentConversation?.id == conversationId) {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: streamingProcessed,
          totalTokens: state.totalTokens,
        );
        // NOTE: Do NOT call onMessagesChanged here!
        // Streaming content updates are handled by StreamingContentNotifier
        // via ValueListenableBuilder, which only rebuilds the streaming message widget.
        // Calling onMessagesChanged would trigger a full page rebuild and cause lag.
      }
    }

    // End reasoning when content starts
    if (state.ctx.streamOutput && chunkContent.isNotEmpty) {
      await _finishReasoningOnContent(state);
    }

    // Schedule throttled UI update via StreamController
    if (state.ctx.streamOutput) {
      streamController.scheduleThrottledUpdate(
        messageId,
        conversationId,
        streamingProcessed,
        totalTokens: state.totalTokens,
        updateMessageInList: (id, content, tokens) {
          onContentUpdated?.call(id, content, tokens);
        },
      );
    }
  }

  /// Finish reasoning segment when content starts arriving.
  Future<void> _finishReasoningOnContent(
      stream_ctrl.StreamingState state) async {
    await streamController.finishReasoningAndPersist(
      state.messageId,
      updateReasoningInDb: (
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
  Future<void> _handleStreamFinish(ChatStreamChunk chunk,
      stream_ctrl.StreamingState state, String chunkContent) async {
    final messageId = state.messageId;
    final conversationId = state.conversationId;

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

    await _finishStreaming(state);

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
      final autoCollapse =
          contextProvider.read<SettingsProvider>().autoCollapseThinking;
      streamController.reasoning[messageId] = stream_ctrl.ReasoningData()
        ..text = state.bufferedReasoning
        ..startAt = startAt
        ..finishedAt = now
        ..expanded = !autoCollapse;
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
  Future<void> _finishStreaming(stream_ctrl.StreamingState state,
      {bool generateTitle = true}) async {
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
    final sanitizedContent =
        await MarkdownMediaSanitizer.replaceInlineBase64Images(processedContent);
    await chatService.updateMessage(
      messageId,
      content: sanitizedContent,
      totalTokens: state.totalTokens,
      isStreaming: false,
    );

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(
        content: sanitizedContent,
        totalTokens: state.totalTokens,
        isStreaming: false,
      );
      onMessagesChanged?.call();
    }
    _setConversationLoading(conversationId, false);

    // Use unified reasoning completion method
    await streamController.finishReasoningAndPersist(
      messageId,
      updateReasoningInDb: (
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
      dynamic e, stream_ctrl.StreamingState state) async {
    final messageId = state.messageId;
    final conversationId = state.conversationId;
    final errorText = e.toString();
    
    // Reset file processing state on error
    onFileProcessingFinished?.call();

    // Mark streaming as ended to allow UI rebuilds again
    streamController.markStreamingEnded(messageId);

    streamController.cleanupTimers(messageId);
    final rawContent =
        state.fullContentRaw.isNotEmpty ? state.fullContentRaw : errorText;
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
    _setConversationLoading(conversationId, false);

    // Use unified reasoning completion method on error
    await streamController.finishReasoningAndPersist(
      messageId,
      updateReasoningInDb: (
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

    // Ensure streaming is marked as ended
    streamController.markStreamingEnded(state.messageId);

    streamController.cleanupTimers(state.messageId);
    if (_loadingConversationIds.contains(conversationId)) {
      await _finishStreaming(state,
          generateTitle: state.ctx.generateTitleOnFinish);
    }
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
          reasoningSegmentsJson: streamController.serializeReasoningSegments(segs),
        );
      }
      // Ensure any inline data URLs get converted even if the user navigates away mid-stream
      onScheduleImageSanitize?.call(streaming.id, latestContent,
          immediate: true);
    } catch (_) {}
  }
}
