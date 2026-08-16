import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../models/message_part.dart';
import '../../logging/flutter_logger.dart';

/// One entry in a shadow kind sequence: text / reasoning / tool_call.
class ShadowSeqItem {
  const ShadowSeqItem(this.kind, {this.length, this.id});

  final String kind;
  final int? length;
  final String? id;

  @override
  bool operator ==(Object other) {
    return other is ShadowSeqItem && other.kind == kind && other.id == id;
  }

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() {
    if (id != null) return '$kind:$id';
    if (length != null) return '$kind:$length';
    return kind;
  }
}

class ShadowBag {
  const ShadowBag({
    this.content = '',
    this.reasoning = '',
    this.toolCallIds = const <String>[],
    this.toolResultIds = const <String>[],
  });

  final String content;
  final String reasoning;
  final List<String> toolCallIds;
  final List<String> toolResultIds;
}

class StreamChunkShadowDiff {
  const StreamChunkShadowDiff({
    required this.handlerKinds,
    required this.legacyKinds,
    required this.handlerText,
    required this.legacyText,
    required this.handlerToolIds,
    required this.legacyToolIds,
    required this.handlerReasoningCount,
    required this.legacyReasoningCount,
    required this.handlerImages,
    required this.legacyImages,
    this.handlerReasoningText,
    this.legacyReasoningText,
    this.compareKinds = true,
    this.responsesImageDuplicates = false,
  });

  final List<ShadowSeqItem> handlerKinds;
  final List<ShadowSeqItem> legacyKinds;
  final String handlerText;
  final String legacyText;
  final Set<String> handlerToolIds;
  final Set<String> legacyToolIds;
  final int handlerReasoningCount;
  final int legacyReasoningCount;
  final int handlerImages;
  final int legacyImages;
  final String? handlerReasoningText;
  final String? legacyReasoningText;
  final bool compareKinds;
  final bool responsesImageDuplicates;

  bool get kindsMatch => !compareKinds || listEquals(handlerKinds, legacyKinds);
  bool get textMatch => handlerText == legacyText;
  bool get toolsMatch => setEquals(handlerToolIds, legacyToolIds);
  bool get reasoningMatch {
    final handlerJoined = handlerReasoningText;
    final legacyJoined = legacyReasoningText;
    if (handlerJoined != null && legacyJoined != null) {
      return handlerJoined == legacyJoined;
    }
    return handlerReasoningCount == legacyReasoningCount;
  }

  /// Responses may emit ImageSnapshot twice (partial + collected). Adapter
  /// appends both markdowns; handler replaces in place. Only that +1 is
  /// exempt, and only when the handler actually produced an image.
  bool get imagesMatch {
    if (handlerImages == legacyImages) return true;
    return responsesImageDuplicates &&
        handlerImages >= 1 &&
        legacyImages == handlerImages + 1;
  }

  bool get matched =>
      kindsMatch && textMatch && toolsMatch && reasoningMatch && imagesMatch;
}

/// Structural shadow compare of [StreamChunkHandler] parts vs the live
/// `fullContentRaw` + split triples path. Logs only; never throws.
class StreamChunkShadow {
  StreamChunkShadow._();

  /// Flip off to silence compare + logs. Default on for daily use.
  static bool enabled = true;

  static const _tag = 'StreamChunkShadow';

  static final RegExp _imageMarkdownRe = RegExp(r'!\[image\]\([^)]*\)');
  static final RegExp _thoughtSigRe = RegExp(
    r'<!--\s*gemini_thought_signatures:.*?-->',
    dotAll: true,
  );

