import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../core/models/conversation.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/logging/context_logger.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/assistant_regex.dart';
import '../../../core/models/assistant_regex.dart';
import '../controllers/stream_controller.dart' as stream_ctrl;
import '../controllers/generation_controller.dart';
import 'ask_user_interaction_service.dart';
import 'message_builder_service.dart';
import 'tool_approval_service.dart';
import '../utils/model_display_helper.dart';

/// Callback types for UI updates from MessageGenerationService
typedef OnMessagesChanged = void Function();
typedef OnConversationLoadingChanged =
    void Function(String conversationId, bool loading);
typedef OnScrollToBottom = void Function();
typedef OnShowError = void Function(String message);
typedef OnShowWarning = void Function(String message);
typedef OnHapticFeedback = void Function();

const String conversationIdHeaderName = 'X-Conversation-Id';
const String _conversationIdHeaderNameLower = 'x-conversation-id';

Map<String, String>? buildConversationRequestHeaders({
  required String conversationId,
  Map<String, String>? customHeaders,
}) {
  final headers = <String, String>{
    if (customHeaders != null)
      for (final entry in customHeaders.entries)
        if (entry.key.toLowerCase() != _conversationIdHeaderNameLower)
          entry.key: entry.value,
  };
  final normalizedConversationId = conversationId.trim();
  if (normalizedConversationId.isNotEmpty) {
    headers[conversationIdHeaderName] = normalizedConversationId;
  }
  return headers.isEmpty ? null : headers;
}

/// Result of preparing a message generation
class PreparedGeneration {
  final List<Map<String, dynamic>> apiMessages;
  final List<Map<String, dynamic>> toolDefs;
  final ToolCallHandler? onToolCall;
  final bool hasBuiltInSearch;
  final List<String> lastUserImagePaths;

  PreparedGeneration({
    required this.apiMessages,
    required this.toolDefs,
    this.onToolCall,
    required this.hasBuiltInSearch,
    required this.lastUserImagePaths,
  });
}

/// Service for handling message generation orchestration.
///
/// This service coordinates:
/// - Message creation (user + assistant placeholder)
/// - API message preparation with all injections
/// - Stream execution and management
/// - Reasoning state initialization
///
/// UI updates are communicated through callbacks to maintain separation.
class MessageGenerationService {
  MessageGenerationService({
    required this.chatService,
    required this.messageBuilderService,
    required this.generationController,
    required this.streamController,
    required this.contextProvider,
  });

  final ChatService chatService;
  final MessageBuilderService messageBuilderService;
  final GenerationController generationController;
  final stream_ctrl.StreamController streamController;
  final BuildContext contextProvider;

  // Callbacks for UI updates (set by home_page)
  OnMessagesChanged? onMessagesChanged;
  OnConversationLoadingChanged? onConversationLoadingChanged;
  OnScrollToBottom? onScrollToBottom;
  OnShowError? onShowError;
  OnShowWarning? onShowWarning;
  OnHapticFeedback? onHapticFeedback;

  /// Called when file processing starts for the assistant message [messageId].
  void Function(String messageId)? onFileProcessingStarted;

  /// Called when file processing finishes. A null [messageId] clears whichever
  /// message currently owns the indicator (error/cancel cleanup paths).
  void Function(String? messageId)? onFileProcessingFinished;

  /// Check if reasoning is enabled for given budget
  bool isReasoningEnabled(int? budget) {
    if (budget == null) return true;
    if (budget == -1) return true;
    return budget >= 1024;
  }

