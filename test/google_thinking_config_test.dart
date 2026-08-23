import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GeminiTest',
    enabled: true,
    name: 'GeminiTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
  );
}

Future<HttpServer> _startGeminiServer(
  void Function(Map<String, dynamic> body) onBody,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final bodyText = await utf8.decoder.bind(request).join();
    onBody(jsonDecode(bodyText) as Map<String, dynamic>);

    request.response.statusCode = HttpStatus.ok;
    if (request.uri.path.endsWith(':streamGenerateContent')) {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
          'usageMetadata': {'promptTokenCount': 1, 'candidatesTokenCount': 1, 'totalTokenCount': 2},
        })}\n\n',
      );
      request.response.write('data: [DONE]');
    } else {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ],
              },
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 1,
            'candidatesTokenCount': 1,
            'totalTokenCount': 2,
          },
        }),
      );
    }
    await request.response.close();
  });
  return server;
}

Map<String, dynamic>? _thinkingConfig(Map<String, dynamic> body) {
  final generationConfig = body['generationConfig'];
  if (generationConfig is! Map) return null;
  final thinkingConfig = generationConfig['thinkingConfig'];
  if (thinkingConfig is! Map) return null;
  return thinkingConfig.cast<String, dynamic>();
}

// Runs one request against a throwaway local server and returns the body it saw.
Future<Map<String, dynamic>> _capture({
  required String modelId,
  int? thinkingBudget,
}) async {
  late Map<String, dynamic> body;
  final server = await _startGeminiServer((b) => body = b);
  addTearDown(() async {
    await server.close(force: true);
  });

  final chunks = await ChatApiService.sendMessageStream(
    config: _geminiConfig(
      'http://${server.address.address}:${server.port}/v1beta',
    ),
    modelId: modelId,
    messages: const [
      {'role': 'user', 'content': 'hello'},
    ],
    thinkingBudget: thinkingBudget,
    stream: false,
  ).toList();

  expect(chunks.isGenerationDone, isTrue, reason: modelId);
  return body;
}

void main() {
  group('Google Gemma 4 thinking config', () {
    test('non-stream request maps custom budget to thinking level', () async {
      late Map<String, dynamic> capturedBody;
      final server = await _startGeminiServer((body) {
        capturedBody = body;
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'google/gemma-4-E4B-it',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 16000,
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(_thinkingConfig(capturedBody), {
        'includeThoughts': true,
        'thinkingLevel': 'high',
      });
      expect(
        _thinkingConfig(capturedBody)!.containsKey('thinkingBudget'),
        isFalse,
      );
    });

    test('stream request maps enabled budget to thinking level', () async {
      late Map<String, dynamic> capturedBody;
      final server = await _startGeminiServer((body) {
        capturedBody = body;
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'google/gemma-4-31B-it',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 1024,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(_thinkingConfig(capturedBody), {
        'includeThoughts': true,
        'thinkingLevel': 'high',
      });
      expect(
        _thinkingConfig(capturedBody)!.containsKey('thinkingBudget'),
        isFalse,
      );
    });

    test('off budget omits thinking config for Gemma 4', () async {
      late Map<String, dynamic> capturedBody;
      final server = await _startGeminiServer((body) {
        capturedBody = body;
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemma-4-E2B-it',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 0,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(_thinkingConfig(capturedBody), isNull);
    });
  });

  group('Gemini 3.x thinking config', () {
    test('Gemini 3.6 Flash defaults to medium with 64K output', () async {
      late Map<String, dynamic> capturedBody;
      final server = await _startGeminiServer((body) {
        capturedBody = body;
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.6-flash',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(_thinkingConfig(capturedBody), {
        'includeThoughts': true,
        'thinkingLevel': 'medium',
      });
      expect(
        (capturedBody['generationConfig'] as Map)['maxOutputTokens'],
        65536,
      );
    });

    test(
      'Gemini 3.7 Flash defaults to medium and rejects minimal off',
      () async {
        late Map<String, dynamic> capturedBody;
        final server = await _startGeminiServer((body) {
          capturedBody = body;
        });
        addTearDown(() async {
          await server.close(force: true);
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-3.7-flash',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          stream: false,
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        expect(_thinkingConfig(capturedBody), {
          'includeThoughts': true,
          'thinkingLevel': 'medium',
        });
        expect(
          (capturedBody['generationConfig'] as Map)['maxOutputTokens'],
          65536,
        );
      },
    );

    test('Gemini 3.5 Flash-Lite defaults to minimal thinking', () async {
      late Map<String, dynamic> capturedBody;
      final server = await _startGeminiServer((body) {
        capturedBody = body;
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.5-flash-lite',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(_thinkingConfig(capturedBody), {
        'includeThoughts': true,
        'thinkingLevel': 'minimal',
      });
      expect(
        (capturedBody['generationConfig'] as Map)['maxOutputTokens'],
        65536,
      );
    });
    test('Gemini 3.1 Pro maps budget to medium thinkingLevel', () async {
      final body = await _capture(
        modelId: 'gemini-3.1-pro-preview',
        thinkingBudget: 16000,
      );

      expect(_thinkingConfig(body), {
        'includeThoughts': true,
        'thinkingLevel': 'medium',
      });
    });

    test(
      'Gemini 3.7 Flash floors at low because minimal is unsupported',
      () async {
        final body = await _capture(
          modelId: 'gemini-3.7-flash',
          thinkingBudget: 0,
        );

        expect(_thinkingConfig(body), {
          'includeThoughts': false,
          'thinkingLevel': 'low',
        });
      },
    );

    test(
      'Gemini 3.6 Flash still floors at minimal when thinking is off',
      () async {
        final body = await _capture(
          modelId: 'gemini-3.6-flash',
          thinkingBudget: 0,
        );

        expect(_thinkingConfig(body), {
          'includeThoughts': false,
          'thinkingLevel': 'minimal',
        });
      },
    );

    // Image ids fall through to the raw-budget branch; the off case is the only
    // one that distinguishes that from the old dedicated image branch.
    test('image ids hide thoughts when thinking is off', () async {
      final body = await _capture(
        modelId: 'gemini-3.1-flash-image',
        thinkingBudget: 0,
      );

      expect(_thinkingConfig(body), {'includeThoughts': false});
    });

    test('TTS ids never get a thinkingLevel', () async {
      final body = await _capture(
        modelId: 'gemini-3.1-flash-tts-preview',
        thinkingBudget: 16000,
      );

      expect(
        _thinkingConfig(body)?.containsKey('thinkingLevel'),
        isNot(isTrue),
      );
      expect(
        (body['generationConfig'] as Map).containsKey('maxOutputTokens'),
        isFalse,
      );
    });
  });
}
