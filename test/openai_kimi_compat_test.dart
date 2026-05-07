import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _moonshotConfig(String baseUrl) {
  return ProviderConfig(
    id: 'MoonshotTest',
    enabled: true,
    name: 'MoonshotTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

void main() {
  group('Moonshot Kimi compatibility', () {
    test(
      'kimi-k2.5 disables thinking and strips unsupported sampling params',
      () async {
        final requestBodyCompleter = Completer<Map<String, dynamic>>();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          if (!requestBodyCompleter.isCompleted) {
            requestBodyCompleter.complete(body);
          }

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-1',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'kimi-k2.5',
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
          config: _moonshotConfig(baseUrl),
          modelId: 'kimi-k2.5',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinkingBudget: 0,
          temperature: 0.7,
          topP: 0.8,
        ).toList();

        final body = await requestBodyCompleter.future;
        expect(chunks.last.isDone, isTrue);
        expect(body['thinking'], {'type': 'disabled'});
        expect(body.containsKey('reasoning_effort'), isFalse);
        expect(body.containsKey('temperature'), isFalse);
        expect(body.containsKey('top_p'), isFalse);
      },
    );

    test(
      'kimi thinking tool continuation preserves reasoning_content and assistant content',
      () async {
        final secondRequestCompleter = Completer<Map<String, dynamic>>();
        final toolInvocations = <Map<String, dynamic>>[];
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
                'id': 'cmpl-1',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'kimi-k2-thinking',
                'choices': [
                  {
                    'index': 0,
                    'delta': {
                      'role': 'assistant',
                      'reasoning_content': '先判断日期',
                      'content': '先查一下',
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
            if (!secondRequestCompleter.isCompleted) {
              secondRequestCompleter.complete(body);
            }
            request.response.write(
              'data: ${jsonEncode({
                'id': 'cmpl-2',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'kimi-k2-thinking',
                'choices': [
                  {
                    'index': 0,
                    'delta': {'role': 'assistant', 'content': '今天是 2026-03-27'},
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
          config: _moonshotConfig(baseUrl),
          modelId: 'kimi-k2-thinking',
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
          onToolCall: (name, args, {toolCallId}) async {
            toolInvocations.add({'name': name, 'args': args});
            return '2026-03-27';
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
        final toolMessage = messages.firstWhere((m) => m['role'] == 'tool');

        expect(toolInvocations, [
          {'name': 'date', 'args': <String, dynamic>{}},
        ]);
        expect(assistantToolMessage['content'], '先查一下');
        expect(assistantToolMessage['reasoning_content'], '先判断日期');
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
      },
    );
  });
}
