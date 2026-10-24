import 'dart:convert';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/utils/message_reasoning_source.dart';
import 'package:Kelivo/features/chat/utils/thinking_tag_parser.dart';
import 'package:Kelivo/features/chat/utils/tool_event_deduplication.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:markstream/markstream_core.dart';

import 'ui_source_map.dart';
import 'ui_source_selection.dart';

typedef UiTimelineSplits = ({
  List<int> offsets,
  List<int> reasoningCounts,
  List<int> toolCounts,
});

/// Stored chronology shared by semantic capture and the read-only image host.
/// Hiding reasoning/tool cards must not change native card source identities.
final class UiMessageTimeline {
  const UiMessageTimeline({
    required this.segments,
    required this.tools,
    required this.splits,
    required this.inlineThinking,
  });
  final List<TimelineReasoningRef> segments;
  final List<TimelineToolRef> tools;
  final UiTimelineSplits? splits;
  final bool inlineThinking;
}

UiMessageTimeline uiMessageTimeline(ChatMessage message) =>
    _messageTimeline(message, _decodeReasoning(message.reasoningSegmentsJson));

/// Historical splits can cut a fence into ordinary code, so raw fence ordinals
/// cannot stand in for the ordinals assigned by the timeline renderer. Source
/// authority and storage leases continue to use uiEligibleFences unchanged.
List<({UiSourceFence fence, int ordinal})> uiPresentedNativeFences(
  ChatMessage message,
) {
  final eligible = uiEligibleFences(message);
  if (eligible.isEmpty) return const [];
  final decoded = _decodeReasoning(message.reasoningSegmentsJson);
  if (decoded?.splits == null) {
    return [
      for (final (ordinal, fence) in eligible.indexed)
        (fence: fence, ordinal: ordinal),
    ];
  }
  final timeline = _messageTimeline(message, decoded);
  final projection = projectAssistantTimeline(
    parts: message.parts,
    liveTools: timeline.tools,
    reasoningSegments: timeline.segments,
    visualContent: message.content,
    contentSplitOffsets: timeline.splits?.offsets,
    reasoningCountAtSplit: timeline.splits?.reasoningCounts,
    toolCountAtSplit: timeline.splits?.toolCounts,
    parseInlineThinking: timeline.inlineThinking,
    partsArrivalOrdered: message.isStreaming,
  );
  final ordinals = <String, int>{};
  for (final block in projection.blocks) {
    final mapped = block.uiSource;
    if (!block.isText || mapped == null) continue;
    final document = const MarkdownParser().parse(block.text!);
    for (final node in document.children.whereType<CodeBlockNode>()) {
      final fence = mapped.resolve(document, node);
      if (fence == null || fence.isWeb) continue;
      final ordinal = mapped.messageOrdinalOf(fence);
      if (ordinal != null) ordinals[fence.surfaceKey] = ordinal;
    }
  }
  return [
    for (final fence in eligible)
      if (ordinals[fence.surfaceKey] case final ordinal?)
        (fence: fence, ordinal: ordinal),
  ];
}

UiMessageTimeline _messageTimeline(
  ChatMessage message,
  _DecodedReasoning? decoded,
) {
  final inlineThinking = messageHasProviderReasoning(message)
      ? ''
      : ThinkingTagParser.parseLegacyInlineBlocks(
          message.content,
          protectedRanges: UiMessageSource.of(
            message.parts,
          ).protectedJoinedRanges,
          includeUnclosed: true,
        ).thinkingTexts.join('\n\n');
  final reasoningText = (message.reasoningText?.isNotEmpty ?? false)
      ? message.reasoningText!
      : inlineThinking;
  final segments = decoded?.segments ?? const <TimelineReasoningRef>[];
  return UiMessageTimeline(
    segments: segments.isNotEmpty
        ? segments
        : [
            if (reasoningText.isNotEmpty)
              TimelineReasoningRef(text: reasoningText),
          ],
    tools: _storedTools(message),
    splits: decoded?.splits,
    inlineThinking: inlineThinking.isNotEmpty,
  );
}

List<TimelineToolRef> _storedTools(ChatMessage message) {
  final events = <Map<String, dynamic>>[];
  for (final part in message.parts.whereType<ToolCallPart>()) {
    try {
      final value = jsonDecode(part.payloadJson);
      if (value is Map) events.add(Map<String, dynamic>.from(value));
    } catch (_) {
      // ChatService ignores an undecodable individual persisted payload.
    }
  }
  try {
    // Match StreamController's batch restore: bad field types reject the tool
    // batch. Do not normalize them into valid steps before split validation.
    return [
      for (final (index, event) in dedupeToolEvents(events).indexed)
        TimelineToolRef(
          providerId: (event['id'] ?? '').toString(),
          fallbackOrdinal: index,
          toolName: (event['name'] ?? '').toString(),
          arguments:
              (event['arguments'] as Map?)?.cast<String, dynamic>() ?? const {},
          content: event['content']?.toString().isNotEmpty == true
              ? event['content'].toString()
              : null,
          metadata: event['metadata'] is Map
              ? Map<String, dynamic>.from(event['metadata'] as Map)
              : null,
          loading: !(event['content']?.toString().isNotEmpty == true),
        ),
    ];
  } catch (_) {
    return const [];
  }
}

typedef _DecodedReasoning = ({
  List<TimelineReasoningRef> segments,
  UiTimelineSplits? splits,
});

_DecodedReasoning? _decodeReasoning(String? source) {
  if (source == null || source.isEmpty) return null;
  try {
    final decoded = jsonDecode(source);
    final List raw;
    final UiTimelineSplits? splits;
    if (decoded is Map<String, dynamic>) {
      raw = decoded['segments'] as List? ?? const [];
      splits = tryParseContentSplits(decoded['contentSplits']);
    } else if (decoded is List) {
      raw = decoded;
      splits = null;
    } else {
      return null;
    }
    // Match persisted timeline all-or-nothing decoding. The projector then
    // validates split coverage against the actual reasoning/tool steps.
    final segments = [
      for (final item in raw)
        TimelineReasoningRef(
          text: item['text'] as String? ?? '',
          expanded: item['expanded'] as bool? ?? false,
          toolStartIndex: item['toolStartIndex'] as int? ?? 0,
          startAt: item['startAt'] == null
              ? null
              : DateTime.parse(item['startAt'] as String),
          finishedAt: item['finishedAt'] == null
              ? null
              : DateTime.parse(item['finishedAt'] as String),
        ),
    ];
    return (segments: segments, splits: splits);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on NoSuchMethodError {
    return null;
  }
}
