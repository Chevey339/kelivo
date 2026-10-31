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
            step.tool?.content,
            step.tool?.fallbackOrdinal,
          ],
      ],
];

void main() {
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
