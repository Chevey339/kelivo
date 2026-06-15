import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _openAIConfig(String baseUrl) {
  return ProviderConfig(
    id: 'EncodingCompatTest',
    enabled: true,
    name: 'EncodingCompatTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

void main() {
  group('ChatApiService.generateText encoding compatibility', () {
    test(
      'decodes OpenAI compatible JSON as UTF-8 when content type lacks charset',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          await utf8.decoder.bind(request).join();

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'text/plain',
          );
          request.response.add(
            utf8.encode('{"choices":[{"message":{"content":"问候交流"}}]}'),
          );
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final title = await ChatApiService.generateText(
          config: _openAIConfig(baseUrl),
          modelId: 'title-model',
          prompt: 'summarize',
        );

        expect(title, '问候交流');
      },
    );

    test(
      'omits fixed Kimi K2.7 Code params from OpenAI compatible JSON',
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
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '标题'},
                },
              ],
            }),
          );
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final title = await ChatApiService.generateText(
          config: _openAIConfig(baseUrl),
          modelId: 'kimi-k2.7-code',
          prompt: 'summarize',
          thinkingBudget: 0,
        );

        expect(title, '标题');
        expect(requestBody['model'], 'kimi-k2.7-code');
        expect(requestBody.containsKey('thinking'), isFalse);
        expect(requestBody.containsKey('reasoning_effort'), isFalse);
        expect(requestBody.containsKey('temperature'), isFalse);
        expect(requestBody.containsKey('top_p'), isFalse);
        expect(requestBody.containsKey('n'), isFalse);
        expect(requestBody.containsKey('presence_penalty'), isFalse);
        expect(requestBody.containsKey('frequency_penalty'), isFalse);
      },
    );
  });
}
