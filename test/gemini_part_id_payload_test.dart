import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GeminiPartIdTest',
    enabled: true,
    name: 'GeminiPartIdTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
  );
}

Map<String, dynamic> _streamChunk(
  List<Map<String, dynamic>> parts, {
  String? finishReason,
}) {
  return {
    'candidates': [
      {
        'content': {'parts': parts},
        if (finishReason != null) 'finishReason': finishReason,
      },
    ],
    'usageMetadata': {
      'promptTokenCount': 1,
      'candidatesTokenCount': 1,
      'totalTokenCount': 2,
    },
  };
}

void _expectNoGooglePartIds(Map<String, dynamic> body) {
  final contents = (body['contents'] as List).cast<Map>();
  for (final content in contents) {
    final parts = (content['parts'] as List?)?.cast<Map>() ?? const <Map>[];
    for (final part in parts) {
      expect(part.containsKey('id'), isFalse, reason: jsonEncode(part));
    }
  }
}

void main() {
  group('Gemini API part ids', () {
    test('strips internal ids from historical function parts', () async {
      Map<String, dynamic>? requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
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
          }),
        );
        await request.response.close();
      });

      await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.1-pro-preview',
        messages: const [
          {'role': 'user', 'content': 'Fetch the page.'},
          {
            'role': 'assistant',
            'content': '\n\n',
            'tool_calls': [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {
                  'name': 'fetch_markdown',
                  'arguments': '{"url":"https://example.com"}',
                },
                'metadata': {
                  'google': {
                    'part': {
                      'id': 'api_call_1',
                      'functionCall': {
                        'name': 'fetch_markdown',
                        'args': {'url': 'https://example.com'},
                      },
                      'thoughtSignature': 'sig-call',
                    },
                  },
                },
              },
            ],
          },
          {
            'role': 'tool',
            'name': 'fetch_markdown',
            'tool_call_id': 'call_1',
            'content': '{"result":"ok"}',
            'metadata': {
              'google': {
                'part': {'id': 'api_call_1'},
              },
            },
          },
          {'role': 'user', 'content': 'Continue.'},
        ],
        stream: false,
      ).toList();

      expect(requestBody, isNotNull);
      _expectNoGooglePartIds(requestBody!);
      final contents = (requestBody!['contents'] as List).cast<Map>();
      final modelParts = (contents[1]['parts'] as List).cast<Map>();
      expect(modelParts.single['thoughtSignature'], 'sig-call');
    });

    test(
      'strips internal ids from live tool-call continuation parts',
      () async {
        final requestBodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        var requestCount = 0;
        server.listen((request) async {
          requestCount++;
          requestBodies.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');

          if (requestCount == 1) {
            request.response.write(
              'data: ${jsonEncode(_streamChunk([
                {
                  'id': '',
                  'functionCall': {
                    'name': 'fetch_markdown',
                    'args': {'url': 'https://example.com'},
                  },
                  'thoughtSignature': 'sig-live',
                },
              ], finishReason: 'STOP'))}\n\n',
            );
            request.response.write('data: [DONE]');
            await request.response.close();
            return;
          }

          if (requestCount == 2) {
            request.response.write(
              'data: ${jsonEncode(_streamChunk([
                {'text': 'done'},
              ], finishReason: 'STOP'))}\n\n',
            );
            request.response.write('data: [DONE]');
            await request.response.close();
            return;
          }

          fail('Unexpected request count: $requestCount');
        });

        final seenToolCallIds = <String?>[];
        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-3.1-pro-preview',
          messages: const [
            {'role': 'user', 'content': 'Fetch the page.'},
          ],
          tools: const [
            {
              'function_declarations': [
                {
                  'name': 'fetch_markdown',
                  'description': 'Fetch markdown',
                  'parameters': {
                    'type': 'object',
                    'properties': {
                      'url': {'type': 'string'},
                    },
                    'required': ['url'],
                  },
                },
              ],
            },
          ],
          onToolCall: (name, args, {toolCallId}) async {
            seenToolCallIds.add(toolCallId);
            return '{"result":"ok"}';
          },
        ).toList();

        expect(chunks.last.isDone, isTrue);
        expect(seenToolCallIds.single, isNotEmpty);
        expect(requestCount, 2);
        expect(requestBodies, hasLength(2));
        _expectNoGooglePartIds(requestBodies[1]);
        final contents = (requestBodies[1]['contents'] as List).cast<Map>();
        final modelParts = (contents[1]['parts'] as List).cast<Map>();
        final userParts = (contents[2]['parts'] as List).cast<Map>();
        expect(modelParts.single['thoughtSignature'], 'sig-live');
        expect(modelParts.single.containsKey('functionCall'), isTrue);
        expect(userParts.single.containsKey('functionResponse'), isTrue);
      },
    );

    test('keeps image parts in live tool-call continuation contents', () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo_gemini_tool_img_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final file = File('${dir.path}/gemini.png');
      await file.writeAsBytes(const [1, 2, 3, 4]);

      final requestBodies = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        requestBodies.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.headers.set('Transfer-Encoding', 'chunked');

        if (requestCount == 1) {
          request.response.write(
            'data: ${jsonEncode(_streamChunk([
              {
                'functionCall': {'name': 'lookup', 'args': <String, dynamic>{}},
              },
            ], finishReason: 'STOP'))}\n\n',
          );
        } else {
          request.response.write(
            'data: ${jsonEncode(_streamChunk([
              {'text': 'done'},
            ], finishReason: 'STOP'))}\n\n',
          );
        }
        request.response.write('data: [DONE]');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-2.5-pro',
        messages: [
          {'role': 'user', 'content': 'inspect [image:${file.path}]'},
        ],
        onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
      ).toList();

      expect(chunks.last.isDone, isTrue);
      expect(requestBodies, hasLength(2));
      final contents = (requestBodies[1]['contents'] as List).cast<Map>();
      final firstUserParts = (contents.first['parts'] as List).cast<Map>();

      expect(firstUserParts.first['text'], 'inspect');
      expect(firstUserParts.any((part) => part['inline_data'] is Map), isTrue);
      final imagePart = firstUserParts.firstWhere(
        (part) => part['inline_data'] is Map,
      );
      expect(imagePart['inline_data']['mime_type'], 'image/png');
      expect(imagePart['inline_data']['data'], 'AQIDBA==');
    });
  });
}