  static StreamChunkShadowDiff compareChat({
    required List<MessagePart> parts,
    required String fullContentRaw,
    required List<int> offsets,
    required List<int> reasoningCounts,
    required List<int> toolCounts,
    required List<String> toolIds,
    required List<({bool hasText, int toolStartIndex})> reasoningSegments,
    String reasoningFallbackText = '',
    bool responsesImageDuplicates = false,
  }) {
    final legacyReasoningCount = effectiveLegacyReasoningCount(
      segmentCount: reasoningSegments.where((s) => s.hasText).length,
      fallbackText: reasoningFallbackText,
    );
    return StreamChunkShadowDiff(
      handlerKinds: sequenceFromParts(parts),
      legacyKinds: sequenceFromLegacy(
        fullContentRaw: fullContentRaw,
        offsets: offsets,
        reasoningCounts: reasoningCounts,
        toolCounts: toolCounts,
        toolIds: toolIds,
        reasoningSegments: reasoningSegments,
        reasoningFallbackText: reasoningFallbackText,
      ),
      handlerText: normalizeShadowText(textFromParts(parts)),
      legacyText: normalizeShadowText(fullContentRaw),
      handlerToolIds: toolIdsFromParts(parts),
      legacyToolIds: toolIds.toSet(),
      handlerReasoningCount: reasoningCountFromParts(parts),
      legacyReasoningCount: legacyReasoningCount,
      handlerImages: imageCountFromParts(parts),
      legacyImages: countImageMarkdown(fullContentRaw),
      responsesImageDuplicates: responsesImageDuplicates,
    );
  }

  static StreamChunkShadowDiff compareLegacy({
    required List<MessagePart> parts,
    required String content,
    required String reasoning,
    required Set<String> toolIds,
    List<ShadowBag> bags = const <ShadowBag>[],
    bool responsesImageDuplicates = false,
  }) {
    return StreamChunkShadowDiff(
      handlerKinds: sequenceFromParts(parts),
      legacyKinds: sequenceFromBags(bags),
      handlerText: normalizeShadowText(textFromParts(parts)),
      legacyText: normalizeShadowText(content),
      handlerToolIds: toolIdsFromParts(parts),
      legacyToolIds: toolIds,
      handlerReasoningCount: reasoningCountFromParts(parts),
      legacyReasoningCount: reasoning.isEmpty ? 0 : 1,
      handlerImages: imageCountFromParts(parts),
      legacyImages: countImageMarkdown(content),
      handlerReasoningText: reasoningTextFromParts(parts),
      legacyReasoningText: reasoning,
      compareKinds: bags.isNotEmpty,
      responsesImageDuplicates: responsesImageDuplicates,
    );
  }

  static void reportChat({
    required String conversationId,
    required String messageId,
    required List<MessagePart> parts,
    required String fullContentRaw,
    required List<int> offsets,
    required List<int> reasoningCounts,
    required List<int> toolCounts,
    required List<String> toolIds,
    required List<({bool hasText, int toolStartIndex})> reasoningSegments,
    String reasoningFallbackText = '',
    bool responsesImageDuplicates = false,
  }) {
    if (!enabled) return;
    try {
      _report(
        compareChat(
          parts: parts,
          fullContentRaw: fullContentRaw,
          offsets: offsets,
          reasoningCounts: reasoningCounts,
          toolCounts: toolCounts,
          toolIds: toolIds,
          reasoningSegments: reasoningSegments,
          reasoningFallbackText: reasoningFallbackText,
          responsesImageDuplicates: responsesImageDuplicates,
        ),
        'conversationId=$conversationId messageId=$messageId',
      );
    } catch (error, stack) {
      _emit(
        'compare failed conversationId=$conversationId '
        'messageId=$messageId error=$error\n$stack',
      );
    }
  }

  static void reportLegacy({
    required String source,
    required List<MessagePart> parts,
    required String content,
    required String reasoning,
    required Set<String> toolIds,
    List<ShadowBag> bags = const <ShadowBag>[],
    bool responsesImageDuplicates = false,
  }) {
    if (!enabled) return;
    try {
      _report(
        compareLegacy(
          parts: parts,
          content: content,
          reasoning: reasoning,
          toolIds: toolIds,
          bags: bags,
          responsesImageDuplicates: responsesImageDuplicates,
        ),
        'source=$source',
      );
    } catch (error, stack) {
      _emit('compare failed source=$source error=$error\n$stack');
    }
  }

  static void _report(StreamChunkShadowDiff diff, String where) {
    final hasImages = diff.handlerImages > 0 || diff.legacyImages > 0;
    if (diff.matched) {
      if (hasImages) {
        _emit(
          'ok $where handlerImages=${diff.handlerImages} '
          'legacyImages=${diff.legacyImages}',
        );
      }
      return;
    }
    _log(diff, where);
  }

