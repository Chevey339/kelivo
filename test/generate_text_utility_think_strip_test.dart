import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _config(String baseUrl) {
  return ProviderConfig(
    id: 'UtilityThinkStripTest',
    enabled: true,
    name: 'UtilityThinkStripTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

Future<String> _generateTextWithReply(String replyContent) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });
  server.listen((request) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'choices': [
          {
            'message': {'content': replyContent},
          },
        ],
      }),
    );
    await request.response.close();
  });

  return ChatApiService.generateText(
    config: _config('http://${server.address.address}:${server.port}/v1'),
    modelId: 'test-model',
    prompt: 'summarize',
  );
}

void main() {
  group('ChatApiService.generateText thinking-tag strip', () {
    test('strips a closed think block from utility output', () async {
      expect(
        await _generateTextWithReply(
          '<think>chain of thought</think>Dark mode chat',
        ),
        'Dark mode chat',
      );
    });

    test('strips multiple mixed think blocks', () async {
      expect(
        await _generateTextWithReply(
          '<thinking>a</thinking>Title<thought>b</thought> tail',
        ),
        'Title tail',
      );
    });

    test('discards a truncated think block from utility output', () async {
      expect(await _generateTextWithReply('<think>truncated reasoning'), '');
    });

    test('keeps plain utility output unchanged', () async {
      expect(await _generateTextWithReply('Dark mode chat'), 'Dark mode chat');
    });
  });
}
