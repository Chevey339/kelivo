import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/logging/context_log_models.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import '../../../core/utils/token_estimator.dart';
import 'message_builder_service.dart';

class ContextImageRef {
  const ContextImageRef({this.width, this.height});

  final int? width;
  final int? height;
}

class ContextAssemblyPreview {
  const ContextAssemblyPreview({
    required this.systemText,
    required this.injectionsText,
    required this.historyText,
    required this.tools,
    required this.images,
    this.memoryText = '',
    this.worldBookText = '',
    this.skillsText = '',
    this.workspaceText = '',
    this.searchText = '',
    this.mcpTools = const [],
  });

  final String systemText;
  final String injectionsText;
  final String historyText;
  final List<Map<String, dynamic>> tools;
  final List<ContextImageRef> images;
  final String memoryText;
  final String worldBookText;
  final String skillsText;
  final String workspaceText;
  final String searchText;
  final List<Map<String, dynamic>> mcpTools;

  /// Attribute the assembled, trimmed payload by origin, not by message role.
  /// World books can occupy any role; memory snapshots live in user messages.
  factory ContextAssemblyPreview.fromApiMessages({
    required List<Map<String, dynamic>> apiMessages,
    required List<Map<String, dynamic>> tools,
    required Set<String> mcpToolNames,
    required List<ContextImageRef> images,
  }) {
    final text = <ContextSource, StringBuffer>{};
    for (final message in apiMessages) {
      for (final segment in segmentsFromTaggedMessage(
        message,
        estimateTokenCounts: false,
        elideDataUris: false,
      )) {
        text.putIfAbsent(segment.source, StringBuffer.new).write(segment.text);
      }
      final reasoning = message['reasoning_content'];
      if (reasoning is String) {
        text
            .putIfAbsent(ContextSource.chatHistory, StringBuffer.new)
            .write(reasoning);
      }
    }
    String content(List<ContextSource> sources) =>
        sources.map((source) => text[source]?.toString() ?? '').join();
    bool isMcp(Map<String, dynamic> tool) =>
        mcpToolNames.contains((tool['function'] as Map?)?['name']);
    return ContextAssemblyPreview(
      systemText: content([ContextSource.systemPrompt]),
      injectionsText: content([ContextSource.instructionInjection]),
      historyText: content([
        ContextSource.chatHistory,
        ContextSource.toolCall,
        ContextSource.toolResult,
      ]),
      memoryText: content([
        ContextSource.memoryRules,
        ContextSource.memorySnapshot,
      ]),
      worldBookText: content([ContextSource.worldBook]),
      skillsText: content([ContextSource.skills]),
      workspaceText: content([ContextSource.workspace]),
      searchText: content([ContextSource.searchPrompt]),
      tools: tools.where((tool) => !isMcp(tool)).toList(),
      mcpTools: tools.where(isMcp).toList(),
      images: images,
    );
  }
}

typedef ContextAssemblyPreviewFn =
    Future<ContextAssemblyPreview> Function({
      required String conversationId,
      required String providerKey,
      required String modelId,
      required String? assistantId,
    });

class ContextEstimateJob {
  const ContextEstimateJob({required this.preview, required this.kind});

  final ContextAssemblyPreview preview;
  final ProviderKind kind;
}

class ContextEstimateResult {
  const ContextEstimateResult({
    required this.system,
    required this.injections,
    required this.history,
    required this.tools,
    required this.attachments,
    required this.memory,
    required this.worldBook,
    required this.skills,
    required this.workspace,
    required this.search,
    required this.mcpTools,
  });

  final int system;
  final int injections;
  final int history;
  final int tools;
  final int attachments;
  final int memory;
  final int worldBook;
  final int skills;
  final int workspace;
  final int search;
  final int mcpTools;
}

