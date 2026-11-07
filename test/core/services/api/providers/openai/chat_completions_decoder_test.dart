import 'dart:convert';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_tool_transcript.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:flutter_test/flutter_test.dart';

SseEvent _event(Map<String, dynamic> data) => SseEvent(data: jsonEncode(data));

Map<String, dynamic> _choice({
  Map<String, dynamic>? delta,
  Map<String, dynamic>? message,
  String? finishReason,
}) {
  return <String, dynamic>{
    'choices': [
      <String, dynamic>{
        if (delta != null) 'delta': delta,
        if (message != null) 'message': message,
        'finish_reason': finishReason,
      },
    ],
  };
}

void main() {
  test('a tool-only message with null content preserves its reasoning', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final result = decoder.accept(
      _event({
        'choices': [
          {
            'message': {
              'content': null,
              'reasoning_content': ' plan\n',
              'tool_calls': [
                {
                  'id': 'a',
                  'type': 'function',
                  'function': {'name': 'lookup', 'arguments': '{}'},
                },
              ],
            },
            'finish_reason': 'tool_calls',
          },
        ],
      }),
    );
    expect(decoder.reasoningEcho, ' plan\n');
    expect(result.chunks.first, isA<ReasoningDelta>());
    expect(result.chunks.whereType<ReasoningDelta>().single.text, ' plan\n');
  });
  test('streams text and reasoning without emitting Finish', () {
    final decoder = ChatCompletionsStreamDecoder();
    final reasoning = decoder.accept(
      _event(_choice(delta: <String, dynamic>{'reasoning_content': 'think'})),
    );
    final text = decoder.accept(
      _event(_choice(delta: <String, dynamic>{'content': 'Hello'})),
    );
    final done = decoder.accept(const SseEvent(data: '[DONE]'));

    expect(reasoning.chunks.whereType<ReasoningDelta>().single.text, 'think');
    expect(reasoning.chunks.whereType<ReasoningDelta>().single.details, isNull);
    expect(text.chunks.whereType<TextDelta>().single.text, 'Hello');
    expect(done.completed, isTrue);
    expect(done.chunks.whereType<Finish>(), isEmpty);
    expect(decoder.onClosed(), isEmpty);
    expect(decoder.assistantContent, 'Hello');
  });

  test(
    'merges message.content with delta and tracks usage without Usage events',
    () {
      final decoder = ChatCompletionsStreamDecoder();
      final result = decoder.accept(
        _event(<String, dynamic>{
          ..._choice(
            delta: <String, dynamic>{'content': 'Hi'},
            message: <String, dynamic>{'content': ' there'},
          ),
          'usage': <String, dynamic>{
            'prompt_tokens': 8,
            'completion_tokens': 2,
            'prompt_tokens_details': <String, dynamic>{'cached_tokens': 3},
          },
        }),
      );

      expect(result.chunks.whereType<TextDelta>().single.text, 'Hi there');
      expect(result.chunks.whereType<Usage>(), isEmpty);
      expect(decoder.usage!.promptTokens, 8);
      expect(decoder.usage!.completionTokens, 2);
      expect(decoder.usage!.cachedTokens, 3);
    },
  );

  test('accumulates indexed tool calls and XinLiu root-level tool_calls', () {
    final decoder = ChatCompletionsStreamDecoder();
    final start = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'tool_calls': [
              <String, dynamic>{
                'index': 0,
                'id': 'call_1',
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{"q":',
                },
              },
            ],
          },
        ),
      ),
    );
    final end = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'tool_calls': [
              <String, dynamic>{
                'index': 0,
                'function': <String, dynamic>{'arguments': '"kelivo"}'},
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );

    expect(decoder.finishReason, 'tool_calls');
    expect(decoder.toolCalls[0]!['id'], 'call_1');
    expect(decoder.toolCalls[0]!['name'], 'lookup');
    expect(decoder.toolCalls[0]!['args'], '{"q":"kelivo"}');
    expect(start.chunks.whereType<ToolCallStart>().single.id, 'call_1');
    expect(start.chunks.whereType<ToolCallStart>().single.toolName, 'lookup');
    expect(start.chunks.whereType<ToolCallDelta>().single.inputDelta, '{"q":');
    expect(
      end.chunks.whereType<ToolCallDelta>().single.inputDelta,
      '"kelivo"}',
    );
    expect(end.chunks.whereType<ToolCallEnd>().single.id, 'call_1');
    expect(decoder.onClosed(), isEmpty);

    final xinliu = ChatCompletionsStreamDecoder();
    final root = xinliu.accept(
      _event(<String, dynamic>{
        'tool_calls': [
          <String, dynamic>{
            'id': 'root_1',
            'type': 'function',
            'function': <String, dynamic>{
              'name': 'search',
              'arguments': '{"q":"x"}',
            },
          },
        ],
        'choices': [
          <String, dynamic>{'finish_reason': 'stop'},
        ],
      }),
    );
    expect(xinliu.finishReason, 'tool_calls');
    expect(xinliu.toolCalls[0]!['id'], 'root_1');
    expect(xinliu.toolCalls[0]!['name'], 'search');
    expect(root.chunks.whereType<ToolCallStart>().single.id, 'root_1');
    expect(root.chunks.whereType<ToolCallEnd>().single.id, 'root_1');
  });

  test('uses StreamChunkIds when a tool call has no vendor id', () {
    final decoder = ChatCompletionsStreamDecoder(sourceId: 'round-0');
    final first = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'tool_calls': [
              <String, dynamic>{
                'index': 0,
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{',
                },
              },
            ],
          },
        ),
      ),
    );
    final id = first.chunks.whereType<ToolCallStart>().single.id;
    expect(id, 'round-0:tool-1');
    decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'tool_calls': [
              <String, dynamic>{
                'index': 0,
                'id': 'call_late',
                'function': <String, dynamic>{'arguments': '}'},
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );
    expect(decoder.toolCalls[0]!['id'], 'call_late');
    expect(decoder.toolCalls[0]!['series_id'], 'round-0:tool-1');
    final calls = clientToolCallsFromChatAcc(decoder.toolCalls);
    expect(calls.single.id, 'round-0:tool-1');
    expect(calls.single.providerCallId, 'call_late');
    expect(openaiToolCallMaps(calls).single['id'], 'call_late');
    expect(
      decoder
          .accept(const SseEvent(data: '[DONE]'))
          .chunks
          .whereType<ToolCallEnd>(),
      isEmpty,
    );
  });

  test('overwrites finishReason from the current choices chunk', () {
    final decoder = ChatCompletionsStreamDecoder();
    decoder.accept(_event(_choice(finishReason: 'tool_calls')));
    expect(decoder.finishReason, 'tool_calls');
    decoder.accept(_event(_choice(delta: <String, dynamic>{'content': 'x'})));
    expect(decoder.finishReason, isNull);
  });

  test('emits grok citations as search_web ServerTool events', () {
    final decoder = ChatCompletionsStreamDecoder();
    final result = decoder.accept(
      _event(<String, dynamic>{
        ..._choice(delta: <String, dynamic>{'content': 'see'}),
        'citations': <String>['https://example.com'],
      }),
    );

    expect(
      result.chunks.whereType<ServerToolStart>().single.toolName,
      'search_web',
    );
    final end = result.chunks.whereType<ServerToolEnd>().single;
    expect(end.id, 'stream:search-1');
    final items = (end.output as Map)['items'] as List;
    expect(items.single, <String, dynamic>{
      'index': 1,
      'url': 'https://example.com',
      'title': 'https://example.com',
    });
  });

  test(
    'accumulates source annotations without losing titles or duplicates',
    () {
      final decoder = ChatCompletionsStreamDecoder();
      decoder.accept(
        _event({
          'citations': ['https://example.com/first'],
        }),
      );
      final titled = decoder.accept(
        _event(
          _choice(
            message: {
              'annotations': [
                {
                  'type': 'url_citation',
                  'url_citation': {
                    'url': 'https://example.com/first',
                    'title': 'First',
                  },
                },
              ],
            },
          ),
        ),
      );
      final update = _choice(
        delta: {
          'annotations': [
            {
              'type': 'url_citation',
              'url': 'https://example.com/first',
              'title': '',
            },
            {
              'type': 'url_citation',
              'url': 'https://example.com/second',
              'title': 'Second',
            },
            {'type': 'url_citation'},
          ],
        },
      );
      final next = decoder.accept(_event(update));
      expect(
        next.chunks.whereType<ServerToolEnd>().single.id,
        titled.chunks.whereType<ServerToolEnd>().single.id,
      );
      expect(
        (next.chunks.whereType<ServerToolEnd>().single.output as Map)['items'],
        [
          {'index': 1, 'url': 'https://example.com/first', 'title': 'First'},
          {'index': 2, 'url': 'https://example.com/second', 'title': 'Second'},
        ],
      );
      expect(
        decoder.accept(_event(update)).chunks.whereType<ServerToolEnd>(),
        isEmpty,
      );
    },
  );

  test('emits Image events only when image output is requested', () {
    final off = ChatCompletionsStreamDecoder();
    off.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': 'pic',
            'images': [
              <String, dynamic>{
                'type': 'image_url',
                'image_url': <String, dynamic>{
                  'url': 'https://img.example/a.png',
                },
              },
            ],
          },
        ),
      ),
    );
    expect(off.assistantContent, 'pic');

    final on = ChatCompletionsStreamDecoder(wantsImageOutput: true);
    final result = on.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': 'pic',
            'image_url': <String, dynamic>{'url': 'https://img.example/a.png'},
          },
        ),
      ),
    );
    expect(result.chunks.whereType<TextDelta>().single.text, 'pic');
    expect(
      result.chunks.whereType<ImageSnapshot>().single.data,
      'https://img.example/a.png',
    );
    expect(result.chunks.whereType<ImageStart>(), hasLength(1));
    expect(result.chunks.whereType<ImageEnd>(), hasLength(1));

    final typeless = ChatCompletionsStreamDecoder(wantsImageOutput: true);
    final typelessResult = typeless.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'images': [
              <String, dynamic>{
                'image_url': <String, dynamic>{
                  'url': 'https://img.example/b.png',
                },
              },
            ],
          },
        ),
      ),
    );
    expect(typelessResult.chunks.whereType<TextDelta>(), isEmpty);
    expect(
      typelessResult.chunks.whereType<ImageSnapshot>().single.data,
      'https://img.example/b.png',
    );
  });

  test('ingests complete message.tool_calls from one-shot JSON', () {
    final decoder = ChatCompletionsStreamDecoder();
    final result = decoder.accept(
      _event(
        _choice(
          message: <String, dynamic>{
            'content': '',
            'tool_calls': [
              <String, dynamic>{
                'id': 'call_ns',
                'type': 'function',
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{"q":"kelivo"}',
                },
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );

    expect(decoder.finishReason, 'tool_calls');
    expect(decoder.toolCalls[0]!['id'], 'call_ns');
    expect(decoder.toolCalls[0]!['name'], 'lookup');
    expect(decoder.toolCalls[0]!['args'], '{"q":"kelivo"}');
    expect(result.chunks.whereType<ToolCallStart>().single.id, 'call_ns');
    expect(result.chunks.whereType<ToolCallEnd>().single.id, 'call_ns');
  });

  test('complete message ignores invalid tool indexes', () {
    final decoder = ChatCompletionsStreamDecoder();
    final result = decoder.accept(
      _event(
        _choice(
          message: <String, dynamic>{
            'content': '正文仍然保留。',
            'tool_calls': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 0,
                'id': 'call_lookup',
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{}',
                },
              },
              <String, dynamic>{
                'index': null,
                'id': 'call_notify',
                'function': <String, dynamic>{
                  'name': 'notify',
                  'arguments': '{}',
                },
              },
              <String, dynamic>{
                'index': 0.9,
                'id': 'call_fractional',
                'function': <String, dynamic>{
                  'name': 'fractional',
                  'arguments': '{"unexpected":0.9}',
                },
              },
              <String, dynamic>{
                'index': -1,
                'id': 'call_negative',
                'function': <String, dynamic>{
                  'name': 'negative',
                  'arguments': '{"unexpected":-1}',
                },
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );

    expect(result.chunks.whereType<TextDelta>().single.text, '正文仍然保留。');
    expect(decoder.toolCalls, <int, Map<String, dynamic>>{
      0: <String, dynamic>{
        'id': 'call_lookup',
        'name': 'lookup',
        'args': '{}',
        'series_id': 'call_lookup',
      },
      1: <String, dynamic>{
        'id': 'call_notify',
        'name': 'notify',
        'args': '{}',
        'series_id': 'call_notify',
      },
    });
    expect(
      result.chunks.whereType<ToolCallStart>().map((chunk) => chunk.toolName),
      <String>['lookup', 'notify'],
    );
    expect(result.chunks.whereType<ToolCallEnd>(), hasLength(2));
  });

  test('complete message fallback avoids an earlier sparse index', () {
    for (final explicitNull in <bool>[false, true]) {
      final decoder = ChatCompletionsStreamDecoder();
      final result = decoder.accept(
        _event(
          _choice(
            message: <String, dynamic>{
              'tool_calls': <Map<String, dynamic>>[
                <String, dynamic>{
                  'index': 1,
                  'id': 'call_explicit',
                  'function': <String, dynamic>{
                    'name': 'explicit',
                    'arguments': '{"slot":1}',
                  },
                },
                <String, dynamic>{
                  if (explicitNull) 'index': null,
                  'id': 'call_fallback',
                  'function': <String, dynamic>{
                    'name': 'fallback',
                    'arguments': '{}',
                  },
                },
              ],
            },
            finishReason: 'tool_calls',
          ),
        ),
      );
      final reason = explicitNull ? 'explicit null index' : 'missing index';

      expect(decoder.toolCalls, <int, Map<String, dynamic>>{
        1: <String, dynamic>{
          'id': 'call_explicit',
          'name': 'explicit',
          'args': '{"slot":1}',
          'series_id': 'call_explicit',
        },
        2: <String, dynamic>{
          'id': 'call_fallback',
          'name': 'fallback',
          'args': '{}',
          'series_id': 'call_fallback',
        },
      }, reason: reason);
      expect(
        result.chunks.whereType<ToolCallStart>().map((chunk) => chunk.id),
        <String>['call_explicit', 'call_fallback'],
        reason: reason,
      );
      expect(
        result.chunks.whereType<ToolCallEnd>().map((chunk) => chunk.id),
        <String>['call_explicit', 'call_fallback'],
        reason: reason,
      );
    }
  });

  test('complete message fallback reserves a later explicit index', () {
    for (final explicitNull in <bool>[false, true]) {
      final decoder = ChatCompletionsStreamDecoder();
      final result = decoder.accept(
        _event(
          _choice(
            message: <String, dynamic>{
              'tool_calls': <Map<String, dynamic>>[
                <String, dynamic>{
                  if (explicitNull) 'index': null,
                  'id': 'call_fallback',
                  'function': <String, dynamic>{
                    'name': 'fallback',
                    'arguments': '{}',
                  },
                },
                <String, dynamic>{
                  'index': 0,
                  'id': 'call_explicit',
                  'function': <String, dynamic>{
                    'name': 'explicit',
                    'arguments': '{"slot":0}',
                  },
                },
              ],
            },
            finishReason: 'tool_calls',
          ),
        ),
      );
      final reason = explicitNull ? 'explicit null index' : 'missing index';

      expect(decoder.toolCalls, <int, Map<String, dynamic>>{
        0: <String, dynamic>{
          'id': 'call_explicit',
          'name': 'explicit',
          'args': '{"slot":0}',
          'series_id': 'call_explicit',
        },
        1: <String, dynamic>{
          'id': 'call_fallback',
          'name': 'fallback',
          'args': '{}',
          'series_id': 'call_fallback',
        },
      }, reason: reason);
      expect(
        result.chunks.whereType<ToolCallStart>().map((chunk) => chunk.id),
        <String>['call_fallback', 'call_explicit'],
        reason: reason,
      );
      expect(
        result.chunks.whereType<ToolCallEnd>().map((chunk) => chunk.id),
        <String>['call_fallback', 'call_explicit'],
        reason: reason,
      );
    }
  });

  test(
    'keeps Gemini extra_content.google.thought_signature on streamed tool calls',
    () {
      const extraContent = <String, dynamic>{
        'google': <String, dynamic>{'thought_signature': 'sig-create-memory'},
      };
      final decoder = ChatCompletionsStreamDecoder();
      final start = decoder.accept(
        _event(
          _choice(
            delta: <String, dynamic>{
              'tool_calls': [
                <String, dynamic>{
                  'index': 0,
                  'id': 'call_mem',
                  'type': 'function',
                  'extra_content': extraContent,
                  'function': <String, dynamic>{
                    'name': 'create_memory',
                    'arguments': '{"content":',
                  },
                },
              ],
            },
          ),
        ),
      );
      decoder.accept(
        _event(
          _choice(
            delta: <String, dynamic>{
              'tool_calls': [
                <String, dynamic>{
                  'index': 0,
                  'function': <String, dynamic>{'arguments': '"note"}'},
                },
              ],
            },
            finishReason: 'tool_calls',
          ),
        ),
      );

      expect(decoder.toolCalls[0]!['extra_content'], extraContent);
      expect(
        start.chunks
            .whereType<ToolCallStart>()
            .single
            .metadata?['google']['extra_content'],
        extraContent,
      );
    },
  );

  test(
    'keeps Gemini extra_content that arrives after the first tool-call delta',
    () {
      const extraContent = <String, dynamic>{
        'google': <String, dynamic>{'thought_signature': 'sig-late'},
      };
      final decoder = ChatCompletionsStreamDecoder();
      decoder.accept(
        _event(
          _choice(
            delta: <String, dynamic>{
              'tool_calls': [
                <String, dynamic>{
                  'index': 0,
                  'id': 'call_late_sig',
                  'function': <String, dynamic>{
                    'name': 'create_memory',
                    'arguments': '{}',
                  },
                },
              ],
            },
          ),
        ),
      );
      final late = decoder.accept(
        _event(
          _choice(
            delta: <String, dynamic>{
              'tool_calls': [
                <String, dynamic>{'index': 0, 'extra_content': extraContent},
              ],
            },
            finishReason: 'tool_calls',
          ),
        ),
      );

      expect(decoder.toolCalls[0]!['extra_content'], extraContent);
      final extraDeltas = late.chunks.whereType<ToolCallDelta>().where((chunk) {
        final google = chunk.metadata?['google'];
        return google is Map && google['extra_content'] is Map;
      });
      expect(extraDeltas, isNotEmpty);
      expect(
        extraDeltas.first.metadata!['google']['extra_content'],
        extraContent,
      );
    },
  );

  test('keeps Gemini extra_content on one-shot and root-level tool_calls', () {
    const extraContent = <String, dynamic>{
      'google': <String, dynamic>{'thought_signature': 'sig-complete'},
    };
    final complete = ChatCompletionsStreamDecoder();
    final completeResult = complete.accept(
      _event(
        _choice(
          message: <String, dynamic>{
            'content': '',
            'tool_calls': [
              <String, dynamic>{
                'id': 'call_ns',
                'type': 'function',
                'extra_content': extraContent,
                'function': <String, dynamic>{
                  'name': 'create_memory',
                  'arguments': '{}',
                },
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );
    expect(complete.toolCalls[0]!['extra_content'], extraContent);
    expect(
      completeResult.chunks
          .whereType<ToolCallStart>()
          .single
          .metadata?['google']['extra_content'],
      extraContent,
    );

    final root = ChatCompletionsStreamDecoder();
    final rootResult = root.accept(
      _event(<String, dynamic>{
        'tool_calls': [
          <String, dynamic>{
            'id': 'root_1',
            'type': 'function',
            'extra_content': extraContent,
            'function': <String, dynamic>{
              'name': 'create_memory',
              'arguments': '{}',
            },
          },
        ],
        'choices': [
          <String, dynamic>{'finish_reason': 'stop'},
        ],
      }),
    );
    expect(root.toolCalls[0]!['extra_content'], extraContent);
    expect(
      rootResult.chunks
          .whereType<ToolCallStart>()
          .single
          .metadata?['google']['extra_content'],
      extraContent,
    );
  });

  test('persists Gemini extra_content onto tool events for later replay', () {
    const extraContent = <String, dynamic>{
      'google': <String, dynamic>{'thought_signature': 'sig-persisted'},
    };
    final decoder = ChatCompletionsStreamDecoder();
    final result = decoder.accept(
      _event(
        _choice(
          message: <String, dynamic>{
            'content': '',
            'tool_calls': [
              <String, dynamic>{
                'id': 'call_mem',
                'type': 'function',
                'extra_content': extraContent,
                'function': <String, dynamic>{
                  'name': 'create_memory',
                  'arguments': '{}',
                },
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );
    final handler = StreamChunkHandler();
    for (final chunk in result.chunks) {
      handler.handle(chunk);
    }
    final payload = jsonDecode(
      handler.parts.whereType<ToolCallPart>().single.payloadJson,
    );
    expect(payload['metadata']['google']['extra_content'], extraContent);
  });

  test('completes raw base64 Chat Completions images at the parse source', () {
    final decoder = ChatCompletionsStreamDecoder(wantsImageOutput: true);
    final result = decoder.accept(
      _event(
        _choice(
          message: <String, dynamic>{
            'content': [
              <String, dynamic>{
                'type': 'image_url',
                'image_url': <String, dynamic>{'url': 'AQIDBA=='},
              },
            ],
          },
        ),
      ),
    );

    expect(
      result.chunks.whereType<ImageSnapshot>().single.data,
      'data:image/png;base64,AQIDBA==',
    );
  });

  test('keeps the data: prefix on Chat Completions image URLs', () {
    const dataUri = 'data:image/png;base64,AQIDBA==';
    final decoder = ChatCompletionsStreamDecoder(wantsImageOutput: true);
    final result = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'images': [
              <String, dynamic>{
                'type': 'image_url',
                'image_url': <String, dynamic>{'url': dataUri},
              },
            ],
          },
        ),
      ),
    );

    expect(result.chunks.whereType<ImageSnapshot>().single.data, dataUri);
    expect(result.chunks.whereType<ImageStart>().single.mimeType, 'image/png');

    final handler = StreamChunkHandler();
    for (final chunk in result.chunks) {
      handler.handle(chunk);
    }
    expect((handler.parts.single as ImagePart).uri, dataUri);
  });

  test('echoes reasoning when requested and accumulates reasoning_details', () {
    final decoder = ChatCompletionsStreamDecoder(
      needsReasoningEcho: true,
      allowReasoningSnapshots: true,
    );
    decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'reasoning': 'a',
            'reasoning_details': [
              <String, dynamic>{'type': 'reasoning.summary', 'text': 'a'},
            ],
          },
        ),
      ),
    );
    decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'reasoning_details': [
              <String, dynamic>{'type': 'reasoning.summary', 'text': 'a'},
              <String, dynamic>{'type': 'reasoning.summary', 'text': 'b'},
            ],
          },
        ),
      ),
    );

    expect(decoder.reasoningEcho, 'a');
    expect(decoder.reasoningDetails, [
      {'type': 'reasoning.summary', 'text': 'ab'},
    ]);
  });

  test('OpenRouter fragments form blocks without dropping repeated deltas', () {
    final decoder = ChatCompletionsStreamDecoder(
      allowReasoningSnapshots: false,
    );
    void accept(List<Map<String, dynamic>> details) {
      decoder.accept(_event(_choice(delta: {'reasoning_details': details})));
    }

    const first = {'type': 'reasoning.text', 'text': 'go', 'index': 0};
    accept([first]);
    final previous = decoder.reasoningDetails;
    accept([
      first,
      {'type': 'reasoning.text', 'text': '\nnext', 'index': 0},
    ]);
    expect(decoder.reasoningDetails, [
      {'type': 'reasoning.text', 'text': 'gogo\nnext', 'index': 0},
    ]);
    expect(previous, [first]);

    accept([
      {'type': 'reasoning.text', 'signature': 'sig', 'index': 0},
      {'type': 'reasoning.encrypted', 'data': 'opaque', 'index': 1},
      {'type': 'reasoning.text', 'text': 'separate', 'index': 2},
    ]);
    expect(decoder.reasoningDetails, [
      {
        'type': 'reasoning.text',
        'text': 'gogo\nnext',
        'index': 0,
        'signature': 'sig',
      },
      {'type': 'reasoning.encrypted', 'data': 'opaque', 'index': 1},
      {'type': 'reasoning.text', 'text': 'separate', 'index': 2},
    ]);
  });

  test('scopes text ids per sourceId', () {
    final first = ChatCompletionsStreamDecoder(sourceId: 'round-0');
    final second = ChatCompletionsStreamDecoder(sourceId: 'round-1');
    expect(
      first
          .accept(_event(_choice(delta: <String, dynamic>{'content': 'a'})))
          .chunks
          .whereType<TextDelta>()
          .single
          .id,
      'round-0:text-1',
    );
    expect(
      second
          .accept(_event(_choice(delta: <String, dynamic>{'content': 'b'})))
          .chunks
          .whereType<TextDelta>()
          .single
          .id,
      'round-1:text-1',
    );
  });

  test('keeps cumulative citations on one sticky search card', () {
    final decoder = ChatCompletionsStreamDecoder(sourceId: 'round-0');
    final handler = StreamChunkHandler();

    final first = decoder.accept(
      _event(<String, dynamic>{
        ..._choice(delta: <String, dynamic>{'content': 'see'}),
        'citations': <String>['https://a.example'],
      }),
    );
    for (final chunk in first.chunks) {
      handler.handle(chunk);
    }
    final firstSearch = first.chunks.whereType<ServerToolStart>().single.id;

    final second = decoder.accept(
      _event(<String, dynamic>{
        'citations': <String>['https://a.example', 'https://b.example'],
      }),
    );
    for (final chunk in second.chunks) {
      handler.handle(chunk);
    }
    final secondSearch = second.chunks.whereType<ServerToolStart>().single.id;

    expect(firstSearch, secondSearch);
    expect(firstSearch, startsWith('round-0:search-'));
    expect(handler.parts.whereType<ToolCallPart>(), hasLength(1));
    final payload = jsonDecode(
      handler.parts.whereType<ToolCallPart>().single.payloadJson,
    );
    expect(payload['name'], 'search_web');
    expect((payload['content'] as Map)['items'], hasLength(2));
  });

  test('skips malformed JSON and does not complete on onClosed', () {
    final decoder = ChatCompletionsStreamDecoder();
    final skipped = decoder.accept(const SseEvent(data: 'not-json'));
    expect(skipped.chunks, isEmpty);
    expect(skipped.completed, isFalse);
    expect(decoder.onClosed(), isEmpty);
    expect(decoder.onClosed(), isEmpty);
  });

  test('follow-up approx chars from separate decoders must be added', () {
    final first = ChatCompletionsStreamDecoder();
    first.accept(_event(_choice(delta: <String, dynamic>{'content': 'abcd'})));
    final second = ChatCompletionsStreamDecoder();
    second.accept(
      _event(_choice(delta: <String, dynamic>{'content': 'efghijkl'})),
    );

    // Chat Completions follow-ups used to assign `chars =` the last decoder
    // only. Provider-omitted usage then estimated tokens from the last round.
    expect(first.approxCompletionChars, 4);
    expect(second.approxCompletionChars, 8);
    expect(first.approxCompletionChars + second.approxCompletionChars, 12);
  });

  test('malformed frame keeps parsed chunks and later text still decodes', () {
    final decoder = ChatCompletionsStreamDecoder();
    final first = decoder.accept(
      _event(_choice(delta: <String, dynamic>{'content': 'Hello'})),
    );
    final textId = first.chunks.whereType<TextDelta>().single.id;

    final malformed = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'tool_calls': [
              <String, dynamic>{
                'index': 0,
                'id': 'call_1',
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{}',
                },
              },
              <String, dynamic>{
                'index': 'bad',
                'function': <String, dynamic>{'name': 'x'},
              },
            ],
          },
        ),
      ),
    );
    expect(malformed.completed, isFalse);
    expect(malformed.chunks.whereType<ToolCallStart>().single.id, 'call_1');

    final later = decoder.accept(
      _event(_choice(delta: <String, dynamic>{'content': ' world'})),
    );
    expect(later.chunks.whereType<TextDelta>().single.text, ' world');
    expect(later.chunks.whereType<TextDelta>().single.id, textId);

    final handler = StreamChunkHandler();
    for (final chunk in [
      ...first.chunks,
      ...malformed.chunks,
      ...later.chunks,
    ]) {
      handler.handle(chunk);
    }
    expect(handler.parts.whereType<TextPart>().single.text, 'Hello world');
    expect(handler.parts.whereType<ToolCallPart>(), hasLength(1));
  });

  test('malformed optional tool metadata cannot discard text', () {
    final decoder = ChatCompletionsStreamDecoder();
    final decoded = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': '*气音*\n\n……我要吃了。',
            'tool_calls': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 'bad',
                'id': 7,
                'function': <String, dynamic>{
                  'name': 9,
                  'arguments': <String, dynamic>{},
                },
              },
            ],
          },
        ),
      ),
    );

    expect(
      decoded.chunks.whereType<TextDelta>().single.text,
      '*气音*\n\n……我要吃了。',
    );
  });

  test('null streamed tool index uses the fallback slot', () {
    final decoder = ChatCompletionsStreamDecoder();
    final result = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'tool_calls': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': null,
                'id': 'call_null',
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{}',
                },
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );

    expect(decoder.toolCalls[0], <String, dynamic>{
      'id': 'call_null',
      'name': 'lookup',
      'args': '{}',
      'series_id': 'call_null',
    });
    expect(result.chunks.whereType<ToolCallStart>().single.id, 'call_null');
    expect(result.chunks.whereType<ToolCallEnd>().single.id, 'call_null');
  });

  test('explicitly invalid tool index cannot corrupt an existing call', () {
    final decoder = ChatCompletionsStreamDecoder();
    decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'tool_calls': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 0,
                'id': 'call_1',
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{"q":"kelivo"}',
                },
              },
            ],
          },
        ),
      ),
    );

    final malformed = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': '正文仍然保留。',
            'tool_calls': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 'bad',
                'id': 'call_bad',
                'function': <String, dynamic>{
                  'name': 'dangerous',
                  'arguments': '{"unexpected":true}',
                },
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );

    expect(malformed.chunks.whereType<TextDelta>().single.text, '正文仍然保留。');
    expect(malformed.chunks.whereType<ToolCallDelta>(), isEmpty);
    expect(decoder.toolCalls.keys, <int>[0]);
    expect(decoder.toolCalls[0], <String, dynamic>{
      'id': 'call_1',
      'name': 'lookup',
      'args': '{"q":"kelivo"}',
      'series_id': 'call_1',
    });
  });

  test('fractional and negative streamed tool indexes are ignored', () {
    final decoder = ChatCompletionsStreamDecoder();
    decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'tool_calls': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 0,
                'id': 'call_1',
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{"q":"kelivo"}',
                },
              },
            ],
          },
        ),
      ),
    );

    final malformed = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': '正文仍然保留。',
            'tool_calls': <Map<String, dynamic>>[
              <String, dynamic>{
                'index': 0.9,
                'id': 'call_fractional',
                'function': <String, dynamic>{
                  'name': 'fractional',
                  'arguments': '{"unexpected":0.9}',
                },
              },
              <String, dynamic>{
                'index': -1,
                'id': 'call_negative',
                'function': <String, dynamic>{
                  'name': 'negative',
                  'arguments': '{"unexpected":-1}',
                },
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );

    expect(malformed.chunks.whereType<TextDelta>().single.text, '正文仍然保留。');
    expect(malformed.chunks.whereType<ToolCallDelta>(), isEmpty);
    expect(decoder.toolCalls, <int, Map<String, dynamic>>{
      0: <String, dynamic>{
        'id': 'call_1',
        'name': 'lookup',
        'args': '{"q":"kelivo"}',
        'series_id': 'call_1',
      },
    });
  });

  test('follow-up decoder usage is the last round only', () {
    final first = ChatCompletionsStreamDecoder();
    first.accept(
      _event(<String, dynamic>{
        ..._choice(delta: <String, dynamic>{'content': 'a'}),
        'usage': <String, dynamic>{
          'prompt_tokens': 100,
          'completion_tokens': 20,
        },
      }),
    );
    expect(first.usage!.promptTokens, 100);
    expect(first.usage!.completionTokens, 20);
    expect(first.usage!.totalTokens, 120);

    final second = ChatCompletionsStreamDecoder(initialUsage: first.usage);
    final result = second.accept(
      _event(<String, dynamic>{
        ..._choice(delta: <String, dynamic>{'content': 'b'}),
        'usage': <String, dynamic>{
          'prompt_tokens': 300,
          'completion_tokens': 40,
        },
      }),
    );

    expect(second.usage!.promptTokens, 300);
    expect(second.usage!.completionTokens, 40);
    expect(second.usage!.totalTokens, 340);
    expect(result.chunks.whereType<Usage>(), isEmpty);
  });

  test('a follow-up round without usage keeps the prior snapshot', () {
    final first = ChatCompletionsStreamDecoder();
    first.accept(
      _event(<String, dynamic>{
        ..._choice(delta: <String, dynamic>{'content': 'a'}),
        'usage': <String, dynamic>{
          'prompt_tokens': 100,
          'completion_tokens': 20,
        },
      }),
    );
    final second = ChatCompletionsStreamDecoder(initialUsage: first.usage);
    second.accept(_event(_choice(delta: <String, dynamic>{'content': 'b'})));

    expect(second.usage!.promptTokens, 100);
    expect(second.usage!.completionTokens, 20);
    expect(second.usage!.totalTokens, 120);
  });

  group('openAIContentParts', () {
    test('splits Mistral thinking and text parts', () {
      expect(
        openAIContentParts(<dynamic>[
          <String, dynamic>{
            'type': 'thinking',
            'thinking': <dynamic>[
              <String, dynamic>{'type': 'text', 'text': '先想'},
              <String, dynamic>{'type': 'text', 'text': '一下'},
            ],
            'closed': true,
          },
          <String, dynamic>{'type': 'text', 'text': '答案'},
        ]),
        (text: '答案', thinking: '先想一下'),
      );
    });

    test('accepts a string thinking payload', () {
      expect(
        openAIContentParts(<dynamic>[
          <String, dynamic>{'type': 'thinking', 'thinking': '纯字符串思考'},
          <String, dynamic>{'type': 'text', 'text': '正文'},
        ]),
        (text: '正文', thinking: '纯字符串思考'),
      );
    });

    test('keeps plain strings and text-only part lists unchanged', () {
      expect(openAIContentParts('hello'), (text: 'hello', thinking: ''));
      expect(openAIContentParts(null), (text: '', thinking: ''));
      expect(
        openAIContentParts(<dynamic>[
          <String, dynamic>{'type': 'text', 'text': 'a'},
          <String, dynamic>{'type': 'text', 'text': 'b'},
        ]),
        (text: 'ab', thinking: ''),
      );
    });

    test('empty thinking contributes nothing', () {
      expect(
        openAIContentParts(<dynamic>[
          <String, dynamic>{
            'type': 'thinking',
            'thinking': <dynamic>[],
            'closed': true,
          },
          <String, dynamic>{'type': 'text', 'text': 'ok'},
        ]),
        (text: 'ok', thinking: ''),
      );
    });
  });

  test('streams Mistral thinking parts as reasoning, not text', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final result = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{
                'type': 'thinking',
                'thinking': <dynamic>[
                  <String, dynamic>{'type': 'text', 'text': '推理'},
                ],
                'closed': true,
              },
            ],
          },
        ),
      ),
    );

    expect(result.chunks.whereType<TextDelta>(), isEmpty);
    expect(result.chunks.whereType<ReasoningDelta>().single.text, '推理');
    expect(decoder.assistantContent, '');
    expect(decoder.reasoningEcho, '推理');
  });

  test('keeps thinking and text from the same delta', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final result = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{
                'type': 'thinking',
                'thinking': <dynamic>[
                  <String, dynamic>{'type': 'text', 'text': '想'},
                ],
                'closed': false,
              },
              <String, dynamic>{'type': 'text', 'text': '答'},
            ],
          },
        ),
      ),
    );

    expect(result.chunks.whereType<ReasoningDelta>().single.text, '想');
    expect(result.chunks.whereType<TextDelta>().single.text, '答');
    expect(decoder.reasoningEcho, '想');
    expect(decoder.assistantContent, '答');
    expect(
      result.chunks.indexWhere((chunk) => chunk is ReasoningDelta),
      lessThan(result.chunks.indexWhere((chunk) => chunk is TextDelta)),
    );
  });

  test('a closed thinking part does not end the reasoning stream', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    Map<String, dynamic> thinking(String text) {
      return _choice(
        delta: <String, dynamic>{
          'content': <dynamic>[
            <String, dynamic>{
              'type': 'thinking',
              'thinking': <dynamic>[
                <String, dynamic>{'type': 'text', 'text': text},
              ],
              'closed': true,
            },
          ],
        },
      );
    }

    decoder.accept(_event(thinking('一')));
    final next = decoder.accept(_event(thinking('二')));

    expect(next.chunks.whereType<ReasoningDelta>().single.text, '二');
    expect(decoder.reasoningEcho, '一二');
  });

  test('scalar reasoning wins over typed thinking in one frame', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final streamed = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{'type': 'thinking', 'thinking': '甲'},
            ],
            'reasoning_content': '乙',
          },
        ),
      ),
    );

    expect(streamed.chunks.whereType<ReasoningDelta>().single.text, '乙');
    expect(decoder.reasoningEcho, '乙');
    expect(streamed.chunks.whereType<TextDelta>(), isEmpty);

    final message = decoder.accept(
      _event(
        _choice(
          message: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{'type': 'thinking', 'thinking': '丙'},
              <String, dynamic>{'type': 'text', 'text': '正文'},
            ],
            'reasoning_content': '丁',
          },
          finishReason: 'stop',
        ),
      ),
    );

    expect(message.chunks.whereType<ReasoningDelta>().single.text, '丁');
    expect(message.chunks.whereType<TextDelta>().single.text, '正文');
    expect(decoder.reasoningEcho, '乙丁');
  });

  test('one event does not duplicate reasoning across delta and message', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final result = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{'type': 'thinking', 'thinking': '甲'},
            ],
          },
          message: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{'type': 'thinking', 'thinking': '甲'},
              <String, dynamic>{'type': 'text', 'text': '正文'},
            ],
            'reasoning_content': '甲',
          },
          finishReason: 'stop',
        ),
      ),
    );

    expect(result.chunks.whereType<ReasoningDelta>(), hasLength(1));
    expect(result.chunks.whereType<ReasoningDelta>().single.text, '甲');
    expect(decoder.reasoningEcho, '甲');
    expect(result.chunks.whereType<TextDelta>().single.text, '正文');
  });

  test('empty delta reasoning still falls back to the message', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final result = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{'type': 'thinking', 'thinking': ''},
            ],
            'reasoning_content': '',
          },
          message: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{'type': 'thinking', 'thinking': '乙'},
              <String, dynamic>{'type': 'text', 'text': '正文'},
            ],
          },
        ),
      ),
    );

    expect(result.chunks.whereType<ReasoningDelta>().single.text, '乙');
    expect(decoder.reasoningEcho, '乙');
    expect(result.chunks.whereType<TextDelta>().single.text, '正文');
  });

  test('reads thinking parts from a complete message.content', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final result = decoder.accept(
      _event(
        _choice(
          message: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{
                'type': 'thinking',
                'thinking': <dynamic>[
                  <String, dynamic>{'type': 'text', 'text': '计划'},
                ],
                'closed': true,
              },
              <String, dynamic>{'type': 'text', 'text': '最终答案'},
            ],
          },
          finishReason: 'stop',
        ),
      ),
    );

    expect(result.chunks.whereType<ReasoningDelta>().single.text, '计划');
    expect(result.chunks.whereType<TextDelta>().single.text, '最终答案');
    expect(decoder.reasoningEcho, '计划');
    expect(decoder.assistantContent, '最终答案');
  });

  test('keeps a thinking-only message.content beside tool calls', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final result = decoder.accept(
      _event(
        _choice(
          message: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{
                'type': 'thinking',
                'thinking': <dynamic>[
                  <String, dynamic>{'type': 'text', 'text': '需要工具'},
                ],
                'closed': true,
              },
            ],
            'tool_calls': <dynamic>[
              <String, dynamic>{
                'id': 'call_1',
                'type': 'function',
                'function': <String, dynamic>{
                  'name': 'lookup',
                  'arguments': '{}',
                },
              },
            ],
          },
          finishReason: 'tool_calls',
        ),
      ),
    );

    expect(result.chunks.whereType<TextDelta>(), isEmpty);
    expect(result.chunks.whereType<ReasoningDelta>().single.text, '需要工具');
    expect(result.chunks.whereType<ToolCallStart>().single.id, 'call_1');
    expect(decoder.reasoningEcho, '需要工具');
  });

  test('plain string content stays text and empty thinking is silent', () {
    final decoder = ChatCompletionsStreamDecoder(needsReasoningEcho: true);
    final plain = decoder.accept(
      _event(_choice(delta: <String, dynamic>{'content': 'Hello'})),
    );
    expect(plain.chunks.whereType<TextDelta>().single.text, 'Hello');
    expect(plain.chunks.whereType<ReasoningDelta>(), isEmpty);

    final empty = decoder.accept(
      _event(
        _choice(
          delta: <String, dynamic>{
            'content': <dynamic>[
              <String, dynamic>{
                'type': 'thinking',
                'thinking': <dynamic>[],
                'closed': true,
              },
            ],
          },
        ),
      ),
    );
    expect(empty.chunks, isEmpty);
    expect(decoder.reasoningEcho, '');
  });
}