  /// Prepare API messages with all injections applied.
  Future<PreparedGeneration> prepareApiMessagesWithInjections({
    required List<ChatMessage> messages,
    required Map<String, int> versionSelections,
    required Conversation? currentConversation,
    required SettingsProvider settings,
    required Assistant? assistant,
    required String? assistantId,
    required String providerKey,
    required String modelId,
    ToolApprovalService? approvalService,
    AskUserInteractionService? askUserService,
    String? processingMessageId,
  }) async {
    final cfg = settings.getProviderConfig(providerKey);
    final kind = ProviderConfig.classify(
      providerKey,
      explicitType: cfg.providerType,
    );
    final includeToolMessages = switch (kind) {
      ProviderKind.openai || ProviderKind.claude || ProviderKind.google => true,
    };

    // Build API messages
    final apiMessages = messageBuilderService.buildApiMessages(
      messages: messages,
      versionSelections: versionSelections,
      currentConversation: currentConversation,
      includeToolMessages: includeToolMessages,
    );

    // Apply assistant replace-only regexes at send-time (visual stays unchanged).
    if (assistant != null && assistant.regexRules.isNotEmpty) {
      for (int i = 0; i < apiMessages.length; i++) {
        final role = (apiMessages[i]['role'] ?? '').toString();
        if (role != 'assistant') continue;
        final raw = (apiMessages[i]['content'] ?? '').toString();
        if (raw.isEmpty) continue;
        apiMessages[i]['content'] = applyAssistantRegexes(
          raw,
          assistant: assistant,
          scope: AssistantRegexScope.assistant,
          target: AssistantRegexTransformTarget.send,
        );
      }
    }

    // Inject prompts first so WorldBook can scan the full untrimmed history
    // (same keyword trigger range as before OCR-after-trim). Document/OCR work
    // runs only after the single final context trim below.
    messageBuilderService.injectSystemPrompt(apiMessages, assistant, modelId);
    await messageBuilderService.injectMemoryAndRecentChats(
      apiMessages,
      assistant,
      settings: settings,
      currentConversationId: currentConversation?.id,
    );

    final hasBuiltInSearch = messageBuilderService.hasBuiltInSearch(
      settings,
      providerKey,
      modelId,
    );
    messageBuilderService.injectSearchPrompt(
      apiMessages,
      settings,
      assistant,
      hasBuiltInSearch,
    );
    await messageBuilderService.injectInstructionPrompts(
      apiMessages,
      assistantId,
    );
    await messageBuilderService.injectWorldBookPrompts(
      apiMessages,
      assistantId,
    );

    // Single final trim after WorldBook TOP/BOTTOM/AT_DEPTH injections. OCR and
    // document extraction must run only on this retained set so images that will
    // not be sent are never processed (#769).
    messageBuilderService.applyContextLimit(
      apiMessages,
      assistant,
      floorIndex: currentConversation?.contextFloor,
    );

    // Only this step does the actual attachment work (document extraction and
    // OCR), so the indicator must not cover the injection/trim passes above —
    // and it only claims to be parsing files when the retained messages really
    // carry files to parse. A text-only send that is merely slow (frozen prompt
    // reads, memory injection, templating) must never show the bar.
    // Tools are assembled first: whether a data file is read into the prompt
    // or left for the sandbox depends on which tools go with it.
    final mcpRouteSnapshot = generationController.captureMcpToolRoutes(
      assistant,
    );
    final toolDefs = generationController.buildToolDefinitions(
      settings,
      assistant,
      providerKey,
      modelId,
      hasBuiltInSearch,
      mcpRouteSnapshot: mcpRouteSnapshot,
    );
    final sandboxDataFiles = BuiltInToolsHelper.sendsDataFilesToSandbox(
      cfg: cfg,
      modelId: modelId,
      clientTools: toolDefs,
    );
    final indicatorMessageId =
        processingMessageId != null &&
            messageBuilderService.hasPendingAttachmentWork(
              apiMessages,
              settings,
              conversation: currentConversation,
              sourceMessages: messages,
              sandboxDataFiles: sandboxDataFiles,
            )
        ? processingMessageId
        : null;
    final List<String> lastUserImagePaths;
    if (indicatorMessageId != null) {
      onFileProcessingStarted?.call(indicatorMessageId);
    }
    try {
      lastUserImagePaths = await messageBuilderService
          .processUserMessagesForApi(
            apiMessages,
            settings,
            assistant,
            conversation: currentConversation,
            sourceMessages: messages,
            sandboxDataFiles: sandboxDataFiles,
          );
    } finally {
      if (indicatorMessageId != null) {
        onFileProcessingFinished?.call(indicatorMessageId);
      }
    }

    await messageBuilderService.inlineLocalImages(apiMessages);
    if (ContextLogger.enabled) {
      final providerName = cfg.name.trim();
      ContextLogger.logPrepared(
        apiMessages: apiMessages,
        conversationId: currentConversation?.id ?? '',
        assistantName: assistant?.name ?? '',
        provider: providerName.isNotEmpty ? providerName : providerKey,
        model: modelId,
      );
    }
    messageBuilderService.stripInternalRevisionIds(apiMessages);

    final onToolCall = toolDefs.isNotEmpty
        ? generationController.buildToolCallHandler(
            settings,
            assistant,
            approvalService: approvalService,
            askUserService: askUserService,
            conversationId: currentConversation?.id,
            mcpRouteSnapshot: mcpRouteSnapshot,
          )
        : null;

    return PreparedGeneration(
      apiMessages: apiMessages,
      toolDefs: toolDefs,
      onToolCall: onToolCall,
      hasBuiltInSearch: hasBuiltInSearch,
      lastUserImagePaths: lastUserImagePaths,
    );
  }

