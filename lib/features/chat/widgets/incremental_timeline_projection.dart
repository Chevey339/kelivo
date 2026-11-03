import '../../../core/models/message_part.dart';
import '../../../core/models/message_part_snapshot.dart';
import '../../../utils/source_text_map.dart';
import 'timeline_projection.dart';
import 'timeline_visibility.dart';

/// Incremental projection of arrival-ordered parts. A changed old part rewinds
/// to its cursor; stable blocks and steps before it retain their identities.
/// Regex/inline-thinking/GenUI transformations use the full projector instead.
class IncrementalTimelineProjection {
  MessagePartSnapshot? _parts;
  List<TimelineToolRef>? _liveTools;
  List<TimelineReasoningRef> _reasoning = const [];
  final _liveById = <String, TimelineToolRef>{};
  final _blocks = <TimelineProjectedBlock>[];
  var _pending = <TimelineProjectedStep>[];
  final _cursors = <_Cursor>[];
  final _toolPositions = <String, List<int>>{};
  final _reasoningPositions = <int>[];
  final _partToolIds = <String?>[];
  List<TimelineToolRef> _emptyTools = const [];
  TimelineProjection? _projection;
  int projectedPartCount = 0;

  TimelineProjection project({
    required MessagePartSnapshot parts,
    required List<TimelineToolRef> liveTools,
    required List<TimelineReasoningRef> reasoning,
  }) {
    final previous = _parts;
    final changed = previous == null ? null : parts.changesSince(previous);
    var start = changed == null ? 0 : parts.length;
    if (changed != null) {
      for (final index in changed) {
        if (index < start) start = index;
      }
    }
    if (!identical(liveTools, _liveTools)) {
      final next = {
        for (final tool in liveTools)
          if (tool.toolName != kBuiltinSearchToolName)
            tool.providerId.trim(): tool,
      };
      // No-id overlays are positional, so use a full rewind for that rare case.
      if (next.containsKey('') || _liveById.containsKey('')) start = 0;
      for (final id in {..._liveById.keys, ...next.keys}) {
        if (identical(_liveById[id], next[id])) continue;
        for (final index in _toolPositions[id] ?? const <int>[]) {
          if (index < start) start = index;
        }
      }
      _liveById
        ..clear()
        ..addAll(next);
      _liveTools = liveTools;
      _emptyTools = liveTools
          .where(
            (tool) =>
                tool.toolName != kBuiltinSearchToolName &&
                tool.providerId.trim().isEmpty,
          )
          .toList();
    }
    final reasonCount = reasoning.length > _reasoning.length
        ? reasoning.length
        : _reasoning.length;
    for (var i = 0; i < reasonCount; i++) {
      if (i < reasoning.length &&
          i < _reasoning.length &&
          _reasoningKey(reasoning[i]) == _reasoningKey(_reasoning[i])) {
        continue;
      }
      if (i < _reasoningPositions.length && _reasoningPositions[i] < start) {
        start = _reasoningPositions[i];
      }
    }
    _reasoning = reasoning;
    if (previous != null &&
        changed != null &&
        changed.isEmpty &&
        start == parts.length &&
        _projection != null) {
      return _projection!;
    }
    start = start.clamp(0, _cursors.length);
    final cursor = start == 0 ? const _Cursor() : _cursors[start - 1];
    final oldPending = cursor.blocks < _blocks.length
        ? _blocks[cursor.blocks].steps
        : _pending;
    TimelineProjectedBlock? reusablePending;
    if (cursor.pending > 0 && oldPending.length == cursor.pending) {
      reusablePending = cursor.blocks < _blocks.length
          ? _blocks[cursor.blocks]
          : _projection?.blocks.last;
    }
    _pending = oldPending.take(cursor.pending).toList();
    _blocks.length = cursor.blocks;
    _cursors.length = start;
    while (_reasoningPositions.isNotEmpty &&
        _reasoningPositions.last >= start) {
      _reasoningPositions.removeLast();
    }
    for (var index = _partToolIds.length - 1; index >= start; index--) {
      final id = _partToolIds[index];
      if (id == null) continue;
      final positions = _toolPositions[id]!;
      positions.removeLast();
      if (positions.isEmpty) _toolPositions.remove(id);
    }
    _partToolIds.length = start;
    var toolCount = cursor.tools;
    var reasoningCount = cursor.reasoning;
    var imageCount = cursor.images;
    var textOffset = cursor.textOffset;
    var sourceOrdinal = cursor.steps;
    void flush() {
      if (_pending.isEmpty) return;
      _blocks.add(
        reusablePending ??
            TimelineProjectedBlock.thinking(List.unmodifiable(_pending)),
      );
      reusablePending = null;
      _pending = [];
    }

    var emptyToolIndex = cursor.emptyTools;

    for (var index = start; index < parts.length; index++) {
      projectedPartCount++;
      final part = parts[index];
      _partToolIds.add(null);
      switch (part) {
        case TextPart(:final text):
          if (text.trim().isNotEmpty) {
            flush();
            _blocks.add(
              TimelineProjectedBlock.text(
                text,
                sourceMap: SourceTextMap.identity(
                  text.length,
                  offset: textOffset,
                ),
              ),
            );
          }
          textOffset += text.length;
        case ReasoningPart(:final text):
          final overlayIndex = reasoningCount++;
          final overlay = overlayIndex < reasoning.length
              ? reasoning[overlayIndex]
              : null;
          // Empty parts still own an overlay and must be invalidated when
          // their activity changes without any text or part mutation.
          _reasoningPositions.add(index);
          final ordinal = sourceOrdinal++;
          if (text.isNotEmpty || overlay?.loading == true) {
            reusablePending = null;
            _pending.add(
              TimelineProjectedStep.reasoning(
                sourceOrdinal: ordinal,
                reasoning: TimelineReasoningRef(
                  text: text,
                  expanded: overlay?.expanded ?? false,
                  loading: overlay?.loading ?? false,
                  startAt: overlay?.startAt,
                  finishedAt: overlay?.finishedAt,
                  toolStartIndex: overlay?.toolStartIndex ?? toolCount,
                ),
                reasoningOverlayIndex: overlay == null ? null : overlayIndex,
                reasoningCountAfter: reasoningCount,
                toolCountAfter: toolCount,
              ),
            );
          }
        case ToolCallPart():
          final parsed = parseTimelineToolPart(
            part,
            fallbackOrdinal: toolCount,
          );
          if (parsed != null && parsed.toolName != kBuiltinSearchToolName) {
            final id = parsed.providerId.trim();
            (_toolPositions[id] ??= []).add(index);
            _partToolIds[index] = id;
            final live = id.isEmpty
                ? (emptyToolIndex < _emptyTools.length
                      ? _emptyTools[emptyToolIndex++]
                      : null)
                : _liveById[id];
            reusablePending = null;
            _pending.add(
              TimelineProjectedStep.tool(
                sourceOrdinal: sourceOrdinal++,
                tool:
                    live?.copyWith(fallbackOrdinal: parsed.fallbackOrdinal) ??
                    parsed,
                reasoningCountAfter: reasoningCount,
                toolCountAfter: ++toolCount,
              ),
            );
          }
        case ImagePart(:final uri):
          if (timelineImagePartFlushesBlock(part)) {
            flush();
            final key = timelineImageBlockKey(
              imageId: part.id,
              assetId: part.assetId,
              sourceOrdinal: imageCount++,
            );
            _blocks.add(
              TimelineProjectedBlock.image(
                uri,
                imageKey: key,
                aspectRatio: timelineImageAspects[key],
              ),
            );
          }
        default:
          break;
      }
      _cursors.add(
        _Cursor(
          blocks: _blocks.length,
          pending: _pending.length,
          tools: toolCount,
          emptyTools: emptyToolIndex,
          reasoning: reasoningCount,
          images: imageCount,
          textOffset: textOffset,
          steps: sourceOrdinal,
        ),
      );
    }
    _parts = parts;
    return _projection = TimelineProjection(
      fromParts: true,
      partsArrivalOrdered: true,
      previous: _projection == null ? null : WeakReference(_projection!),
      unchangedBlockPrefix: cursor.blocks,
      blocks: List.unmodifiable([
        ..._blocks,
        if (_pending.isNotEmpty)
          reusablePending ??
              TimelineProjectedBlock.thinking(List.unmodifiable(_pending)),
      ]),
    );
  }

  static Object _reasoningKey(TimelineReasoningRef value) => (
    value.text,
    value.expanded,
    value.loading,
    value.startAt,
    value.finishedAt,
    value.toolStartIndex,
  );
}

class _Cursor {
  const _Cursor({
    this.blocks = 0,
    this.pending = 0,
    this.tools = 0,
    this.emptyTools = 0,
    this.reasoning = 0,
    this.images = 0,
    this.textOffset = 0,
    this.steps = 0,
  });
  final int blocks,
      pending,
      tools,
      emptyTools,
      reasoning,
      images,
      textOffset,
      steps;
}
