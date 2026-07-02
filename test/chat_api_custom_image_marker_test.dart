import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/api/chat_api_service.dart';

ProviderConfig _openAiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'OpenAITest',
    enabled: true,
    name: 'OpenAITest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: false,
  );
}

ProviderConfig _openAiResponsesConfig(String baseUrl) {
  return _openAiConfig(baseUrl).copyWith(useResponseApi: true);
}

void main() {
  group('ChatApiService custom image markers', () {
    test('encodes existing local custom image markers as data URLs', () async {
      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        final dir = await Directory.systemTemp.createTemp('kelivo_local_img_');
        addTearDown(() async {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        });

        final file = File('${dir.path}/sample.png');
        await file.writeAsBytes(const [1, 2, 3, 4]);

        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: [
            {'role': 'user', 'content': 'before [image:${file.path}] after'},
          ],
          stream: false,
        ).toList();
      });

      final parts = _extractSingleMessageParts(body);
      expect(parts, hasLength(2));
      expect(parts.first['type'], 'text');
      expect(parts.first['text'], 'before  after');
      expect(parts.last['type'], 'image_url');
      expect(
        (parts.last['image_url'] as Map<String, dynamic>)['url'] as String,
        'data:image/png;base64,AQIDBA==',
      );
    });

    test(
      'passes data URL custom image markers through without file access',
      () async {
        const dataUrl = 'data:image/png;base64,QUJD';
        final body = await _sendAndCaptureRequestBody((baseUrl) async {
          return ChatApiService.sendMessageStream(
            config: _openAiConfig(baseUrl),
            modelId: 'gpt-4.1',
            messages: const [
              {
                'role': 'user',
                'content': 'inline [image:data:image/png;base64,QUJD]',
              },
            ],
            stream: false,
          ).toList();
        });

        final parts = _extractSingleMessageParts(body);
        expect(parts, hasLength(2));
        expect(parts.first['type'], 'text');
        expect(parts.first['text'], 'inline');
        expect(parts.last['type'], 'image_url');
        expect(
          (parts.last['image_url'] as Map<String, dynamic>)['url'] as String,
          dataUrl,
        );
      },
    );

    test('strips historical image markers for text-only models', () async {
      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'mimo-v2.5-pro',
          messages: const [
            {
              'role': 'user',
              'content': 'look [image:data:image/png;base64,QUJD]',
            },
            {'role': 'assistant', 'content': 'noted'},
            {'role': 'user', 'content': 'continue'},
          ],
          stream: false,
        ).toList();
      });

      expect(jsonEncode(body), isNot(contains('image_url')));
      final messages = (body['messages'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
      expect(messages.first['content'], 'look');
      expect(messages.last['content'], 'continue');
    });

    test('strips structured image_url parts for text-only models', () async {
      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'mimo-v2.5-pro',
          messages: const [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'look'},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,QUJD'},
                },
              ],
            },
            {'role': 'user', 'content': 'continue'},
          ],
          stream: false,
        ).toList();
      });

      expect(jsonEncode(body), isNot(contains('image_url')));
      final messages = (body['messages'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
      expect(messages.first['content'], 'look');
      expect(messages.last['content'], 'continue');
    });

    test(
      'strips historical local image markers for text-only models',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'kelivo_text_only_history_img_',
        );
        addTearDown(() async {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        });

        final file = File('${dir.path}/history.png');
        await file.writeAsBytes(const [1, 2, 3, 4]);

        final body = await _sendAndCaptureRequestBody((baseUrl) async {
          return ChatApiService.sendMessageStream(
            config: _openAiConfig(baseUrl),
            modelId: 'mimo-v2.5-pro',
            messages: [
              {'role': 'user', 'content': 'before [image:${file.path}] after'},
              {'role': 'user', 'content': 'continue'},
            ],
            stream: false,
          ).toList();
        });

        final encoded = jsonEncode(body);
        expect(encoded, isNot(contains('image_url')));
        expect(encoded, isNot(contains(file.path)));
        final messages = (body['messages'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);
        expect(messages.first['content'], 'before  after');
        expect(messages.last['content'], 'continue');
      },
    );

    test('does not attach current images for text-only models', () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo_text_only_current_img_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      final file = File('${dir.path}/current.png');
      await file.writeAsBytes(const [1, 2, 3, 4]);

      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'mimo-v2.5-pro',
          messages: const [
            {'role': 'user', 'content': 'continue'},
          ],
          userImagePaths: [file.path],
          stream: false,
        ).toList();
      });

      expect(jsonEncode(body), isNot(contains('image_url')));
      final messages = (body['messages'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
      expect(messages.single['content'], 'continue');
    });

    test('keeps historical image markers for image-capable models', () async {
      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: const [
            {
              'role': 'user',
              'content': 'look [image:data:image/png;base64,QUJD]',
            },
            {'role': 'user', 'content': 'continue'},
          ],
          stream: false,
        ).toList();
      });

      final messages = (body['messages'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
      final content = (messages.first['content'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
      expect(content.first['text'], 'look');
      expect(content.last['type'], 'image_url');
      expect(
        (content.last['image_url'] as Map<String, dynamic>)['url'],
        'data:image/png;base64,QUJD',
      );
    });

    test('keeps structured image_url parts for image-capable models', () async {
      final body = await _sendAndCaptureRequestBody((baseUrl) async {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: const [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'look'},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,QUJD'},
                },
              ],
            },
          ],
          stream: false,
        ).toList();
      });

      final content =
          ((body['messages'] as List).single as Map<String, dynamic>)['content']
              as List<dynamic>;
      final parts = content
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
      expect(parts.first['text'], 'look');
      expect(parts.last['type'], 'image_url');
      expect(
        (parts.last['image_url'] as Map<String, dynamic>)['url'],
        'data:image/png;base64,QUJD',
      );
    });

    test(
      'strips historical image markers from Responses input for text-only models',
      () async {
        final body = await _sendAndCaptureRequestBody((baseUrl) async {
          return ChatApiService.sendMessageStream(
            config: _openAiResponsesConfig(baseUrl),
            modelId: 'mimo-v2.5-pro',
            messages: const [
              {
                'role': 'user',
                'content': 'look [image:data:image/png;base64,QUJD]',
              },
              {'role': 'user', 'content': 'continue'},
            ],
            stream: false,
          ).toList();
        });

        expect(jsonEncode(body), isNot(contains('input_image')));
        expect(jsonEncode(body), isNot(contains('image_url')));
        final input = (body['input'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);
        expect(input.first['content'], 'look');
        expect(input.last['content'], 'continue');
      },
    );

    test(
      'keeps missing local custom image markers as text instead of reading files',
      () async {
        final missingPath =
            '${Directory.systemTemp.path}/missing_${DateTime.now().microsecondsSinceEpoch}.png';
        final body = await _sendAndCaptureRequestBody((baseUrl) async {
          return ChatApiService.sendMessageStream(
            config: _openAiConfig(baseUrl),
            modelId: 'gpt-4.1',
            messages: [
              {'role': 'user', 'content': 'before [image:$missingPath] after'},
            ],
            stream: false,
          ).toList();
        });

        final parts = _extractSingleMessageParts(body);
        expect(parts, hasLength(1));
        expect(parts.single['type'], 'text');
        expect(parts.single['text'], 'before [image:$missingPath] after');
      },
    );

    test(
      're-encodes local custom image markers for tool continuation requests',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'kelivo_tool_local_img_',
        );
        addTearDown(() async {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        });

        final file = File('${dir.path}/tool.png');
        await file.writeAsBytes(const [1, 2, 3, 4]);

        final requestBodies = await _sendToolCallAndCaptureRequestBodies((
          baseUrl,
        ) {
          return ChatApiService.sendMessageStream(
            config: _openAiConfig(baseUrl),
            modelId: 'gpt-4.1',
            messages: [
              {'role': 'user', 'content': 'inspect [image:${file.path}]'},
            ],
            tools: const [
              {
                'type': 'function',
                'function': {
                  'name': 'lookup',
                  'description': 'Lookup metadata',
                  'parameters': {
                    'type': 'object',
                    'properties': <String, dynamic>{},
                  },
                },
              },
            ],
            onToolCall: (_, __, {toolCallId}) async => 'metadata',
            stream: false,
          ).toList();
        });

        expect(requestBodies, hasLength(2));
        final secondMessages = (requestBodies[1]['messages'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);
        final userMessage = secondMessages.firstWhere(
          (message) => message['role'] == 'user',
        );
        final content = (userMessage['content'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);

        expect(content.first['text'], 'inspect');
        expect(
          (content.last['image_url'] as Map<String, dynamic>)['url'],
          'data:image/png;base64,AQIDBA==',
        );
      },
    );

    test(
      'keeps local custom image markers in Responses tool continuation input',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'kelivo_responses_tool_img_',
        );
        addTearDown(() async {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        });

        final file = File('${dir.path}/responses.png');
        await file.writeAsBytes(const [1, 2, 3, 4]);

        final requestBodies =
            await _sendResponsesToolCallAndCaptureRequestBodies((baseUrl) {
              return ChatApiService.sendMessageStream(
                config: _openAiResponsesConfig(baseUrl),
                modelId: 'gpt-4.1',
                messages: [
                  {'role': 'user', 'content': 'inspect [image:${file.path}]'},
                ],
                tools: const [
                  {
                    'type': 'function',
                    'function': {
                      'name': 'lookup',
                      'description': 'Lookup metadata',
                      'parameters': {
                        'type': 'object',
                        'properties': <String, dynamic>{},
                      },
                    },
                  },
                ],
                onToolCall: (_, __, {toolCallId}) async => 'metadata',
              ).toList();
            });

        expect(requestBodies, hasLength(2));
        final secondInput = (requestBodies[1]['input'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);
        final userInput = secondInput.firstWhere(
          (item) => item['role'] == 'user',
        );
        final content = (userInput['content'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);

        expect(content.first['text'], 'inspect');
        expect(content.last['type'], 'input_image');
        expect(content.last['image_url'], 'data:image/png;base64,AQIDBA==');
      },
    );

    test(
      'Responses tool continuation keeps streamed function call before output',
      () async {
        final requestBodies =
            await _sendResponsesToolCallAndCaptureRequestBodies(
              completedOutput: const <Map<String, dynamic>>[],
              (baseUrl) {
                return ChatApiService.sendMessageStream(
                  config: _openAiResponsesConfig(baseUrl),
                  modelId: 'gpt-5.5',
                  messages: const [
                    {'role': 'user', 'content': 'hi'},
                  ],
                  tools: const [
                    {
                      'type': 'function',
                      'function': {
                        'name': 'lookup',
                        'description': 'Lookup test data',
                        'parameters': {
                          'type': 'object',
                          'properties': <String, dynamic>{},
                        },
                      },
                    },
                  ],
                  onToolCall: (_, __, {toolCallId}) async => '{"result":"ok"}',
                ).toList();
              },
            );

        expect(requestBodies, hasLength(2));
        final followUpInput = (requestBodies[1]['input'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);
        final functionCallIndex = followUpInput.indexWhere(
          (item) =>
              item['type'] == 'function_call' && item['call_id'] == 'call_1',
        );
        final outputIndex = followUpInput.indexWhere(
          (item) =>
              item['type'] == 'function_call_output' &&
              item['call_id'] == 'call_1',
        );

        expect(functionCallIndex, isNonNegative);
        expect(outputIndex, isNonNegative);
        expect(functionCallIndex, lessThan(outputIndex));
      },
    );
  });
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

