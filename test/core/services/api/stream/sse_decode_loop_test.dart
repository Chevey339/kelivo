import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/services/api/providers/openai/chat_completions_decoder.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_decoder.dart';
import 'package:Kelivo/core/services/api/stream/sse_decode_loop.dart';
import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/sse_framing.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
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

  test(
    'pending recovered text reaches the handler before a transport error',
    () async {
      final input = StreamController<String>();
      final decoder = ChatCompletionsStreamDecoder();
      final handler = StreamChunkHandler();
      final timeline = <String>[];
      final errorSeen = Completer<void>();
      final transportError = StateError('transport failed');
      final transportStack = StackTrace.current;
      Object? receivedError;
      StackTrace? receivedStack;
      String? textAtError;
      final subscription =
          decodeSseEvents(
            parseSseEventStrings(
              input.stream,
              recoverAdjacentJsonDataRecords: true,
            ),
            decoder,
          ).listen(
            (chunk) {
              handler.handle(chunk);
              timeline.add('data');
            },
            onError: (Object error, StackTrace stackTrace) {
              receivedError = error;
              receivedStack = stackTrace;
              textAtError = handler.toResult().text;
              timeline.add('error');
              errorSeen.complete();
            },
          );
      addTearDown(() async {
        await input.close();
        await subscription.cancel();
      });

      input.add(
        'data: ${jsonEncode(<String, dynamic>{
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{
              'delta': <String, dynamic>{'content': '正文仍然保留。'},
              'finish_reason': null,
            },
          ],
        })}\n',
      );
      await Future<void>.delayed(Duration.zero);
      expect(handler.toResult().text, isEmpty);

      input.addError(transportError, transportStack);
      await errorSeen.future.timeout(const Duration(seconds: 1));

      expect(textAtError, '正文仍然保留。');
      expect(handler.toResult().text, '正文仍然保留。');
      expect(timeline, <String>['data', 'error']);
      expect(receivedError, same(transportError));
      expect(receivedStack.toString(), transportStack.toString());
    },
  );
}