  /// Create user message from input data.
  Future<ChatMessage> createUserMessage({
    required String conversationId,
    required ChatInputData input,
    required Assistant? assistant,
  }) async {
    final parts = await MessageGenerationService.buildPersistedUserMessageParts(
      input,
      assistant: assistant,
    );
    return chatService.addMessage(
      conversationId: conversationId,
      role: 'user',
      parts: parts,
    );
  }

  Future<
    ({ChatMessage userMessage, ChatMessage assistantMessage, String? runId})
  >
  beginSendGeneration({
    required String conversationId,
    required ChatInputData input,
    required Assistant? assistant,
    required String modelId,
    required String providerKey,
  }) async {
    final userParts = await buildPersistedUserMessageParts(
      input,
      assistant: assistant,
    );
    if (chatService.isTemporaryConversation(conversationId)) {
      final userMessage = await chatService.addMessage(
        conversationId: conversationId,
        role: 'user',
        parts: userParts,
      );
      final assistantMessage = await createAssistantPlaceholder(
        conversationId: conversationId,
        modelId: modelId,
        providerKey: providerKey,
      );
      return (
        userMessage: userMessage,
        assistantMessage: assistantMessage,
        runId: null,
      );
    }
    final result = await chatService.beginSendGeneration(
      conversationId: conversationId,
      userParts: userParts,
      modelId: modelId,
      providerId: providerKey,
    );
    return (
      userMessage: result.userMessage!,
      assistantMessage: result.assistantMessage,
      runId: result.run.id,
    );
  }

  Future<({ChatMessage assistantMessage, String? runId})> beginRegeneration({
    required String conversationId,
    required String modelId,
    required String providerKey,
    required String groupId,
    required int version,
    required bool truncateFuture,
  }) async {
    if (chatService.isTemporaryConversation(conversationId)) {
      final assistantMessage = await createAssistantPlaceholder(
        conversationId: conversationId,
        modelId: modelId,
        providerKey: providerKey,
        groupId: groupId,
        version: version,
      );
      return (assistantMessage: assistantMessage, runId: null);
    }
    final result = await chatService.beginRegeneration(
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerKey,
      groupId: groupId,
      version: version,
      truncateFuture: truncateFuture,
    );
    return (assistantMessage: result.assistantMessage, runId: result.run.id);
  }

  Future<({ChatMessage assistantMessage, String? runId})>
  beginAssistantGeneration({
    required String conversationId,
    required String modelId,
    required String providerKey,
    required String anchorGroupId,
    required bool truncateFuture,
  }) async {
    if (chatService.isTemporaryConversation(conversationId)) {
      final assistantMessage = await createAssistantPlaceholder(
        conversationId: conversationId,
        modelId: modelId,
        providerKey: providerKey,
        temporaryAfterGroupId: anchorGroupId,
      );
      return (assistantMessage: assistantMessage, runId: null);
    }
    final result = await chatService.beginAssistantGeneration(
      conversationId: conversationId,
      modelId: modelId,
      providerId: providerKey,
      anchorGroupId: anchorGroupId,
      truncateFuture: truncateFuture,
    );
    return (assistantMessage: result.assistantMessage, runId: result.run.id);
  }

