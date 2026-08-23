import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'support/collect_generation.dart';

ProviderConfig _testConfig(String baseUrl) {
  return ProviderConfig(
    id: 'SseTest',
    enabled: true,
    name: 'SseTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

void main() {
  group('SSE buffer flush – last line without trailing newline', () {
    test(
      'OpenAI-compatible adjacent data records keep every text delta',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        const fragments = <String>[
          '*被窝裹住，她反而笑得更',
          '甜*\n\n*懒懒地、',
          '黏糊糊地*\n\n对',
          '……后面的内容仍然保留。',
        ];
        server.listen((request) async {
          await request.drain<void>();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          for (var index = 0; index < fragments.length; index++) {
            request.response.write(
              'data: ${jsonEncode(<String, dynamic>{
                'choices': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'delta': <String, dynamic>{'content': fragments[index]},
                    'finish_reason': null,
                  },
                ],
              })}${index == 1 ? '\n' : '\n\n'}',
            );
          }
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _testConfig('http://localhost:${server.port}/v1'),
          modelId: 'test-model',
          messages: const [
            {'role': 'user', 'content': 'hi'},
          ],
        ).toList();

        expect(chunks.joinedContent, fragments.join());
        expect(chunks.isGenerationDone, isTrue);
      },
    );

    test('tool follow-up also recovers adjacent data records', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      const fragments = <String>['*气音*', '\n\n……我要吃了。'];
      server.listen((request) async {
        requestCount += 1;
        await request.drain<void>();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        if (requestCount == 1) {
          request.response.write(
            'data: ${jsonEncode(<String, dynamic>{
              'choices': <Map<String, dynamic>>[
                <String, dynamic>{
                  'delta': <String, dynamic>{
                    'tool_calls': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'index': 0,
                        'id': 'call_1',
                        'type': 'function',
                        'function': <String, dynamic>{'name': 'noop', 'arguments': '{}'},
                      },
                    ],
                  },
                  'finish_reason': 'tool_calls',
                },
              ],
            })}\n\n',
          );
        } else {
          for (final fragment in fragments) {
            request.response.write(
              'data: ${jsonEncode(<String, dynamic>{
                'choices': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'delta': <String, dynamic>{'content': fragment},
                    'finish_reason': null,
                  },
                ],
              })}\n',
            );
          }
        }
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _testConfig('http://localhost:${server.port}/v1'),
        modelId: 'test-model',
        messages: const [
          {'role': 'user', 'content': 'hi'},
        ],
        tools: const [
          {
            'type': 'function',
            'function': {
              'name': 'noop',
              'parameters': {'type': 'object'},
            },
          },
        ],
        onToolCall: (_, __, {toolCallId}) async => 'ok',
      ).toList();

      expect(requestCount, 2);
      expect(chunks.joinedContent, fragments.join());
      expect(chunks.isGenerationDone, isTrue);
    });

    test(
      'content is NOT truncated when final SSE chunk lacks trailing \\n',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) {
          request.response.statusCode = 200;
          request.response.headers
            ..contentType = ContentType('text', 'event-stream')
            ..set('Transfer-Encoding', 'chunked');

          final chunk1 = jsonEncode({
            'choices': [
              {
                'delta': {'content': 'Hello '},
                'finish_reason': null,
              },
            ],
          });
          final chunk2 = jsonEncode({
            'choices': [
              {
                'delta': {'content': 'World'},
                'finish_reason': 'stop',
              },
            ],
          });

          // First chunk: properly terminated
          request.response.write('data: $chunk1\n\n');
          // Second chunk: properly terminated
          request.response.write('data: $chunk2\n\n');
          // [DONE] without trailing newline – this is the edge case
          request.response.write('data: [DONE]');
          request.response.close();
        });

        final config = _testConfig('http://localhost:${server.port}/v1');
        final chunks = <StreamChunk>[];

        await for (final c in ChatApiService.sendMessageStream(
          config: config,
          modelId: 'test-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        )) {
          chunks.add(c);
        }

        final fullContent = chunks.joinedContent;
        expect(fullContent, contains('Hello '));
        expect(fullContent, contains('World'));
        expect(chunks.isGenerationDone, isTrue);
      },
    );

    test('stream without [DONE] still yields all content', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) {
        request.response.statusCode = 200;
        request.response.headers
          ..contentType = ContentType('text', 'event-stream')
          ..set('Transfer-Encoding', 'chunked');

        final chunk1 = jsonEncode({
          'choices': [
            {
              'delta': {'content': 'Partial'},
              'finish_reason': null,
            },
          ],
        });
        final chunk2 = jsonEncode({
          'choices': [
            {
              'delta': {'content': ' response'},
              'finish_reason': null,
            },
          ],
        });

        request.response.write('data: $chunk1\n\n');
        // Last chunk without trailing newline AND no [DONE]
        request.response.write('data: $chunk2');
        request.response.close();
      });

      final config = _testConfig('http://localhost:${server.port}/v1');
      final chunks = <StreamChunk>[];

      await for (final c in ChatApiService.sendMessageStream(
        config: config,
        modelId: 'test-model',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
      )) {
        chunks.add(c);
      }

      final fullContent = chunks.joinedContent;
      expect(fullContent, contains('Partial'));
      expect(fullContent, contains(' response'));
      expect(chunks.isGenerationDone, isTrue);
    });

    test('usage-only chunk after stop still populates token details', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) {
        request.response.statusCode = 200;
        request.response.headers
          ..contentType = ContentType('text', 'event-stream')
          ..set('Transfer-Encoding', 'chunked');

        final stopChunk = jsonEncode({
          'choices': [
            {
              'finish_reason': 'stop',
              'delta': {'content': '', 'reasoning_content': null},
              'index': 0,
              'logprobs': null,
            },
          ],
          'object': 'chat.completion.chunk',
          'usage': null,
          'created': 1777256825,
          'system_fingerprint': null,
          'model': 'deepseek-v4-pro',
          'id': 'chatcmpl-test',
        });
        final usageChunk = jsonEncode({
          'choices': [],
          'object': 'chat.completion.chunk',
          'usage': {
            'prompt_tokens': 842,
            'completion_tokens': 53,
            'total_tokens': 895,
            'completion_tokens_details': {'reasoning_tokens': 30},
            'prompt_tokens_details': {'cached_tokens': 384},
          },
          'created': 1777256825,
          'system_fingerprint': null,
          'model': 'deepseek-v4-pro',
          'id': 'chatcmpl-test',
        });

        request.response.write('data: $stopChunk\n\n');
        request.response.write('data: $usageChunk\n\n');
        request.response.write('data: [DONE]\n\n');
        request.response.close();
      });

      final config = _testConfig('http://localhost:${server.port}/v1');
      final chunks = await ChatApiService.sendMessageStream(
        config: config,
        modelId: 'deepseek-v4-pro',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(chunks.lastTotalTokens, 895);
      expect(chunks.lastUsage?.promptTokens, 842);
      expect(chunks.lastUsage?.completionTokens, 53);
      expect(chunks.lastUsage?.cachedTokens, 384);
    });
  });
}
