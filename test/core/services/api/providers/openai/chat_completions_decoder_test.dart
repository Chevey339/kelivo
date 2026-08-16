import 'dart:convert';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/stream/legacy_chunk_adapter.dart';
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

  test(
    'emits grok citations as search_web and maps them through the adapter',
    () {
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

      final adapter = LegacyChunkAdapter();
      final mapped = <ChatStreamChunk>[
        for (final chunk in result.chunks) ...adapter.handle(chunk),
      ];
      expect(
        mapped
            .where((c) => c.toolResults != null)
            .single
            .toolResults!
            .single
            .name,
        'search_web',
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
    expect(decoder.reasoningDetails, hasLength(2));
  });

  test('scopes text ids per sourceId and search ids per citation burst', () {
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

    final citations = ChatCompletionsStreamDecoder(sourceId: 'round-0');
    final firstSearch = citations
        .accept(
          _event(<String, dynamic>{
            ..._choice(delta: <String, dynamic>{'content': 'see'}),
            'citations': <String>['https://a.example'],
          }),
        )
        .chunks
        .whereType<ServerToolStart>()
        .single
        .id;
    final secondSearch = citations
        .accept(
          _event(<String, dynamic>{
            'citations': <String>['https://b.example'],
          }),
        )
        .chunks
        .whereType<ServerToolStart>()
        .single
        .id;
    expect(firstSearch, isNot(secondSearch));
    expect(firstSearch, startsWith('round-0:search-'));
  });

  test('skips malformed JSON and does not complete on onClosed', () {
    final decoder = ChatCompletionsStreamDecoder();
    final skipped = decoder.accept(const SseEvent(data: 'not-json'));
    expect(skipped.chunks, isEmpty);
    expect(skipped.completed, isFalse);
    expect(decoder.onClosed(), isEmpty);
    expect(decoder.onClosed(), isEmpty);
  });
}
