import 'dart:convert';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/generation/text_generation_result.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a hosted card keeps its input when the result lands a response later',
    () {
      // A turn that starts a hosted tool alongside a client one is cut in two:
      // the call streams its input in the first response and the result only
      // arrives in the second, whose decoder never saw that input.
      final handler = StreamChunkHandler();
      handler.handle(const ToolCallStart(id: 'srvtoolu_1', toolName: 'web 获取'));
      handler.handle(
        const ServerToolStart(id: 'srvtoolu_1', toolName: 'web 获取'),
      );
      handler.handle(
        const ToolCallDelta(
          id: 'srvtoolu_1',
          inputDelta: '{"url":"https://example.com"}',
        ),
      );
      handler.handle(const ToolCallEnd('srvtoolu_1'));
      handler.handle(
        const ServerToolEnd(
          id: 'srvtoolu_1',
          output: <String, dynamic>{'content': 'ok'},
        ),
      );

      final card = jsonDecode(
        handler.parts.whereType<ToolCallPart>().single.payloadJson,
      );
      expect(card['arguments'], {'url': 'https://example.com'});
    },
  );

  test(
    'an empty input reported for a card does not erase the streamed one',
    () {
      // Empty arguments are no news, whoever reports them: a decoder closing an
      // unfinished call still knows less about its input than the deltas do.
      final handler = StreamChunkHandler();
      handler.handle(const ToolCallStart(id: 'srvtoolu_1', toolName: 'web 获取'));
      handler.handle(
        const ToolCallDelta(
          id: 'srvtoolu_1',
          inputDelta: '{"url":"https://example.com"}',
        ),
      );
      handler.handle(
        const ServerToolEnd(
          id: 'srvtoolu_1',
          input: <String, dynamic>{},
          status: ServerToolStatus.failed,
        ),
      );

      final card = jsonDecode(
        handler.parts.whereType<ToolCallPart>().single.payloadJson,
      );
      expect(card['arguments'], {'url': 'https://example.com'});
    },
  );

  test('a generated file becomes an image part only when it is one', () {
    final handler = StreamChunkHandler();
    handler.handle(
      const GeneratedFile(
        uri: 'kelivo-file:///upload/chart.png',
        name: 'chart.png',
        mime: 'image/png',
      ),
    );
    handler.handle(
      const GeneratedFile(
        uri: 'kelivo-file:///upload/data.csv',
        name: 'data.csv',
        mime: 'text/csv',
      ),
    );
    handler.handle(
      const GeneratedFile(uri: '', name: 'nothing.txt', mime: 'text/plain'),
    );

    expect(handler.parts, hasLength(2));
    final image = handler.parts[0] as ImagePart;
    expect(image.uri, 'kelivo-file:///upload/chart.png');
    expect(image.mime, 'image/png');
    final file = handler.parts[1] as FilePart;
    expect(file.uri, 'kelivo-file:///upload/data.csv');
    expect(file.name, 'data.csv');
  });

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

  test('ImageDelta does not publish an accumulating data URI', () {
    final handler = StreamChunkHandler();
    handler.handle(const ImageStart(id: 'img', mimeType: 'image/png'));
    handler.handle(const ImageDelta(id: 'img', data: 'aaa'));
    handler.handle(const ImageDelta(id: 'img', data: 'bbb'));

    expect(handler.parts.whereType<ImagePart>(), isEmpty);

    handler.handle(const ImageEnd('img'));
    final image = handler.parts.single as ImagePart;
    expect(image.uri, 'data:image/png;base64,aaabbb');
    expect(image.id, 'img');
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

  test('ImageStart without data does not create an image part', () {
    final handler = StreamChunkHandler();
    handler.handle(const ImageStart(id: 'img', mimeType: 'image/png'));
    handler.handle(const ImageEnd('img'));
    handler.handle(const Finish(finishReason: 'stop'));

    expect(handler.parts.whereType<ImagePart>(), isEmpty);
    expect(handler.toResult().parts.whereType<ImagePart>(), isEmpty);
  });

  test(
    'ImageSnapshot replaces a non-data URI instead of splitting on a comma',
    () {
      final handler = StreamChunkHandler();
      handler.handle(const ImageStart(id: 'img', mimeType: 'image/png'));
      handler.handle(
        const ImageSnapshot(id: 'img', data: 'https://img.example/a,b.png'),
      );
      handler.handle(const ImageSnapshot(id: 'img', data: 'bbb'));

      final image = handler.parts.single as ImagePart;
      expect(image.uri, 'data:image/png;base64,bbb');
      expect(image.mime, 'image/png');
    },
  );

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

  test('fills a local ToolCallResult without marking the part server-side', () {
    final handler = StreamChunkHandler();
    handler.handle(const ToolCallStart(id: 'call_1', toolName: 'lookup'));
    handler.handle(
      const ToolCallDelta(id: 'call_1', inputDelta: '{"q":"kelivo"}'),
    );
    handler.handle(const ToolCallEnd('call_1'));
    handler.handle(const ToolCallResult(id: 'call_1', output: '{"ok":true}'));

    final payload = jsonDecode(
      (handler.parts.single as ToolCallPart).payloadJson,
    );
    expect(payload['id'], 'call_1');
    expect(payload['name'], 'lookup');
    expect(payload['arguments'], <String, dynamic>{'q': 'kelivo'});
    expect(payload['content'], '{"ok":true}');
    expect(payload['server'], isFalse);
  });

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

  test('folds Annotations into a server search tool part', () {
    final handler = StreamChunkHandler();
    handler.handle(
      const Annotations([
        UrlCitationAnnotation(url: 'https://a.example', title: 'A'),
      ], id: 'round-0:search-1'),
    );
    handler.handle(
      const Annotations([
        UrlCitationAnnotation(url: 'https://b.example', title: 'B'),
      ], id: 'round-0:search-1'),
    );

    expect(handler.parts, hasLength(1));
    final payload = jsonDecode(
      (handler.parts.single as ToolCallPart).payloadJson,
    );
    expect(payload['id'], 'round-0:search-1');
    expect(payload['name'], 'builtin_search');
    expect(payload['server'], isTrue);
    expect(payload['content']['items'], [
      {'url': 'https://a.example', 'title': 'A'},
      {'url': 'https://b.example', 'title': 'B'},
    ]);
  });

  test('merges Annotations onto an existing hosted search tool', () {
    final handler = StreamChunkHandler();
    handler.handle(const ServerToolStart(id: 'st_1', toolName: 'search_web'));
    handler.handle(
      const ServerToolEnd(id: 'st_1', output: {'query': 'kotlin'}),
    );
    handler.handle(
      const Annotations([
        UrlCitationAnnotation(url: 'https://example.com'),
      ], id: 'round-0:search-1'),
    );

    expect(handler.parts, hasLength(1));
    final payload = jsonDecode(
      (handler.parts.single as ToolCallPart).payloadJson,
    );
    expect(payload['id'], 'st_1');
    expect(payload['name'], 'search_web');
    expect(payload['content']['query'], 'kotlin');
    expect(payload['content']['items'], [
      {'url': 'https://example.com'},
    ]);
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

  test('collect folds chunks into a TextGenerationResult', () {
    final result = StreamChunkHandler.collect([
      const TextDelta(id: 't', text: 'Hello'),
      const Usage(TokenUsage(totalTokens: 4)),
      const Finish(finishReason: 'stop'),
    ]);

    expect(result.text, 'Hello');
    expect(result.finishReason, 'stop');
    expect(result.usage?.totalTokens, 4);
    expect(result.parts, hasLength(1));
  });

  test('seed keeps prior parts and later ToolCallResult updates that card', () {
    final seed = <MessagePart>[
      const TextPart('before'),
      const ReasoningPart('plan'),
      ToolCallPart(
        jsonEncode(<String, dynamic>{
          'id': 'call_1',
          'name': 'lookup',
          'arguments': <String, dynamic>{'q': 'kelivo'},
          'server': false,
        }),
      ),
    ];
    final handler = StreamChunkHandler(seed: seed);
    handler.handle(const ToolCallResult(id: 'call_1', output: '{"ok":true}'));
    handler.handle(const TextDelta(id: 'round-1:text-1', text: 'after'));

    expect(handler.parts.map((part) => part.kind).toList(), [
      'text',
      'reasoning',
      'tool_call',
      'text',
    ]);
    expect((handler.parts[0] as TextPart).text, 'before');
    expect((handler.parts[1] as ReasoningPart).text, 'plan');
    final tool = jsonDecode((handler.parts[2] as ToolCallPart).payloadJson);
    expect(tool['name'], 'lookup');
    expect(tool['arguments'], <String, dynamic>{'q': 'kelivo'});
    expect(tool['content'], '{"ok":true}');
    expect((handler.parts[3] as TextPart).text, 'after');
  });

  test(
    'handleResult after seed appends the new round instead of replacing',
    () {
      final handler = StreamChunkHandler(
        seed: const [TextPart('before'), ReasoningPart('plan')],
      );
      handler.handleResult(
        const TextGenerationResult(
          parts: [TextPart('after')],
          finishReason: 'stop',
        ),
      );

      expect(handler.parts.whereType<TextPart>().map((part) => part.text), [
        'before',
        'after',
      ]);
      expect(handler.parts.whereType<ReasoningPart>().single.text, 'plan');
    },
  );

  test('Finish re-encodes tool payloads so late blocks reach the metadata', () {
    final handler = StreamChunkHandler();
    // Providers hand out a live reference to the block list they keep
    // appending to, so a payload encoded mid-turn misses everything that
    // arrives after the tool chunk.
    final blocks = <Map<String, dynamic>>[
      {'type': 'server_tool_use', 'id': 's1', 'name': 'web_search'},
    ];
    final metadata = <String, dynamic>{
      'anthropic': <String, dynamic>{'assistant_blocks': blocks},
    };
    handler.handle(
      ToolCallStart(id: 's1', toolName: 'search_web', metadata: metadata),
    );

    List<String> replayedBlocks() {
      final payload =
          jsonDecode(handler.parts.whereType<ToolCallPart>().single.payloadJson)
              as Map;
      final list =
          ((payload['metadata'] as Map)['anthropic'] as Map)['assistant_blocks']
              as List;
      return [for (final b in list) (b as Map)['type'].toString()];
    }

    expect(replayedBlocks(), ['server_tool_use']);

    blocks.add({'type': 'web_search_tool_result', 'tool_use_id': 's1'});
    blocks.add({'type': 'text', 'text': 'Kyoto has many temples.'});
    handler.handle(const Finish(finishReason: 'end_turn'));

    expect(replayedBlocks(), [
      'server_tool_use',
      'web_search_tool_result',
      'text',
    ]);
  });
  test('handleResult keeps image URIs as-is and does not add data:', () {
    final handler = StreamChunkHandler();
    handler.handleResult(
      const TextGenerationResult(
        parts: [
          TextPart('done'),
          ImagePart(uri: 'https://img.example/a.png', mime: 'image/png'),
          ImagePart(uri: 'data:image/png;base64,AQID', mime: 'image/png'),
          ImagePart(uri: 'kelivo-file:///images/a.png', mime: 'image/png'),
        ],
        finishReason: 'stop',
      ),
    );

    expect(handler.finished, isTrue);
    expect(handler.finishReason, 'stop');
    expect(handler.parts.whereType<ImagePart>().map((part) => part.uri), [
      'https://img.example/a.png',
      'data:image/png;base64,AQID',
      'kelivo-file:///images/a.png',
    ]);
    expect(handler.parts.whereType<TextPart>().single.text, 'done');
  });
}