  static void _log(StreamChunkShadowDiff diff, String where) {
    final lines = <String>[
      'mismatch $where',
      if (diff.compareKinds)
        '  kinds handler=${diff.handlerKinds} legacy=${diff.legacyKinds}',
      '  text equal=${diff.textMatch} '
          'handlerLen=${diff.handlerText.length} '
          'legacyLen=${diff.legacyText.length}',
      '  tools handler=${_sorted(diff.handlerToolIds)} '
          'legacy=${_sorted(diff.legacyToolIds)}',
      '  reasoning handler=${diff.handlerReasoningCount} '
          'legacy=${diff.legacyReasoningCount}',
      '  images handler=${diff.handlerImages} legacy=${diff.legacyImages}',
    ];
    _emit(lines.join('\n'));
  }

  static void _emit(String message) {
    debugPrint('[$_tag] $message');
    FlutterLogger.log(message, tag: _tag);
  }

  static List<String> _sorted(Set<String> ids) {
    final out = ids.toList()..sort();
    return out;
  }
}

List<ShadowSeqItem> sequenceFromParts(List<MessagePart> parts) {
  final out = <ShadowSeqItem>[];
  for (final part in parts) {
    switch (part) {
      case TextPart(:final text):
        if (text.isEmpty) continue;
        _appendText(out, text.length);
      case ReasoningPart(:final text):
        if (text.isEmpty) continue;
        out.add(ShadowSeqItem('reasoning', length: text.length));
      case ToolCallPart(:final payloadJson):
        out.add(ShadowSeqItem('tool_call', id: toolIdFromPayload(payloadJson)));
      case ImagePart():
        // Adapter still folds images into markdown text.
        _appendText(out, 0);
      default:
        break;
    }
  }
  return out;
}

List<ShadowSeqItem> sequenceFromLegacy({
  required String fullContentRaw,
  required List<int> offsets,
  required List<int> reasoningCounts,
  required List<int> toolCounts,
  required List<String> toolIds,
  required List<({bool hasText, int toolStartIndex})> reasoningSegments,
  String reasoningFallbackText = '',
}) {
  var segments = reasoningSegments;
  var counts = reasoningCounts;
  if (segments.isEmpty && reasoningFallbackText.isNotEmpty) {
    segments = const [(hasText: true, toolStartIndex: 0)];
    counts = [for (final count in reasoningCounts) count < 1 ? 1 : count];
  }

  final steps = _legacyNonTextSteps(segments: segments, toolIds: toolIds);
  final seq = <ShadowSeqItem>[];
  var stepIndex = 0;
  var textStart = 0;

  for (var i = 0; i < offsets.length; i++) {
    final offset = offsets[i].clamp(0, fullContentRaw.length);
    if (offset > textStart) {
      seq.add(ShadowSeqItem('text', length: offset - textStart));
    }
    final targetReasoning = i < counts.length ? counts[i] : 0;
    final targetTool = i < toolCounts.length ? toolCounts[i] : 0;
    while (stepIndex < steps.length) {
      final step = steps[stepIndex++];
      seq.add(step.item);
      if (step.reasoningAfter == targetReasoning &&
          step.toolAfter == targetTool) {
        break;
      }
    }
    textStart = offset;
  }

  if (textStart < fullContentRaw.length) {
    seq.add(ShadowSeqItem('text', length: fullContentRaw.length - textStart));
  }
  while (stepIndex < steps.length) {
    seq.add(steps[stepIndex++].item);
  }
  return seq;
}

String textFromParts(List<MessagePart> parts) {
  final buffer = StringBuffer();
  for (final part in parts) {
    switch (part) {
      case TextPart(:final text):
        buffer.write(text);
      case ImagePart(:final uri):
        buffer.write('\n\n![image]($uri)');
      default:
        break;
    }
  }
  return buffer.toString();
}

