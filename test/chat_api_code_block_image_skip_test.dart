import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _openAiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'OpenAICodeBlockTest',
    enabled: true,
    name: 'OpenAICodeBlockTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: false,
  );
}

Future<Map<String, dynamic>> _sendAndCaptureRequestBody(
  Future<List<dynamic>> Function(String baseUrl) sendRequest,
) async {
  Map<String, dynamic>? requestBody;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.address}:${server.port}/v1';

  try {
    server.listen((request) async {
      final rawBody = await utf8.decoder.bind(request).join();
      requestBody = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'id': 'chatcmpl-1',
          'object': 'chat.completion',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'ok'},
              'finish_reason': 'stop',
            },
          ],
          'usage': {
            'prompt_tokens': 1,
            'completion_tokens': 1,
            'total_tokens': 2,
          },
        }),
      );
      await request.response.close();
    });

    final chunks = await sendRequest(baseUrl);
    expect(chunks, isNotEmpty);
    expect(requestBody, isNotNull);
    return requestBody!;
  } finally {
    await server.close(force: true);
  }
}

List<Map<String, dynamic>> _extractSingleMessageParts(
  Map<String, dynamic> body,
) {
  final messages = (body['messages'] as List).cast<dynamic>();
  expect(messages, hasLength(1));
  final content =
      (messages.single as Map<String, dynamic>)['content'] as List<dynamic>;
  return content
      .map((e) => (e as Map).cast<String, dynamic>())
      .toList(growable: false);
}

/// Extracts the text content from the single user message in the request body.
/// Handles both plain string content and structured [{"type":"text","text":...}] content.
String _extractTextContent(Map<String, dynamic> body) {
  final messages = (body['messages'] as List).cast<dynamic>();
  expect(messages, hasLength(1));
  final content = (messages.single as Map<String, dynamic>)['content'];
  if (content is String) return content;
  if (content is List) {
    final parts = content
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList(growable: false);
    expect(parts, hasLength(1));
    expect(parts.single['type'], 'text');
    return parts.single['text'] as String;
  }
  fail('Unexpected content type: ${content.runtimeType}');
}

void main() {
  group('Image refs inside code blocks are not extracted', () {
    test('fenced code block with backticks', () async {
      const input =
          'Check this:\n'
          '```markdown\n'
          '![Join QQ](https://img.shields.io/badge/QQ)\n'
          '```\n'
          'What does this mean?';

      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: [
            {'role': 'user', 'content': input},
          ],
          stream: false,
        ).toList();
      });

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('image_url')));
      expect(_extractTextContent(body), input);
    });

    test('fenced code block with tildes', () async {
      const input =
          'Example:\n'
          '~~~\n'
          '![alt](https://example.com/img.png)\n'
          '~~~';

      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: [
            {'role': 'user', 'content': input},
          ],
          stream: false,
        ).toList();
      });

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('image_url')));
      expect(_extractTextContent(body), input);
    });

    test('inline code with backticks', () async {
      const input = 'Use `![alt](https://example.com/pic.png)` in markdown.';

      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: [
            {'role': 'user', 'content': input},
          ],
          stream: false,
        ).toList();
      });

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('image_url')));
      expect(_extractTextContent(body), input);
    });

    test('double backtick inline code', () async {
      const input = 'Syntax: ``![img](https://x.com/a.png)`` here.';

      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: [
            {'role': 'user', 'content': input},
          ],
          stream: false,
        ).toList();
      });

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('image_url')));
      expect(_extractTextContent(body), input);
    });

    test('image outside code block is still extracted', () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo_code_block_test_',
      );
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final file = File('${dir.path}/real.png');
      await file.writeAsBytes(const [1, 2, 3, 4]);

      final input = '```\ncode\n```\n[image:${file.path}]';

      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: [
            {'role': 'user', 'content': input},
          ],
          stream: false,
        ).toList();
      });

      final parts = _extractSingleMessageParts(body);
      expect(parts, hasLength(2));
      expect(parts.first['type'], 'text');
      expect(parts.last['type'], 'image_url');
    });

    test('unclosed fence treats rest as code', () async {
      const input = '```\n![img](https://example.com/a.png)\nmore text';

      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: [
            {'role': 'user', 'content': input},
          ],
          stream: false,
        ).toList();
      });

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('image_url')));
      expect(_extractTextContent(body), input);
    });

    test('data URL inside code block is not extracted', () async {
      const input = '```\n![img](data:image/png;base64,QUJD)\n```\nPlain text.';

      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: [
            {'role': 'user', 'content': input},
          ],
          stream: false,
        ).toList();
      });

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('image_url')));
      expect(_extractTextContent(body), input);
    });
  });
}
