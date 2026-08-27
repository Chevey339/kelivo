import 'dart:convert';

import '../../../core/models/message_part.dart';
import 'timeline_visibility.dart';

/// A tool as the timeline projector sees it.
///
/// Field-compatible with [ToolUIPart] so the renderer and estimator share one
/// walk without importing the widget file.
class TimelineToolRef {
  const TimelineToolRef({
    required this.providerId,
    required this.fallbackOrdinal,
    required this.toolName,
    required this.arguments,
    this.content,
    this.metadata,
    this.loading = false,
    this.memoToken,
  });

  /// Provider-supplied id. Empty when the payload had no id. Never synthesized.
  final String providerId;

  /// Tool ordinal used when [providerId] is empty. Disjoint from real ids.
  final int fallbackOrdinal;

  final String toolName;
  final Map<String, dynamic> arguments;
  final String? content;
  final Map<String, dynamic>? metadata;
  final bool loading;

  /// Identity of the original [ToolUIPart] (or a stable field hash).
  ///
  /// The renderer must not memo on a temporary converted object.
  final int? memoToken;

  /// Raw provider id. Empty when the tool has no provider id.
  String get id => providerId;

  TimelineToolRef copyWith({
    String? providerId,
    int? fallbackOrdinal,
    String? toolName,
    Map<String, dynamic>? arguments,
    String? content,
    Map<String, dynamic>? metadata,
    bool? loading,
    int? memoToken,
  }) {
    return TimelineToolRef(
      providerId: providerId ?? this.providerId,
      fallbackOrdinal: fallbackOrdinal ?? this.fallbackOrdinal,
      toolName: toolName ?? this.toolName,
      arguments: arguments ?? this.arguments,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      loading: loading ?? this.loading,
      memoToken: memoToken ?? this.memoToken,
    );
  }
}

/// Reasoning overlay used when structured parts or legacy segments are present.
class TimelineReasoningRef {
  const TimelineReasoningRef({
    required this.text,
    this.expanded = true,
    this.loading = false,
    this.startAt,
    this.finishedAt,
    this.toolStartIndex = 0,
  });

  final String text;
  final bool expanded;
  final bool loading;
  final DateTime? startAt;
  final DateTime? finishedAt;
  final int toolStartIndex;
}

class TimelineProjectedStep {
  const TimelineProjectedStep.reasoning({
    required this.sourceOrdinal,
    required this.reasoning,
    required this.reasoningCountAfter,
    required this.toolCountAfter,
    this.reasoningOverlayIndex,
  }) : tool = null;

  const TimelineProjectedStep.tool({
    required this.sourceOrdinal,
    required this.tool,
    required this.reasoningCountAfter,
    required this.toolCountAfter,
  }) : reasoning = null,
       reasoningOverlayIndex = null;

  final int sourceOrdinal;
  final TimelineReasoningRef? reasoning;
  final TimelineToolRef? tool;
  final int reasoningCountAfter;
  final int toolCountAfter;

  /// Index into the provided reasoning-segment overlay, if any.
  final int? reasoningOverlayIndex;

  bool get isReasoning => reasoning != null;
  bool get isTool => tool != null;
}

class TimelineProjectedBlock {
  const TimelineProjectedBlock.text(this.text)
    : steps = const [],
      imageUri = null,
      imageKey = null,
      aspectRatio = null;

  const TimelineProjectedBlock.thinking(this.steps)
    : text = null,
      imageUri = null,
      imageKey = null,
      aspectRatio = null;

  const TimelineProjectedBlock.image(
    this.imageUri, {
    this.imageKey,
    this.aspectRatio,
  }) : text = null,
       steps = const [];

  final String? text;
  final String? imageUri;
  final String? imageKey;
  final double? aspectRatio;
  final List<TimelineProjectedStep> steps;

  bool get isText => text != null;
  bool get isImage => imageUri != null;
  bool get isThinking => steps.isNotEmpty;
}

/// Fallback height of an inlined [ImagePart] before aspect is known.
/// Width is the message/bubble width. Do not infer from Markdown.
const double kTimelineImageBlockHeight = 240;

/// Laid-out height from a known width/height aspect (`width / height`).
double estimateTimelineImageHeight({
  required double maxWidth,
  double? aspectRatio,
}) {
  if (aspectRatio == null || !aspectRatio.isFinite || aspectRatio <= 0) {
    return kTimelineImageBlockHeight;
  }
  return maxWidth / aspectRatio;
}

