import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _siliconFlowConfig(String baseUrl, {String apiKey = ''}) {
  return ProviderConfig(
    id: 'SiliconFlow',
    enabled: true,
    name: 'SiliconFlow',
    apiKey: apiKey,
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

String _siliconFlowBaseUrl(HttpServer server) {
  return 'http://${server.address.address}:${server.port}/v1';
}

Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
  return jsonDecode(await utf8.decoder.bind(request).join())
      as Map<String, dynamic>;
}

void main() {
  group('SiliconFlow compatibility', () {
    test(
      'reasoning on/off maps to thinking_budget and enable_thinking',
      () async {
        final requests = <Map<String, dynamic>>[];
        final authHeaders = <String?>[];
        const apiKey = 'sf-test-key';

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          authHeaders.add(
            request.headers.value(HttpHeaders.authorizationHeader),
          );
          requests.add(await _readJsonBody(request));
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-sf',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'Qwen/Qwen3-8B',
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

        final baseUrl = _siliconFlowBaseUrl(server);
        await ChatApiService.sendMessageStream(
          config: _siliconFlowConfig(baseUrl, apiKey: apiKey),
          modelId: 'Qwen/Qwen3-8B',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinkingBudget: 1024,
        ).toList();

        await ChatApiService.sendMessageStream(
          config: _siliconFlowConfig(baseUrl, apiKey: apiKey),
          modelId: 'Qwen/Qwen3-8B',
          messages: const [
            {'role': 'user', 'content': 'hello again'},
          ],
          thinkingBudget: 0,
        ).toList();

        expect(requests, hasLength(2));
        expect(authHeaders, ['Bearer $apiKey', 'Bearer $apiKey']);

        final enabledBody = requests[0];
        expect(enabledBody['thinking_budget'], 1024);
        expect(enabledBody.containsKey('enable_thinking'), isFalse);
        expect(enabledBody.containsKey('reasoning_effort'), isFalse);

        final disabledBody = requests[1];
        expect(disabledBody['enable_thinking'], isFalse);
        expect(disabledBody.containsKey('thinking_budget'), isFalse);
        expect(disabledBody.containsKey('reasoning_effort'), isFalse);
      },
    );

    test(
      'streaming tool continuation keeps thinking params and auth',
      () async {
        final requestBodies = <Map<String, dynamic>>[];
        final authHeaders = <String?>[];
        const apiKey = 'sf-test-key';
        var requestCount = 0;

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestCount += 1;
          authHeaders.add(
            request.headers.value(HttpHeaders.authorizationHeader),
          );
          requestBodies.add(await _readJsonBody(request));

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );

          if (requestCount == 1) {
            request.response.write(
              'data: ${jsonEncode({
                'id': 'cmpl-1',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'Qwen/Qwen3-8B',
                'choices': [
                  {
                    'index': 0,
                    'delta': {
                      'role': 'assistant',
                      'reasoning_content': '先查一下',
                      'content': '我去调用工具',
                      'tool_calls': [
                        {
                          'index': 0,
                          'id': 'call_1',
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
                'id': 'cmpl-2',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'Qwen/Qwen3-8B',
                'choices': [
                  {
                    'index': 0,
                    'delta': {'role': 'assistant', 'content': '今天是 2026-03-27'},
                    'finish_reason': 'stop',
                  },
                ],
                'usage': null,
              })}\n\n',
            );
            request.response.write(
              'data: ${jsonEncode({
                'id': 'cmpl-2',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'Qwen/Qwen3-8B',
                'choices': [],
                'usage': {
                  'prompt_tokens': 842,
                  'completion_tokens': 53,
                  'total_tokens': 895,
                  'prompt_tokens_details': {'cached_tokens': 384},
                },
              })}\n\n',
            );
          }

          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final baseUrl = _siliconFlowBaseUrl(server);
        final chunks = await ChatApiService.sendMessageStream(
          config: _siliconFlowConfig(baseUrl, apiKey: apiKey),
          modelId: 'Qwen/Qwen3-8B',
          messages: const [
            {'role': 'user', 'content': '今天几号？'},
          ],
          thinkingBudget: 1024,
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'date',
                'description': 'Get current date',
                'parameters': {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              },
            },
          ],
          onToolCall: (_, __, {toolCallId}) async => '2026-03-27',
        ).toList();

        expect(requestBodies, hasLength(2));
        expect(authHeaders, ['Bearer $apiKey', 'Bearer $apiKey']);
        expect(requestBodies[0]['thinking_budget'], 1024);
        expect(requestBodies[1]['thinking_budget'], 1024);
        expect(requestBodies[0]['tool_choice'], 'auto');
        expect(requestBodies[1]['tool_choice'], 'auto');
        expect(requestBodies[0]['tools'], isNotEmpty);
        expect(requestBodies[1]['tools'], isNotEmpty);

        final secondMessages = (requestBodies[1]['messages'] as List)
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final assistantToolMessage = secondMessages.firstWhere(
          (m) => m['role'] == 'assistant' && m['tool_calls'] is List,
        );
        final toolMessage = secondMessages.firstWhere(
          (m) => m['role'] == 'tool',
        );
        expect(assistantToolMessage['content'], '我去调用工具');
        expect(assistantToolMessage['tool_calls'], [
          {
            'id': 'call_1',
            'type': 'function',
            'function': {'name': 'date', 'arguments': '{}'},
          },
        ]);
        expect(toolMessage['tool_call_id'], 'call_1');
        expect(toolMessage['name'], 'date');
        expect(toolMessage['content'], '2026-03-27');
        expect(
          chunks.map((chunk) => chunk.content).join(),
          contains('今天是 2026-03-27'),
        );
        expect(chunks.last.totalTokens, 895);
        expect(chunks.last.usage?.promptTokens, 842);
        expect(chunks.last.usage?.completionTokens, 53);
        expect(chunks.last.usage?.cachedTokens, 384);
      },
    );

    test(
      'non-stream tool continuation keeps thinking params and auth',
      () async {
        final requestBodies = <Map<String, dynamic>>[];
        final authHeaders = <String?>[];
        const apiKey = 'sf-test-key';
        var requestCount = 0;

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestCount += 1;
          authHeaders.add(
            request.headers.value(HttpHeaders.authorizationHeader),
          );
          requestBodies.add(await _readJsonBody(request));

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;

          if (requestCount == 1) {
            request.response.write(
              jsonEncode({
                'id': 'cmpl-1',
                'object': 'chat.completion',
                'created': 0,
                'model': 'Qwen/Qwen3-8B',
                'choices': [
                  {
                    'index': 0,
                    'message': {
                      'role': 'assistant',
                      'reasoning_content': '先查日期',
                      'content': '我去调用工具',
                      'tool_calls': [
                        {
                          'id': 'call_1',
                          'type': 'function',
                          'function': {'name': 'date', 'arguments': '{}'},
                        },
                      ],
                    },
                    'finish_reason': 'tool_calls',
                  },
                ],
              }),
            );
          } else {
            request.response.write(
              jsonEncode({
                'id': 'cmpl-2',
                'object': 'chat.completion',
                'created': 0,
                'model': 'Qwen/Qwen3-8B',
                'choices': [
                  {
                    'index': 0,
                    'message': {
                      'role': 'assistant',
                      'content': '今天是 2026-03-27',
                    },
                    'finish_reason': 'stop',
                  },
                ],
              }),
            );
          }

          await request.response.close();
        });

        final baseUrl = _siliconFlowBaseUrl(server);
        final chunks = await ChatApiService.sendMessageStream(
          config: _siliconFlowConfig(baseUrl, apiKey: apiKey),
          modelId: 'Qwen/Qwen3-8B',
          messages: const [
            {'role': 'user', 'content': '今天几号？'},
          ],
          thinkingBudget: 1024,
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'date',
                'description': 'Get current date',
                'parameters': {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              },
            },
          ],
          onToolCall: (_, __, {toolCallId}) async => '2026-03-27',
          stream: false,
        ).toList();

        expect(requestBodies, hasLength(2));
        expect(authHeaders, ['Bearer $apiKey', 'Bearer $apiKey']);
        expect(requestBodies[0]['thinking_budget'], 1024);
        expect(requestBodies[1]['thinking_budget'], 1024);
        expect(requestBodies[0]['tool_choice'], 'auto');
        expect(requestBodies[1]['tool_choice'], 'auto');
        expect(requestBodies[0]['tools'], isNotEmpty);
        expect(requestBodies[1]['tools'], isNotEmpty);

        final secondMessages = (requestBodies[1]['messages'] as List)
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final assistantToolMessage = secondMessages.firstWhere(
          (m) => m['role'] == 'assistant' && m['tool_calls'] is List,
        );
        final toolMessage = secondMessages.firstWhere(
          (m) => m['role'] == 'tool',
        );
        expect(assistantToolMessage['content'], '我去调用工具');
        expect(toolMessage['tool_call_id'], 'call_1');
        expect(toolMessage['content'], '2026-03-27');
        expect(
          chunks.lastWhere((chunk) => chunk.isDone).totalTokens,
          greaterThanOrEqualTo(0),
        );
        expect(
          chunks.map((chunk) => chunk.content).join(),
          contains('今天是 2026-03-27'),
        );
      },
    );
  });
}
