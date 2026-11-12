import 'dart:convert';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/message_part_snapshot.dart';
import 'package:Kelivo/features/chat/widgets/incremental_timeline_projection.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:flutter_test/flutter_test.dart';

Object describe(TimelineProjection projection) => [
  for (final block in projection.blocks)
    if (block.isText)
      ['text', block.text]
    else if (block.isImage)
      ['image', block.imageUri, block.imageKey]
    else
      [
        for (final step in block.steps)
          [
            step.sourceOrdinal,
            step.reasoningCountAfter,
            step.toolCountAfter,
            step.reasoningOverlayIndex,
            step.reasoning?.text,
            step.reasoning?.expanded,
            step.tool?.id,
            step.tool?.toolName,
            step.tool?.content,
            step.tool?.fallbackOrdinal,
          ],
      ],
];

void main() {
  test('empty reasoning is visible only while active in both projectors', () {
    final builder = MessagePartSnapshotBuilder(arrivalOrdered: true);
    final projector = IncrementalTimelineProjection();
    final parts = builder.update(const [ReasoningPart('')]);
    for (final loading in [true, false, true]) {
      final reasoning = [TimelineReasoningRef(text: '', loading: loading)];
      final incremental = projector.project(
        parts: parts,
        liveTools: const [],
        reasoning: reasoning,
      );
      final full = projectAssistantTimeline(
        parts: parts,
        liveTools: const [],
        reasoningSegments: reasoning,
        visualContent: '',
        partsArrivalOrdered: true,
      );
      for (final projection in [incremental, full]) {
        expect(projection.blocks, hasLength(loading ? 1 : 0));
        if (loading) {
          expect(
            projection.blocks.single.steps.single.reasoning!.loading,
            isTrue,
          );
        }
      }
    }
  });

  test('hidden empty reasoning keeps subsequent overlays aligned', () {
    final builder = MessagePartSnapshotBuilder(arrivalOrdered: true);
    final projector = IncrementalTimelineProjection();
    final parts = builder.update(const [
      ReasoningPart(''),
      ToolCallPart('{"id":"t","name":"shell","content":"done"}'),
      ReasoningPart('summary'),
    ]);
    final start = DateTime(2026, 11, 2);
    for (final loading in [true, false]) {
      final reasoning = [
        const TimelineReasoningRef(text: '', expanded: false),
        TimelineReasoningRef(text: 'summary', loading: loading, startAt: start),
      ];
      final incremental = projector.project(
        parts: parts,
        liveTools: const [],
        reasoning: reasoning,
      );
      final full = projectAssistantTimeline(
        parts: parts,
        liveTools: const [],
        reasoningSegments: reasoning,
        visualContent: '',
        partsArrivalOrdered: true,
      );
      for (final projection in [incremental, full]) {
        final steps = projection.blocks.single.steps;
        expect(steps, hasLength(2));
        expect(steps.last.reasoningOverlayIndex, 1);
        expect(steps.last.reasoning!.startAt, start);
        expect(steps.last.reasoning!.loading, loading);
      }
    }
  });

  test('ending empty reasoning preserves the following tool identity', () {
    final parts = MessagePartSnapshotBuilder(arrivalOrdered: true).update(
      const [ReasoningPart(''), ToolCallPart('{"id":"t","name":"shell"}')],
    );
    final projector = IncrementalTimelineProjection();
    for (final loading in [true, false]) {
      final reasoning = [TimelineReasoningRef(text: '', loading: loading)];
      final incremental = projector.project(
        parts: parts,
        liveTools: const [],
        reasoning: reasoning,
      );
      final full = projectAssistantTimeline(
        parts: parts,
        liveTools: const [],
        reasoningSegments: reasoning,
        visualContent: '',
        partsArrivalOrdered: true,
      );
      for (final projection in [incremental, full]) {
        expect(projection.blocks.single.steps.last.sourceOrdinal, 1);
      }
    }
  });

  test('suffix rewinds retain the no-ID overlay position', () {
    final builder = MessagePartSnapshotBuilder(arrivalOrdered: true);
    final projector = IncrementalTimelineProjection();
    final parts = <MessagePart>[
      const ToolCallPart('{"name":"shell"}'),
      const TextPart('before'),
      const ToolCallPart('{"name":"write_file"}'),
    ];
    const live = [
      TimelineToolRef(
        providerId: '',
        fallbackOrdinal: 0,
        toolName: 'shell',
        arguments: {},
        content: 'first result',
      ),
      TimelineToolRef(
        providerId: '',
        fallbackOrdinal: 1,
        toolName: 'write_file',
        arguments: {},
        content: 'second result',
      ),
    ];
    final original = projector.project(
      parts: builder.update(parts),
      liveTools: live,
      reasoning: const [],
    );
    final projectedCount = projector.projectedPartCount;
    parts[1] = const TextPart('after');
    final snapshot = builder.update(parts, changed: {1});
    final actual = projector.project(
      parts: snapshot,
      liveTools: live,
      reasoning: const [],
    );
    final expected = projectAssistantTimeline(
      parts: snapshot,
      liveTools: live,
      reasoningSegments: const [],
      visualContent: 'after',
      partsArrivalOrdered: true,
      renderFromParts: true,
      parseInlineThinking: false,
    );
    expect(describe(actual), describe(expected));
    expect(actual.blocks.first, same(original.blocks.first));
    expect(actual.blocks.last.steps.single.tool!.content, 'second result');
    expect(projector.projectedPartCount - projectedCount, 2);
  });

  test('built-in search never consumes or replaces a tool overlay', () {
    final builder = MessagePartSnapshotBuilder(arrivalOrdered: true);
    final parts = builder.update(const [
      ToolCallPart('{"name":"builtin_search"}'),
      ToolCallPart('{"name":"shell"}'),
      ToolCallPart('{"id":"named","name":"read_file","content":"saved"}'),
    ]);
    const live = [
      TimelineToolRef(
        providerId: '',
        fallbackOrdinal: 0,
        toolName: 'builtin_search',
        arguments: {},
        content: 'citations',
      ),
      TimelineToolRef(
        providerId: '',
        fallbackOrdinal: 1,
        toolName: 'shell',
        arguments: {},
        content: 'shell result',
      ),
      TimelineToolRef(
        providerId: 'named',
        fallbackOrdinal: 2,
        toolName: 'builtin_search',
        arguments: {},
        content: 'other citations',
      ),
    ];
    final actual = IncrementalTimelineProjection().project(
      parts: parts,
      liveTools: live,
      reasoning: const [],
    );
    final expected = projectAssistantTimeline(
      parts: parts,
      liveTools: live,
      reasoningSegments: const [],
      visualContent: '',
      partsArrivalOrdered: true,
      renderFromParts: true,
      parseInlineThinking: false,
    );
    expect(describe(actual), describe(expected));
    expect(actual.blocks.single.steps.map((step) => step.tool!.toolName), [
      'shell',
      'read_file',
    ]);
  });

  test(
    'text after 5000 completed calls reprojects one part and reuses the group',
    () {
      final builder = MessagePartSnapshotBuilder();
      final projector = IncrementalTimelineProjection();
      final parts = <MessagePart>[
        for (var i = 0; i < 5000; i++)
          ToolCallPart(
            jsonEncode({'id': 't$i', 'name': 'shell', 'content': 'done'}),
          ),
        const TextPart('initial'),
      ];
      var snapshot = builder.update(parts);
      var projection = projector.project(
        parts: snapshot,
        liveTools: const [],
        reasoning: const [],
      );
      final group = projection.blocks.first;
      final count = projector.projectedPartCount;
      for (var i = 0; i < 10; i++) {
        parts[5000] = TextPart('tail $i');
        snapshot = builder.update(parts, changed: {5000});
        projection = projector.project(
          parts: snapshot,
          liveTools: const [],
          reasoning: const [],
        );
        expect(projection.blocks.first, same(group));
      }
      expect(projector.projectedPartCount - count, 10);
      expect(group.steps.length, 5000);
      expect(projection.blocks.last.text, 'tail 9');
    },
  );

  test(
    'append, late result, reorder and truncate match the authoritative projector',
    () {
      final builder = MessagePartSnapshotBuilder();
      final projector = IncrementalTimelineProjection();
      final parts = <MessagePart>[];
      const live = <TimelineToolRef>[];
      const reasoning = [TimelineReasoningRef(text: 'plan', expanded: true)];
      void check() {
        final snapshot = builder.update(parts);
        final actual = projector.project(
          parts: snapshot,
          liveTools: live,
          reasoning: reasoning,
        );
        final expected = projectAssistantTimeline(
          parts: snapshot,
          liveTools: live,
          reasoningSegments: reasoning,
          visualContent: parts.whereType<TextPart>().map((p) => p.text).join(),
          partsArrivalOrdered: true,
          renderFromParts: true,
          parseInlineThinking: false,
        );
        expect(describe(actual), describe(expected));
      }

      parts.add(const ReasoningPart('plan'));
      check();
      parts.add(const ToolCallPart('{"id":"a","name":"shell"}'));
      check();
      parts.add(const ToolCallPart('{"id":"b","name":"shell"}'));
      check();
      parts.add(const TextPart('explaining'));
      check();
      parts.add(const AssistantRoundEndPart());
      check();
      parts.add(const ImagePart(uri: 'file:///tmp/example.png'));
      check();
      parts.add(const ToolCallPart('{"id":"c","name":"write_file"}'));
      check();
      parts[1] = const ToolCallPart(
        '{"id":"a","name":"shell","content":"late"}',
      );
      check();
      final swap = parts[1];
      parts[1] = parts[2];
      parts[2] = swap;
      check();
      parts.removeRange(3, parts.length);
      check();
    },
  );

  test(
    'live status and old reasoning changes invalidate the affected suffix',
    () {
      final builder = MessagePartSnapshotBuilder();
      final projector = IncrementalTimelineProjection();
      final parts = builder.update(const [
        ReasoningPart('plan'),
        ToolCallPart('{"id":"a","name":"shell"}'),
      ]);
      const pending = TimelineToolRef(
        providerId: 'a',
        fallbackOrdinal: 0,
        toolName: 'shell',
        arguments: {},
        loading: true,
      );
      projector.project(
        parts: parts,
        liveTools: const [pending],
        reasoning: const [],
      );
      final complete = pending.copyWith(content: 'done', loading: false);
      final projected = projector.project(
        parts: parts,
        liveTools: [complete],
        reasoning: const [TimelineReasoningRef(text: 'plan', expanded: true)],
      );
      expect(projected.blocks.single.steps.first.reasoning!.expanded, isTrue);
      expect(projected.blocks.single.steps.last.tool!.content, 'done');
      expect(projected.blocks.single.steps.last.tool!.loading, isFalse);
    },
  );
}