/// Stable image identity. Never the payload URI.
String timelineImageBlockKey({
  String? imageId,
  String? assetId,
  required int sourceOrdinal,
}) {
  final streamId = imageId?.trim() ?? '';
  if (streamId.isNotEmpty) return 'image-id:$streamId';
  final asset = assetId?.trim() ?? '';
  if (asset.isNotEmpty) return 'image-id:$asset';
  return 'image-ordinal:$sourceOrdinal';
}

/// In-memory aspects keyed by [timelineImageBlockKey].
final Map<String, double> timelineImageAspects = <String, double>{};

/// Shared reasoning-loading decision for renderer and estimator.
bool timelineReasoningLoading({
  required DateTime? finishedAt,
  required bool isStreaming,
  bool usingInlineThink = false,
}) {
  if (usingInlineThink) return false;
  if (finishedAt != null) return false;
  return isStreaming;
}

class VisibleTimelineBlock {
  const VisibleTimelineBlock({
    required this.visibleSteps,
    required this.hiddenCount,
  });

  final List<TimelineProjectedStep> visibleSteps;
  final int hiddenCount;

  bool get hasExpandRow => hiddenCount > 0;
}

/// Shared [fromParts] decision plus the blocks the renderer and estimator walk.
class TimelineProjection {
  const TimelineProjection({
    required this.fromParts,
    required this.blocks,
    this.partsArrivalOrdered = false,
  });

  final bool fromParts;
  final List<TimelineProjectedBlock> blocks;

  /// Caller-supplied: current streaming messages walk arrival order.
  ///
  /// Do not infer this from the presence of [ReasoningPart] / [ToolCallPart].
  /// Legal historical [contentSplits] still restore prefix → tool/thinking →
  /// suffix when this is false.
  final bool partsArrivalOrdered;
}

/// One visible assistant block after role settings and approval filters.
class TimelineVisibleBlock {
  const TimelineVisibleBlock.text(this.text)
    : imageUri = null,
      imageKey = null,
      aspectRatio = null,
      thinkingSteps = const [];

  const TimelineVisibleBlock.image(
    this.imageUri, {
    this.imageKey,
    this.aspectRatio,
  }) : text = null,
       thinkingSteps = const [];

  const TimelineVisibleBlock.thinking(this.thinkingSteps)
    : text = null,
      imageUri = null,
      imageKey = null,
      aspectRatio = null;

  final String? text;
  final String? imageUri;
  final String? imageKey;
  final double? aspectRatio;

  /// Approval/settings-filtered steps. Collapse is applied by the walker.
  final List<TimelineProjectedStep> thinkingSteps;

  bool get isText => text != null;
  bool get isImage => imageUri != null;
  bool get isThinking => thinkingSteps.isNotEmpty;
}

/// Parse a persisted tool_call payload the same way the renderer does.
TimelineToolRef? parseTimelineToolPayload(
  String payloadJson, {
  int fallbackOrdinal = 0,
}) {
  try {
    final decoded = _decodeJsonMap(payloadJson);
    if (decoded == null) return null;
    final providerId = (decoded['id'] ?? '').toString().trim();
    final name = (decoded['name'] ?? '').toString();
    final args = decoded['arguments'];
    final content = decoded['content']?.toString();
    final rawMeta = decoded['metadata'];
    final metadata = rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : null;
    final arguments = args is Map
        ? args.cast<String, dynamic>()
        : const <String, dynamic>{};
    final loading = content == null || content.isEmpty;
    return TimelineToolRef(
      providerId: providerId,
      fallbackOrdinal: fallbackOrdinal,
      toolName: name,
      arguments: arguments,
      content: content,
      metadata: metadata,
      loading: loading,
      memoToken: Object.hash(
        providerId,
        fallbackOrdinal,
        name,
        content,
        loading,
        Object.hashAll(
          arguments.entries.map((entry) => Object.hash(entry.key, entry.value)),
        ),
      ),
    );
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _decodeJsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
  } catch (_) {}
  return null;
}

/// Stable tool key. Trimmed ids and fallbacks use disjoint namespaces so an
/// id of `fallback:0:search` cannot collide with an empty-id tool.
String timelineToolStepKey({
  required String id,
  required int sourceOrdinal,
  required String toolName,
}) {
  final trimmed = id.trim();
  if (trimmed.isNotEmpty) return 'tool-id:$trimmed';
  return 'tool-fallback:$sourceOrdinal:$toolName';
}

/// Whether an image part starts a new render block, matching the renderer.
bool timelineImagePartFlushesBlock(ImagePart part) =>
    !part.unavailable && part.uri.trim().isNotEmpty;

