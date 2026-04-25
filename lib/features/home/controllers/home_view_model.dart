import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/logging/flutter_logger.dart';
import '../../chat/widgets/chat_message_widget.dart' show ToolUIPart;
import '../services/message_builder_service.dart';
import '../services/message_generation_service.dart';
import 'chat_actions.dart';
import 'chat_controller.dart';
import 'generation_controller.dart';
import 'stream_controller.dart' as stream_ctrl;

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
    required ChatService chatService,
    required MessageBuilderService messageBuilderService,
    required MessageGenerationService messageGenerationService,
    required GenerationController generationController,
    required stream_ctrl.StreamController streamController,
    required ChatController chatController,
    required BuildContext contextProvider,
    required this.getTitleForLocale,
  }) : _chatService = chatService,
       _messageBuilderService = messageBuilderService,
       _messageGenerationService = messageGenerationService,
       _generationController = generationController,
       _streamController = streamController,
       _chatController = chatController,
       _contextProvider = contextProvider {
    // Initialize ChatActions
    _chatActions = ChatActions(
      chatService: chatService,
      chatController: chatController,
      streamController: streamController,
      generationController: generationController,
      messageGenerationService: messageGenerationService,
      contextProvider: contextProvider,
      viewModel: this,
    );

    // Wire up callbacks
    _chatActions.onMessagesChanged = _onMessagesChanged;
    _chatActions.onLoadingChanged = _onLoadingChanged;
    _chatActions.onContentUpdated = _onContentUpdated;
    _chatActions.onStreamError = _onStreamError;
    _chatActions.onMaybeGenerateTitle = _onMaybeGenerateTitle;
    _chatActions.onMaybeGenerateSummary = _onMaybeGenerateSummary;
    _chatActions.onStreamFinished = _onStreamFinished;
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
  late final ChatActions _chatActions;
  QueuedChatInput? _queuedInput;
  bool _isDrainingQueuedInput = false;

  /// Function to get localized title
  final String Function(BuildContext context) getTitleForLocale;

  // ============================================================================
  // Callbacks for UI (set by HomePage)
  // ============================================================================

  /// Called when an error occurs (UI should show snackbar).
  void Function(String error)? onError;

  /// Called when a warning occurs (UI should show snackbar).
  void Function(String warning)? onWarning;

  /// Called when streaming finishes (UI may show notification).
  VoidCallback? onStreamFinished;

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
  Set<String> get loadingConversationIds =>
      _chatController.loadingConversationIds;
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

  /// Whether the current conversation is actively generating.
  bool get isCurrentConversationLoading =>
      _chatController.isCurrentConversationLoading;

  QueuedChatInput? get currentQueuedInput {
    final cid = currentConversation?.id;
    final queued = _queuedInput;
    if (cid == null || queued == null || queued.conversationId != cid) {
      return null;
    }
    return queued;
  }

  final ValueNotifier<bool> isProcessingFiles = ValueNotifier<bool>(false);

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
      messages[index] = messages[index].copyWith(
        content: content,
        totalTokens: totalTokens,
      );
      _chatController.invalidateCache();
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
    // Trigger title generation asynchronously
    _maybeGenerateTitleFor(conversationId);
  }

  void _onMaybeGenerateSummary(String conversationId) {
    // Trigger summary generation asynchronously
    _maybeGenerateSummaryFor(conversationId);
  }

  void _onStreamFinished() {
    onStreamFinished?.call();
  }

  void _onFileProcessingStarted() {
    isProcessingFiles.value = true;
  }

  void _onFileProcessingFinished() {
    isProcessingFiles.value = false;
  }

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

    if (input.documents.isNotEmpty) {
      isProcessingFiles.value = true;
    }

    onHapticFeedback?.call();
    onScrollToBottom?.call();

    final result = await _chatActions.sendMessage(
      input: input,
      conversation: conversation,
    );

    if (!result.success) {
      if (result.errorMessage == 'no_model') {
        onWarning?.call('no_model');
      } else if (result.errorMessage != 'empty_input') {
        onError?.call(result.errorMessage ?? 'unknown_error');
      }
      return false;
    }

    onScrollToBottom?.call();
    return true;
  }

  ChatInputData _cloneInput(ChatInputData input) {
    return ChatInputData(
      text: input.text,
      imagePaths: List<String>.of(input.imagePaths),
      documents: List<DocumentAttachment>.of(input.documents),
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
  }) async {
    final conversation = currentConversation;
    if (conversation == null) {
      return false;
    }

    // Set up image sanitization callback before regenerating
    _chatActions.onScheduleImageSanitize = onScheduleImageSanitize;

    onHapticFeedback?.call();

    final result = await _chatActions.regenerateAtMessage(
      message: message,
      conversation: conversation,
      assistantAsNewReply: assistantAsNewReply,
    );

    if (!result.success) {
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

    final remainingCount = sorted
        .where((message) => !deletedMessageIds.contains(message.id))
        .length;
    if (remainingCount <= 0) return null;

    int newSelection = oldSelection ?? (sorted.length - 1);
    final deletedIndices = <int>[];
    for (int i = 0; i < sorted.length; i++) {
      if (deletedMessageIds.contains(sorted[i].id)) {
        deletedIndices.add(i);
      }
    }

    for (final deletedIndex in deletedIndices) {
      if (deletedIndex < newSelection) {
        newSelection -= 1;
      } else if (deletedIndex == newSelection) {
        newSelection = newSelection > 0 ? newSelection - 1 : 0;
      }
    }

    if (newSelection < 0) return 0;
    if (newSelection > remainingCount - 1) return remainingCount - 1;
    return newSelection;
  }

  Future<void> _deleteMessageVersions({
    required String gid,
    required List<ChatMessage> versionsBefore,
    required Set<String> deletedMessageIds,
  }) async {
    if (deletedMessageIds.isEmpty) return;

    final oldSel =
        versionSelections[gid] ??
        (versionsBefore.isNotEmpty ? versionsBefore.length - 1 : 0);
    final newSel = computeNextVersionSelection(
      versionsBefore: versionsBefore,
      deletedMessageIds: deletedMessageIds,
      oldSelection: oldSel,
    );

    // Clean up message UI state
    for (final id in deletedMessageIds) {
      _streamController.clearMessageState(id);
    }

    // Adjust selected version index for this group
    if (newSel == null) {
      _chatController.versionSelections.remove(gid);
    } else {
      _chatController.versionSelections[gid] = newSel;
    }

    if (currentConversation != null) {
      try {
        if (newSel == null) {
          await _chatService.clearSelectedVersion(currentConversation!.id, gid);
        } else {
          await _chatService.setSelectedVersion(
            currentConversation!.id,
            gid,
            newSel,
          );
        }
      } catch (_) {}
    }

    final messagesToDelete = versionsBefore
        .where((message) => deletedMessageIds.contains(message.id))
        .toList();
    for (final message in messagesToDelete) {
      await _chatService.deleteMessage(message.id);
    }

    // Reload messages
    _chatController.reloadMessages();
    notifyListeners();
  }

  // ============================================================================
  // Public Methods - Conversation Management
  // ============================================================================

  /// Switch to an existing conversation.
  Future<void> switchConversation(String id) async {
    final assistantProvider = _contextProvider.read<AssistantProvider>();
    final settings = _contextProvider.read<SettingsProvider>();

    // Flush current conversation progress before switching
    await _chatActions.flushConversationProgress(currentConversation);

    // Reset processing state on switch
    isProcessingFiles.value = false;

    if (currentConversation?.id == id) return;

    _chatService.setCurrentConversation(id);
    final convo = _chatService.getConversation(id);
    if (convo != null) {
      final convoAssistantId = convo.assistantId;
      if (convoAssistantId != null &&
          assistantProvider.currentAssistantId != convoAssistantId &&
          assistantProvider.getById(convoAssistantId) != null) {
        await assistantProvider.setCurrentAssistant(convoAssistantId);
      }
      // Restore conversation's model override if set (for UI display consistency)
      if (convo.modelProvider != null && convo.modelId != null) {
        await settings.setCurrentModel(convo.modelProvider!, convo.modelId!);
      }
      _chatController.setCurrentConversation(convo);
      _streamController.clearGeminiThoughtSigs();
      notifyListeners();
      onConversationSwitched?.call();
      unawaited(_drainQueuedInputIfReady(id));
    }
  }

  /// Create a new conversation.
  Future<void> createNewConversation() async {
    // Flush current conversation progress before creating new
    await _chatActions.flushConversationProgress(currentConversation);
    if (!_contextProvider.mounted) return;

    // Reset processing state on create
    isProcessingFiles.value = false;

    final ap = _contextProvider.read<AssistantProvider>();
    final settings = _contextProvider.read<SettingsProvider>();
    final assistantId = ap.currentAssistantId;
    final a = ap.currentAssistant;

    // Capture current model for new conversation
    final currentModelProvider = settings.currentModelProvider;
    final currentModelId = settings.currentModelId;

    final conversation = await _chatService.createDraftConversation(
      title: getTitleForLocale(_contextProvider),
      assistantId: assistantId,
      modelProvider: currentModelProvider,
      modelId: currentModelId,
    );

    _chatController.setCurrentConversation(conversation);
    _streamController.clearAllState();
    notifyListeners();

    // Inject assistant preset messages into new conversation (ordered)
    try {
      final presets = ap.getPresetMessagesForAssistant(a?.id);
      if (presets.isNotEmpty && currentConversation != null) {
        for (final pm in presets) {
          final role = (pm['role'] == 'assistant') ? 'assistant' : 'user';
          final content = (pm['content'] ?? '').trim();
          if (content.isEmpty) continue;
          await _chatService.addMessage(
            conversationId: currentConversation!.id,
            role: role,
            content: content,
          );
          _chatController.reloadMessages();
          notifyListeners();
        }
      }
    } catch (_) {}

    onScrollToBottom?.call();
  }

  /// Fork conversation at a specific message.
  Future<void> forkConversation(ChatMessage message) async {
    // Determine included groups up to the message's group (inclusive)
    final Map<String, int> groupFirstIndex = <String, int>{};
    final List<String> groupOrder = <String>[];
    for (int i = 0; i < messages.length; i++) {
      final gid0 = (messages[i].groupId ?? messages[i].id);
      if (!groupFirstIndex.containsKey(gid0)) {
        groupFirstIndex[gid0] = i;
        groupOrder.add(gid0);
      }
    }
    final targetGroup = (message.groupId ?? message.id);
    final targetOrderIndex = groupOrder.indexOf(targetGroup);
    if (targetOrderIndex < 0) return;

    final includeGroups = groupOrder.take(targetOrderIndex + 1).toSet();
    final selected = [
      for (final m in messages)
        if (includeGroups.contains(m.groupId ?? m.id)) m,
    ];
    // Filter version selections to included groups
    final sel = <String, int>{};
    for (final gid in includeGroups) {
      final v = versionSelections[gid];
      if (v != null) sel[gid] = v;
    }
    final newConvo = await _chatService.forkConversation(
      title: getTitleForLocale(_contextProvider),
      assistantId: currentConversation?.assistantId,
      sourceMessages: selected,
      versionSelections: sel,
      modelProvider: currentConversation?.modelProvider,
      modelId: currentConversation?.modelId,
    );

    // Switch to the new conversation
    _chatService.setCurrentConversation(newConvo.id);
    _chatController.setCurrentConversation(newConvo);
    _restoreMessageUiState();
    notifyListeners();
    onConversationSwitched?.call();
    onScrollToBottom?.call();
  }

  /// Clear context (toggle truncate at tail).
  Future<void> clearContext() async {
    final convo = currentConversation;
    if (convo == null) return;

    final updated = await _chatService.toggleTruncateAtTail(
      convo.id,
      defaultTitle: getTitleForLocale(_contextProvider),
    );
    if (updated != null) {
      _chatController.updateCurrentConversation(updated);
      notifyListeners();
    }
  }

  /// Compress context: summarize messages via LLM, create new conversation with summary.
  /// Returns null on success, or an error key string on failure.
  Future<String?> compressContext() async {
    final convo = currentConversation;
    if (convo == null) return 'no_conversation';

    // Get messages and collapse to selected versions
    final allMsgs = _chatController.messages;
    final collapsed = collapseVersions(allMsgs);
    if (collapsed.isEmpty) return 'no_messages';

    // Build conversation text for compression
    final joined = collapsed
        .where((m) => m.content.trim().isNotEmpty)
        .map(
          (m) =>
              '${m.role == "assistant" ? "Assistant" : "User"}: ${m.content}',
        )
        .join('\n\n');
    if (joined.trim().isEmpty) return 'no_messages';

    // Truncate to reasonable length
    final content = joined.length > 6000 ? joined.substring(0, 6000) : joined;
    final locale = Localizations.localeOf(_contextProvider).toLanguageTag();

    // Resolve model: compress model → summary model → title model → assistant model → global default
    final settings = _contextProvider.read<SettingsProvider>();
    final ap = _contextProvider.read<AssistantProvider>();
    final assistant = convo.assistantId != null
        ? ap.getById(convo.assistantId!)
        : ap.currentAssistant;

    final provKey =
        settings.compressModelProvider ??
        settings.summaryModelProvider ??
        settings.titleModelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final mdlId =
        settings.compressModelId ??
        settings.summaryModelId ??
        settings.titleModelId ??
        assistant?.chatModelId ??
        settings.currentModelId;
    if (provKey == null || mdlId == null) return 'no_model';

    final cfg = settings.getProviderConfig(provKey);

    // Build compression prompt from settings template
    final prompt = settings.compressPrompt
        .replaceAll('{content}', content)
        .replaceAll('{locale}', locale);

    try {
      final summary = (await ChatApiService.generateText(
        config: cfg,
        modelId: mdlId,
        prompt: prompt,
      )).trim();

      if (summary.isEmpty) return 'empty_summary';

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
      _chatController.setCurrentConversation(
        _chatService.getConversation(newConvo.id) ?? newConvo,
      );
      _streamController.clearAllState();
      notifyListeners();
      onConversationSwitched?.call();
      onScrollToBottom?.call();

      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  /// Update current conversation reference.
  void updateCurrentConversation(Conversation? conversation) {
    _chatController.updateCurrentConversation(conversation);
    notifyListeners();
  }

  /// Reload messages from storage.
  void reloadMessages() {
    _chatController.reloadMessages();
    notifyListeners();
  }

  /// Set selected version for a message group.
  Future<void> setSelectedVersion(String groupId, int version) async {
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
          getGeminiThoughtSigFromDb: (id) =>
              _chatService.getGeminiThoughtSignature(id),
        );

        // Clean content from gemini thought signatures
        final cleanedContent = _streamController.captureGeminiThoughtSignature(
          m.content,
          m.id,
        );
        if (cleanedContent != m.content) {
          final updated = m.copyWith(content: cleanedContent);
          messages[i] = updated;
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
    final configured = (assistant?.limitContextMessages ?? true)
        ? (assistant?.contextMessageSize ?? 0)
        : 0;
    // Use collapsed view for counting
    final collapsed = collapseVersions(messages);
    // Map raw truncate index to collapsed start index
    final int tRaw = currentConversation?.truncateIndex ?? -1;
    int startCollapsed = 0;
    if (tRaw > 0) {
      final seen = <String>{};
      final int limit = tRaw < messages.length ? tRaw : messages.length;
      int count = 0;
      for (int i = 0; i < limit; i++) {
        final gid0 = (messages[i].groupId ?? messages[i].id);
        if (seen.add(gid0)) count++;
      }
      startCollapsed = count;
    }
    int remaining = 0;
    for (int i = 0; i < collapsed.length; i++) {
      if (i >= startCollapsed) {
        if (collapsed[i].content.trim().isNotEmpty) remaining++;
      }
    }
    if (configured > 0) {
      final actual = remaining > configured ? configured : remaining;
      return withCountFormatter(actual.toString(), configured.toString());
    }
    return defaultLabel;
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
    final assistantProvider = _contextProvider.read<AssistantProvider>();

    // Get assistant for this conversation
    final assistant = convo.assistantId != null
        ? assistantProvider.getById(convo.assistantId!)
        : assistantProvider.currentAssistant;

    // Decide model: prefer title model, else fall back to assistant's model, then to global default
    final provKey =
        settings.titleModelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final mdlId =
        settings.titleModelId ??
        assistant?.chatModelId ??
        settings.currentModelId;
    if (provKey == null || mdlId == null) return;
    final cfg = settings.getProviderConfig(provKey);
    final budget = assistant?.thinkingBudget ?? settings.thinkingBudget;

    // Build content from messages (truncate to reasonable length)
    final msgs = _chatService.getMessages(convo.id);
    final tIndex = convo.truncateIndex;
    final List<ChatMessage> sourceAll = (tIndex >= 0 && tIndex <= msgs.length)
        ? msgs.sublist(tIndex)
        : msgs;
    final List<ChatMessage> source = collapseVersions(sourceAll);
    final joined = source
        .where((m) => m.content.isNotEmpty)
        .map(
          (m) =>
              '${m.role == 'assistant' ? 'Assistant' : 'User'}: ${m.content}',
        )
        .join('\n\n');
    final content = joined.length > 3000 ? joined.substring(0, 3000) : joined;
    final locale = Localizations.localeOf(_contextProvider).toLanguageTag();

    String prompt = settings.titlePrompt
        .replaceAll('{locale}', locale)
        .replaceAll('{content}', content);

    try {
      final title = (await ChatApiService.generateText(
        config: cfg,
        modelId: mdlId,
        prompt: prompt,
        thinkingBudget: budget,
      )).trim();
      if (title.isNotEmpty) {
        await _chatService.renameConversation(convo.id, title);
        if (currentConversation?.id == convo.id) {
          _chatController.updateCurrentConversation(
            _chatService.getConversation(convo.id),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      FlutterLogger.log(
        '[TitleGen] Generation failed: $e',
        tag: 'HomeViewModel',
      );
      // Ignore title generation failure silently
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

    final settings = _contextProvider.read<SettingsProvider>();
    final msgCount = convo.messageIds.length;
    final assistantProvider = _contextProvider.read<AssistantProvider>();

    // Get assistant for this conversation
    final assistant = convo.assistantId != null
        ? assistantProvider.getById(convo.assistantId!)
        : assistantProvider.currentAssistant;

    final budget = assistant?.thinkingBudget ?? settings.thinkingBudget;

    // Only generate summary if assistant has recent chats reference enabled
    if (assistant?.enableRecentChatsReference != true) return;

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
    final msgs = _chatService.getMessages(convo.id);
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

    try {
      final summary = (await ChatApiService.generateText(
        config: cfg,
        modelId: mdlId,
        prompt: prompt,
        thinkingBudget: budget,
      )).trim();

      if (summary.isNotEmpty) {
        await _chatService.updateConversationSummary(
          convo.id,
          summary,
          msgCount,
        );
        if (currentConversation?.id == convo.id) {
          _chatController.updateCurrentConversation(
            _chatService.getConversation(convo.id),
          );
          notifyListeners();
        }
      }
    } catch (_) {
      // Keep old summary on failure, ignore silently
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
