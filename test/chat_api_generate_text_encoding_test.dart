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
  });
}
