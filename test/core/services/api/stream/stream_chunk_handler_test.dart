import 'dart:convert';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a text part on Delta when Start was omitted', () {
    final handler = StreamChunkHandler();
    handler.handle(const TextDelta(id: 't', text: 'Hello'));
    handler.handle(const TextDelta(id: 't', text: ' world'));

    expect(handler.parts, hasLength(1));
    expect((handler.parts.single as TextPart).text, 'Hello world');
  });

  test('keeps interleaved text and reasoning as separate parts by id', () {
    final handler = StreamChunkHandler();
    handler.handle(const ReasoningDelta(id: 'r1', text: 'think1'));
    handler.handle(const TextDelta(id: 't1', text: 'Hello'));
    handler.handle(const ReasoningDelta(id: 'r2', text: 'think2'));
    handler.handle(const TextDelta(id: 't1', text: ' world'));
    handler.handle(const TextDelta(id: 't2', text: '!'));

    expect(handler.parts.map((p) => p.kind).toList(), [
      'reasoning',
      'text',
      'reasoning',
      'text',
    ]);
    expect((handler.parts[0] as ReasoningPart).text, 'think1');
    expect((handler.parts[1] as TextPart).text, 'Hello world');
    expect((handler.parts[2] as ReasoningPart).text, 'think2');
    expect((handler.parts[3] as TextPart).text, '!');
  });

  test('places a tool call between reasoning and later text', () {
    final handler = StreamChunkHandler();
    handler.handle(const ReasoningDelta(id: 'r', text: 'plan'));
    handler.handle(const ToolCallStart(id: 'call_1', toolName: 'lookup'));
    handler.handle(
      const ToolCallDelta(id: 'call_1', inputDelta: '{"q":"kelivo"}'),
    );
    handler.handle(const ToolCallEnd('call_1'));
    handler.handle(const TextDelta(id: 't', text: 'done'));

    expect(handler.parts.map((p) => p.kind).toList(), [
      'reasoning',
      'tool_call',
      'text',
    ]);
    final tool = jsonDecode((handler.parts[1] as ToolCallPart).payloadJson);
    expect(tool['id'], 'call_1');
    expect(tool['name'], 'lookup');
    expect(tool['arguments'], <String, dynamic>{'q': 'kelivo'});
    expect(tool['server'], isFalse);
    expect(tool.containsKey('metadata'), isFalse);
    expect((handler.parts[2] as TextPart).text, 'done');
  });

  test('locates parallel tool calls by id, not by last part', () {
    final handler = StreamChunkHandler();
    handler.handle(const ToolCallStart(id: 'a', toolName: 'search_web'));
    handler.handle(const ToolCallStart(id: 'b', toolName: 'search_web'));
    handler.handle(
      const ToolCallDelta(id: 'b', inputDelta: '{"query":"Ktor"}'),
    );
    handler.handle(
      const ToolCallDelta(id: 'a', inputDelta: '{"query":"Kotlin"}'),
    );
    handler.handle(const ToolCallEnd('a'));
    handler.handle(const ToolCallEnd('b'));

    final payloads = [
      for (final part in handler.parts.whereType<ToolCallPart>())
        jsonDecode(part.payloadJson) as Map<String, dynamic>,
    ];
    expect(payloads.map((p) => p['id']), ['a', 'b']);
    expect(payloads[0]['arguments']['query'], 'Kotlin');
    expect(payloads[1]['arguments']['query'], 'Ktor');
  });

  test('ImageSnapshot replaces previous data for the same id', () {
    final handler = StreamChunkHandler();
    handler.handle(const ImageStart(id: 'img', mimeType: 'image/png'));
    handler.handle(const ImageDelta(id: 'img', data: 'aaa'));
    handler.handle(const ImageSnapshot(id: 'img', data: 'bbb'));
    handler.handle(const TextDelta(id: 't', text: 'caption'));

    expect(handler.parts.map((p) => p.kind).toList(), ['image', 'text']);
    final image = handler.parts[0] as ImagePart;
    expect(image.uri, 'data:image/png;base64,bbb');
    expect(image.mime, 'image/png');
    expect((handler.parts[1] as TextPart).text, 'caption');
  });

  test('keeps a complete image URI instead of wrapping it as base64', () {
    final handler = StreamChunkHandler();
    handler.handle(const ImageStart(id: 'img', mimeType: 'image/png'));
    handler.handle(
      const ImageSnapshot(id: 'img', data: 'https://img.example/a.png'),
    );
    handler.handle(const ImageEnd('img'));

    final image = handler.parts.single as ImagePart;
    expect(image.uri, 'https://img.example/a.png');
    expect(image.mime, 'image/png');
  });

  test('Finish is applied once and later deltas are ignored', () {
    final handler = StreamChunkHandler();
    handler.handle(const TextDelta(id: 't', text: 'Hi'));
    handler.handle(
      const Usage(TokenUsage(promptTokens: 3, completionTokens: 1)),
    );
    handler.handle(const Finish(finishReason: 'stop'));
    handler.handle(const TextDelta(id: 't', text: ' ignored'));
    handler.handle(const Finish(finishReason: 'stop'));

    expect((handler.parts.single as TextPart).text, 'Hi');
    expect(handler.finished, isTrue);
    expect(handler.finishReason, 'stop');
    expect(handler.usage!.promptTokens, 3);
    expect(handler.usage!.completionTokens, 1);
  });

  test(
    'stores reasoning_details from ReasoningDelta without changing text id',
    () {
      final handler = StreamChunkHandler();
      handler.handle(
        const ReasoningDelta(
          id: 'r',
          text: 'a',
          details: [
            {'type': 'reasoning.summary', 'text': 'a'},
          ],
        ),
      );
      expect((handler.parts.single as ReasoningPart).text, 'a');
      expect(handler.reasoningDetails, isNotEmpty);
    },
  );

  test('maps a server tool result onto a tool_call part', () {
    final handler = StreamChunkHandler();
    handler.handle(
      const ServerToolStart(id: 'builtin_search', toolName: 'search_web'),
    );
    handler.handle(
      const ServerToolEnd(
        id: 'builtin_search',
        output: {
          'items': [
            {'index': 1, 'url': 'https://example.com'},
          ],
        },
      ),
    );
    final payload = jsonDecode(
      (handler.parts.single as ToolCallPart).payloadJson,
    );
    expect(payload['id'], 'builtin_search');
    expect(payload['name'], 'search_web');
    expect(payload['content']['items'], isNotEmpty);
    expect(payload['server'], isTrue);
  });

  test('keeps tool metadata and merges later keys onto the same id', () {
    final handler = StreamChunkHandler();
    handler.handle(
      const ToolCallStart(
        id: 'srv_1',
        toolName: 'web_search',
        metadata: {
          'server_tool_use': {'id': 'srv_1'},
        },
      ),
    );
    handler.handle(const ToolCallEnd('srv_1'));
    handler.handle(
      const ServerToolEnd(
        id: 'srv_1',
        output: {'ok': true},
        metadata: {
          'web_search_tool_result': {'id': 'srv_1'},
        },
      ),
    );

    final payload = jsonDecode(
      (handler.parts.single as ToolCallPart).payloadJson,
    );
    expect(payload['server'], isTrue);
    expect(payload['metadata']['server_tool_use']['id'], 'srv_1');
    expect(payload['metadata']['web_search_tool_result']['id'], 'srv_1');
  });

  test('keeps tool name and args when ServerToolEnd follows ToolCallEnd', () {
    final handler = StreamChunkHandler();
    handler.handle(const ToolCallStart(id: 'srv_1', toolName: 'search_web'));
    handler.handle(
      const ToolCallDelta(id: 'srv_1', inputDelta: '{"query":"Kyoto"}'),
    );
    handler.handle(const ToolCallEnd('srv_1'));
    handler.handle(
      const ServerToolEnd(
        id: 'srv_1',
        output: {
          'items': [
            {'url': 'https://example.com'},
          ],
        },
      ),
    );

    final payload = jsonDecode(
      (handler.parts.single as ToolCallPart).payloadJson,
    );
    expect(payload['name'], 'search_web');
    expect(payload['arguments'], <String, dynamic>{'query': 'Kyoto'});
    expect(payload['content']['items'], isNotEmpty);
  });

  test(
    'keeps follow-up round text as a new part when decoder ids are scoped',
    () {
      final handler = StreamChunkHandler();
      final round1 = ChatCompletionsStreamDecoder(sourceId: 'round-0');
      final round2 = ChatCompletionsStreamDecoder(sourceId: 'round-1');

      for (final chunk
          in round1
              .accept(
                SseEvent(
                  data: jsonEncode({
                    'choices': [
                      {
                        'delta': {'content': 'before'},
                      },
                    ],
                  }),
                ),
              )
              .chunks) {
        handler.handle(chunk);
      }
      handler.handle(const ToolCallStart(id: 'call_1', toolName: 'lookup'));
      handler.handle(const ToolCallEnd('call_1'));
      for (final chunk
          in round2
              .accept(
                SseEvent(
                  data: jsonEncode({
                    'choices': [
                      {
                        'delta': {'content': 'after'},
                      },
                    ],
                  }),
                ),
              )
              .chunks) {
        handler.handle(chunk);
      }

      expect(handler.parts.map((p) => p.kind).toList(), [
        'text',
        'tool_call',
        'text',
      ]);
      expect((handler.parts[0] as TextPart).text, 'before');
      expect((handler.parts[2] as TextPart).text, 'after');
    },
  );

  test('merges follow-up text when two decoders share a sourceId', () {
    final handler = StreamChunkHandler();
    final round1 = ChatCompletionsStreamDecoder(sourceId: 'stream');
    final round2 = ChatCompletionsStreamDecoder(sourceId: 'stream');

    for (final chunk
        in round1
            .accept(
              SseEvent(
                data: jsonEncode({
                  'choices': [
                    {
                      'delta': {'content': 'before'},
                    },
                  ],
                }),
              ),
            )
            .chunks) {
      handler.handle(chunk);
    }
    handler.handle(const ToolCallStart(id: 'call_1', toolName: 'lookup'));
    handler.handle(const ToolCallEnd('call_1'));
    for (final chunk
        in round2
            .accept(
              SseEvent(
                data: jsonEncode({
                  'choices': [
                    {
                      'delta': {'content': 'after'},
                    },
                  ],
                }),
              ),
            )
            .chunks) {
      handler.handle(chunk);
    }

    expect(handler.parts.map((p) => p.kind).toList(), ['text', 'tool_call']);
    expect((handler.parts[0] as TextPart).text, 'beforeafter');
  });
}
