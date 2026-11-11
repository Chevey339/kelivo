import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/models/request_budget.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';

void main() {
  const tool = {
    'type': 'function',
    'function': {
      'name': 'get_note',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  };
  for (final responses in [false, true]) {
    for (final stream in [false, true]) {
      for (final transportCheck in [false, true]) {
        test(
          'tool budget errors propagate: responses=$responses stream=$stream transport=$transportCheck',
          () async {
            var sends = 0;
            final config = ProviderConfig(
              id: 'test',
              name: 'test',
              enabled: true,
              apiKey: '',
              baseUrl: 'https://example.test/v1',
              useResponseApi: responses,
              providerType: ProviderKind.openai,
            );
            final responseCall = {
              'type': 'function_call',
              'id': 'fc-1',
              'call_id': 'call-1',
              'name': 'get_note',
              'arguments': '{}',
              'status': 'completed',
            };
            final message = {
              'role': 'assistant',
              'content': '',
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call-1',
                  'type': 'function',
                  'function': {'name': 'get_note', 'arguments': '{}'},
                },
              ],
            };
            final client = MockClient((_) async {
              sends++;
              if (sends > 1) {
                throw const ImageContextBudgetException(
                  kind: ImageContextBudgetKind.requestBody,
                  actual: 2001,
                  limit: 2000,
                );
              }
              final event = responses
                  ? {
                      'type': 'response.completed',
                      'response': {
                        'id': 'r-1',
                        'output': [responseCall],
                      },
                    }
                  : {
                      'choices': [
                        {
                          'index': 0,
                          stream ? 'delta' : 'message': message,
                          'finish_reason': 'tool_calls',
                        },
                      ],
                    };
              return http.Response(
                stream
                    ? '${responses ? 'data: ${jsonEncode({'type': 'response.output_item.done', 'output_index': 0, 'item': responseCall})}\n\n' : ''}data: ${jsonEncode(event)}\n\ndata: [DONE]\n\n'
                    : jsonEncode(
                        responses
                            ? {
                                'id': 'r-1',
                                'output': [responseCall],
                              }
                            : event,
                      ),
                200,
                headers: {
                  'content-type': stream
                      ? 'text/event-stream'
                      : 'application/json',
                },
              );
            });
            addTearDown(client.close);
            final images = RequestImageContext(
              settings: const ImageContextSettings(),
              images: [],
              budget: const RequestBudget(bodyBytes: 2000),
            );
            final chunks = <StreamChunk>[];
            Object? failure;
            try {
              await for (final chunk in images.run(
                () => sendOpenAIStream(
                  client,
                  config,
                  'plain-model',
                  [
                    {'role': 'user', 'content': 'hi'},
                  ],
                  stream: stream,
                  tools: const [tool],
                  onToolCall: (name, args, {toolCallId}) async =>
                      transportCheck ? 'small' : 'x' * 3000,
                ),
              )) {
                chunks.add(chunk);
              }
            } catch (error) {
              failure = error;
            }
            expect(failure, isA<ImageContextBudgetException>());
            expect(
              (failure as ImageContextBudgetException).kind,
              ImageContextBudgetKind.requestBody,
            );
            expect(sends, transportCheck ? 2 : 1);
            expect(chunks.whereType<Finish>(), isEmpty);
          },
        );
      }
    }
  }
}
