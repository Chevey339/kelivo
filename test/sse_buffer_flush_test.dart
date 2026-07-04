import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/api/chat_api_service.dart';

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
        final chunks = <ChatStreamChunk>[];

        await for (final c in ChatApiService.sendMessageStream(
          config: config,
          modelId: 'test-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        )) {
          chunks.add(c);
        }

        final fullContent = chunks.map((c) => c.content).join();
        expect(fullContent, contains('Hello '));
        expect(fullContent, contains('World'));
        expect(chunks.last.isDone, isTrue);
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
      final chunks = <ChatStreamChunk>[];

      await for (final c in ChatApiService.sendMessageStream(
        config: config,
        modelId: 'test-model',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
      )) {
        chunks.add(c);
      }

      final fullContent = chunks.map((c) => c.content).join();
      expect(fullContent, contains('Partial'));
      expect(fullContent, contains(' response'));
      expect(chunks.last.isDone, isTrue);
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

      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.totalTokens, 895);
      expect(chunks.last.usage?.promptTokens, 842);
      expect(chunks.last.usage?.completionTokens, 53);
      expect(chunks.last.usage?.cachedTokens, 384);
    });
  });
}