/// Project assistant timeline blocks using the same rules as the renderer:
/// structured parts, or mixed reasoning+tool order with content-split fallback.
TimelineProjection projectAssistantTimeline({
  required List<MessagePart> parts,
  required List<TimelineToolRef> liveTools,
  required List<TimelineReasoningRef> reasoningSegments,
  required String visualContent,
  List<int>? contentSplitOffsets,
  List<int>? reasoningCountAtSplit,
  List<int>? toolCountAtSplit,
  String Function(String text)? transformText,
  bool? renderFromParts,
  bool partsArrivalOrdered = false,
}) {
  final usableSplits = contentSplitsAreUsable(
    contentSplitOffsets,
    reasoningCountAtSplit,
    toolCountAtSplit,
  );
  final fromParts =
      renderFromParts ??
      _shouldProjectFromParts(
        parts: parts,
        visualContent: visualContent,
        liveTools: liveTools,
        reasoningSegments: reasoningSegments,
        contentSplitOffsets: contentSplitOffsets,
        reasoningCountAtSplit: reasoningCountAtSplit,
        toolCountAtSplit: toolCountAtSplit,
        usableSplits: usableSplits,
        partsArrivalOrdered: partsArrivalOrdered,
      );
  if (fromParts) {
    return mergeLiveToolsIntoProjection(
      TimelineProjection(
        fromParts: true,
        partsArrivalOrdered: partsArrivalOrdered,
        blocks: _projectFromParts(
          parts: parts,
          reasoningSegments: reasoningSegments,
          transformText: transformText,
        ),
      ),
      liveTools,
    );
  }

  final mixed = _interleaveReasoningAndTools(
    liveTools: [
      for (final tool in liveTools)
        if (toolCreatesTimelineCard(tool.toolName)) tool,
    ],
    reasoningSegments: reasoningSegments,
  );
  if (mixed.isEmpty) {
    return mergeLiveToolsIntoProjection(
      TimelineProjection(
        fromParts: false,
        partsArrivalOrdered: partsArrivalOrdered,
        blocks: visualContent.trim().isEmpty
            ? const <TimelineProjectedBlock>[]
            : <TimelineProjectedBlock>[
                TimelineProjectedBlock.text(visualContent),
              ],
      ),
      liveTools,
    );
  }
  final offsets = contentSplitOffsets;
  final reasoningCounts = reasoningCountAtSplit;
  final toolCounts = toolCountAtSplit;
  if (offsets == null ||
      reasoningCounts == null ||
      toolCounts == null ||
      !contentSplitsMatchTimeline(
        offsets: offsets,
        reasoningCounts: reasoningCounts,
        toolCounts: toolCounts,
        contentLength: visualContent.length,
        stepReasoningCounts: [
          for (final step in mixed) step.reasoningCountAfter,
        ],
        stepToolCounts: [for (final step in mixed) step.toolCountAfter],
      )) {
    return mergeLiveToolsIntoProjection(
      TimelineProjection(
        fromParts: false,
        partsArrivalOrdered: partsArrivalOrdered,
        blocks: <TimelineProjectedBlock>[
          TimelineProjectedBlock.thinking(mixed),
          if (visualContent.trim().isNotEmpty)
            TimelineProjectedBlock.text(visualContent),
        ],
      ),
      liveTools,
    );
  }

  final blocks = <TimelineProjectedBlock>[];
  var stepIndex = 0;
  var textStart = 0;
  for (var i = 0; i < offsets.length; i++) {
    final safeOffset = offsets[i].clamp(0, visualContent.length);
    final textSlice = visualContent.substring(textStart, safeOffset);
    if (textSlice.trim().isNotEmpty) {
      blocks.add(TimelineProjectedBlock.text(textSlice.trim()));
    }
    final targetReasoning = reasoningCounts[i];
    final targetTool = toolCounts[i];
    final blockSteps = <TimelineProjectedStep>[];
    while (stepIndex < mixed.length) {
      final step = mixed[stepIndex];
      blockSteps.add(step);
      stepIndex++;
      if (step.reasoningCountAfter == targetReasoning &&
          step.toolCountAfter == targetTool) {
        break;
      }
    }
    if (blockSteps.isNotEmpty) {
      blocks.add(TimelineProjectedBlock.thinking(blockSteps));
    }
    textStart = safeOffset;
  }
  final trailing = visualContent.substring(textStart);
  if (trailing.trim().isNotEmpty) {
    blocks.add(TimelineProjectedBlock.text(trailing.trim()));
  }
  return mergeLiveToolsIntoProjection(
    TimelineProjection(
      fromParts: false,
      partsArrivalOrdered: partsArrivalOrdered,
      blocks: blocks,
    ),
    liveTools,
  );
}

