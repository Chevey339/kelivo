import 'dart:convert';

import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_decoder.dart';
import 'package:Kelivo/core/services/api/stream/legacy_chunk_adapter.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

SseEvent _event(Map<String, dynamic> data) => SseEvent(data: jsonEncode(data));

void main() {
  test('streams text and reasoning and completes without Finish', () {
    final decoder = ResponsesStreamDecoder();
    final reasoning = decoder.accept(
      _event({'type': 'response.reasoning_text.delta', 'delta': 'think'}),
    );
    final text = decoder.accept(
      _event({'type': 'response.output_text.delta', 'delta': 'Hello'}),
    );
    final done = decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'usage': {
            'input_tokens': 10,
            'output_tokens': 4,
            'input_tokens_details': {'cached_tokens': 2},
          },
          'output': const [],
        },
      }),
    );

    expect(reasoning.chunks.whereType<ReasoningDelta>().single.text, 'think');
    expect(text.chunks.whereType<TextDelta>().single.text, 'Hello');
    expect(done.completed, isTrue);
    expect(done.chunks.whereType<Finish>(), isEmpty);
    expect(decoder.usage!.promptTokens, 10);
    expect(decoder.usage!.completionTokens, 4);
    expect(decoder.usage!.cachedTokens, 2);
    expect(decoder.onClosed(), isEmpty);
  });

  test('assembles indexed function calls and citations', () {
    final decoder = ResponsesStreamDecoder();
    decoder.accept(
      _event({
        'type': 'response.output_item.added',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'lookup',
        },
      }),
    );
    decoder.accept(
      _event({
        'type': 'response.function_call_arguments.delta',
        'output_index': 0,
        'delta': '{"q":',
      }),
    );
    decoder.accept(
      _event({
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'lookup',
          'arguments': '{"q":"kelivo"}',
        },
      }),
    );
    decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'annotations': [
                    {
                      'type': 'url_citation',
                      'url': 'https://example.com',
                      'title': 'Example',
                    },
                  ],
                },
              ],
            },
          ],
        },
      }),
    );

    final call = decoder.takeFunctionCalls().single;
    expect(call.callId, 'call_1');
    expect(call.name, 'lookup');
    expect(call.decodedArguments['q'], 'kelivo');
    expect(decoder.citations.single['url'], 'https://example.com');
    expect(decoder.outputItems, isNotEmpty);
  });

  test('keeps the latest image generation snapshot per index', () {
    final decoder = ResponsesStreamDecoder();
    decoder.accept(
      _event({
        'type': 'response.image_generation_call.partial_image',
        'output_index': 2,
        'partial_image_b64': 'aaa',
        'output_format': 'png',
      }),
    );
    decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'output': [
            {'type': 'message', 'content': const []},
            {'type': 'message', 'content': const []},
            {
              'type': 'image_generation_call',
              'result': 'final-bytes',
              'output_format': 'jpeg',
            },
          ],
        },
      }),
    );

    final image = decoder.takeImages().single;
    expect(image.index, 2);
    expect(image.base64, 'final-bytes');
    expect(image.outputFormat, 'jpeg');
  });

  test('completes even when a message content block is not a list', () {
    final decoder = ResponsesStreamDecoder();
    final done = decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'usage': {'input_tokens': 3, 'output_tokens': 1},
          'output': [
            {'type': 'message', 'content': 'plain-string'},
            {
              'type': 'function_call',
              'call_id': 'call_x',
              'name': 'lookup',
              'arguments': '{}',
            },
          ],
        },
      }),
    );

    expect(done.completed, isTrue);
    expect(decoder.usage!.promptTokens, 3);
    expect(decoder.outputItems, hasLength(2));
  });

  test('skips malformed JSON and maps citations through the adapter', () {
    final decoder = ResponsesStreamDecoder();
    decoder.accept(const SseEvent(data: 'not-json'));
    decoder.accept(
      _event({
        'type': 'response.completed',
        'response': {
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'annotations': [
                    {
                      'type': 'url_citation',
                      'url': 'https://a.example',
                      'title': 'A',
                    },
                  ],
                },
              ],
            },
          ],
        },
      }),
    );

    final adapter = LegacyChunkAdapter();
    final mapped = <ChatStreamChunk>[
      for (final chunk in [
        const ServerToolStart(id: 'builtin_search', toolName: 'search_web'),
        ServerToolEnd(
          id: 'builtin_search',
          output: <String, dynamic>{'items': decoder.citations},
        ),
      ])
        ...adapter.handle(chunk),
    ];
    expect(mapped.single.toolResults!.single.name, 'search_web');
  });
}
