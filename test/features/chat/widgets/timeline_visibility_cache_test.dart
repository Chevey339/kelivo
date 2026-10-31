import 'dart:convert';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/message_part_snapshot.dart';
import 'package:Kelivo/features/chat/widgets/incremental_timeline_projection.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interleaved text updates filter only the changed block suffix', () {
    final snapshots = MessagePartSnapshotBuilder(arrivalOrdered: true);
    final projector = IncrementalTimelineProjection();
    final visibility = TimelineVisibilityCache();
    final parts = <MessagePart>[
      for (var i = 0; i < 5000; i++) ...[
        ToolCallPart(
          jsonEncode({'id': 't$i', 'name': 'shell', 'content': 'done'}),
        ),
        TextPart('explanation $i'),
      ],
    ];
    var projection = projector.project(
      parts: snapshots.update(parts),
      liveTools: const [],
      reasoning: const [],
    );
    final original = visibility.project(
      projection,
      showThinkingCards: true,
      showToolCards: true,
      isPendingApproval: (_) => false,
    );
    expect(original, hasLength(10000));
    expect(projection.previous, isNull);
    for (var i = 0; i < 10; i++) {
      final previous = projection;
      final before = visibility.filteredBlockCount;
      parts[9999] = TextPart('tail $i');
      projection = projector.project(
        parts: snapshots.update(parts, changed: {9999}),
        liveTools: const [],
        reasoning: const [],
      );
      expect(projection.previous?.target, same(previous));
      expect(projection.unchangedBlockPrefix, 9998);
      final visible = visibility.project(
        projection,
        showThinkingCards: true,
        showToolCards: true,
        isPendingApproval: (_) => false,
      );
      expect(visibility.filteredBlockCount - before, 2);
      expect(visible, hasLength(10000));
      expect(visible.first, same(original.first));
      expect(visible.last.text, 'tail $i');
      expect(original.last.text, 'explanation 4999');
      expect(() => visible.clear(), throwsUnsupportedError);
      expect(
        visibility.project(
          projection,
          showThinkingCards: true,
          showToolCards: true,
          isPendingApproval: (_) => true,
        ),
        same(visible),
      );
      expect(visibility.filteredBlockCount - before, 2);
    }
  });

  test(
    'hidden blocks use visible prefix counts and settings invalidate them',
    () {
      final snapshots = MessagePartSnapshotBuilder(arrivalOrdered: true);
      final projector = IncrementalTimelineProjection();
      final visibility = TimelineVisibilityCache();
      final parts = <MessagePart>[
        const ReasoningPart('first plan'),
        const TextPart('first body'),
        const ReasoningPart('second plan'),
        const TextPart('second body'),
      ];
      var projection = projector.project(
        parts: snapshots.update(parts),
        liveTools: const [],
        reasoning: const [],
      );
      final original = _expectMatches(visibility, projection, thinking: false);
      expect(original.map((block) => block.text), [
        'first body',
        'second body',
      ]);
      final before = visibility.filteredBlockCount;
      parts[3] = const TextPart('updated body');
      projection = projector.project(
        parts: snapshots.update(parts, changed: {3}),
        liveTools: const [],
        reasoning: const [],
      );
      final updated = _expectMatches(visibility, projection, thinking: false);
      expect(visibility.filteredBlockCount - before, 2);
      expect(updated.map((block) => block.text), [
        'first body',
        'updated body',
      ]);
      expect(updated.first, same(original.first));
      final beforeSettings = visibility.filteredBlockCount;
      expect(_expectMatches(visibility, projection), hasLength(4));
      expect(visibility.filteredBlockCount - beforeSettings, 4);
      expect(
        _expectMatches(visibility, projection, thinking: false),
        hasLength(2),
      );
      expect(original.last.text, 'second body');
    },
  );

  test(
    'empty, appended, edited, truncated and reset sources match full filtering',
    () {
      var snapshots = MessagePartSnapshotBuilder(arrivalOrdered: true);
      var projector = IncrementalTimelineProjection();
      final visibility = TimelineVisibilityCache();
      final parts = <MessagePart>[];
      TimelineProjection? previous;
      TimelineProjection check() {
        final projection = projector.project(
          parts: snapshots.update(parts),
          liveTools: const [],
          reasoning: const [],
        );
        final prior = previous;
        if (prior != null && identical(projection.previous?.target, prior)) {
          for (var i = 0; i < projection.unchangedBlockPrefix; i++) {
            expect(projection.blocks[i], same(prior.blocks[i]));
          }
        }
        _expectMatches(visibility, projection, thinking: false);
        previous = projection;
        return projection;
      }

      expect(check().blocks, isEmpty);
      parts.add(const ReasoningPart('hidden'));
      check();
      parts.add(const TextPart('first'));
      check();
      parts.addAll(const [
        ToolCallPart('{"id":"tool","name":"shell","content":"done"}'),
        TextPart('tail'),
        ImagePart(uri: 'file:///tmp/visible.png', id: 'picture'),
      ]);
      check();
      parts[1] = const TextPart('rewritten first body');
      check();
      parts[2] = const ToolCallPart(
        '{"id":"tool","name":"shell","content":"corrected"}',
      );
      check();
      final last = parts.removeLast();
      parts.insert(0, last);
      check();
      parts.removeRange(2, parts.length);
      check();
      parts.clear();
      expect(check().blocks, isEmpty);
      parts.add(const TextPart('new source'));
      snapshots = MessagePartSnapshotBuilder(arrivalOrdered: true);
      expect(check().unchangedBlockPrefix, 0);
      projector = IncrementalTimelineProjection();
      final before = visibility.filteredBlockCount;
      expect(check().previous, isNull);
      expect(visibility.filteredBlockCount - before, 1);
    },
  );

  test(
    'skipped projections and ordinary projections rebuild the visible result',
    () {
      final snapshots = MessagePartSnapshotBuilder(arrivalOrdered: true);
      final projector = IncrementalTimelineProjection();
      final visibility = TimelineVisibilityCache();
      final parts = <MessagePart>[
        const TextPart('first'),
        const TextPart('tail'),
      ];
      TimelineProjection project() => projector.project(
        parts: snapshots.update(parts),
        liveTools: const [],
        reasoning: const [],
      );
      _expectMatches(visibility, project());
      parts[0] = const TextPart('edited while hidden');
      final skipped = project();
      parts[1] = const TextPart('current tail');
      final current = project();
      expect(current.previous?.target, same(skipped));
      expect(current.unchangedBlockPrefix, 1);
      final before = visibility.filteredBlockCount;
      final visible = _expectMatches(visibility, current);
      expect(visibility.filteredBlockCount - before, 2);
      expect(visible.first.text, 'edited while hidden');

      final ordinary = TimelineProjection(
        fromParts: true,
        blocks: [
          current.blocks.first,
          const TimelineProjectedBlock.text('full'),
        ],
      );
      final beforeOrdinary = visibility.filteredBlockCount;
      expect(_expectMatches(visibility, ordinary).last.text, 'full');
      expect(visibility.filteredBlockCount - beforeOrdinary, 2);
      expect(visible.last.text, 'current tail');
    },
  );

  test(
    'hidden tool cards recheck approvals even for an identical projection',
    () {
      const projection = TimelineProjection(
        fromParts: true,
        blocks: [
          TimelineProjectedBlock.thinking([
            TimelineProjectedStep.tool(
              sourceOrdinal: 0,
              reasoningCountAfter: 0,
              toolCountAfter: 1,
              tool: TimelineToolRef(
                providerId: 'pending',
                fallbackOrdinal: 0,
                toolName: 'shell',
                arguments: {},
                loading: true,
              ),
            ),
          ]),
          TimelineProjectedBlock.text('body'),
        ],
      );
      final visibility = TimelineVisibilityCache();
      final hidden = _expectMatches(visibility, projection, tools: false);
      expect(hidden, hasLength(1));
      final before = visibility.filteredBlockCount;
      final approved = _expectMatches(
        visibility,
        projection,
        tools: false,
        pending: true,
      );
      expect(approved, hasLength(2));
      expect(visibility.filteredBlockCount - before, 2);
      expect(
        _expectMatches(visibility, projection, tools: false),
        hasLength(1),
      );
      expect(_expectMatches(visibility, projection), hasLength(2));
      expect(
        _expectMatches(visibility, projection, tools: false),
        hasLength(1),
      );
      expect(hidden, hasLength(1));
      expect(approved, hasLength(2));
    },
  );
}

List<TimelineVisibleBlock> _expectMatches(
  TimelineVisibilityCache cache,
  TimelineProjection projection, {
  bool thinking = true,
  bool tools = true,
  bool pending = false,
}) {
  final visible = cache.project(
    projection,
    showThinkingCards: thinking,
    showToolCards: tools,
    isPendingApproval: (_) => pending,
  );
  expect(
    _describeVisible(visible),
    _describeVisible(
      visibleAssistantTimeline(
        projection,
        showThinkingCards: thinking,
        showToolCards: tools,
        isPendingApproval: (_) => pending,
      ),
    ),
  );
  return visible;
}

Object _describeVisible(List<TimelineVisibleBlock> blocks) => [
  for (final block in blocks)
    if (block.isText)
      [
        'text',
        block.text,
        block.sourceMap?.sourceRange(0, block.text!.length).start,
        block.sourceMap?.sourceRange(0, block.text!.length).end,
      ]
    else if (block.isImage)
      ['image', block.imageUri, block.imageKey, block.aspectRatio]
    else
      [
        for (final step in block.thinkingSteps)
          [
            step.sourceOrdinal,
            step.reasoning?.text,
            step.tool?.id,
            step.tool?.content,
            step.tool?.loading,
          ],
      ],
];
