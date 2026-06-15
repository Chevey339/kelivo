import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _zhipuConfig(String baseUrl) {
  return ProviderConfig(
    id: 'ZhipuTest',
    enabled: true,
    name: 'ZhipuTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    models: const ['glm-5.2'],
    modelOverrides: const {
      'glm-5.2': {
        'type': 'chat',
        'input': ['text'],
        'output': ['text'],
        'abilities': ['tool', 'reasoning'],
      },
    },
  );
}

void main() {
  group('Zhipu GLM compatibility', () {
    test('glm-5.2 maps reasoning budget to thinking type', () async {
      final requests = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requests.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({
            'id': 'cmpl-glm52',
            'object': 'chat.completion.chunk',
            'created': 0,
            'model': 'glm-5.2',
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
      await ChatApiService.sendMessageStream(
        config: _zhipuConfig(baseUrl),
        modelId: 'glm-5.2',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 1024,
      ).toList();

      await ChatApiService.sendMessageStream(
        config: _zhipuConfig(baseUrl),
        modelId: 'glm-5.2',
        messages: const [
          {'role': 'user', 'content': 'hello again'},
        ],
        thinkingBudget: 0,
      ).toList();

      expect(requests, hasLength(2));
      expect(requests[0]['thinking'], {'type': 'enabled'});
      expect(requests[0].containsKey('reasoning_effort'), isFalse);
      expect(requests[1]['thinking'], {'type': 'disabled'});
      expect(requests[1].containsKey('reasoning_effort'), isFalse);
    });

    test('glm-5.2 tool continuation preserves reasoning_content', () async {
      final secondRequestCompleter = Completer<Map<String, dynamic>>();
      var requestCount = 0;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestCount += 1;
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );

        if (requestCount == 1) {
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-glm52-tool',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'glm-5.2',
              'choices': [
                {
                  'index': 0,
                  'delta': {
                    'role': 'assistant',
                    'reasoning_content': '先获取当前日期',
                    'content': '我先查一下日期。',
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
          if (!secondRequestCompleter.isCompleted) {
            secondRequestCompleter.complete(body);
          }
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-glm52-final',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'glm-5.2',
              'choices': [
                {
                  'index': 0,
                  'delta': {'role': 'assistant', 'content': '今天是 2026-06-15'},
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
        config: _zhipuConfig(baseUrl),
        modelId: 'glm-5.2',
        messages: const [
          {'role': 'user', 'content': '今天几号？'},
        ],
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
        thinkingBudget: 1024,
        onToolCall: (name, args, {toolCallId}) async {
          return '2026-06-15';
        },
      ).toList();

      final secondBody = await secondRequestCompleter.future;
      final messages = (secondBody['messages'] as List)
          .cast<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final assistantToolMessage = messages.firstWhere(
        (m) => m['role'] == 'assistant' && m['tool_calls'] is List,
      );

      expect(chunks.last.isDone, isTrue);
      expect(secondBody['thinking'], {'type': 'enabled'});
      expect(secondBody.containsKey('reasoning_effort'), isFalse);
      expect(assistantToolMessage['content'], '我先查一下日期。');
      expect(assistantToolMessage['reasoning_content'], '先获取当前日期');
      expect(assistantToolMessage['tool_calls'], [
        {
          'id': 'call_date',
          'type': 'function',
          'function': {'name': 'date', 'arguments': '{}'},
        },
      ]);
    });
  });
}
