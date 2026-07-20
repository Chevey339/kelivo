import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/api/chat_api_service.dart';

ProviderConfig _openAiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'OpenAITextOnlyImageFilterTest',
    enabled: true,
    name: 'OpenAITextOnlyImageFilterTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

ProviderConfig _claudeConfig(String baseUrl) {
  return ProviderConfig(
    id: 'ClaudeTextOnlyImageFilterTest',
    enabled: true,
    name: 'ClaudeTextOnlyImageFilterTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.claude,
    modelOverrides: const <String, dynamic>{
      'claude-sonnet-4-6': <String, dynamic>{
        'input': <String>['text'],
      },
    },
  );
}

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GeminiTextOnlyImageFilterTest',
    enabled: true,
    name: 'GeminiTextOnlyImageFilterTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
    modelOverrides: const <String, dynamic>{
      'gemini-2.5-pro': <String, dynamic>{
        'input': <String>['text'],
      },
    },
  );
}

Future<Map<String, dynamic>> _captureJsonRequest(
  Future<void> Function(String baseUrl) send, {
  required Map<String, dynamic> responseBody,
}) async {
  late Map<String, dynamic> requestBody;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });

  server.listen((request) async {
    requestBody = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
        .cast<String, dynamic>();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(responseBody));
    await request.response.close();
  });

  await send('http://${server.address.address}:${server.port}');
  return requestBody;
}

Future<File> _tempPng(String prefix) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  final file = File('${dir.path}/sample.png');
  await file.writeAsBytes(const [1, 2, 3, 4]);
  addTearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });
  return file;
}

void main() {
  group('ChatApiService text-only image filtering', () {
    test('removes OpenAI image_url parts when OCR is inactive', () async {
      final file = await _tempPng('kelivo_openai_text_only_filter_');
      final body = await _captureJsonRequest(
        (baseUrl) {
          return ChatApiService.sendMessageStream(
            config: _openAiConfig(baseUrl),
            modelId: 'mimo-v2.5-pro',
            messages: [
              {'role': 'user', 'content': 'before [image:${file.path}] after'},
              {
                'role': 'user',
                'content': const [
                  {'type': 'text', 'text': 'next'},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/png;base64,QUJD'},
                  },
                ],
              },
            ],
            stream: false,
          ).toList();
        },
        responseBody: const <String, dynamic>{
          'choices': [
            {
              'message': {'content': 'ok'},
            },
          ],
        },
      );

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('image_url')));
      expect(encoded, isNot(contains('[image:')));
      expect(encoded, isNot(contains(file.path)));
      final messages = (body['messages'] as List).cast<Map>();
      expect(messages.first['content'], 'before  after');
      expect(messages.last['content'], 'next');
    });

    test('removes Claude image blocks when OCR is inactive', () async {
      final file = await _tempPng('kelivo_claude_text_only_filter_');
      final body = await _captureJsonRequest(
        (baseUrl) {
          return ChatApiService.sendMessageStream(
            config: _claudeConfig(baseUrl),
            modelId: 'claude-sonnet-4-6',
            messages: [
              {'role': 'user', 'content': 'before [image:${file.path}] after'},
              {'role': 'user', 'content': 'continue'},
            ],
            userMediaPaths: [file.path],
            stream: false,
          ).toList();
        },
        responseBody: const <String, dynamic>{
          'id': 'msg_1',
          'content': [
            {'type': 'text', 'text': 'ok'},
          ],
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        },
      );

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('"type":"image"')));
      expect(encoded, isNot(contains('[image:')));
      expect(encoded, isNot(contains(file.path)));
      final messages = (body['messages'] as List).cast<Map>();
      expect(messages.first['content'], 'before  after');
      expect(messages.last['content'], 'continue');
    });

    test('removes Gemini inline_data parts when OCR is inactive', () async {
      final file = await _tempPng('kelivo_gemini_text_only_filter_');
      final body = await _captureJsonRequest(
        (baseUrl) {
          return ChatApiService.sendMessageStream(
            config: _geminiConfig('$baseUrl/v1beta'),
            modelId: 'gemini-2.5-pro',
            messages: [
              {'role': 'user', 'content': 'before [image:${file.path}] after'},
              {'role': 'user', 'content': 'continue'},
            ],
            userMediaPaths: [file.path],
            stream: false,
          ).toList();
        },
        responseBody: const <String, dynamic>{
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ],
              },
            },
          ],
        },
      );

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('inline_data')));
      expect(encoded, isNot(contains('[image:')));
      expect(encoded, isNot(contains(file.path)));
      final contents = (body['contents'] as List).cast<Map>();
      final firstParts = (contents.first['parts'] as List).cast<Map>();
      final lastParts = (contents.last['parts'] as List).cast<Map>();
      expect(firstParts.single['text'], 'before  after');
      expect(lastParts.single['text'], 'continue');
    });
  });
}
