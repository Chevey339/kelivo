import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/features/home/services/assistant_tool_history.dart';
import 'support/collect_generation.dart';

/// Regression tests for https://github.com/Chevey339/kelivo/issues/764
///
/// Claude models served through OpenAI-compatible proxies rebuild Anthropic
/// thinking blocks from the echoed reasoning fields. An unsigned
/// `reasoning_content` echo fails validation with
/// "thinking.signature: Field required", so it must be dropped unless the
/// signature-carrying `reasoning_details` are present.
ProviderConfig _openAIConfig(String baseUrl) {
  return ProviderConfig(
    id: 'ClaudeProxyTest',
    enabled: true,
    name: 'ClaudeProxyTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    modelOverrides: {
      'claude-sonnet-4-6': {
        'reasoning': {'replay': 'all'},
      },
    },
  );
}

void main() {
  for (final stream in [false, true]) {
    for (final replay in ['none', 'toolTurns', 'all']) {
      test(
        'signed tool state obeys history replay=$replay, stream=$stream',
        () async {
          const model = 'claude-sonnet-4-6';
          final config = _openAIConfig('https://example.com/v1').copyWith(
            modelOverrides: {
              model: {
                'reasoning': {'replay': replay},
              },
            },
          );
          final bodies = <Map<String, dynamic>>[];
          const details = [
            {
              'type': 'reasoning.text',
              'text': 'Plan',
              'signature': 'signed-plan',
              'format': 'anthropic-claude-v1',
              'index': 0,
            },
          ];
          final client = MockClient((request) async {
            bodies.add(jsonDecode(request.body));
            final first = bodies.length == 1;
            final message = first
                ? {
                    'content': 'Checking.',
                    'reasoning_details': details,
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call1',
                        'type': 'function',
                        'function': {'name': 'lookup', 'arguments': '{}'},
                      },
                    ],
                  }
                : {'content': 'Done'};
            final body = jsonEncode({
              'choices': [
                {
                  stream ? 'delta' : 'message': message,
                  'finish_reason': first ? 'tool_calls' : 'stop',
                },
              ],
            });
            return http.Response(
              stream ? 'data: $body\n\ndata: [DONE]\n\n' : body,
              200,
            );
          });
          addTearDown(client.close);
          final chunks = await sendOpenAIStream(
            client,
            config,
            model,
            [
              {'role': 'user', 'content': 'Look up'},
            ],
            stream: stream,
            tools: [
              {
                'type': 'function',
                'function': {
                  'name': 'lookup',
                  'parameters': {'type': 'object', 'properties': {}},
                },
              },
            ],
            onToolCall: (name, args, {toolCallId}) async => 'found',
          ).toList();
          // Disabling history replay must not break the current tool loop.
          expect(
            (bodies[1]['messages'] as List)[1]['reasoning_details'],
            details,
          );
          final result = StreamChunkHandler.collect(chunks);
          expect(result.reasoningDetails, isNull);
          final history = buildAssistantToolHistory(result.parts);
          expect(history.messages.first['reasoning_details'], details);
          await sendOpenAIStream(client, config, model, [
            {'role': 'user', 'content': 'Look up'},
            ...history.messages,
            {'role': 'assistant', 'content': history.content},
            {'role': 'user', 'content': 'Next'},
          ], stream: stream).toList();
          final pastToolRound = (bodies.last['messages'] as List)[1] as Map;
          expect(
            pastToolRound['reasoning_details'],
            replay == 'none' ? isNull : details,
          );
          expect(pastToolRound['tool_calls'], hasLength(1));
        },
      );
    }
  }

  for (final stream in [false, true]) {
    test(
      'Claude alias keeps signature guard on tool followup: stream=$stream',
      () async {
        const model = 'friendly-alias';
        final config = _openAIConfig('https://example.com/v1').copyWith(
          modelOverrides: {
            model: {
              'apiModelId': 'claude-sonnet-4-6',
              'reasoning': {'replay': 'all'},
            },
          },
        );
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          bodies.add(jsonDecode(request.body));
          final first = bodies.length == 1;
          final message = first
              ? {
                  'role': 'assistant',
                  'content': null,
                  'reasoning_content': 'Current reasoning',
                  'reasoning_details': [
                    {
                      'type': 'reasoning.text',
                      'text': 'Current reasoning',
                      'signature': 'current-signed-state',
                    },
                  ],
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call1',
                      'type': 'function',
                      'function': {'name': 'lookup', 'arguments': '{}'},
                    },
                  ],
                }
              : {'role': 'assistant', 'content': 'Done'};
          final response = jsonEncode({
            'choices': [
              {
                stream ? 'delta' : 'message': message,
                'finish_reason': first ? 'tool_calls' : 'stop',
              },
            ],
          });
          return http.Response(
            stream ? 'data: $response\n\ndata: [DONE]\n\n' : response,
            200,
            headers: {
              'content-type': stream ? 'text/event-stream' : 'application/json',
            },
          );
        });
        addTearDown(client.close);
        await sendOpenAIStream(
          client,
          config,
          model,
          [
            {'role': 'user', 'content': 'Old question'},
            {
              'role': 'assistant',
              'content': 'Old answer',
              'reasoning_content': 'Legacy unsigned thinking',
            },
            {'role': 'user', 'content': 'Use lookup'},
          ],
          stream: stream,
          tools: [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {'type': 'object', 'properties': {}},
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async => 'found',
        ).toList();
        expect(bodies, hasLength(2));
        for (final body in bodies) {
          final history = (body['messages'] as List)[1] as Map;
          expect(history, {'role': 'assistant', 'content': 'Old answer'});
        }
        final toolRound = (bodies.last['messages'] as List)
            .cast<Map>()
            .singleWhere((message) => message['tool_calls'] != null);
        expect(
          toolRound['reasoning_details'].single['signature'],
          'current-signed-state',
        );
      },
    );
  }

  group('Claude via OpenAI-compatible proxy thinking signature', () {
    test('stream emits captured reasoning_details for persistence', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_content":"thinking..."},"finish_reason":null}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"thinking...","signature":"sig-proxy-1"}],"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(chunks.lastReasoningDetails, isA<List>());
      expect(
        (chunks.lastReasoningDetails as List).first['signature'],
        'sig-proxy-1',
      );
    });

    test(
      'all history replay still strips unsigned Claude reasoning_content',
      () async {
        late Map<String, dynamic> requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBody =
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                  .cast<String, dynamic>();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _openAIConfig(
            'http://${server.address.address}:${server.port}/v1',
          ),
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': 'hello'},
            {
              'role': 'assistant',
              'content': 'hi there',
              'reasoning_content': 'unsigned thinking text',
            },
            {'role': 'user', 'content': 'follow up'},
          ],
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        final messages = (requestBody['messages'] as List).cast<Map>();
        final assistant = messages[1];
        expect(assistant.containsKey('reasoning_content'), isFalse);
        expect(assistant.containsKey('reasoning'), isFalse);
        expect(assistant['content'], 'hi there');
      },
    );

    test(
      'Claude history replays signed details without reasoning_content',
      () async {
        late Map<String, dynamic> requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBody =
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                  .cast<String, dynamic>();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        const details = [
          {
            'type': 'reasoning.text',
            'text': 'signed thinking text',
            'signature': 'sig-proxy-1',
          },
        ];
        final chunks = await ChatApiService.sendMessageStream(
          config: _openAIConfig(
            'http://${server.address.address}:${server.port}/v1',
          ),
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': 'hello'},
            {
              'role': 'assistant',
              'content': 'hi there',
              'reasoning_content': 'signed thinking text',
              'reasoning_details': details,
            },
            {'role': 'user', 'content': 'follow up'},
          ],
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        final messages = (requestBody['messages'] as List).cast<Map>();
        final assistant = messages[1];
        expect(assistant.containsKey('reasoning_content'), isFalse);
        expect(
          (assistant['reasoning_details'] as List).first['signature'],
          'sig-proxy-1',
        );
      },
    );

    test(
      'streamed reasoning_details fragments replay as one signed block',
      () async {
        late Map<String, dynamic> requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBody =
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                  .cast<String, dynamic>();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        // Persisted history keeps one entry per streamed delta; the signature
        // arrives last with no text. Replaying that raw makes Bedrock-backed
        // proxies reject the block for a null reasoningText.text.
        const details = [
          {'type': 'reasoning.text', 'text': 'part A', 'index': 0},
          {'type': 'reasoning.text', 'text': ' part B', 'index': 0},
          {'type': 'reasoning.text', 'signature': 'sig-proxy-1', 'index': 0},
        ];
        final chunks = await ChatApiService.sendMessageStream(
          config: _openAIConfig(
            'http://${server.address.address}:${server.port}/v1',
          ),
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': 'hello'},
            {
              'role': 'assistant',
              'content': 'hi there',
              'reasoning_details': details,
            },
            {'role': 'user', 'content': 'follow up'},
          ],
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        final messages = (requestBody['messages'] as List).cast<Map>();
        final replayed = (messages[1]['reasoning_details'] as List).cast<Map>();
        expect(replayed, hasLength(1));
        expect(replayed.first['text'], 'part A part B');
        expect(replayed.first['signature'], 'sig-proxy-1');
      },
    );

    test('non-Claude upstreams replay the block sequence verbatim', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody =
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      const details = [
        {'type': 'reasoning.text', 'text': 'part A', 'index': 0},
        {'type': 'reasoning.text', 'text': ' part B', 'index': 0},
      ];
      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'deepseek-reasoner',
        messages: const [
          {'role': 'user', 'content': 'hello'},
          {
            'role': 'assistant',
            'content': 'hi there',
            'reasoning_details': details,
          },
          {'role': 'user', 'content': 'follow up'},
        ],
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      final messages = (requestBody['messages'] as List).cast<Map>();
      expect((messages[1]['reasoning_details'] as List), hasLength(2));
    });

    test('streamed reasoning_details deltas are accumulated in order', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        // OpenRouter-style: the array arrives as ordered deltas across chunks.
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part A","signature":"sig-a"}]},"finish_reason":null}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part B","signature":"sig-b"}],"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      final details = chunks.lastReasoningDetails as List;
      expect(details, hasLength(2));
      expect(details[0]['signature'], 'sig-a');
      expect(details[1]['signature'], 'sig-b');
    });

    test('identical consecutive reasoning_details deltas are both kept', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        // Two byte-identical deltas: per OpenRouter docs the full sequence is
        // the ordered concatenation of all chunks, so both must be kept.
        const delta =
            'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"same","signature":"sig-x"}]},"finish_reason":null}]}\n\n';
        request.response.write(delta);
        request.response.write(delta);
        request.response.write(
          'data: {"choices":[{"delta":{"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      final details = chunks.lastReasoningDetails as List;
      expect(details, hasLength(2));
      expect(details[0]['signature'], 'sig-x');
      expect(details[1]['signature'], 'sig-x');
    });

    test(
      'OpenRouter deltas are always concatenated, even with repeated prefix',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          // Two delta chunks where the second carries two new entries; per
          // OpenRouter docs the full sequence is the ordered concatenation of
          // all chunks, so the result must be [X, X, Y], not [X, Y].
          request.response.write(
            'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"entry","signature":"sig-x"}]},"finish_reason":null}]}\n\n',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"entry","signature":"sig-x"},{"type":"reasoning.text","text":"other","signature":"sig-y"}],"content":"done"},"finish_reason":"stop"}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: ProviderConfig(
            id: 'OpenRouter',
            enabled: true,
            name: 'OpenRouter',
            apiKey: 'test-key',
            baseUrl: 'http://${server.address.address}:${server.port}/v1',
            providerType: ProviderKind.openai,
          ),
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
        ).toList();

        final details = chunks.lastReasoningDetails as List;
        expect(details, hasLength(3));
        expect(details[0]['signature'], 'sig-x');
        expect(details[1]['signature'], 'sig-x');
        expect(details[2]['signature'], 'sig-y');
      },
    );

    test('cumulative reasoning_details snapshots replace, not duplicate', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        // Some providers resend the full array-so-far with each chunk.
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part A","signature":"sig-a"}]},"finish_reason":null}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part A","signature":"sig-a"},{"type":"reasoning.text","text":"part B","signature":"sig-b"}],"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        // Final chunk repeats the same full array; it must not be appended.
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part A","signature":"sig-a"},{"type":"reasoning.text","text":"part B","signature":"sig-b"}]},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      final details = chunks.lastReasoningDetails as List;
      expect(details, hasLength(2));
      expect(details[0]['signature'], 'sig-a');
      expect(details[1]['signature'], 'sig-b');
    });

    test(
      'Kimi preserved-thinking route variants keep ordinary history',
      () async {
        final requestBodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBodies.add(
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>(),
          );
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        for (final modelId in const [
          'moonshotai/kimi-k3:nitro',
          'moonshotai/kimi-k2.7-code:floor',
        ]) {
          final chunks = await ChatApiService.sendMessageStream(
            config: _openAIConfig(
              'http://${server.address.address}:${server.port}/v1',
            ),
            modelId: modelId,
            messages: const [
              {'role': 'user', 'content': 'hello'},
              {
                'role': 'assistant',
                'content': 'hi there',
                'reasoning_content': 'preserved thinking text',
              },
              {'role': 'user', 'content': 'follow up'},
            ],
          ).toList();

          expect(chunks.isGenerationDone, isTrue);
        }

        expect(requestBodies, hasLength(2));
        for (final requestBody in requestBodies) {
          final messages = (requestBody['messages'] as List).cast<Map>();
          expect(messages[1]['reasoning_content'], 'preserved thinking text');
        }
      },
    );
  });
}
