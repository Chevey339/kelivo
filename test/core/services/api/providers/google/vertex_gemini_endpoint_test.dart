import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

void main() {
  test('Vertex Gemini streams from the origin vertexOrigin picks', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'ok'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
        })}\n\n',
      );
      await request.response.close();
    });

    await ChatApiService.sendMessageStream(
      config: ProviderConfig(
        id: 'VertexGeminiTest',
        enabled: true,
        name: 'VertexGeminiTest',
        apiKey: 'token',
        baseUrl: 'http://${server.address.address}:${server.port}',
        providerType: ProviderKind.google,
        vertexAI: true,
        location: 'eu',
        projectId: 'proj',
      ),
      modelId: 'gemini-4-argon',
      messages: const [
        {'role': 'user', 'content': 'hi'},
      ],
    ).toList();

    expect(paths, [
      '/v1/projects/proj/locations/eu/publishers/google/models/gemini-4-argon:streamGenerateContent',
    ]);
  });
}
