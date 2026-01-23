import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../utils/assistant_regex.dart';
import '../../../core/models/assistant_regex.dart';
import '../controllers/stream_controller.dart' as stream_ctrl;
import '../controllers/generation_controller.dart';
import 'message_builder_service.dart';

/// Callback types for UI updates from MessageGenerationService
typedef OnMessagesChanged = void Function();
typedef OnConversationLoadingChanged = void Function(String conversationId, bool loading);
typedef OnScrollToBottom = void Function();
typedef OnShowError = void Function(String message);
typedef OnShowWarning = void Function(String message);
typedef OnHapticFeedback = void Function();

/// Result of preparing a message generation
class PreparedGeneration {
  final List<Map<String, dynamic>> apiMessages;
  final List<Map<String, dynamic>> toolDefs;
  final Future<String> Function(String, Map<String, dynamic>)? onToolCall;
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

  /// Called when file processing starts.
  VoidCallback? onFileProcessingStarted;

  /// Called when file processing finishes.
  VoidCallback? onFileProcessingFinished;

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
  }) async {
    final cfg = settings.getProviderConfig(providerKey);
    final kind = ProviderConfig.classify(providerKey, explicitType: cfg.providerType);
    final includeOpenAIToolMessages = kind == ProviderKind.openai;

    try {
      onFileProcessingStarted?.call();
      
      // Build API messages
      final apiMessages = messageBuilderService.buildApiMessages(
        messages: messages,
        versionSelections: versionSelections,
        currentConversation: currentConversation,
        includeOpenAIToolMessages: includeOpenAIToolMessages,
      );

      // Process user messages (documents, OCR, templates)
      final lastUserImagePaths = await messageBuilderService.processUserMessagesForApi(
        apiMessages,
        settings,
        assistant,
      );

      // Signal processing finished
      onFileProcessingFinished?.call();
      
      // Inject prompts
      messageBuilderService.injectSystemPrompt(apiMessages, assistant, modelId);
      await messageBuilderService.injectMemoryAndRecentChats(
        apiMessages,
        assistant,
        currentConversationId: currentConversation?.id,
      );

      final hasBuiltInSearch = messageBuilderService.hasBuiltInGeminiSearch(settings, providerKey, modelId);
      messageBuilderService.injectSearchPrompt(apiMessages, settings, hasBuiltInSearch);
      await messageBuilderService.injectInstructionPrompts(apiMessages, assistantId);

      // Apply context limit and inline images
      messageBuilderService.applyContextLimit(apiMessages, assistant);
      await messageBuilderService.inlineLocalImages(apiMessages);

      // Prepare tools
      final toolDefs = generationController.buildToolDefinitions(
        settings,
        assistant,
        providerKey,
        modelId,
        hasBuiltInSearch,
      );
      final onToolCall = toolDefs.isNotEmpty
          ? generationController.buildToolCallHandler(settings, assistant)
          : null;

      return PreparedGeneration(
        apiMessages: apiMessages,
        toolDefs: toolDefs,
        onToolCall: onToolCall,
        hasBuiltInSearch: hasBuiltInSearch,
        lastUserImagePaths: lastUserImagePaths,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Create user message from input data.
  Future<ChatMessage> createUserMessage({
    required String conversationId,
    required ChatInputData input,
    required Assistant? assistant,
  }) async {
    final content = input.text.trim();
    final imageMarkers = input.imagePaths.map((p) => '\n[image:$p]').join();
    final docMarkers = input.documents.map((d) => '\n[file:${d.path}|${d.fileName}|${d.mime}]').join();

    final processedUserText = applyAssistantRegexes(
      content,
      assistant: assistant,
      scope: AssistantRegexScope.user,
      visual: false,
    );

    return chatService.addMessage(
      conversationId: conversationId,
      role: 'user',
      content: processedUserText + imageMarkers + docMarkers,
    );
  }

  /// Create assistant message placeholder.
  Future<ChatMessage> createAssistantPlaceholder({
    required String conversationId,
    required String modelId,
    required String providerKey,
    String? groupId,
    int version = 0,
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
    required String providerKey,
    required String modelId,
    required Assistant? assistant,
    required SettingsProvider settings,
    required bool supportsReasoning,
    required bool enableReasoning,
    required bool generateTitleOnFinish,
  }) {
    return stream_ctrl.GenerationContext(
      assistantMessage: assistantMessage,
      apiMessages: prepared.apiMessages,
      userImagePaths: userImagePaths,
      providerKey: providerKey,
      modelId: modelId,
      assistant: assistant,
      settings: settings,
      config: settings.getProviderConfig(providerKey),
      toolDefs: prepared.toolDefs,
      onToolCall: prepared.onToolCall,
      extraHeaders: generationController.buildCustomHeaders(assistant),
      extraBody: generationController.buildCustomBody(assistant),
      supportsReasoning: supportsReasoning,
      enableReasoning: enableReasoning,
      streamOutput: assistant?.streamOutput ?? true,
      generateTitleOnFinish: generateTitleOnFinish,
    );
  }

  /// Get current model and provider from assistant or global settings.
  ({String? providerKey, String? modelId}) getModelConfig(
    SettingsProvider settings,
    Assistant? assistant,
  ) {
    return (
      providerKey: assistant?.chatModelProvider ?? settings.currentModelProvider,
      modelId: assistant?.chatModelId ?? settings.currentModelId,
    );
  }

  /// Calculate version info for regeneration.
  ({String? targetGroupId, int nextVersion, int lastKeep}) calculateRegenerationVersioning({
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
        if (messages[i].role == 'assistant') {
          aid = i;
          break;
        }
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

    return (targetGroupId: targetGroupId, nextVersion: nextVersion, lastKeep: lastKeep);
  }

  /// Remove trailing messages after regeneration cut point.
  Future<List<String>> removeTrailingMessages({
    required List<ChatMessage> messages,
    required int lastKeep,
    required String? targetGroupId,
  }) async {
    if (lastKeep >= messages.length - 1) {
      return const [];
    }

    // Collect groups that appear at or before lastKeep
    final keepGroups = <String>{};
    for (int i = 0; i <= lastKeep && i < messages.length; i++) {
      final g = (messages[i].groupId ?? messages[i].id);
      keepGroups.add(g);
    }
    if (targetGroupId != null) keepGroups.add(targetGroupId);

    final trailing = messages.sublist(lastKeep + 1);
    final removeIds = <String>[];
    for (final m in trailing) {
      final gid = (m.groupId ?? m.id);
      final shouldKeep = keepGroups.contains(gid);
      if (!shouldKeep) removeIds.add(m.id);
    }

    for (final id in removeIds) {
      try {
        await chatService.deleteMessage(id);
      } catch (_) {}
      streamController.reasoning.remove(id);
      streamController.toolParts.remove(id);
      streamController.reasoningSegments.remove(id);
    }

    return removeIds;
  }

  /// Build user image paths considering OCR mode.
  List<String> buildUserImagePaths({
    required ChatInputData? input,
    required List<String> lastUserImagePaths,
    required SettingsProvider settings,
  }) {
    final bool ocrActive = settings.ocrEnabled &&
        settings.ocrModelProvider != null &&
        settings.ocrModelId != null;

    if (ocrActive) {
      return const <String>[];
    }

    if (input != null) {
      final currentVideoPaths = <String>[
        for (final d in input.documents)
          if (d.mime.toLowerCase().startsWith('video/')) d.path,
      ];
      return <String>[
        ...input.imagePaths,
        ...currentVideoPaths,
      ];
    }

    return lastUserImagePaths;
  }
}
