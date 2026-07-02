import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/api/chat_api_service.dart';

ProviderConfig _deepSeekConfig(String baseUrl) {
  return ProviderConfig(
    id: 'DeepSeekCompatTest',
    enabled: true,
    name: 'DeepSeekCompatTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
  return jsonDecode(await utf8.decoder.bind(request).join())
      as Map<String, dynamic>;
}

void main() {
  group('DeepSeek OpenAI compatibility', () {
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

        expect(chunks.last.isDone, isTrue);
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

      expect(chunks.last.isDone, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single['thinking'], {'type': 'disabled'});
      expect(requests.single.containsKey('reasoning_effort'), isFalse);
    });
  });
}
