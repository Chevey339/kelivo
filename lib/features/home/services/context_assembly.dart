import 'dart:convert';

import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/settings_provider.dart';
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
  });

  final String systemText;
  final String injectionsText;
  final String historyText;
  final List<Map<String, dynamic>> tools;
  final List<ContextImageRef> images;
}

typedef ContextAssemblyPreviewFn =
    Future<ContextAssemblyPreview> Function({
      required String conversationId,
      required String providerKey,
      required String modelId,
      required String? assistantId,
    });

class ContextEstimateJob {
  const ContextEstimateJob({
    required this.systemText,
    required this.injectionsText,
    required this.historyText,
    required this.draftText,
    required this.tools,
    required this.images,
    required this.kind,
  });

  final String systemText;
  final String injectionsText;
  final String historyText;
  final String draftText;
  final List<Map<String, dynamic>> tools;
  final List<ContextImageRef> images;
  final ProviderKind kind;
}

class ContextEstimateResult {
  const ContextEstimateResult({
    required this.system,
    required this.injections,
    required this.history,
    required this.tools,
    required this.attachments,
    required this.draft,
  });

  final int system;
  final int injections;
  final int history;
  final int tools;
  final int attachments;
  final int draft;
}

ContextEstimateResult estimateContextBuckets(ContextEstimateJob job) {
  var attachments = 0;
  for (final image in job.images) {
    attachments += estimateImageTokens(
      job.kind,
      width: image.width,
      height: image.height,
    );
  }
  return ContextEstimateResult(
    system: estimateTokens(job.systemText),
    injections: estimateTokens(job.injectionsText),
    history: estimateTokens(job.historyText),
    tools: estimateToolsTokens(job.tools),
    attachments: attachments,
    draft: estimateTokens(job.draftText),
  );
}

String firstSystemContent(List<Map<String, dynamic>> apiMessages) {
  if (apiMessages.isEmpty) return '';
  final first = apiMessages.first;
  if ((first['role'] ?? '').toString() != 'system') return '';
  return (first['content'] ?? '').toString();
}

String injectionsAfterSystem(String systemBefore, String systemAfter) {
  if (systemAfter == systemBefore) return '';
  if (systemBefore.isNotEmpty && systemAfter.startsWith(systemBefore)) {
    return systemAfter.substring(systemBefore.length);
  }
  return systemAfter;
}

String historyTextFromApiMessages(List<Map<String, dynamic>> apiMessages) {
  final buf = StringBuffer();
  for (final message in apiMessages) {
    if ((message['role'] ?? '').toString() == 'system') continue;
    final content = message['content'];
    if (content is String && content.isNotEmpty) {
      buf.write(content);
    } else if (content is List) {
      for (final part in content) {
        if (part is! Map) continue;
        final text = part['text'];
        if (text is String && text.isNotEmpty) buf.write(text);
      }
    }
    final reasoning = message['reasoning_content'];
    if (reasoning is String && reasoning.isNotEmpty) {
      buf.write(reasoning);
    }
    final toolCalls = message['tool_calls'];
    if (toolCalls != null) {
      try {
        buf.write(jsonEncode(toolCalls));
      } catch (_) {}
    }
  }
  return buf.toString();
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
