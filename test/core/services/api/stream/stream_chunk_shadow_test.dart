import 'dart:convert';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_shadow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters empty text and folds images into the text kind', () {
    final seq = sequenceFromParts(const [
      TextPart(''),
      ReasoningPart('plan'),
      ImagePart(uri: 'data:image/png;base64,aaa', mime: 'image/png'),
      TextPart('caption'),
    ]);

    expect(seq.map((item) => item.kind).toList(), ['reasoning', 'text']);
  });

  test('reconstructs reasoning then text from a leading split', () {
    final seq = sequenceFromLegacy(
      fullContentRaw: 'hello',
      offsets: const [0],
      reasoningCounts: const [1],
      toolCounts: const [0],
      toolIds: const [],
      reasoningSegments: const [(hasText: true, toolStartIndex: 0)],
    );

    expect(seq.map((item) => item.kind).toList(), ['reasoning', 'text']);
  });

  test('reconstructs reasoning, tool, then trailing text', () {
    final seq = sequenceFromLegacy(
      fullContentRaw: 'done',
      offsets: const [0],
      reasoningCounts: const [1],
      toolCounts: const [1],
      toolIds: const ['call_1'],
      reasoningSegments: const [(hasText: true, toolStartIndex: 0)],
    );

    expect(seq, [
      const ShadowSeqItem('reasoning'),
      const ShadowSeqItem('tool_call', id: 'call_1'),
      const ShadowSeqItem('text', length: 4),
    ]);
  });

  test('treats stream:false buffered reasoning as one segment', () {
    expect(
      effectiveLegacyReasoningCount(segmentCount: 0, fallbackText: 'think'),
      1,
    );
    expect(
      effectiveLegacyReasoningCount(segmentCount: 2, fallbackText: 'think'),
      2,
    );

    final seq = sequenceFromLegacy(
      fullContentRaw: 'answer',
      offsets: const [0],
      reasoningCounts: const [0],
      toolCounts: const [0],
      toolIds: const [],
      reasoningSegments: const [],
      reasoningFallbackText: 'think',
    );
    expect(seq.map((item) => item.kind).toList(), ['reasoning', 'text']);
  });

  test('chat compare matches handler parts against split triples', () {
    final handler = StreamChunkHandler();
    handler.handle(const ReasoningDelta(id: 'r', text: 'plan'));
    handler.handle(const ToolCallStart(id: 'call_1', toolName: 'lookup'));
    handler.handle(const ToolCallEnd('call_1'));
    handler.handle(const TextDelta(id: 't', text: 'done'));

    final diff = StreamChunkShadow.compareChat(
      parts: handler.parts,
      fullContentRaw: 'done',
      offsets: const [0],
      reasoningCounts: const [1],
      toolCounts: const [1],
      toolIds: const ['call_1'],
      reasoningSegments: const [(hasText: true, toolStartIndex: 0)],
    );

    expect(diff.matched, isTrue);
    expect(diff.handlerText, 'done');
    expect(diff.handlerToolIds, {'call_1'});
    expect(diff.handlerReasoningCount, 1);
  });

  test(
    'does not hide a missing handler image behind keep-count truncation',
    () {
      final handler = StreamChunkHandler();
      handler.handle(const TextDelta(id: 't', text: 'caption'));

      final diff = StreamChunkShadow.compareChat(
        parts: handler.parts,
        fullContentRaw: 'caption\n\n![image](data:image/png;base64,aaa)',
        offsets: const [],
        reasoningCounts: const [],
        toolCounts: const [],
        toolIds: const [],
        reasoningSegments: const [],
      );

      expect(diff.textMatch, isTrue);
      expect(diff.handlerImages, 0);
      expect(diff.legacyImages, 1);
      expect(diff.imagesMatch, isFalse);
      expect(diff.matched, isFalse);
    },
  );

  test('exempts only Responses partial+collected extra markdown', () {
    final handler = StreamChunkHandler();
    handler.handle(const ImageStart(id: 'img', mimeType: 'image/png'));
    handler.handle(const ImageSnapshot(id: 'img', data: 'aaa'));
    handler.handle(const ImageEnd('img'));

    final markdown = '\n\n![image](data:image/png;base64,aaa)';
    final duplicate = StreamChunkShadow.compareLegacy(
      parts: handler.parts,
      content: '$markdown$markdown',
      reasoning: '',
      toolIds: const {},
      bags: [
        ShadowBag(content: markdown),
        ShadowBag(content: markdown),
      ],
      responsesImageDuplicates: true,
    );
    expect(duplicate.handlerImages, 1);
    expect(duplicate.legacyImages, 2);
    expect(duplicate.imagesMatch, isTrue);
    expect(duplicate.textMatch, isTrue);
    expect(duplicate.matched, isTrue);

    final notResponses = StreamChunkShadow.compareLegacy(
      parts: handler.parts,
      content: '$markdown$markdown',
      reasoning: '',
      toolIds: const {},
      bags: [
        ShadowBag(content: markdown),
        ShadowBag(content: markdown),
      ],
    );
    expect(notResponses.imagesMatch, isFalse);
    expect(notResponses.matched, isFalse);

    final leaked = StreamChunkShadow.compareLegacy(
      parts: const [TextPart('caption')],
      content: 'caption$markdown',
      reasoning: '',
      toolIds: const {},
      bags: [ShadowBag(content: 'caption$markdown')],
      responsesImageDuplicates: true,
    );
    expect(leaked.handlerImages, 0);
    expect(leaked.legacyImages, 1);
    expect(leaked.imagesMatch, isFalse);
    expect(leaked.matched, isFalse);
  });

  test('masks sanitized image markdown so Gemini dual-path still matches', () {
    final handler = StreamChunkHandler();
    handler.handle(const ImageStart(id: 'img', mimeType: 'image/png'));
    handler.handle(const ImageDelta(id: 'img', data: 'aaa'));
    handler.handle(const ImageEnd('img'));

    final diff = StreamChunkShadow.compareChat(
      parts: handler.parts,
      fullContentRaw: '\n\n![image](kelivo-file://abc.png)',
      offsets: const [],
      reasoningCounts: const [],
      toolCounts: const [],
      toolIds: const [],
      reasoningSegments: const [],
    );

    expect(diff.textMatch, isTrue);
    expect(diff.handlerImages, 1);
    expect(diff.legacyImages, 1);
    expect(diff.kindsMatch, isTrue);
    expect(diff.matched, isTrue);
  });

  test('legacy compare reconstructs kind order from pre-coalesce bags', () {
    final handler = StreamChunkHandler();
    handler.handle(const ReasoningDelta(id: 'r', text: 'think'));
    handler.handle(const ToolCallStart(id: 'a', toolName: 'lookup'));
    handler.handle(const ToolCallEnd('a'));
    handler.handle(const TextDelta(id: 't', text: 'hi'));

    final bags = const [
      ShadowBag(reasoning: 'think'),
      ShadowBag(toolCallIds: ['a']),
      ShadowBag(toolResultIds: ['a']),
      ShadowBag(content: 'hi'),
    ];
    expect(sequenceFromBags(bags).map((item) => item.kind).toList(), [
      'reasoning',
      'tool_call',
      'text',
    ]);

    final match = StreamChunkShadow.compareLegacy(
      parts: handler.parts,
      content: 'hi',
      reasoning: 'think',
      toolIds: const {'a'},
      bags: bags,
    );
    expect(match.kindsMatch, isTrue);
    expect(match.matched, isTrue);

    final mismatch = StreamChunkShadow.compareLegacy(
      parts: handler.parts,
      content: 'hi',
      reasoning: 'think',
      toolIds: const {'builtin_search'},
      bags: const [
        ShadowBag(reasoning: 'think'),
        ShadowBag(toolResultIds: ['builtin_search']),
        ShadowBag(content: 'hi'),
      ],
    );
    expect(mismatch.matched, isFalse);
    expect(mismatch.toolsMatch, isFalse);
    expect(mismatch.kindsMatch, isFalse);
  });

  test('tool payload used by shadow still carries server and metadata', () {
    final handler = StreamChunkHandler();
    handler.handle(
      const ServerToolStart(
        id: 'srv_1',
        toolName: 'web_search',
        metadata: {
          'server_tool_use': {'id': 'srv_1'},
        },
      ),
    );
    handler.handle(const ServerToolEnd(id: 'srv_1', output: 'ok'));

    final payload = jsonDecode(
      (handler.parts.single as ToolCallPart).payloadJson,
    );
    expect(payload['server'], isTrue);
    expect(payload['metadata']['server_tool_use']['id'], 'srv_1');
    expect(toolIdsFromParts(handler.parts), {'srv_1'});
  });
}