Future<List<Map<String, dynamic>>> _sendToolCallAndCaptureRequestBodies(
  Future<List<dynamic>> Function(String baseUrl) sendRequest,
) async {
  final requestBodies = <Map<String, dynamic>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.address}:${server.port}/v1';
  var requestCount = 0;

  try {
    server.listen((request) async {
      requestCount += 1;
      final rawBody = await utf8.decoder.bind(request).join();
      requestBodies.add((jsonDecode(rawBody) as Map).cast<String, dynamic>());
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;

      if (requestCount == 1) {
        request.response.write(
          jsonEncode({
            'id': 'chatcmpl-tool-1',
            'object': 'chat.completion',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': 'checking',
                  'tool_calls': [
                    {
                      'id': 'call_1',
                      'type': 'function',
                      'function': {'name': 'lookup', 'arguments': '{}'},
                    },
                  ],
                },
                'finish_reason': 'tool_calls',
              },
            ],
          }),
        );
      } else {
        request.response.write(
          jsonEncode({
            'id': 'chatcmpl-tool-2',
            'object': 'chat.completion',
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': 'done'},
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
      }
      await request.response.close();
    });

    final chunks = await sendRequest(baseUrl);
    expect(chunks, isNotEmpty);
    return requestBodies;
  } finally {
    await server.close(force: true);
  }
}

