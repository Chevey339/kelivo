import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/google_gemini.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';

import 'support/collect_generation.dart';

void main() {
  for (final stream in [false, true]) {
    for (final includeMessage in [false, true]) {
      for (final content in ['missing', 'empty', 'functionCall']) {
        test('malformed tool round fails (stream=$stream, '
            'message=$includeMessage, content=$content)', () async {
          const detail =
              'Malformed function call: call:search_web {query: "北京天气"}';
          var requests = 0;
          var toolCalls = 0;
          final client = MockClient((request) async {
            requests++;
            expect(requests, lessThanOrEqualTo(2));
            final failed = requests == 2;
            final candidate = {
              if (!failed || content != 'missing')
                'content': {
                  'role': 'model',
                  'parts': [
                    if (!failed || content == 'functionCall')
                      {
                        'functionCall': {
                          'name': 'search_web',
                          'args': {'query': failed ? 'invalid' : 'first'},
                        },
                        'thoughtSignature': 'test-signature',
                      },
                  ],
                },
              'finishReason': failed ? 'MALFORMED_FUNCTION_CALL' : 'STOP',
              if (failed && includeMessage) 'finishMessage': detail,
            };
            final response = jsonEncode({
              'candidates': [candidate],
            });
            final partial = jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Checking the result.'},
                    ],
                  },
                },
              ],
            });
            return http.Response(
              stream
                  ? '${failed ? 'data: $partial\n\n' : ''}data: $response\n\n'
                  : response,
              200,
              headers: {
                'content-type': stream
                    ? 'text/event-stream; charset=utf-8'
                    : 'application/json; charset=utf-8',
              },
            );
          });
          addTearDown(client.close);

          final chunks = <StreamChunk>[];
          final result = sendGoogleGeminiStream(
            client,
            ProviderConfig(
              id: 'GeminiMalformedFunctionCallTest',
              name: 'Gemini',
              enabled: true,
              apiKey: 'test-key',
              baseUrl: 'https://example.test/v1beta',
              providerType: ProviderKind.google,
            ),
            'gemini-3.8-flash',
            const [
              {'role': 'user', 'content': 'Search for the weather.'},
            ],
            tools: const [
              {
                'type': 'function',
                'function': {
                  'name': 'search_web',
                  'parameters': {
                    'type': 'object',
                    'properties': {
                      'query': {'type': 'string'},
                    },
                  },
                },
              },
            ],
            onToolCall: (name, args, {toolCallId}) async {
              toolCalls++;
              expect(args, {'query': 'first'});
              return 'result';
            },
            stream: stream,
          ).forEach(chunks.add);

          await expectLater(
            result,
            throwsA(
              isA<HttpException>().having(
                (error) => error.message,
                'message',
                includeMessage
                    ? 'Gemini function call failed (MALFORMED_FUNCTION_CALL): $detail'
                    : 'Gemini function call failed (MALFORMED_FUNCTION_CALL)',
              ),
            ),
          );
          expect(requests, 2);
          expect(toolCalls, 1);
          expect(chunks.whereType<Finish>(), isEmpty);
          if (stream) {
            expect(chunks.joinedContent, 'Checking the result.');
          }
        });
      }
    }
  }
}