  /// Build structured parts for a persisted user message.
  ///
  /// Text is always present (possibly empty). Attachments follow in the
  /// user's selection order. No legacy attachment markers are produced.
  static Future<List<MessagePart>> buildPersistedUserMessageParts(
    ChatInputData input, {
    required Assistant? assistant,
  }) async {
    final processedUserText = applyAssistantRegexes(
      input.text.trim(),
      assistant: assistant,
      scope: AssistantRegexScope.user,
      target: AssistantRegexTransformTarget.persist,
    );

    final parts = <MessagePart>[TextPart(processedUserText)];
    for (final path in input.imagePaths) {
      parts.add(
        ImagePart(
          uri: SandboxPathResolver.canonicalize(path),
          mime: await inferAttachmentMime(uri: path),
        ),
      );
    }
    for (final document in input.documents) {
      parts.add(
        FilePart(
          uri: SandboxPathResolver.canonicalize(document.path),
          name: document.fileName,
          mime: await inferAttachmentMime(
            uri: document.path,
            explicitMime: document.mime,
            fileName: document.fileName,
          ),
        ),
      );
    }
    return parts;
  }

  /// Derived text body for callers that still need a plain string.
  static Future<String> buildPersistedUserMessageContent(
    ChatInputData input, {
    required Assistant? assistant,
  }) async {
    final parts = await buildPersistedUserMessageParts(
      input,
      assistant: assistant,
    );
    return parts.whereType<TextPart>().map((part) => part.text).join();
  }

