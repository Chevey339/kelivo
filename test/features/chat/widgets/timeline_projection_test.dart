import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
import 'package:Kelivo/features/chat/widgets/timeline_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

TimelineToolRef _live({
  required String providerId,
  required int fallbackOrdinal,
  required String toolName,
  required String content,
}) {
  return TimelineToolRef(
    providerId: providerId,
    fallbackOrdinal: fallbackOrdinal,
    toolName: toolName,
    arguments: const <String, dynamic>{},
    content: content,
  );
}

List<TimelineToolRef> _toolsIn(TimelineProjection projected) {
  return [
    for (final block in projected.blocks)
      if (block.isThinking)
        for (final step in block.steps)
          if (step.isTool) step.tool!,
  ];
}

void main() {
  test('parseTimelineToolPayload does not synthesize string ids', () {
    final parsed = parseTimelineToolPayload(
      '{"id":"","name":"read_file","arguments":{}}',
      fallbackOrdinal: 0,
    );
    expect(parsed, isNotNull);
    expect(parsed!.providerId, isEmpty);
    expect(parsed.fallbackOrdinal, 0);
    expect(parsed.id, isEmpty);
    expect(parsed.id, isNot('read_file-0'));
  });

  test('empty-id tools in separate blocks keep their own live tools', () {
    final projected = projectAssistantTimeline(
      parts: const [
        ToolCallPart(
          '{"id":"","name":"read_file","arguments":{},"content":"A"}',
        ),
        TextPart('middle'),
        ToolCallPart(
          '{"id":"","name":"read_file","arguments":{},"content":"B"}',
        ),
      ],
      liveTools: [
        _live(
          providerId: '',
          fallbackOrdinal: 0,
          toolName: 'read_file',
          content: 'LIVE-A',
        ),
        _live(
          providerId: '',
          fallbackOrdinal: 1,
          toolName: 'read_file',
          content: 'LIVE-B',
        ),
      ],
      reasoningSegments: const [],
      visualContent: '',
    );

    expect(projected.fromParts, isTrue);
    expect(projected.blocks, hasLength(3));
    expect(projected.blocks[0].isThinking, isTrue);
    expect(projected.blocks[1].isText, isTrue);
    expect(projected.blocks[2].isThinking, isTrue);
    final tools = _toolsIn(projected);
    expect(tools, hasLength(2));
    expect(tools[0].content, 'LIVE-A');
    expect(tools[1].content, 'LIVE-B');
    expect(projected.partsArrivalOrdered, isFalse);
    expect(projected.fromParts, isTrue);
    expect(tools[0].providerId, isEmpty);
    expect(tools[1].providerId, isEmpty);
    expect(tools[0].fallbackOrdinal, 0);
    expect(tools[1].fallbackOrdinal, 1);
  });

  test('empty-id builtin_search is not assigned to a real tool', () {
    final projected = projectAssistantTimeline(
      parts: const [
        ToolCallPart(
          '{"id":"","name":"builtin_search","arguments":{},"content":"hits"}',
        ),
        ToolCallPart(
          '{"id":"t1","name":"read_file","arguments":{},"content":"file"}',
        ),
      ],
      liveTools: [
        _live(
          providerId: '',
          fallbackOrdinal: 0,
          toolName: kBuiltinSearchToolName,
          content: 'SEARCH',
        ),
        _live(
          providerId: 't1',
          fallbackOrdinal: 1,
          toolName: 'read_file',
          content: 'LIVE-FILE',
        ),
      ],
      reasoningSegments: const [],
      visualContent: '',
    );

    final tools = _toolsIn(projected);
    expect(tools, hasLength(1));
    expect(tools.single.toolName, 'read_file');
    expect(tools.single.content, 'LIVE-FILE');
    expect(tools.single.providerId, 't1');
  });

  test('empty-id fallback does not collide with a real id read_file-0', () {
    final projected = projectAssistantTimeline(
      parts: const [
        ToolCallPart(
          '{"id":"","name":"read_file","arguments":{},"content":"a"}',
        ),
        ToolCallPart(
          '{"id":"read_file-0","name":"grep","arguments":{},"content":"b"}',
        ),
      ],
      liveTools: [
        _live(
          providerId: 'read_file-0',
          fallbackOrdinal: 0,
          toolName: 'grep',
          content: 'GREP-LIVE',
        ),
        _live(
          providerId: '',
          fallbackOrdinal: 1,
          toolName: 'read_file',
          content: 'READ-LIVE',
        ),
      ],
      reasoningSegments: const [],
      visualContent: '',
    );

    final tools = _toolsIn(projected);
    expect(tools.map((tool) => tool.toolName), ['read_file', 'grep']);
    expect(tools[0].content, 'READ-LIVE');
    expect(tools[1].content, 'GREP-LIVE');
    expect(tools[0].providerId, isEmpty);
    expect(tools[1].providerId, 'read_file-0');
    expect(
      timelineToolStepKey(
        id: tools[0].providerId,
        sourceOrdinal: 0,
        toolName: tools[0].toolName,
      ),
      isNot(
        timelineToolStepKey(
          id: tools[1].providerId,
          sourceOrdinal: 1,
          toolName: tools[1].toolName,
        ),
      ),
    );
  });

  test('ImagePart projects as an image block, not markdown', () {
    final hugeUri = 'data:image/png;base64,${'A' * 4000}';
    final projected = projectAssistantTimeline(
      parts: [
        ImagePart(uri: hugeUri),
        const TextPart('hello'),
      ],
      liveTools: const [],
      reasoningSegments: const [],
      visualContent: '',
    );

    expect(projected.fromParts, isTrue);
    expect(projected.blocks, hasLength(2));
    expect(projected.blocks[0].isImage, isTrue);
    expect(projected.blocks[0].imageUri, hugeUri);
    expect(projected.blocks[0].text, isNull);
    expect(projected.blocks[0].imageUri, isNot(contains('![image]')));
    expect(projected.blocks[1].isText, isTrue);
    expect(projected.blocks[1].text, 'hello');
    expect(projected.blocks[0].imageKey, isNot(contains(hugeUri)));
    expect(
      projected.blocks[0].imageKey,
      timelineImageBlockKey(sourceOrdinal: 0),
    );
  });

  test('legal historical splits keep prefix then thinking then suffix', () {
    final projected = projectAssistantTimeline(
      parts: const [ReasoningPart('plan'), TextPart('beforeAFTER')],
      liveTools: const [],
      reasoningSegments: const [TimelineReasoningRef(text: 'plan')],
      visualContent: 'beforeAFTER',
      contentSplitOffsets: const [6],
      reasoningCountAtSplit: const [1],
      toolCountAtSplit: const [0],
    );

    expect(projected.partsArrivalOrdered, isFalse);
    expect(projected.fromParts, isFalse);
    expect(projected.blocks, hasLength(3));
    expect(projected.blocks[0].text, 'before');
    expect(projected.blocks[1].isThinking, isTrue);
    expect(projected.blocks[2].text, 'AFTER');
  });

  test('streaming partsArrivalOrdered keeps arrival order', () {
    final projected = projectAssistantTimeline(
      parts: const [ReasoningPart('plan'), TextPart('beforeAFTER')],
      liveTools: const [],
      reasoningSegments: const [TimelineReasoningRef(text: 'plan')],
      visualContent: 'beforeAFTER',
      contentSplitOffsets: const [6],
      reasoningCountAtSplit: const [1],
      toolCountAtSplit: const [0],
      partsArrivalOrdered: true,
    );

    expect(projected.partsArrivalOrdered, isTrue);
    expect(projected.fromParts, isTrue);
    expect(projected.blocks[0].isThinking, isTrue);
    expect(projected.blocks[1].text, 'beforeAFTER');
  });

  test('tool memo signature changes when only arguments change', () {
    final before = parseTimelineToolPayload(
      '{"id":"t1","name":"read_file","arguments":{"path":"a.dart"},"content":"ok"}',
    );
    final after = parseTimelineToolPayload(
      '{"id":"t1","name":"read_file","arguments":{"path":"b.dart"},"content":"ok"}',
    );
    expect(before, isNotNull);
    expect(after, isNotNull);
    expect(before!.memoToken, isNot(after!.memoToken));
  });

  test('shared reasoning loading matches finishedAt and streaming', () {
    expect(
      timelineReasoningLoading(finishedAt: null, isStreaming: true),
      isTrue,
    );
    expect(
      timelineReasoningLoading(
        finishedAt: DateTime.utc(2026, 1, 1),
        isStreaming: true,
      ),
      isFalse,
    );
    expect(
      timelineReasoningLoading(finishedAt: null, isStreaming: false),
      isFalse,
    );
  });
}
