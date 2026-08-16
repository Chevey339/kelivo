import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/legacy_chunk_adapter.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyChunkAdapter mapping', () {
    test(
      'round-trips a mixed event sequence into ChatStreamChunk fields',
      () async {
        const details = <Map<String, String>>[
          {'type': 'reasoning.text', 'id': 'rd_1'},
        ];
        final adapter = LegacyChunkAdapter();
        final chunks = await adapter
            .adapt(
              Stream<StreamChunk>.fromIterable(const <StreamChunk>[
                TextStart('t1'),
                TextDelta(id: 't1', text: 'Hello'),
                ReasoningStart(id: 'r1'),
                ReasoningDelta(id: 'r1', text: 'think', details: details),
                ReasoningEnd(id: 'r1'),
                TextDelta(id: 't1', text: ' world'),
                TextEnd('t1'),
                ToolCallStart(id: 'call_1', toolName: 'search'),
                ToolCallDelta(id: 'call_1', inputDelta: '{"q":'),
                ToolCallDelta(id: 'call_1', inputDelta: '"hi"}'),
                ToolCallEnd('call_1'),
                ServerToolStart(id: 'srv_1', toolName: 'web_search'),
                ServerToolEnd(
                  id: 'srv_1',
                  output: <String, dynamic>{
                    'items': <Map<String, String>>[
                      {'url': 'https://example.com'},
                    ],
                  },
                ),
                ImageStart(id: 'img_1', mimeType: 'image/png'),
                ImageDelta(id: 'img_1', data: 'aaa'),
                ImageDelta(id: 'img_1', data: 'bbb'),
                ImageEnd('img_1'),
                Usage(
                  TokenUsage(
                    promptTokens: 2,
                    completionTokens: 4,
                    totalTokens: 6,
                  ),
                ),
                Finish(finishReason: 'stop'),
              ]),
            )
            .toList();

        expect(
          chunks.map((c) => c.content).join(),
          'Hello world\n\n![image](data:image/png;base64,aaabbb)',
        );
        expect(
          chunks.where((c) => (c.reasoning ?? '').isNotEmpty).single.reasoning,
          'think',
        );
        expect(
          chunks
              .where((c) => c.reasoningDetails != null)
              .map((c) => c.reasoningDetails),
          everyElement(details),
        );
        expect(chunks.last.reasoningDetails, details);

        final toolChunks = chunks
            .where((c) => (c.toolCalls ?? const <ToolCallInfo>[]).isNotEmpty)
            .toList();
        expect(toolChunks, hasLength(2));
        expect(toolChunks.first.toolCalls!.single.arguments, isEmpty);
        expect(toolChunks.last.toolCalls!.single.id, 'call_1');
        expect(toolChunks.last.toolCalls!.single.name, 'search');
        expect(toolChunks.last.toolCalls!.single.arguments, <String, dynamic>{
          'q': 'hi',
        });

        final resultChunk = chunks.singleWhere(
          (c) => (c.toolResults ?? const <ToolResultInfo>[]).isNotEmpty,
        );
        expect(resultChunk.toolResults!.single.id, 'srv_1');
        expect(resultChunk.toolResults!.single.name, 'web_search');
        expect(
          resultChunk.toolResults!.single.content,
          contains('example.com'),
        );

        expect(chunks.where((c) => c.isDone), hasLength(1));
        expect(chunks.last.isDone, isTrue);
        expect(chunks.last.usage?.totalTokens, 6);
        expect(chunks.last.totalTokens, 6);
      },
    );

    test('ImageSnapshot becomes a complete data:image markdown payload', () {
      final adapter = LegacyChunkAdapter();
      final chunks = adapter.handle(
        const ImageSnapshot(id: 'img', data: 'iVBORw0K'),
      );

      expect(chunks, hasLength(1));
      expect(
        chunks.single.content,
        '\n\n![image](data:image/png;base64,iVBORw0K)',
      );
      expect(chunks.single.content, contains('data:image'));
    });

    test('ToolCallStart emits a placeholder card before arguments arrive', () {
      final adapter = LegacyChunkAdapter();
      final chunks = adapter.handle(
        const ToolCallStart(id: 'call_1', toolName: 'search'),
      );

      expect(chunks.single.toolCalls!.single.id, 'call_1');
      expect(chunks.single.toolCalls!.single.name, 'search');
      expect(chunks.single.toolCalls!.single.arguments, isEmpty);
    });

    test('tolerates a ToolCallEnd without Start', () {
      final adapter = LegacyChunkAdapter();
      adapter.handle(const ToolCallDelta(id: 'x', inputDelta: '{"a":1}'));
      final chunks = adapter.handle(const ToolCallEnd('x'));

      expect(chunks.single.toolCalls!.single.id, 'x');
      expect(chunks.single.toolCalls!.single.arguments, <String, dynamic>{
        'a': 1,
      });
    });

    test('keeps the latest ToolCallDelta metadata on End', () {
      final adapter = LegacyChunkAdapter();
      adapter.handle(
        const ToolCallStart(
          id: 'call_1',
          toolName: 'search',
          metadata: <String, dynamic>{'source': 'start'},
        ),
      );
      adapter.handle(
        const ToolCallDelta(
          id: 'call_1',
          inputDelta: '{}',
          metadata: <String, dynamic>{'source': 'delta', 'signature': 'sig'},
        ),
      );
      final chunks = adapter.handle(const ToolCallEnd('call_1'));

      expect(chunks.single.toolCalls!.single.metadata, <String, dynamic>{
        'source': 'delta',
        'signature': 'sig',
      });
    });

    test('ImageSnapshot uses the mime type from ImageStart', () {
      final adapter = LegacyChunkAdapter();
      adapter.handle(const ImageStart(id: 'img', mimeType: 'image/jpeg'));
      final chunks = adapter.handle(
        const ImageSnapshot(id: 'img', data: '/9j/xx'),
      );

      expect(
        chunks.single.content,
        '\n\n![image](data:image/jpeg;base64,/9j/xx)',
      );
    });

    test('Finish closes an in-progress ImageDelta markdown', () {
      final adapter = LegacyChunkAdapter();
      final chunks = <ChatStreamChunk>[
        ...adapter.handle(const ImageStart(id: 'img', mimeType: 'image/png')),
        ...adapter.handle(const ImageDelta(id: 'img', data: 'aaa')),
        ...adapter.handle(const Finish()),
      ];

      expect(
        chunks.map((c) => c.content).join(),
        '\n\n![image](data:image/png;base64,aaa)',
      );
      expect(chunks.where((c) => c.isDone), hasLength(1));
      expect(chunks.last.isDone, isTrue);
    });
  });

  group('Finish exactly once', () {
    test('a single Finish yields exactly one isDone chunk', () {
      final adapter = LegacyChunkAdapter();
      final chunks = <ChatStreamChunk>[
        ...adapter.handle(const TextDelta(id: 't', text: 'hi')),
        ...adapter.handle(const Finish()),
      ];

      expect(chunks.where((c) => c.isDone), hasLength(1));
      expect(chunks.last.isDone, isTrue);
    });

    test('duplicate Finish and later deltas are ignored', () {
      final adapter = LegacyChunkAdapter();
      final chunks = <ChatStreamChunk>[
        ...adapter.handle(const Finish(finishReason: 'stop')),
        ...adapter.handle(const Finish(finishReason: 'stop')),
        ...adapter.handle(const TextDelta(id: 't', text: 'late')),
        ...adapter.handle(const Usage(TokenUsage(totalTokens: 9))),
      ];

      expect(chunks, hasLength(1));
      expect(chunks.single.isDone, isTrue);
      expect(chunks.single.content, isEmpty);
    });

    test('adapt() also emits Finish only once', () async {
      final adapter = LegacyChunkAdapter();
      final chunks = await adapter
          .adapt(
            Stream<StreamChunk>.fromIterable(const <StreamChunk>[
              Finish(),
              Finish(),
            ]),
          )
          .toList();

      expect(chunks.where((c) => c.isDone), hasLength(1));
    });
  });
}
