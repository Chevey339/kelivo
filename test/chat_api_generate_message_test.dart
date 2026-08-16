import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _openAIConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GenerateMessageTest',
    enabled: true,
    name: 'GenerateMessageTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

void main() {
  test(
    'generateMessage folds non-stream JSON into complete renderable parts',
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
                'finish_reason': 'stop',
                'message': {
                  'content': [
                    {'type': 'text', 'text': 'hello'},
                    {
                      'type': 'image_url',
                      'image_url': {'url': 'AQIDBA=='},
                    },
                  ],
                },
              },
            ],
            'usage': {
              'prompt_tokens': 3,
              'completion_tokens': 2,
              'total_tokens': 5,
            },
          }),
        );
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      final result = await ChatApiService.generateMessage(
        config: _openAIConfig(baseUrl),
        modelId: 'title-model',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
      );

      expect(requestBody['stream'], isFalse);
      expect(result.text, 'hello');
      expect(result.finishReason, 'stop');
      expect(result.usage?.totalTokens, 5);
      expect(
        result.parts.whereType<ImagePart>().single.uri,
        'data:image/png;base64,AQIDBA==',
      );
    },
  );
}
