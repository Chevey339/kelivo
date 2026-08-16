import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'support/collect_generation.dart';

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GeminiThoughtTest',
    enabled: true,
    name: 'GeminiThoughtTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
  );
}

Future<HttpServer> _startServer(
  void Function(Map<String, dynamic> body) onBody, {
  required void Function(HttpRequest request) writeResponse,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final bodyText = await utf8.decoder.bind(request).join();
    onBody(jsonDecode(bodyText) as Map<String, dynamic>);
    writeResponse(request);
    await request.response.close();
  });
  return server;
}

void main() {
  group('Gemini thought parts', () {
    test('non-stream response emits thought text as reasoning', () async {
      late Map<String, dynamic> capturedBody;
      final server = await _startServer(
        (body) {
          capturedBody = body;
        },
        writeResponse: (request) {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'Check constraints.', 'thought': true},
                        {'text': 'Final answer.'},
                      ],
                    },
                  },
                ],
                'usageMetadata': {
                  'promptTokenCount': 1,
                  'candidatesTokenCount': 2,
                  'totalTokenCount': 3,
                },
              }),
            );
        },
      );
      addTearDown(() async {
        await server.close(force: true);
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-custom-thinking',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        stream: false,
      ).toList();

      expect(chunks.whereType<ReasoningDelta>().map((chunk) => chunk.text), [
        'Check constraints.',
      ]);
      expect(chunks.joinedContent, 'Final answer.');
      expect(chunks.isGenerationDone, isTrue);
      expect(
        capturedBody['generationConfig']['thinkingConfig'],
        containsPair('includeThoughts', true),
      );
    });

    test(
      'stream response keeps normal text separate from thought text',
      () async {
        late Map<String, dynamic> capturedBody;
        final server = await _startServer(
          (body) {
            capturedBody = body;
          },
          writeResponse: (request) {
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType('text', 'event-stream')
              ..headers.set('Transfer-Encoding', 'chunked')
              ..write(
                'data: ${jsonEncode({
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': 'Reasoning delta.', 'thought': true},
                          {'text': 'Visible delta.'},
                        ],
                      },
                      'finishReason': 'STOP',
                    },
                  ],
                })}\n\n',
              )
              ..write('data: [DONE]');
          },
        );
        addTearDown(() async {
          await server.close(force: true);
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-custom-thinking',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
        ).toList();

        expect(chunks.whereType<ReasoningDelta>().map((chunk) => chunk.text), [
          'Reasoning delta.',
        ]);
        expect(chunks.joinedContent, 'Visible delta.');
        expect(chunks.isGenerationDone, isTrue);
        expect(
          capturedBody['generationConfig']['thinkingConfig'],
          containsPair('includeThoughts', true),
        );
      },
    );
  });
}
