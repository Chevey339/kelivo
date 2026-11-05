import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final responses in [false, true]) {
    for (final tier in ['default', 'fast', 'ultrafast']) {
      test(
        '${responses ? 'Responses' : 'Chat Completions'} keeps $tier through retries and tools',
        () async {
          final bodies = <Map<String, dynamic>>[];
          var toolCalls = 0;
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) async {
            bodies.add(
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>,
            );
            if (bodies.length == 1 || bodies.length == 3) {
              request.response.statusCode = 503;
              request.response.write('temporarily unavailable');
            } else {
              final tool = bodies.length == 2;
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode(
                  responses
                      ? {
                          'id': 'resp-${bodies.length}',
                          'status': 'completed',
                          'output': [
                            if (tool)
                              {
                                'type': 'function_call',
                                'id': 'fc-1',
                                'call_id': 'call-1',
                                'name': 'lookup',
                                'arguments': '{}',
                              }
                            else
                              {
                                'type': 'message',
                                'role': 'assistant',
                                'content': [
                                  {'type': 'output_text', 'text': 'done'},
                                ],
                              },
                          ],
                        }
                      : {
                          'choices': [
                            {
                              'message': {
                                'role': 'assistant',
                                'content': tool ? '' : 'done',
                                if (tool)
                                  'tool_calls': [
                                    {
                                      'id': 'call-1',
                                      'type': 'function',
                                      'function': {
                                        'name': 'lookup',
                                        'arguments': '{}',
                                      },
                                    },
                                  ],
                              },
                              'finish_reason': tool ? 'tool_calls' : 'stop',
                            },
                          ],
                        },
                ),
              );
            }
            await request.response.close();
          });
          await ChatApiService.sendMessageStream(
            config: ProviderConfig(
              id: 'test',
              enabled: true,
              name: 'test',
              apiKey: 'fixture',
              baseUrl: 'http://${server.address.address}:${server.port}/v1',
              providerType: ProviderKind.openai,
              useResponseApi: responses,
              customBody: const [
                {'key': 'service_tier', 'value': 'priority'},
              ],
              modelOverrides: const {
                'gpt-6-astra': {
                  'body': [
                    {'key': 'service_tier', 'value': 'priority'},
                  ],
                  'abilities': ['tool', 'reasoning'],
                  'reasoning': {
                    'levels': ['low', 'high'],
                    'dialect': 'openaiResponsesReasoning',
                  },
                },
              },
            ),
            modelId: 'gpt-6-astra',
            messages: const [
              {'role': 'user', 'content': 'look up'},
            ],
            reasoning: const ReasoningRequest(ReasoningLevel.high),
            serviceTier: tier,
            extraBody: const {'service_tier': 'priority'},
            stream: false,
            tools: const [
              {
                'type': 'function',
                'function': {
                  'name': 'lookup',
                  'parameters': {'type': 'object', 'properties': {}},
                },
              },
            ],
            onToolCall: (name, args, {toolCallId}) async {
              toolCalls++;
              return 'result';
            },
            retryOverride: AutoRetryOptions(
              enabled: true,
              maxRetries: 2,
              initialDelayMs: 0,
              multiplier: 1,
              maxDelayMs: 0,
              jitter: false,
              retryOnNetworkError: true,
              retryStatusCodes: AutoRetryOptions.defaultRetryStatusCodes,
              retryKeywords: AutoRetryOptions.defaultRetryKeywords,
              stopKeywords: AutoRetryOptions.defaultStopKeywords,
            ),
          ).toList();
          expect(bodies, hasLength(4));
          expect(toolCalls, 1);
          for (final body in bodies) {
            expect(body['service_tier'], tier);
            expect(
              body[responses ? 'reasoning' : 'reasoning_effort'],
              responses ? containsPair('effort', 'high') : 'high',
            );
          }
        },
      );
    }
  }
}
