import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';

ProviderConfig _deepSeekConfig(String baseUrl, {bool useResponseApi = false}) {
  return ProviderConfig(
    id: 'DeepSeekCompatTest',
    enabled: true,
    name: 'DeepSeekCompatTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
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

    test(
      'xhigh reasoning keeps thinking enabled and passes xhigh effort',
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
          thinkingBudget: 64000,
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        expect(requests, hasLength(1));
        expect(requests.single['thinking'], {'type': 'enabled'});
        expect(requests.single['reasoning_effort'], 'xhigh');
      },
    );

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
  });
}
