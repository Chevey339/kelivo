import 'dart:convert';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/utils/thinking_tag_parser.dart';
import 'ui_source_map.dart';

/// Shared original-source eligibility for the renderer and durable storage.
/// The visible block budget belongs to presentation, not persisted identity.
List<UiSourceFence> uiEligibleFences(
  ChatMessage message, {
  bool hasProviderReasoning = false,
}) {
  if (message.role != 'assistant') return const [];
  final source = UiMessageSource.of(message.parts);
  if (!source.hasFences) return const [];
  var providerReasoning =
      hasProviderReasoning ||
      (message.reasoningText?.isNotEmpty ?? false) ||
      message.parts.any((part) => part is ReasoningPart);
  if (!providerReasoning && message.reasoningSegmentsJson != null) {
    try {
      final payload = jsonDecode(message.reasoningSegmentsJson!);
      final segments = payload is Map ? payload['segments'] : payload;
      // Match both persisted formats and the renderer's all-or-nothing decode.
      // A malformed segment must not turn inline thinking into main content.
      providerReasoning =
          segments is List &&
          segments.isNotEmpty &&
          segments.every(_validReasoningSegment);
    } on FormatException {
      // Malformed metadata cannot grant additional rendering authority.
    }
  }
  final hidden = providerReasoning
      ? const <ThinkingTagHiddenRange>[]
      : ThinkingTagParser.parseWithRanges(
          message.content,
          includeUnclosed: true,
          protectedRanges: source.protectedJoinedRanges,
        ).hiddenRanges;
  return [
    for (final run in source.runs)
      for (final fence in run.fences)
        if (fence.topLevel &&
            !hidden.any(
              (range) =>
                  range.start < run.joinedStart + fence.node.span.end &&
                  range.end > run.joinedStart + fence.node.span.start,
            ))
          fence,
  ];
}

bool _validReasoningSegment(Object? value) {
  if (value is! Map) return false;
  if (value['text'] != null && value['text'] is! String) return false;
  if (value['expanded'] != null && value['expanded'] is! bool) return false;
  if (value['toolStartIndex'] != null && value['toolStartIndex'] is! int) {
    return false;
  }
  for (final key in const ['startAt', 'finishedAt']) {
    final raw = value[key];
    if (raw != null && (raw is! String || DateTime.tryParse(raw) == null)) {
      return false;
    }
  }
  return true;
}