/// Assign live tools once across every thinking block.
///
/// Matches by [TimelineToolRef.providerId] first. Remaining empty-id live
/// tools (except [kBuiltinSearchToolName]) are assigned in encounter order
/// to empty-id projected steps. Never synthesizes string ids.
TimelineProjection mergeLiveToolsIntoProjection(
  TimelineProjection projection,
  List<TimelineToolRef> liveTools,
) {
  final liveById = <String, TimelineToolRef>{};
  final emptyIdLive = <TimelineToolRef>[];
  for (final tool in liveTools) {
    if (tool.toolName == kBuiltinSearchToolName) continue;
    final trimmed = tool.providerId.trim();
    if (trimmed.isNotEmpty) {
      liveById[trimmed] = tool;
    } else {
      emptyIdLive.add(tool);
    }
  }
  var emptyIndex = 0;
  TimelineToolRef resolve(TimelineToolRef projected) {
    final trimmed = projected.providerId.trim();
    if (trimmed.isNotEmpty) {
      final live = liveById[trimmed];
      if (live != null) {
        return live.copyWith(fallbackOrdinal: projected.fallbackOrdinal);
      }
      return projected;
    }
    if (emptyIndex >= emptyIdLive.length) return projected;
    final live = emptyIdLive[emptyIndex++];
    return live.copyWith(fallbackOrdinal: projected.fallbackOrdinal);
  }

  return TimelineProjection(
    fromParts: projection.fromParts,
    partsArrivalOrdered: projection.partsArrivalOrdered,
    blocks: [
      for (final block in projection.blocks)
        if (block.isThinking)
          TimelineProjectedBlock.thinking([
            for (final step in block.steps)
              if (step.isTool)
                TimelineProjectedStep.tool(
                  sourceOrdinal: step.sourceOrdinal,
                  tool: resolve(step.tool!),
                  reasoningCountAfter: step.reasoningCountAfter,
                  toolCountAfter: step.toolCountAfter,
                )
              else
                step,
          ])
        else
          block,
    ],
  );
}

bool _shouldProjectFromParts({
  required List<MessagePart> parts,
  required String visualContent,
  required List<TimelineToolRef> liveTools,
  required List<TimelineReasoningRef> reasoningSegments,
  required List<int>? contentSplitOffsets,
  required List<int>? reasoningCountAtSplit,
  required List<int>? toolCountAtSplit,
  required bool usableSplits,
  required bool partsArrivalOrdered,
}) {
  if (partsArrivalOrdered &&
      (renderAssistantFromParts(parts: parts, hasContentSplits: false) ||
          parts.any(
            (part) => part is ImagePart && timelineImagePartFlushesBlock(part),
          ))) {
    return true;
  }
  if (renderAssistantFromParts(parts: parts, hasContentSplits: usableSplits)) {
    return true;
  }
  // Same structured signal as the old renderer: reasoning, tools, or images
  // that should inline. ImagePart must not be dropped when splits exist but
  // do not match the live timeline.
  if (!renderAssistantFromParts(parts: parts, hasContentSplits: false)) {
    return false;
  }
  if (!usableSplits ||
      contentSplitOffsets == null ||
      reasoningCountAtSplit == null ||
      toolCountAtSplit == null) {
    return false;
  }
  final mixed = _interleaveReasoningAndTools(
    liveTools: [
      for (final tool in liveTools)
        if (toolCreatesTimelineCard(tool.toolName)) tool,
    ],
    reasoningSegments: reasoningSegments,
  );
  return !contentSplitsMatchTimeline(
    offsets: contentSplitOffsets,
    reasoningCounts: reasoningCountAtSplit,
    toolCounts: toolCountAtSplit,
    contentLength: visualContent.length,
    stepReasoningCounts: [for (final step in mixed) step.reasoningCountAfter],
    stepToolCounts: [for (final step in mixed) step.toolCountAfter],
  );
}

