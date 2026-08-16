import 'dart:convert';

import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_decoder.dart';
import 'package:Kelivo/core/services/api/stream/legacy_chunk_adapter.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

SseEvent _event(String type, Map<String, dynamic> data) {
  return SseEvent(event: type, data: jsonEncode(data));
}

void main() {
  test('streams text deltas and completes on message_stop without Finish', () {
    final decoder = ClaudeStreamDecoder();
    final chunks = <StreamChunk>[
      ...decoder
          .accept(
            _event('content_block_start', {
              'type': 'content_block_start',
              'index': 0,
              'content_block': {'type': 'text', 'text': ''},
            }),
          )
          .chunks,
      ...decoder
          .accept(
            _event('content_block_delta', {
              'type': 'content_block_delta',
              'index': 0,
              'delta': {'type': 'text_delta', 'text': 'Hello'},
            }),
          )
          .chunks,
      ...decoder
          .accept(
            _event('content_block_delta', {
              'type': 'content_block_delta',
              'index': 0,
              'delta': {'type': 'text_delta', 'text': ' world'},
            }),
          )
          .chunks,
    ];
    final stop = decoder.accept(
      _event('message_stop', {'type': 'message_stop'}),
    );

    expect(
      chunks.whereType<TextDelta>().map((c) => c.text).join(),
      'Hello world',
    );
    expect(stop.completed, isTrue);
    expect(stop.chunks.whereType<Finish>(), isEmpty);
    expect(decoder.assistantBlocks.single, {
      'type': 'text',
      'text': 'Hello world',
    });
    expect(decoder.onClosed(), isEmpty);
    expect(decoder.onClosed(), isEmpty);
  });

  test('preserves thinking text and signature for tool continuation', () {
    final decoder = ClaudeStreamDecoder();
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'thinking', 'thinking': ''},
      }),
    );
    decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'thinking_delta', 'thinking': 'hmm'},
      }),
    );
    decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'signature_delta', 'signature': 'sig-1'},
      }),
    );
    decoder.accept(
      _event('content_block_stop', {'type': 'content_block_stop', 'index': 0}),
    );

    expect(decoder.assistantBlocks.single, {
      'type': 'thinking',
      'thinking': 'hmm',
      'signature': 'sig-1',
    });
  });

  test('assembles a client tool call and marks it complete on stop', () {
    final decoder = ClaudeStreamDecoder();
    final start = decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 1,
        'content_block': {'type': 'tool_use', 'id': 'call_1', 'name': 'lookup'},
      }),
    );
    decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {'type': 'input_json_delta', 'partial_json': '{"q":'},
      }),
    );
    decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {'type': 'input_json_delta', 'partial_json': '"hi"}'},
      }),
    );
    final stop = decoder.accept(
      _event('content_block_stop', {'type': 'content_block_stop', 'index': 1}),
    );

    expect(start.chunks.whereType<ToolCallStart>().single.id, 'call_1');
    expect(stop.chunks.whereType<ToolCallEnd>().single.id, 'call_1');
    expect(decoder.isClientTool('call_1'), isTrue);
    expect(decoder.clientTools['call_1']!.decodedArguments, {'q': 'hi'});
    expect(decoder.assistantBlocks.single['input'], {'q': 'hi'});
  });

  test('maps web_search results to ServerToolEnd items', () {
    final decoder = ClaudeStreamDecoder();
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'server_tool_use',
          'id': 'srv_1',
          'name': 'web_search',
        },
      }),
    );
    decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'input_json_delta', 'partial_json': '{"query":"x"}'},
      }),
    );
    final result = decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 1,
        'content_block': {
          'type': 'web_search_tool_result',
          'tool_use_id': 'srv_1',
          'content': [
            {
              'type': 'web_search_result',
              'title': 'Example',
              'url': 'https://example.com',
            },
          ],
        },
      }),
    );

    final end = result.chunks.whereType<ServerToolEnd>().single;
    expect(end.id, 'srv_1');
    expect(end.output, isA<Map>());
    expect((end.output as Map)['items'], isNotEmpty);

    final adapter = LegacyChunkAdapter();
    final mapped = <ChatStreamChunk>[
      for (final chunk in [
        ...decoder
            .accept(
              _event('content_block_start', {
                'type': 'content_block_start',
                'index': 0,
                'content_block': {
                  'type': 'server_tool_use',
                  'id': 'srv_2',
                  'name': 'web_search',
                },
              }),
            )
            .chunks,
        ...decoder
            .accept(
              _event('content_block_start', {
                'type': 'content_block_start',
                'index': 1,
                'content_block': {
                  'type': 'web_search_tool_result',
                  'tool_use_id': 'srv_2',
                  'content': [
                    {
                      'type': 'web_search_result',
                      'title': 'Example',
                      'url': 'https://example.com',
                    },
                  ],
                },
              }),
            )
            .chunks,
      ])
        ...adapter.handle(chunk),
    ];
    expect(
      mapped
          .where((c) => (c.toolResults ?? const <ToolResultInfo>[]).isNotEmpty)
          .single
          .toolResults!
          .single
          .name,
      'search_web',
    );
  });

  test('maps citations_delta onto ServerToolEnd after server_tool_use', () {
    final decoder = ClaudeStreamDecoder();
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'server_tool_use',
          'id': 'srv_live',
          'name': 'web_search',
        },
      }),
    );
    decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {
          'type': 'citations_delta',
          'citation': {
            'type': 'web_search_result_location',
            'url': 'https://example.com/kyoto',
            'title': 'Kyoto',
            'cited_text': 'Kyoto is a city.',
          },
        },
      }),
    );
    final stop = decoder.accept(
      _event('message_stop', {'type': 'message_stop'}),
    );

    final end = stop.chunks.whereType<ServerToolEnd>().single;
    expect(end.id, 'srv_live');
    final items = (end.output as Map)['items'] as List;
    expect(items.single['url'], 'https://example.com/kyoto');
    expect(items.single['title'], 'Kyoto');
  });

  test('does not emit a second ServerToolEnd after web_search_tool_result', () {
    final decoder = ClaudeStreamDecoder();
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'server_tool_use',
          'id': 'srv_1',
          'name': 'web_search',
        },
      }),
    );
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 1,
        'content_block': {
          'type': 'web_search_tool_result',
          'tool_use_id': 'srv_1',
          'content': [
            {
              'type': 'web_search_result',
              'title': 'Example',
              'url': 'https://example.com',
            },
          ],
        },
      }),
    );
    decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 2,
        'delta': {
          'type': 'citations_delta',
          'citation': {
            'type': 'web_search_result_location',
            'url': 'https://example.com/extra',
            'title': 'Extra',
          },
        },
      }),
    );
    final stop = decoder.accept(
      _event('message_stop', {'type': 'message_stop'}),
    );

    expect(stop.chunks.whereType<ServerToolEnd>(), isEmpty);
    expect(decoder.onClosed(), isEmpty);
  });

  test('skips malformed JSON instead of throwing', () {
    final decoder = ClaudeStreamDecoder();
    expect(decoder.accept(const SseEvent(data: 'not-json')).chunks, isEmpty);
  });
}
