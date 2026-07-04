import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/api/chat_api_service.dart';

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

      expect(chunks.last.isDone, isTrue);
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

      expect(chunks.last.isDone, isTrue);
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

      expect(chunks.last.isDone, isTrue);
      expect(_thinkingConfig(capturedBody), isNull);
    });
  });
}
