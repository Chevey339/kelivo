import 'dart:convert';

import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_decode_loop.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

SseEvent _json(Map<String, dynamic> data) => SseEvent(data: jsonEncode(data));

SseEvent _chatChoice({Map<String, dynamic>? delta, String? finishReason}) {
  return _json(<String, dynamic>{
    'choices': [
      <String, dynamic>{
        if (delta != null) 'delta': delta,
        'finish_reason': finishReason,
      },
    ],
  });
}

void main() {
  test(
    'Responses [DONE] yields ServerToolEnd for an in-progress search',
    () async {
      final decoder = ResponsesStreamDecoder();
      final chunks = await decodeSseEvents(
        Stream<SseEvent>.fromIterable([
          _json({
            'type': 'response.output_item.added',
            'item': {
              'id': 'st_1',
              'type': 'web_search_call',
              'status': 'in_progress',
            },
          }),
          const SseEvent(data: '[DONE]'),
        ]),
        decoder,
      ).toList();

      expect(chunks.whereType<ServerToolStart>().single.id, 'st_1');
      expect(chunks.whereType<ServerToolEnd>().single.id, 'st_1');
      expect(decoder.onClosed(), isEmpty);
    },
  );

  test(
    'Chat Completions [DONE] ends tools when finish_reason is stop',
    () async {
      final decoder = ChatCompletionsStreamDecoder();
      final chunks = await decodeSseEvents(
        Stream<SseEvent>.fromIterable([
          _chatChoice(
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
              ],
            },
          ),
          _chatChoice(finishReason: 'stop'),
          const SseEvent(data: '[DONE]'),
        ]),
        decoder,
      ).toList();

      expect(chunks.whereType<ToolCallStart>().single.id, 'call_1');
      expect(chunks.whereType<ToolCallEnd>().single.id, 'call_1');
    },
  );

  test('onClosed ends open tools when the SSE stream omits [DONE]', () async {
    final decoder = ChatCompletionsStreamDecoder();
    final chunks = await decodeSseEvents(
      Stream<SseEvent>.fromIterable([
        _chatChoice(
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
            ],
          },
        ),
        _chatChoice(finishReason: 'stop'),
      ]),
      decoder,
    ).toList();

    expect(chunks.whereType<ToolCallEnd>().single.id, 'call_1');
  });
}