String normalizeShadowText(String raw) {
  return raw
      .replaceAll(StreamChunkShadow._thoughtSigRe, '')
      .replaceAll(StreamChunkShadow._imageMarkdownRe, '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

int imageCountFromParts(List<MessagePart> parts) =>
    parts.whereType<ImagePart>().length;

int countImageMarkdown(String raw) =>
    StreamChunkShadow._imageMarkdownRe.allMatches(raw).length;

List<ShadowSeqItem> sequenceFromBags(Iterable<ShadowBag> bags) {
  final out = <ShadowSeqItem>[];
  final seenTools = <String>{};
  for (final bag in bags) {
    if (bag.reasoning.isNotEmpty) {
      if (out.isEmpty || out.last.kind != 'reasoning') {
        out.add(ShadowSeqItem('reasoning', length: bag.reasoning.length));
      }
    }
    for (final id in bag.toolCallIds.followedBy(bag.toolResultIds)) {
      if (id.isEmpty || !seenTools.add(id)) continue;
      out.add(ShadowSeqItem('tool_call', id: id));
    }
    if (bag.content.isNotEmpty) {
      _appendText(out, bag.content.length);
    }
  }
  return out;
}

Set<String> toolIdsFromParts(List<MessagePart> parts) {
  final ids = <String>{};
  for (final part in parts.whereType<ToolCallPart>()) {
    final id = toolIdFromPayload(part.payloadJson);
    if (id != null && id.isNotEmpty) ids.add(id);
  }
  return ids;
}

int reasoningCountFromParts(List<MessagePart> parts) {
  return parts
      .whereType<ReasoningPart>()
      .where((part) => part.text.isNotEmpty)
      .length;
}

String reasoningTextFromParts(List<MessagePart> parts) {
  return parts.whereType<ReasoningPart>().map((part) => part.text).join();
}

int effectiveLegacyReasoningCount({
  required int segmentCount,
  required String fallbackText,
}) {
  if (segmentCount > 0) return segmentCount;
  return fallbackText.isEmpty ? 0 : 1;
}

String? toolIdFromPayload(String payloadJson) {
  try {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map) {
      final id = decoded['id'];
      if (id != null) return id.toString();
    }
  } catch (_) {}
  return null;
}

class _LegacyStep {
  const _LegacyStep(this.item, this.reasoningAfter, this.toolAfter);

  final ShadowSeqItem item;
  final int reasoningAfter;
  final int toolAfter;
}

List<_LegacyStep> _legacyNonTextSteps({
  required List<({bool hasText, int toolStartIndex})> segments,
  required List<String> toolIds,
}) {
  if (segments.isEmpty) {
    var toolAfter = 0;
    return [
      for (final id in toolIds)
        _LegacyStep(ShadowSeqItem('tool_call', id: id), 0, ++toolAfter),
    ];
  }

  final steps = <_LegacyStep>[];
  var reasoningAfter = 0;
  var toolAfter = 0;
  var toolIndex = 0;

  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    final segmentToolStart = segment.toolStartIndex.clamp(0, toolIds.length);
    while (toolIndex < segmentToolStart && toolIndex < toolIds.length) {
      steps.add(
        _LegacyStep(
          ShadowSeqItem('tool_call', id: toolIds[toolIndex]),
          reasoningAfter,
          ++toolAfter,
        ),
      );
      toolIndex++;
    }
    if (segment.hasText) {
      steps.add(
        _LegacyStep(
          const ShadowSeqItem('reasoning'),
          ++reasoningAfter,
          toolAfter,
        ),
      );
    }
    final nextBoundary = i < segments.length - 1
        ? segments[i + 1].toolStartIndex.clamp(0, toolIds.length)
        : toolIds.length;
    while (toolIndex < nextBoundary && toolIndex < toolIds.length) {
      steps.add(
        _LegacyStep(
          ShadowSeqItem('tool_call', id: toolIds[toolIndex]),
          reasoningAfter,
          ++toolAfter,
        ),
      );
      toolIndex++;
    }
  }

  while (toolIndex < toolIds.length) {
    steps.add(
      _LegacyStep(
        ShadowSeqItem('tool_call', id: toolIds[toolIndex]),
        reasoningAfter,
        ++toolAfter,
      ),
    );
    toolIndex++;
  }
  return steps;
}

void _appendText(List<ShadowSeqItem> out, int length) {
  if (out.isNotEmpty && out.last.kind == 'text') return;
  out.add(ShadowSeqItem('text', length: length));
}