List<TimelineProjectedBlock> _projectFromParts({
  required List<MessagePart> parts,
  required List<TimelineReasoningRef> reasoningSegments,
  String Function(String text)? transformText,
}) {
  final blocks = <TimelineProjectedBlock>[];
  var pending = <TimelineProjectedStep>[];
  var reasoningCount = 0;
  var toolCount = 0;
  var reasoningIndex = 0;
  var sourceOrdinal = 0;
  var imageOrdinal = 0;

  void flushSteps() {
    if (pending.isEmpty) return;
    blocks.add(TimelineProjectedBlock.thinking(List.of(pending)));
    pending = <TimelineProjectedStep>[];
  }

  for (final part in parts) {
    switch (part) {
      case TextPart(:final text):
        final visual = transformText?.call(text) ?? text;
        if (visual.trim().isEmpty) continue;
        flushSteps();
        blocks.add(TimelineProjectedBlock.text(visual));
      case ImagePart(:final uri):
        if (!timelineImagePartFlushesBlock(part)) continue;
        flushSteps();
        final imageKey = timelineImageBlockKey(
          imageId: part.id,
          assetId: part.assetId,
          sourceOrdinal: imageOrdinal++,
        );
        blocks.add(
          TimelineProjectedBlock.image(
            uri,
            imageKey: imageKey,
            aspectRatio: timelineImageAspects[imageKey],
          ),
        );
      case ReasoningPart(:final text):
        if (text.isEmpty) continue;
        final provided = reasoningIndex < reasoningSegments.length
            ? reasoningSegments[reasoningIndex]
            : null;
        reasoningIndex++;
        pending.add(
          TimelineProjectedStep.reasoning(
            sourceOrdinal: sourceOrdinal++,
            reasoning: TimelineReasoningRef(
              text: text,
              expanded: provided?.expanded ?? true,
              loading: provided?.loading ?? false,
              startAt: provided?.startAt,
              finishedAt: provided?.finishedAt,
              toolStartIndex: provided?.toolStartIndex ?? toolCount,
            ),
            reasoningCountAfter: ++reasoningCount,
            toolCountAfter: toolCount,
            reasoningOverlayIndex: provided == null ? null : reasoningIndex - 1,
          ),
        );
      case ToolCallPart(:final payloadJson):
        final parsed = parseTimelineToolPayload(
          payloadJson,
          fallbackOrdinal: toolCount,
        );
        if (parsed == null || parsed.toolName == kBuiltinSearchToolName) {
          continue;
        }
        pending.add(
          TimelineProjectedStep.tool(
            sourceOrdinal: sourceOrdinal++,
            tool: parsed,
            reasoningCountAfter: reasoningCount,
            toolCountAfter: ++toolCount,
          ),
        );
      default:
        break;
    }
  }
  flushSteps();
  return blocks;
}

List<TimelineProjectedStep> _interleaveReasoningAndTools({
  required List<TimelineToolRef> liveTools,
  required List<TimelineReasoningRef> reasoningSegments,
}) {
  var sourceOrdinal = 0;
  var assignedFallback = 0;
  TimelineToolRef withFallback(TimelineToolRef tool) {
    if (tool.providerId.trim().isNotEmpty) return tool;
    return tool.copyWith(fallbackOrdinal: assignedFallback++);
  }

  if (reasoningSegments.isEmpty) {
    var toolCount = 0;
    return [
      for (final tool in liveTools)
        TimelineProjectedStep.tool(
          sourceOrdinal: sourceOrdinal++,
          tool: withFallback(tool),
          reasoningCountAfter: 0,
          toolCountAfter: ++toolCount,
        ),
    ];
  }

  final steps = <TimelineProjectedStep>[];
  var reasoningCount = 0;
  var toolCount = 0;
  var toolIndex = 0;

  for (var i = 0; i < reasoningSegments.length; i++) {
    final segment = reasoningSegments[i];
    final segmentToolStart = segment.toolStartIndex.clamp(0, liveTools.length);
    while (toolIndex < segmentToolStart && toolIndex < liveTools.length) {
      steps.add(
        TimelineProjectedStep.tool(
          sourceOrdinal: sourceOrdinal++,
          tool: withFallback(liveTools[toolIndex]),
          reasoningCountAfter: reasoningCount,
          toolCountAfter: ++toolCount,
        ),
      );
      toolIndex++;
    }
    if (segment.text.isNotEmpty) {
      steps.add(
        TimelineProjectedStep.reasoning(
          sourceOrdinal: sourceOrdinal++,
          reasoning: segment,
          reasoningCountAfter: ++reasoningCount,
          toolCountAfter: toolCount,
          reasoningOverlayIndex: i,
        ),
      );
    }
    final nextToolBoundary = i < reasoningSegments.length - 1
        ? reasoningSegments[i + 1].toolStartIndex.clamp(0, liveTools.length)
        : liveTools.length;
    while (toolIndex < nextToolBoundary && toolIndex < liveTools.length) {
      steps.add(
        TimelineProjectedStep.tool(
          sourceOrdinal: sourceOrdinal++,
          tool: withFallback(liveTools[toolIndex]),
          reasoningCountAfter: reasoningCount,
          toolCountAfter: ++toolCount,
        ),
      );
      toolIndex++;
    }
  }
  while (toolIndex < liveTools.length) {
    steps.add(
      TimelineProjectedStep.tool(
        sourceOrdinal: sourceOrdinal++,
        tool: withFallback(liveTools[toolIndex]),
        reasoningCountAfter: reasoningCount,
        toolCountAfter: ++toolCount,
      ),
    );
    toolIndex++;
  }
  return steps;
}

