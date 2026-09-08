import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GeminiLeadingFinishReasonTest',
    enabled: true,
    name: 'GeminiLeadingFinishReasonTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
  );
}

String _chunk(List<Map<String, dynamic>> parts, {String? finishReason}) {
  return 'data: ${jsonEncode({
    'candidates': [
      {
        'content': {'parts': parts, 'role': 'model'},
        'index': 0,
        if (finishReason != null) 'finishReason': finishReason,
      },
    ],
  })}\n\n';
}

void main() {
  test(
    'keeps streaming past an empty candidate that already says STOP',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.headers.set('Transfer-Encoding', 'chunked');
        // Some Gemini-compatible endpoints open the stream this way.
        request.response.write(_chunk(const [], finishReason: 'STOP'));
        request.response.write(_chunk(const [], finishReason: 'STOP'));
        request.response.write(
          _chunk(const [
            {'text': 'pro 20x '},
          ]),
        );
        request.response.write(
          _chunk(const [
            {'text': 'is four times 5x.'},
          ]),
        );
        request.response.write(_chunk(const [], finishReason: 'STOP'));
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.1-flash-preview',
        messages: const [
          {'role': 'user', 'content': 'How many tasks fit in pro 20x?'},
        ],
      ).toList();

      expect(chunks.joinedContent, 'pro 20x is four times 5x.');
      expect(chunks.isGenerationDone, isTrue);
    },
  );
}
