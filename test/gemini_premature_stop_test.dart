import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';

String _frame({String? text, String? finishReason}) {
  return 'data: ${jsonEncode({
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            if (text != null) {'text': text},
          ],
        },
        if (finishReason != null) 'finishReason': finishReason,
      },
    ],
  })}\n\n';
}

void main() {
  for (final ending in ['STOP', 'EOF', 'DONE']) {
    for (final hasText in [true, false]) {
      test('leading empty STOP preserves text=$hasText with $ending', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var requestCount = 0;
        server.listen((request) async {
          requestCount++;
          await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType(
              'text',
              'event-stream',
              charset: 'utf-8',
            );
          request.response
            ..write(_frame(finishReason: 'STOP'))
            ..write(_frame(finishReason: 'STOP'));
          if (hasText) {
            for (final text in ['第一段正文。', '第二段正文。', '最后一段。']) {
              request.response.write(_frame(text: text));
            }
          }
          if (ending == 'STOP') {
            request.response
              ..write(_frame(finishReason: 'STOP'))
              ..write(_frame(finishReason: 'STOP'));
          } else if (ending == 'DONE') {
            request.response.write('data: [DONE]\n\n');
          }
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: ProviderConfig(
            id: 'GeminiPrematureStopTest',
            enabled: true,
            name: 'GeminiPrematureStopTest',
            apiKey: 'test-key',
            baseUrl: 'http://${server.address.address}:${server.port}/v1beta',
            providerType: ProviderKind.google,
          ),
          modelId: 'gemini-2.5-flash',
          messages: const [
            {'role': 'user', 'content': 'hi'},
          ],
        ).toList().timeout(const Duration(seconds: 10));

        expect(requestCount, 1);
        expect(chunks.joinedContent, hasText ? '第一段正文。第二段正文。最后一段。' : '');
        expect(chunks.isGenerationDone, isTrue);
      });
    }
  }
}