List<TimelineProjectedStep> _filteredThinkingSteps(
  TimelineProjectedBlock block, {
  required bool showThinkingCards,
  required bool showToolCards,
  required bool Function(TimelineToolRef tool) isPendingApproval,
}) {
  if (!block.isThinking) return const [];
  return [
    for (final step in block.steps)
      if (step.isReasoning
          ? showThinkingCards
          : isTimelineToolVisible(
              toolName: step.tool!.toolName,
              loading: step.tool!.loading,
              showToolCards: showToolCards,
              pendingApproval: isPendingApproval(step.tool!),
            ))
        step,
  ];
}

VisibleTimelineBlock? _visibleThinkingFromProjected(
  TimelineProjectedBlock block, {
  required bool showThinkingCards,
  required bool showToolCards,
  required bool collapseThinkingSteps,
  required bool Function(TimelineToolRef tool) isPendingApproval,
}) {
  final filtered = _filteredThinkingSteps(
    block,
    showThinkingCards: showThinkingCards,
    showToolCards: showToolCards,
    isPendingApproval: isPendingApproval,
  );
  if (filtered.isEmpty) return null;
  final collapsed = collapseTimelineSteps(
    filtered,
    collapseThinkingSteps: collapseThinkingSteps,
  );
  return VisibleTimelineBlock(
    visibleSteps: collapsed.visibleSteps,
    hiddenCount: collapsed.hiddenCount,
  );
}

/// Visibility filter + per-block collapse. Expand-row is [VisibleTimelineBlock.hasExpandRow].
List<VisibleTimelineBlock> collapseProjectedTimeline(
  List<TimelineProjectedBlock> blocks, {
  required bool showThinkingCards,
  required bool showToolCards,
  required bool collapseThinkingSteps,
  required bool Function(TimelineToolRef tool) isPendingApproval,
}) {
  return [
    for (final block in blocks)
      if (_visibleThinkingFromProjected(
            block,
            showThinkingCards: showThinkingCards,
            showToolCards: showToolCards,
            collapseThinkingSteps: collapseThinkingSteps,
            isPendingApproval: isPendingApproval,
          )
          case final visible?)
        visible,
  ];
}

/// Final visible assistant blocks after settings and approval filters.
///
/// Renderer and estimator both walk this list and apply the same 8px gaps.
List<TimelineVisibleBlock> visibleAssistantTimeline(
  TimelineProjection projection, {
  required bool showThinkingCards,
  required bool showToolCards,
  required bool Function(TimelineToolRef tool) isPendingApproval,
}) {
  final visible = <TimelineVisibleBlock>[];
  for (final block in projection.blocks) {
    if (block.isText && (block.text?.trim().isNotEmpty ?? false)) {
      visible.add(TimelineVisibleBlock.text(block.text!));
      continue;
    }
    if (block.isImage && (block.imageUri?.trim().isNotEmpty ?? false)) {
      visible.add(
        TimelineVisibleBlock.image(
          block.imageUri!,
          imageKey: block.imageKey,
          aspectRatio:
              block.aspectRatio ?? timelineImageAspects[block.imageKey],
        ),
      );
      continue;
    }
    final thinking = _filteredThinkingSteps(
      block,
      showThinkingCards: showThinkingCards,
      showToolCards: showToolCards,
      isPendingApproval: isPendingApproval,
    );
    if (thinking.isNotEmpty) {
      visible.add(TimelineVisibleBlock.thinking(thinking));
    }
  }
  return visible;
}

int visibleTimelineStepCount(List<VisibleTimelineBlock> blocks) {
  var count = 0;
  for (final block in blocks) {
    count += block.visibleSteps.length;
  }
  return count;
}
