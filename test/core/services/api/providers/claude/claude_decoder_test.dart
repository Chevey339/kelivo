import 'dart:convert';

import 'package:Kelivo/core/services/api/providers/claude/claude_decoder.dart';
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

    final second = decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 2,
        'content_block': {
          'type': 'server_tool_use',
          'id': 'srv_2',
          'name': 'web_search',
        },
      }),
    );
    expect(
      second.chunks.whereType<ServerToolStart>().single.toolName,
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

  test('onClosed ends an open server tool when the result never arrives', () {
    final decoder = ClaudeStreamDecoder();
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'server_tool_use',
          'id': 'srv_open',
          'name': 'web_search',
        },
      }),
    );

    final closed = decoder.onClosed();
    final end = closed.whereType<ServerToolEnd>().single;
    expect(end.id, 'srv_open');
    expect(end.status, ServerToolStatus.failed);
    expect(decoder.onClosed(), isEmpty);
  });

  test('skips malformed JSON instead of throwing', () {
    final decoder = ClaudeStreamDecoder();
    expect(decoder.accept(const SseEvent(data: 'not-json')).chunks, isEmpty);
  });

  test('malformed frame keeps parsed chunks and later text still decodes', () {
    final decoder = ClaudeStreamDecoder();
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'text', 'text': ''},
      }),
    );
    final first = decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'Hello'},
      }),
    );
    final textId = first.chunks.whereType<TextDelta>().single.id;

    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 1,
        'content_block': {'type': 'tool_use', 'id': 'call_1', 'name': 'lookup'},
      }),
    );

    final malformed = decoder.accept(const SseEvent(data: '{not-json'));
    expect(malformed.completed, isFalse);
    expect(malformed.chunks, isEmpty);

    final later = decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': ' world'},
      }),
    );
    expect(later.chunks.whereType<TextDelta>().single.text, ' world');
    expect(later.chunks.whereType<TextDelta>().single.id, textId);

    final toolDelta = decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 1,
        'delta': {'type': 'input_json_delta', 'partial_json': '{"q":'},
      }),
    );
    expect(toolDelta.chunks.whereType<ToolCallDelta>().single.id, 'call_1');
    expect(decoder.clientTools['call_1']!.input.toString(), '{"q":');
  });

  test(
    'official stream folds message_start input into usage with message_delta output',
    () {
      final decoder = ClaudeStreamDecoder();
      final start = decoder.accept(
        _event('message_start', {
          'type': 'message_start',
          'message': {
            'id': 'msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY',
            'type': 'message',
            'role': 'assistant',
            'content': <dynamic>[],
            'model': 'claude-opus-5',
            'stop_reason': null,
            'stop_sequence': null,
            'usage': {
              'input_tokens': 25,
              'cache_creation_input_tokens': 10,
              'cache_read_input_tokens': 5,
              'output_tokens': 1,
            },
          },
        }),
      );
      expect(decoder.usage!.promptTokens, 25);
      expect(decoder.usage!.completionTokens, 1);
      expect(decoder.usage!.cachedTokens, 15);
      expect(start.chunks.whereType<Usage>().single.usage.promptTokens, 25);

      final delta = decoder.accept(
        _event('message_delta', {
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn', 'stop_sequence': null},
          'usage': {'output_tokens': 15},
        }),
      );
      expect(decoder.usage!.promptTokens, 25);
      expect(decoder.usage!.completionTokens, 15);
      expect(decoder.usage!.cachedTokens, 15);
      expect(decoder.usage!.totalTokens, 40);
      final streamed = delta.chunks.whereType<Usage>().single.usage;
      expect(streamed.promptTokens, 25);
      expect(streamed.completionTokens, 15);
      expect(streamed.cachedTokens, 15);
      expect(streamed.totalTokens, 40);
    },
  );

  test('follow-up decoder usage is the cumulative snapshot', () {
    final first = ClaudeStreamDecoder();
    first.accept(
      _event('message_start', {
        'type': 'message_start',
        'message': {
          'id': 'msg_1',
          'type': 'message',
          'role': 'assistant',
          'content': <dynamic>[],
          'usage': {'input_tokens': 100, 'output_tokens': 1},
        },
      }),
    );
    final firstDone = first.accept(
      _event('message_delta', {
        'type': 'message_delta',
        'delta': {'stop_reason': 'end_turn', 'stop_sequence': null},
        'usage': {'output_tokens': 20},
      }),
    );
    expect(first.usage!.promptTokens, 100);
    expect(first.usage!.completionTokens, 20);
    expect(first.usage!.totalTokens, 120);
    expect(firstDone.chunks.whereType<Usage>().single.usage.promptTokens, 100);
    expect(
      firstDone.chunks.whereType<Usage>().single.usage.completionTokens,
      20,
    );

    final second = ClaudeStreamDecoder(initialUsage: first.usage);
    second.accept(
      _event('message_start', {
        'type': 'message_start',
        'message': {
          'id': 'msg_2',
          'type': 'message',
          'role': 'assistant',
          'content': <dynamic>[],
          'usage': {'input_tokens': 300, 'output_tokens': 1},
        },
      }),
    );
    final follow = second.accept(
      _event('message_delta', {
        'type': 'message_delta',
        'delta': {'stop_reason': 'end_turn', 'stop_sequence': null},
        'usage': {'output_tokens': 40},
      }),
    );

    expect(second.usage!.promptTokens, 400);
    expect(second.usage!.completionTokens, 60);
    expect(second.usage!.totalTokens, 460);
    final streamed = follow.chunks.whereType<Usage>().single.usage;
    expect(streamed.promptTokens, 400);
    expect(streamed.completionTokens, 60);
    expect(streamed.totalTokens, 460);
  });

  test('a follow-up round without usage keeps the prior snapshot', () {
    final first = ClaudeStreamDecoder();
    first.accept(
      _event('message_start', {
        'type': 'message_start',
        'message': {
          'id': 'msg_1',
          'type': 'message',
          'role': 'assistant',
          'content': <dynamic>[],
          'usage': {'input_tokens': 100, 'output_tokens': 1},
        },
      }),
    );
    first.accept(
      _event('message_delta', {
        'type': 'message_delta',
        'delta': {'stop_reason': 'end_turn', 'stop_sequence': null},
        'usage': {'output_tokens': 20},
      }),
    );
    final second = ClaudeStreamDecoder(initialUsage: first.usage);
    final silent = second.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'ok'},
      }),
    );

    expect(second.usage!.promptTokens, 100);
    expect(second.usage!.completionTokens, 20);
    expect(second.usage!.totalTokens, 120);
    expect(silent.chunks.whereType<Usage>(), isEmpty);
  });

  test(
    'web search blocks are replayable verbatim, encrypted content included',
    () {
      final decoder = ClaudeStreamDecoder();
      decoder.accept(
        _event('content_block_start', {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {
            'type': 'server_tool_use',
            'id': 'srvtoolu_1',
            'name': 'web_search',
            'caller': {
              'type': 'code_execution_20260120',
              'tool_id': 'srvtoolu_0',
            },
          },
        }),
      );
      decoder.accept(
        _event('content_block_delta', {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {
            'type': 'input_json_delta',
            'partial_json': '{"query":"kyoto"}',
          },
        }),
      );
      decoder.accept(
        _event('content_block_stop', {
          'type': 'content_block_stop',
          'index': 0,
        }),
      );
      decoder.accept(
        _event('content_block_start', {
          'type': 'content_block_start',
          'index': 1,
          'content_block': {
            'type': 'web_search_tool_result',
            'tool_use_id': 'srvtoolu_1',
            'caller': {
              'type': 'code_execution_20260120',
              'tool_id': 'srvtoolu_0',
            },
            'content': [
              {
                'type': 'web_search_result',
                'url': 'https://example.com',
                'title': 'Example',
                'encrypted_content': 'EqgfCioIARgBIiQ3',
              },
            ],
          },
        }),
      );

      final call = decoder.assistantBlocks.firstWhere(
        (block) => block['type'] == 'server_tool_use',
      );
      expect(call['id'], 'srvtoolu_1');
      expect(call['name'], 'web_search');
      expect(call['input'], {'query': 'kyoto'});
      expect((call['caller'] as Map)['tool_id'], 'srvtoolu_0');

      final result = decoder.assistantBlocks.firstWhere(
        (block) => block['type'] == 'web_search_tool_result',
      );
      // The API only restores search results into context when this comes back
      // untouched; dropping it is what makes follow-up turns lose the content.
      expect(
        ((result['content'] as List).first as Map)['encrypted_content'],
        'EqgfCioIARgBIiQ3',
      );
      expect((result['caller'] as Map)['tool_id'], 'srvtoolu_0');
    },
  );

  test('text before a server tool keeps its place in the replayed blocks', () {
    final decoder = ClaudeStreamDecoder();
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'text', 'text': ''},
      }),
    );
    decoder.accept(
      _event('content_block_delta', {
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'Searching now.'},
      }),
    );
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 1,
        'content_block': {
          'type': 'server_tool_use',
          'id': 'srvtoolu_2',
          'name': 'web_search',
        },
      }),
    );

    expect(decoder.assistantBlocks.map((block) => block['type']).toList(), [
      'text',
      'server_tool_use',
    ]);
  });

  test('a throttled code execution surfaces as a failed tool card', () {
    final decoder = ClaudeStreamDecoder();
    final start = decoder
        .accept(
          _event('content_block_start', {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {
              'type': 'server_tool_use',
              'id': 'srvtoolu_3',
              'name': 'code_execution',
            },
          }),
        )
        .chunks;
    expect(
      start.whereType<ServerToolStart>().single.toolName,
      'code_execution',
    );

    final chunks = decoder
        .accept(
          _event('content_block_start', {
            'type': 'content_block_start',
            'index': 1,
            'content_block': {
              'type': 'code_execution_tool_result',
              'tool_use_id': 'srvtoolu_3',
              'content': {
                'type': 'code_execution_tool_result_error',
                'error_code': 'too_many_requests',
              },
            },
          }),
        )
        .chunks;

    final end = chunks.whereType<ServerToolEnd>().single;
    expect(end.id, 'srvtoolu_3');
    expect(end.status, ServerToolStatus.failed);
    expect((end.output as Map)['error'], 'too_many_requests');
  });

  test('a successful code execution surfaces its output', () {
    final decoder = ClaudeStreamDecoder();
    decoder.accept(
      _event('content_block_start', {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {
          'type': 'server_tool_use',
          'id': 'srvtoolu_4',
          'name': 'code_execution',
        },
      }),
    );
    final chunks = decoder
        .accept(
          _event('content_block_start', {
            'type': 'content_block_start',
            'index': 1,
            'content_block': {
              'type': 'code_execution_tool_result',
              'tool_use_id': 'srvtoolu_4',
              'content': {
                'type': 'code_execution_result',
                'stdout': '42',
                'return_code': 0,
              },
            },
          }),
        )
        .chunks;

    final end = chunks.whereType<ServerToolEnd>().single;
    expect(end.status, ServerToolStatus.completed);
    expect((end.output as Map)['stdout'], '42');
  });

  test('a fetched page reaches the card clipped', () {
    final decoder = ClaudeStreamDecoder();
    final start = decoder
        .accept(
          _event('content_block_start', {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {
              'type': 'server_tool_use',
              'id': 'srvtoolu_6',
              'name': 'web_fetch',
            },
          }),
        )
        .chunks;
    expect(start.whereType<ServerToolStart>().single.toolName, 'web_fetch');

    final chunks = decoder
        .accept(
          _event('content_block_start', {
            'type': 'content_block_start',
            'index': 1,
            'content_block': {
              'type': 'web_fetch_tool_result',
              'tool_use_id': 'srvtoolu_6',
              'content': {
                'type': 'web_fetch_result',
                'url': 'https://example.com',
                'content': {
                  'type': 'document',
                  'source': {'type': 'text', 'data': 'x' * 9000},
                },
              },
            },
          }),
        )
        .chunks;

    final end = chunks.whereType<ServerToolEnd>().single;
    expect(end.status, ServerToolStatus.completed);
    final data =
        (((end.output as Map)['content'] as Map)['source'] as Map)['data']
            as String;
    expect(data.length, lessThan(9000));
    expect(data.endsWith('…'), isTrue);
    // The block itself is replayed whole, clipping is card-only.
    final block = decoder.assistantBlocks.singleWhere(
      (b) => b['type'] == 'web_fetch_tool_result',
    );
    final raw =
        (((block['content'] as Map)['content'] as Map)['source']
            as Map)['data'];
    expect((raw as String).length, 9000);
  });

  test('a server tool without a card emits no orphan tool chunks', () {
    final decoder = ClaudeStreamDecoder();
    final start = decoder
        .accept(
          _event('content_block_start', {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {
              'type': 'server_tool_use',
              'id': 'srvtoolu_9',
              'name': 'memory',
            },
          }),
        )
        .chunks;
    expect(start.whereType<ServerToolStart>(), isEmpty);
    expect(start.whereType<ToolCallStart>(), isEmpty);

    final delta = decoder
        .accept(
          _event('content_block_delta', {
            'type': 'content_block_delta',
            'index': 0,
            'delta': {
              'type': 'input_json_delta',
              'partial_json': '{"command":"view"}',
            },
          }),
        )
        .chunks;
    expect(delta.whereType<ToolCallDelta>(), isEmpty);

    final stop = decoder
        .accept(
          _event('content_block_stop', {
            'type': 'content_block_stop',
            'index': 0,
          }),
        )
        .chunks;
    expect(stop.whereType<ToolCallEnd>(), isEmpty);

    // The block is still replayed with its input, card or no card.
    final block = decoder.assistantBlocks.single;
    expect(block['name'], 'memory');
    expect(block['input'], {'command': 'view'});
  });
}
