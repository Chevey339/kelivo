import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';

ProviderConfig _deepSeekConfig(
  String baseUrl, {
  bool useResponseApi = false,
  Map<String, dynamic> modelOverrides = const <String, dynamic>{},
}) {
  return ProviderConfig(
    id: 'DeepSeekCompatTest',
    enabled: true,
    name: 'DeepSeekCompatTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
    modelOverrides: modelOverrides,
  );
}

Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
  return jsonDecode(await utf8.decoder.bind(request).join())
      as Map<String, dynamic>;
}

void main() {
  group('DeepSeek OpenAI compatibility', () {
    test('Responses non-stream returns reasoning and cached tokens', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody = await _readJsonBody(request);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'resp-deepseek',
            'object': 'response',
            'status': 'completed',
            'output_text': '9.8 is greater.',
            'output': [
              {
                'id': 'reasoning-deepseek',
                'type': 'reasoning',
                'content': [
                  {
                    'type': 'reasoning_text',
                    'text': 'Compare the decimal values.',
                  },
                ],
              },
              {
                'id': 'message-deepseek',
                'type': 'message',
                'role': 'assistant',
                'status': 'completed',
                'content': [
                  {'type': 'output_text', 'text': '9.8 is greater.'},
                ],
              },
            ],
            'usage': {
              'input_tokens': 100,
              'input_tokens_details': {'cached_tokens': 64},
              'output_tokens': 30,
              'output_tokens_details': {'reasoning_tokens': 20},
              'total_tokens': 130,
            },
          }),
        );
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      final chunks = await ChatApiService.sendMessageStream(
        config: _deepSeekConfig(baseUrl, useResponseApi: true),
        modelId: 'deepseek-v4-flash',
        messages: const [
          {'role': 'user', 'content': '9.11 and 9.8, which is greater?'},
        ],
        thinkingBudget: 2000,
        stream: false,
      ).toList();

      expect(requestBody['stream'], isFalse);
      expect(chunks.joinedContent, '9.8 is greater.');
      expect(chunks.joinedReasoning, 'Compare the decimal values.');
      expect(chunks.lastUsage?.promptTokens, 100);
      expect(chunks.lastUsage?.completionTokens, 30);
      expect(chunks.lastUsage?.cachedTokens, 64);
      expect(chunks.lastUsage?.totalTokens, 130);
    });

    test('Responses stream reports cached tokens without DONE event', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await _readJsonBody(request);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.completed',
            'response': {
              'output': const [],
              'usage': {
                'input_tokens': 80,
                'input_tokens_details': {'cached_tokens': 48},
                'output_tokens': 12,
                'output_tokens_details': {'reasoning_tokens': 8},
                'total_tokens': 92,
              },
            },
          })}\n\n',
        );
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      final chunks = await ChatApiService.sendMessageStream(
        config: _deepSeekConfig(baseUrl, useResponseApi: true),
        modelId: 'deepseek-v4-flash',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(chunks.lastUsage?.promptTokens, 80);
      expect(chunks.lastUsage?.completionTokens, 12);
      expect(chunks.lastUsage?.cachedTokens, 48);
      expect(chunks.lastUsage?.totalTokens, 92);
    });

    test('Responses off reasoning sends effort none', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody = await _readJsonBody(request);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'resp-deepseek',
            'object': 'response',
            'status': 'completed',
            'output_text': 'ok',
            'output': const [],
            'usage': {
              'input_tokens': 1,
              'input_tokens_details': {'cached_tokens': 0},
              'output_tokens': 1,
              'output_tokens_details': {'reasoning_tokens': 0},
              'total_tokens': 2,
            },
          }),
        );
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      final chunks = await ChatApiService.sendMessageStream(
        config: _deepSeekConfig(baseUrl, useResponseApi: true),
        modelId: 'deepseek-v4-flash',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 0,
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(requestBody['reasoning'], {'effort': 'none'});
    });

    test('Responses max reasoning sends official max effort', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody = await _readJsonBody(request);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'resp-deepseek',
            'object': 'response',
            'status': 'completed',
            'output_text': 'ok',
            'output': const [],
            'usage': {
              'input_tokens': 1,
              'input_tokens_details': {'cached_tokens': 0},
              'output_tokens': 1,
              'output_tokens_details': {'reasoning_tokens': 0},
              'total_tokens': 2,
            },
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _deepSeekConfig(
          'http://${server.address.address}:${server.port}/v1',
          useResponseApi: true,
        ),
        modelId: 'deepseek-v4-flash-vision-exp',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 128000,
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect((requestBody['reasoning'] as Map)['effort'], 'max');
    });

    test('maps official thinking efforts and keeps thinking enabled', () async {
      Future<Map<String, dynamic>> capture(int budget) async {
        late Map<String, dynamic> requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBody = await _readJsonBody(request);
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-deepseek',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'deepseek-v4-pro',
              'choices': [
                {
                  'index': 0,
                  'delta': {'role': 'assistant', 'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _deepSeekConfig(
            'http://${server.address.address}:${server.port}/v1',
          ),
          modelId: 'deepseek-v4-pro',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinkingBudget: budget,
        ).toList();
        expect(chunks.isGenerationDone, isTrue);
        return requestBody;
      }

      final low = await capture(2000);
      final medium = await capture(16000);
      final xhigh = await capture(64000);
      final max = await capture(128000);

      expect(low['thinking'], {'type': 'enabled'});
      expect(low['reasoning_effort'], 'low');
      expect(medium['thinking'], {'type': 'enabled'});
      expect(medium['reasoning_effort'], 'high');
      expect(xhigh['thinking'], {'type': 'enabled'});
      expect(xhigh['reasoning_effort'], 'high');
      expect(max['thinking'], {'type': 'enabled'});
      expect(max['reasoning_effort'], 'max');
    });

    test('off reasoning disables thinking and strips effort', () async {
      final requests = <Map<String, dynamic>>[];

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requests.add(await _readJsonBody(request));
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({
            'id': 'cmpl-deepseek',
            'object': 'chat.completion.chunk',
            'created': 0,
            'model': 'deepseek-v4-pro',
            'choices': [
              {
                'index': 0,
                'delta': {'role': 'assistant', 'content': 'ok'},
                'finish_reason': 'stop',
              },
            ],
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      final chunks = await ChatApiService.sendMessageStream(
        config: _deepSeekConfig(baseUrl),
        modelId: 'deepseek-v4-pro',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 0,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single['thinking'], {'type': 'disabled'});
      expect(requests.single.containsKey('reasoning_effort'), isFalse);
    });

    test(
      'tool-only model echoes empty reasoning_content for tool continuation',
      () async {
        final requests = <Map<String, dynamic>>[];

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requests.add(await _readJsonBody(request));
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          if (requests.length == 1) {
            request.response.write(
              'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {
                      'role': 'assistant',
                      'content': '',
                      'tool_calls': [
                        {
                          'index': 0,
                          'id': 'call_date',
                          'type': 'function',
                          'function': {'name': 'date', 'arguments': '{}'},
                        },
                      ],
                    },
                    'finish_reason': 'tool_calls',
                  },
                ],
              })}\n\n',
            );
          } else {
            request.response.write(
              'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'role': 'assistant', 'content': '2026-08-29'},
                    'finish_reason': 'stop',
                  },
                ],
              })}\n\n',
            );
          }
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final chunks = await ChatApiService.sendMessageStream(
          config: _deepSeekConfig(
            baseUrl,
            modelOverrides: const {
              'deepseek-v4-flash': {
                'abilities': ['tool'],
              },
            },
          ),
          modelId: 'deepseek-v4-flash',
          messages: const [
            {'role': 'user', 'content': 'What is the date?'},
          ],
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'date',
                'description': 'Get the current date',
                'parameters': {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              },
            },
          ],
          onToolCall: (_, __, {toolCallId}) async => '2026-08-29',
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        expect(requests, hasLength(2));
        expect(requests[1].containsKey('thinking'), isFalse);
        final messages = (requests[1]['messages'] as List).cast<Map>();
        final assistantToolMessage = messages.firstWhere(
          (message) =>
              message['role'] == 'assistant' && message['tool_calls'] is List,
        );
        expect(assistantToolMessage['reasoning_content'], '');
      },
    );

    test('ordinary history strips reasoning_content', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody = await _readJsonBody(request);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'ok'},
                'finish_reason': 'stop',
              },
            ],
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      await ChatApiService.sendMessageStream(
        config: _deepSeekConfig(baseUrl),
        modelId: 'deepseek-reasoner',
        messages: const [
          {'role': 'user', 'content': 'first question'},
          {
            'role': 'assistant',
            'content': 'first answer',
            'reasoning_content': 'private first-turn reasoning',
          },
          {'role': 'user', 'content': 'follow up'},
        ],
      ).toList();

      final history = (requestBody['messages'] as List).cast<Map>();
      expect(history[1].containsKey('reasoning_content'), isFalse);
    });

    test(
      'tool-call turn preserves every assistant reasoning_content',
      () async {
        late Map<String, dynamic> requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBody = await _readJsonBody(request);
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        await ChatApiService.sendMessageStream(
          config: _deepSeekConfig(baseUrl),
          modelId: 'deepseek-reasoner',
          messages: const [
            {'role': 'user', 'content': 'check the weather'},
            {
              'role': 'assistant',
              'content': '',
              'reasoning_content': 'decide to call weather tool',
              'tool_calls': [
                {
                  'id': 'call_weather',
                  'type': 'function',
                  'function': {'name': 'weather', 'arguments': '{}'},
                },
              ],
            },
            {
              'role': 'tool',
              'tool_call_id': 'call_weather',
              'content': 'sunny',
            },
            {
              'role': 'assistant',
              'content': 'It is sunny.',
              'reasoning_content': 'summarize the tool result',
            },
            {'role': 'user', 'content': 'thanks'},
          ],
        ).toList();

        final history = (requestBody['messages'] as List).cast<Map>();
        expect(history[1]['reasoning_content'], 'decide to call weather tool');
        expect(history[3]['reasoning_content'], 'summarize the tool result');
      },
    );

    test(
      'Responses API supports built-in search for the DeepSeek V4 family',
      () {
        for (final modelId in const ['deepseek-v4-pro', 'deepseek-v4-flash']) {
          final modelOverrides = <String, dynamic>{
            modelId: <String, dynamic>{
              'builtInTools': const <String>[BuiltInToolNames.search],
            },
          };
          final responsesConfig = _deepSeekConfig(
            'https://api.deepseek.com/v1',
            useResponseApi: true,
            modelOverrides: modelOverrides,
          );
          final chatConfig = _deepSeekConfig(
            'https://api.deepseek.com/v1',
            modelOverrides: modelOverrides,
          );

          expect(
            BuiltInToolsHelper.supportsBuiltInSearchForModel(
              cfg: responsesConfig,
              modelId: modelId,
            ),
            isTrue,
            reason: modelId,
          );
          expect(
            BuiltInToolsHelper.supportsBuiltInSearchForModel(
              cfg: chatConfig,
              modelId: modelId,
            ),
            isFalse,
            reason: modelId,
          );
        }
      },
    );

    test('Responses search requires a DeepSeek provider for V4 models', () {
      const modelId = 'deepseek-v4-pro';
      final cfg = ProviderConfig(
        id: 'CustomOpenAI',
        enabled: true,
        name: 'Custom OpenAI',
        apiKey: 'test-key',
        baseUrl: 'https://proxy.example/v1',
        providerType: ProviderKind.openai,
        useResponseApi: true,
        modelOverrides: const <String, dynamic>{
          modelId: <String, dynamic>{
            'builtInTools': <String>[BuiltInToolNames.search],
          },
        },
      );

      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: cfg,
          modelId: modelId,
        ),
        isFalse,
      );
      expect(
        BuiltInToolsHelper.buildResponsesTools(
          cfg: cfg,
          modelId: modelId,
          upstreamModelId: modelId,
        ).tools,
        isEmpty,
      );
    });

    test('Responses request injects web_search for DeepSeek V4', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      Map<String, dynamic>? requestBody;
      server.listen((request) async {
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'output_text': 'ok',
            'usage': {'input_tokens': 1, 'output_tokens': 1},
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _deepSeekConfig(
          'http://${server.address.address}:${server.port}/v1',
          useResponseApi: true,
          modelOverrides: const <String, dynamic>{
            'deepseek-v4-pro': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.search],
            },
          },
        ),
        modelId: 'deepseek-v4-pro',
        messages: const [
          {'role': 'user', 'content': 'search for the latest news'},
        ],
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(requestBody, isNotNull);
      expect(requestBody!['model'], 'deepseek-v4-pro');
      expect(
        requestBody!['tools'],
        contains(
          predicate<Map<String, dynamic>>(
            (tool) => tool['type'] == 'web_search',
          ),
        ),
      );
    });
  });
}