  /// Create assistant message placeholder.
  Future<ChatMessage> createAssistantPlaceholder({
    required String conversationId,
    required String modelId,
    required String providerKey,
    String? groupId,
    int version = 0,
    String? temporaryAfterGroupId,
  }) async {
    return chatService.addMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      modelId: modelId,
      providerId: providerKey,
      isStreaming: true,
      groupId: groupId,
      version: version,
      selectVersion: groupId != null,
      temporaryAfterGroupId: temporaryAfterGroupId,
    );
  }

  /// Initialize reasoning state for a message if reasoning is enabled.
  Future<void> initializeReasoningState({
    required String messageId,
    required bool enableReasoning,
  }) async {
    if (enableReasoning) {
      final rd = stream_ctrl.ReasoningData();
      streamController.reasoning[messageId] = rd;
      await chatService.updateMessage(
        messageId,
        reasoningStartAt: DateTime.now(),
      );
    }
  }

  /// Build GenerationContext for streaming.
  stream_ctrl.GenerationContext buildGenerationContext({
    required ChatMessage assistantMessage,
    required PreparedGeneration prepared,
    required List<String> userImagePaths,
    required bool allowImagesApiRouting,
    required String providerKey,
    required String modelId,
    required Assistant? assistant,
    required SettingsProvider settings,
    required bool supportsReasoning,
    required bool enableReasoning,
    required bool generateTitleOnFinish,
    String? generationRunId,
  }) {
    final bool ocrActive =
        settings.ocrEnabled &&
        settings.ocrModelProvider != null &&
        settings.ocrModelId != null;

    return stream_ctrl.GenerationContext(
      assistantMessage: assistantMessage,
      apiMessages: prepared.apiMessages,
      userImagePaths: userImagePaths,
      allowImagesApiRouting: allowImagesApiRouting,
      providerKey: providerKey,
      modelId: modelId,
      assistant: assistant,
      settings: settings,
      config: settings.getProviderConfig(providerKey),
      toolDefs: prepared.toolDefs,
      onToolCall: prepared.onToolCall,
      extraHeaders: buildConversationRequestHeaders(
        conversationId: assistantMessage.conversationId,
        customHeaders: generationController.buildCustomHeaders(assistant),
      ),
      extraBody: generationController.buildCustomBody(assistant),
      supportsReasoning: supportsReasoning,
      enableReasoning: enableReasoning,
      streamOutput: assistant?.streamOutput ?? true,
      ocrActive: ocrActive,
      generateTitleOnFinish: generateTitleOnFinish,
      generationRunId: generationRunId,
    );
  }

  /// Get the model this conversation sends with: the conversation's own
  /// override, else the assistant's model, else the global default.
  ({String? providerKey, String? modelId}) getModelConfig(
    SettingsProvider settings,
    Assistant? assistant, {
    Conversation? conversation,
  }) => resolveChatModel(
    settings,
    conversation: conversation,
    assistant: assistant,
  );

  /// Calculate version info for regeneration.
  ({String? targetGroupId, int nextVersion, int lastKeep})
  calculateRegenerationVersioning({
    required ChatMessage message,
    required List<ChatMessage> messages,
    required bool assistantAsNewReply,
  }) {
    final idx = messages.indexWhere((m) => m.id == message.id);
    if (idx < 0) {
      return (targetGroupId: null, nextVersion: 0, lastKeep: -1);
    }

    String? targetGroupId;
    int nextVersion = 0;
    int lastKeep;

    if (message.role == 'assistant') {
      lastKeep = idx;
      if (assistantAsNewReply) {
        targetGroupId = null;
        nextVersion = 0;
      } else {
        targetGroupId = message.groupId ?? message.id;
        int maxVer = -1;
        for (final m in messages) {
          final gid = (m.groupId ?? m.id);
          if (gid == targetGroupId) {
            if (m.version > maxVer) maxVer = m.version;
          }
        }
        nextVersion = maxVer + 1;
      }
    } else {
      // User message
      final userGroupId = message.groupId ?? message.id;
      int userFirst = -1;
      for (int i = 0; i < messages.length; i++) {
        final gid0 = (messages[i].groupId ?? messages[i].id);
        if (gid0 == userGroupId) {
          userFirst = i;
          break;
        }
      }
      if (userFirst < 0) userFirst = idx;

      int aid = -1;
      for (int i = userFirst + 1; i < messages.length; i++) {
        final candidateGroupId = messages[i].groupId ?? messages[i].id;
        if (candidateGroupId == userGroupId) continue;
        if (messages[i].role == 'assistant') {
          aid = i;
        }
        break;
      }

      if (aid >= 0) {
        lastKeep = aid;
        targetGroupId = messages[aid].groupId ?? messages[aid].id;
        int maxVer = -1;
        for (final m in messages) {
          final gid = (m.groupId ?? m.id);
          if (gid == targetGroupId) {
            if (m.version > maxVer) maxVer = m.version;
          }
        }
        nextVersion = maxVer + 1;
      } else {
        lastKeep = userFirst;
        targetGroupId = null;
        nextVersion = 0;
      }
    }

    return (
      targetGroupId: targetGroupId,
      nextVersion: nextVersion,
      lastKeep: lastKeep,
    );
  }

  /// Remove trailing messages after regeneration cut point.
  @visibleForTesting
  static List<String> collectTrailingMessageIdsForRemoval({
    required List<ChatMessage> messages,
    required int lastKeep,
    required String? targetGroupId,
  }) {
    if (lastKeep >= messages.length - 1) {
      return const [];
    }

    final keepGroups = <String>{};
    for (int i = 0; i <= lastKeep && i < messages.length; i++) {
      keepGroups.add(messages[i].groupId ?? messages[i].id);
    }
    if (targetGroupId != null) keepGroups.add(targetGroupId);

    final removeIds = <String>[];
    for (final message in messages.sublist(lastKeep + 1)) {
      final groupId = message.groupId ?? message.id;
      if (!keepGroups.contains(groupId)) {
        removeIds.add(message.id);
      }
    }
    return removeIds;
  }

  /// Remove trailing messages after regeneration cut point.
  Future<List<String>> removeTrailingMessages({
    required List<ChatMessage> messages,
    required int lastKeep,
    required String? targetGroupId,
  }) async {
    final removeIds = collectTrailingMessageIdsForRemoval(
      messages: messages,
      lastKeep: lastKeep,
      targetGroupId: targetGroupId,
    );

    var deletedIds = removeIds;
    if (removeIds.isNotEmpty && messages.isNotEmpty) {
      final removeIdSet = removeIds.toSet();
      final conversationId = messages.first.conversationId;
      final selectionChanges = <String, int?>{};
      for (final message in messages) {
        if (removeIdSet.contains(message.id)) {
          selectionChanges[message.groupId ?? message.id] = null;
        }
      }
      deletedIds = (await chatService.deleteMessages(
        conversationId: conversationId,
        messageIds: removeIdSet,
        versionSelectionChanges: selectionChanges,
      )).toList(growable: false);
    }
    for (final id in deletedIds) {
      streamController.reasoning.remove(id);
      streamController.toolParts.remove(id);
      streamController.reasoningSegments.remove(id);
    }

    return deletedIds;
  }

  bool _shouldIncludeAudioForProvider(
    SettingsProvider settings, {
    required String providerKey,
    required String modelId,
  }) {
    // Former Omni audio allowlist removed; OpenAI-compatible providers do not
    // receive special audio attachment support via this gate.
    return false;
  }

  bool supportsAudioAttachmentsForProvider(
    SettingsProvider settings, {
    required String providerKey,
    required String modelId,
  }) {
    return _shouldIncludeAudioForProvider(
      settings,
      providerKey: providerKey,
      modelId: modelId,
    );
  }

  String _effectiveAttachmentMime(DocumentAttachment attachment) {
    return resolveDocumentAttachmentMime(attachment);
  }

  bool inputContainsAudioAttachments(ChatInputData input) {
    for (final attachment in input.documents) {
      if (isAudioMime(_effectiveAttachmentMime(attachment))) {
        return true;
      }
    }
    return false;
  }

  bool apiMessagesContainAudioAttachments(List<Map<String, dynamic>> messages) {
    for (final message in messages) {
      for (final ref in parseInternalMediaRefs(
        message[MessageBuilderService.internalMediaPathsKey],
      )) {
        final mime = (ref.mime != null && ref.mime!.trim().isNotEmpty)
            ? ref.mime!.trim()
            : inferMediaMimeFromSource(ref.uri);
        if (isAudioMime(mime)) {
          return true;
        }
      }
    }
    return false;
  }

  List<String> _filterMediaPathsForProvider(
    List<String> paths, {
    required bool includeAudio,
  }) {
    return paths
        .where((path) {
          final mime = inferMediaMimeFromSource(
            path,
            fallbackMime: 'image/png',
          );
          if (isAudioMime(mime)) return includeAudio;
          return isImageMime(mime) || isVideoMime(mime);
        })
        .toList(growable: false);
  }

  /// Build user image paths considering OCR mode.
  List<String> buildUserImagePaths({
    required ChatInputData? input,
    required List<String> lastUserImagePaths,
    required SettingsProvider settings,
    required String providerKey,
    required String modelId,
  }) {
    final bool ocrActive =
        settings.ocrEnabled &&
        settings.ocrModelProvider != null &&
        settings.ocrModelId != null;

    final includeAudio = _shouldIncludeAudioForProvider(
      settings,
      providerKey: providerKey,
      modelId: modelId,
    );

    if (input != null) {
      final currentMediaPaths = <String>[];
      for (final d in input.documents) {
        final effectiveMime = _effectiveAttachmentMime(d);
        if (isVideoMime(effectiveMime) ||
            (includeAudio && isAudioMime(effectiveMime))) {
          currentMediaPaths.add(d.path);
        }
      }
      return _filterMediaPathsForProvider(<String>[
        if (!ocrActive) ...input.imagePaths,
        ...currentMediaPaths,
      ], includeAudio: includeAudio);
    }

    return _filterMediaPathsForProvider(
      lastUserImagePaths
          .where((path) {
            if (!ocrActive) return true;
            return !isImageMime(
              inferMediaMimeFromSource(path, fallbackMime: 'image/png'),
            );
          })
          .toList(growable: false),
      includeAudio: includeAudio,
    );
  }
}