Future<List<Map<String, dynamic>>>
_sendResponsesToolCallAndCaptureRequestBodies(
  Future<List<dynamic>> Function(String baseUrl) sendRequest, {
  List<Map<String, dynamic>> completedOutput = const [
    {
      'type': 'function_call',
      'call_id': 'call_1',
      'name': 'lookup',
      'arguments': '{}',
    },
  ],
}) async {
  final requestBodies = <Map<String, dynamic>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.address}:${server.port}/v1';
  var requestCount = 0;

  try {
    server.listen((request) async {
      requestCount += 1;
      final rawBody = await utf8.decoder.bind(request).join();
      requestBodies.add((jsonDecode(rawBody) as Map).cast<String, dynamic>());
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.headers.set('Transfer-Encoding', 'chunked');

      if (requestCount == 1) {
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.output_item.added',
            'output_index': 0,
            'item': {'type': 'function_call', 'call_id': 'call_1', 'name': 'lookup'},
          })}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.output_item.done',
            'output_index': 0,
            'item': {'type': 'function_call', 'call_id': 'call_1', 'name': 'lookup', 'arguments': '{}'},
          })}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.completed',
            'response': {
              'output': completedOutput,
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            },
          })}\n\n',
        );
      } else {
        request.response.write(
          'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'done'})}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.completed',
            'response': {
              'output': [
                {
                  'type': 'message',
                  'content': [
                    {'type': 'output_text', 'text': 'done'},
                  ],
                },
              ],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            },
          })}\n\n',
        );
      }
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });

    final chunks = await sendRequest(baseUrl);
    expect(chunks, isNotEmpty);
    return requestBodies;
  } finally {
    await server.close(force: true);
  }
}