ContextEstimateResult estimateContextBuckets(ContextEstimateJob job) {
  var attachments = 0;
  final preview = job.preview;
  for (final image in preview.images) {
    attachments += estimateImageTokens(
      job.kind,
      width: image.width,
      height: image.height,
    );
  }
  return ContextEstimateResult(
    system: estimateTokens(preview.systemText),
    injections: estimateTokens(preview.injectionsText),
    history: estimateTokens(preview.historyText),
    tools: estimateToolsTokens(preview.tools),
    memory: estimateTokens(preview.memoryText),
    worldBook: estimateTokens(preview.worldBookText),
    skills: estimateTokens(preview.skillsText),
    workspace: estimateTokens(preview.workspaceText),
    search: estimateTokens(preview.searchText),
    mcpTools: estimateToolsTokens(preview.mcpTools),
    attachments: attachments,
  );
}

List<ContextImageRef> imageRefsFromApiMessages(
  List<Map<String, dynamic>> apiMessages, {
  List<ChatMessage> sourceMessages = const [],
}) {
  final images = <ContextImageRef>[];
  for (final message in apiMessages) {
    for (final _ in parseInternalMediaRefs(
      message[MessageBuilderService.internalMediaPathsKey],
    )) {
      images.add(const ContextImageRef());
    }
  }
  if (images.isNotEmpty) return images;
  for (final message in sourceMessages) {
    for (final part in message.parts) {
      if (part is ImagePart &&
          !part.unavailable &&
          part.uri.trim().isNotEmpty) {
        images.add(const ContextImageRef());
      }
    }
  }
  return images;
}

bool assistantTurnHadTools({
  required ChatMessage assistantMessage,
  List<Map<String, dynamic>> toolEvents = const [],
}) {
  return assistantMessage.parts.any((part) => part is ToolCallPart) ||
      toolEvents.isNotEmpty;
}

/// Whether the next request will send this turn's reasoning back.
bool replaysAssistantReasoning({
  required ReasoningReplayPolicy replay,
  required ChatMessage assistantMessage,
  List<Map<String, dynamic>> toolEvents = const [],
}) {
  return replay == ReasoningReplayPolicy.all ||
      (replay == ReasoningReplayPolicy.toolTurns &&
          assistantTurnHadTools(
            assistantMessage: assistantMessage,
            toolEvents: toolEvents,
          ));
}

/// Visible assistant text plus reasoning only when it will be replayed.
/// Tool payloads are never counted: they already sit in [TokenUsage.promptTokens].
int estimateFinalAssistantTokens({
  required ChatMessage assistantMessage,
  required ReasoningReplayPolicy replay,
  List<Map<String, dynamic>> toolEvents = const [],
}) {
  var tokens = estimateTokens(assistantMessage.content);
  if (!replaysAssistantReasoning(
    replay: replay,
    assistantMessage: assistantMessage,
    toolEvents: toolEvents,
  )) {
    return tokens;
  }
  final reasoning = (assistantMessage.reasoningText ?? '').trim();
  if (reasoning.isEmpty) return tokens;
  return tokens + estimateTokens(reasoning);
}

/// Context size after a completed turn: last-request prompt + final completion,
/// minus reasoning that will not be replayed. When the API omits completion
/// tokens, fall back to [estimateFinalAssistantTokens].
int contextTokensAfterTurn({
  required TokenUsage usage,
  required ChatMessage assistantMessage,
  required ReasoningReplayPolicy replay,
  List<Map<String, dynamic>> toolEvents = const [],
}) {
  if (usage.completionTokens > 0) {
    var used = usage.promptTokens + usage.completionTokens;
    if (!replaysAssistantReasoning(
          replay: replay,
          assistantMessage: assistantMessage,
          toolEvents: toolEvents,
        ) &&
        usage.reasoningTokens > 0) {
      used -= usage.reasoningTokens;
    }
    return used < 0 ? 0 : used;
  }
  return usage.promptTokens +
      estimateFinalAssistantTokens(
        assistantMessage: assistantMessage,
        replay: replay,
        toolEvents: toolEvents,
      );
}
