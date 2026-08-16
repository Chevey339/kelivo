import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';

void main() {
  test('Images API uses the same custom request priority', () async {
    late HttpHeaders receivedHeaders;
    late Map<String, dynamic> receivedBody;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((request) async {
      receivedHeaders = request.headers;
      receivedBody =
          (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
              .cast<String, dynamic>();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': [
            {'url': 'https://example.test/image.png'},
          ],
        }),
      );
      await request.response.close();
    });

    final config = ProviderConfig(
      id: 'ImageTest',
      enabled: true,
      name: 'ImageTest',
      apiKey: 'test-key',
      baseUrl: 'http://${server.address.address}:${server.port}/v1',
      providerType: ProviderKind.openai,
      customHeaders: const [
        {'name': 'X-Level', 'value': 'provider'},
      ],
      customBody: const [
        {'key': 'quality', 'value': 'provider'},
      ],
      modelOverrides: const {
        'gpt-image-2': {
          'headers': [
            {'name': 'x-level', 'value': 'model'},
          ],
          'body': [
            {'key': 'quality', 'value': 'model'},
          ],
        },
      },
    );

    final chunks = await ChatApiService.sendMessageStream(
      config: config,
      modelId: 'gpt-image-2',
      messages: const [
        {'role': 'user', 'content': 'draw a cat'},
      ],
      extraHeaders: const {'X-Level': 'assistant'},
      extraBody: const {'quality': 'assistant'},
      stream: false,
    ).toList();

    expect(chunks.isGenerationDone, isTrue);
    expect(receivedHeaders.value('x-level'), 'model');
    expect(receivedBody['quality'], 'model');
  });
}
