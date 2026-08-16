import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';

ProviderConfig _moonshotConfig(String baseUrl) {
  return ProviderConfig(
    id: 'MoonshotTest',
    enabled: true,
    name: 'MoonshotTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

Future<Map<String, dynamic>> _captureMoonshotBody({
  required String modelId,
  required List<Map<String, dynamic>> messages,
  List<String>? userImagePaths,
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
    request.response.write(
      jsonEncode({
        'choices': [
          {
            'message': {'content': 'ok'},
            'finish_reason': 'stop',
          },
        ],
      }),
    );
    await request.response.close();
  });

  await ChatApiService.sendMessageStream(
    config: _moonshotConfig(
      'http://${server.address.address}:${server.port}/v1',
    ),
    modelId: modelId,
    messages: messages,
    userImagePaths: userImagePaths,
    stream: false,
  ).toList();
  return requestBody;
}

void main() {
  group('Moonshot Kimi compatibility', () {
    test('kimi-k3 filters remote images from every input path', () async {
      final dir = await Directory.systemTemp.createTemp(
        'kelivo_kimi_k3_images_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final localImage = File('${dir.path}/local.png');
      await localImage.writeAsBytes(const [1, 2, 3, 4]);

      final body = await _captureMoonshotBody(
        modelId: 'moonshotai/kimi-k3',
        messages: const [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'structured'},
              {
                'type': 'image_url',
                'image_url': {'url': 'https://example.com/structured.png'},
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,QUJD'},
              },
            ],
          },
          {
            'role': 'user',
            'content':
                'markdown ![remote](https://example.com/markdown.png) '
                '![inline](data:image/png;base64,REVG)',
          },
        ],
        userImagePaths: [
          'https://example.com/attached.png',
          'data:image/png;base64,R0hJ',
          localImage.path,
        ],
      );

      final encoded = jsonEncode(body);
      expect(encoded, isNot(contains('example.com/structured.png')));
      // Remote structured/attached refs are kept as plain text, not image_url.
      expect(encoded, contains('example.com/attached.png'));
      expect(encoded, contains('example.com/markdown.png'));

      final imageUrls = <String>[];
      for (final message in (body['messages'] as List).cast<Map>()) {
        final content = message['content'];
        if (content is! List) continue;
        for (final part in content.whereType<Map>()) {
          if (part['type'] != 'image_url') continue;
          final imageUrl = part['image_url'];
          if (imageUrl is Map && imageUrl['url'] is String) {
            imageUrls.add(imageUrl['url'] as String);
          }
        }
      }

      expect(
        imageUrls,
        containsAll([
          'data:image/png;base64,QUJD',
          'data:image/png;base64,REVG',
          'data:image/png;base64,R0hJ',
          'data:image/png;base64,AQIDBA==',
        ]),
      );
      expect(
        imageUrls,
        everyElement(
          isNot(anyOf(startsWith('http://'), startsWith('https://'))),
        ),
      );
    });

    test(
      'kimi-k2.5 disables thinking and strips unsupported sampling params',
      () async {
        final requestBodyCompleter = Completer<Map<String, dynamic>>();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          if (!requestBodyCompleter.isCompleted) {
            requestBodyCompleter.complete(body);
          }

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-1',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'kimi-k2.5',
              'choices': [
                {
                  'index': 0,
                  'delta': {'role': 'assistant', 'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final chunks = await ChatApiService.sendMessageStream(
          config: _moonshotConfig(baseUrl),
          modelId: 'kimi-k2.5',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinkingBudget: 0,
          temperature: 0.7,
          topP: 0.8,
        ).toList();

        final body = await requestBodyCompleter.future;
        expect(chunks.isGenerationDone, isTrue);
        expect(body['thinking'], {'type': 'disabled'});
        expect(body.containsKey('reasoning_effort'), isFalse);
        expect(body.containsKey('temperature'), isFalse);
        expect(body.containsKey('top_p'), isFalse);
      },
    );

    test(
      'kimi-k2.7-code omits unsupported thinking and sampling params',
      () async {
        final requestBodyCompleter = Completer<Map<String, dynamic>>();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          if (!requestBodyCompleter.isCompleted) {
            requestBodyCompleter.complete(body);
          }

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-k27',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'kimi-k2.7-code',
              'choices': [
                {
                  'index': 0,
                  'delta': {'role': 'assistant', 'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final chunks = await ChatApiService.sendMessageStream(
          config: _moonshotConfig(baseUrl),
          modelId: 'kimi-k2.7-code',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinkingBudget: 0,
          temperature: 0.7,
          topP: 0.8,
        ).toList();

        final body = await requestBodyCompleter.future;
        expect(chunks.isGenerationDone, isTrue);
        expect(body.containsKey('thinking'), isFalse);
        expect(body.containsKey('reasoning_effort'), isFalse);
        expect(body.containsKey('temperature'), isFalse);
        expect(body.containsKey('top_p'), isFalse);
      },
    );

    test(
      'kimi-k3 tool continuation preserves reasoning_content and assistant content',
      () async {
        final secondRequestCompleter = Completer<Map<String, dynamic>>();
        final toolInvocations = <Map<String, dynamic>>[];
        var requestCount = 0;

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestCount += 1;
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );

          if (requestCount == 1) {
            request.response.write(
              'data: ${jsonEncode({
                'id': 'cmpl-1',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'kimi-k3',
                'choices': [
                  {
                    'index': 0,
                    'delta': {
                      'role': 'assistant',
                      'reasoning_content': '先判断日期',
                      'content': '先查一下',
                      'tool_calls': [
                        {
                          'index': 0,
                          'id': 'call_1',
                          'type': 'function',
                          'function': {'name': 'date', 'arguments': '{}'},
                        },
                      ],
                    },
                    'finish_reason': 'tool_calls',
                  },
                ],
              })}\n\n',
            );
          } else {
            if (!secondRequestCompleter.isCompleted) {
              secondRequestCompleter.complete(body);
            }
            request.response.write(
              'data: ${jsonEncode({
                'id': 'cmpl-2',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'kimi-k3',
                'choices': [
                  {
                    'index': 0,
                    'delta': {'role': 'assistant', 'content': '今天是 2026-03-27'},
                    'finish_reason': 'stop',
                  },
                ],
              })}\n\n',
            );
          }

          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final chunks = await ChatApiService.sendMessageStream(
          config: _moonshotConfig(baseUrl),
          modelId: 'kimi-k3',
          messages: const [
            {'role': 'user', 'content': '今天几号？'},
          ],
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'date',
                'description': 'Get current date',
                'parameters': {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async {
            toolInvocations.add({'name': name, 'args': args});
            return '2026-03-27';
          },
        ).toList();

        final secondBody = await secondRequestCompleter.future;
        final messages = (secondBody['messages'] as List)
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final assistantToolMessage = messages.firstWhere(
          (m) => m['role'] == 'assistant' && m['tool_calls'] is List,
        );
        final toolMessage = messages.firstWhere((m) => m['role'] == 'tool');

        expect(toolInvocations, [
          {'name': 'date', 'args': <String, dynamic>{}},
        ]);
        expect(assistantToolMessage['content'], '先查一下');
        expect(assistantToolMessage['reasoning_content'], '先判断日期');
        expect(assistantToolMessage['tool_calls'], [
          {
            'id': 'call_1',
            'type': 'function',
            'function': {'name': 'date', 'arguments': '{}'},
          },
        ]);
        expect(toolMessage['tool_call_id'], 'call_1');
        expect(toolMessage['name'], 'date');
        expect(toolMessage['content'], '2026-03-27');
        expect(chunks.joinedContent, contains('今天是 2026-03-27'));
      },
    );

    test('empty streamed tool call id is replaced with local id', () async {
      final toolCallIds = <String?>[];
      var requestCount = 0;

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestCount += 1;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );

        if (requestCount == 1) {
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-empty-tool-id',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'kimi-k2-thinking',
              'choices': [
                {
                  'index': 0,
                  'delta': {
                    'role': 'assistant',
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': '',
                        'type': 'function',
                        'function': {'name': 'date', 'arguments': '{}'},
                      },
                    ],
                  },
                  'finish_reason': 'tool_calls',
                },
              ],
            })}\n\n',
          );
        } else {
          request.response.write(
            'data: ${jsonEncode({
              'id': 'cmpl-empty-tool-id-2',
              'object': 'chat.completion.chunk',
              'created': 0,
              'model': 'kimi-k2-thinking',
              'choices': [
                {
                  'index': 0,
                  'delta': {'role': 'assistant', 'content': 'done'},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\n',
          );
        }

        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      final chunks = await ChatApiService.sendMessageStream(
        config: _moonshotConfig(baseUrl),
        modelId: 'kimi-k2-thinking',
        messages: const [
          {'role': 'user', 'content': '今天几号？'},
        ],
        tools: const [
          {
            'type': 'function',
            'function': {
              'name': 'date',
              'description': 'Get current date',
              'parameters': {
                'type': 'object',
                'properties': <String, dynamic>{},
              },
            },
          },
        ],
        onToolCall: (name, args, {toolCallId}) async {
          toolCallIds.add(toolCallId);
          return '2026-03-27';
        },
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(toolCallIds.single, isNotEmpty);
    });

    test(
      'kimi-k2.6 tool continuation includes empty reasoning_content when missing from stream',
      () async {
        final secondRequestCompleter = Completer<Map<String, dynamic>>();
        var requestCount = 0;

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestCount += 1;
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );

          if (requestCount == 1) {
            request.response.write(
              'data: ${jsonEncode({
                'id': 'cmpl-k26-tool',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'kimi-k2.6',
                'choices': [
                  {
                    'index': 0,
                    'delta': {
                      'role': 'assistant',
                      'content': '我来帮您查看当前时间。',
                      'tool_calls': [
                        {
                          'index': 0,
                          'id': 'get_time_info:0',
                          'type': 'function',
                          'function': {'name': 'get_time_info', 'arguments': '{}'},
                        },
                      ],
                    },
                    'finish_reason': 'tool_calls',
                  },
                ],
              })}\n\n',
            );
          } else {
            if (!secondRequestCompleter.isCompleted) {
              secondRequestCompleter.complete(body);
            }
            request.response.write(
              'data: ${jsonEncode({
                'id': 'cmpl-k26-final',
                'object': 'chat.completion.chunk',
                'created': 0,
                'model': 'kimi-k2.6',
                'choices': [
                  {
                    'index': 0,
                    'delta': {'role': 'assistant', 'content': '现在是 15:43'},
                    'finish_reason': 'stop',
                  },
                ],
              })}\n\n',
            );
          }

          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final chunks = await ChatApiService.sendMessageStream(
          config: _moonshotConfig(baseUrl),
          modelId: 'kimi-k2.6',
          messages: const [
            {'role': 'user', 'content': '现在几点了'},
          ],
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'get_time_info',
                'description': 'Get the current local date and time info',
                'parameters': {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async {
            return '{"time":"15:43:49"}';
          },
        ).toList();

        final secondBody = await secondRequestCompleter.future;
        final messages = (secondBody['messages'] as List)
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final assistantToolMessage = messages.firstWhere(
          (m) => m['role'] == 'assistant' && m['tool_calls'] is List,
        );

        expect(chunks.isGenerationDone, isTrue);
        expect(secondBody.containsKey('reasoning_effort'), isFalse);
        expect(secondBody.containsKey('thinking'), isFalse);
        expect(assistantToolMessage['content'], '我来帮您查看当前时间。');
        expect(assistantToolMessage['reasoning_content'], '');
        expect(assistantToolMessage['tool_calls'], [
          {
            'id': 'get_time_info:0',
            'type': 'function',
            'function': {'name': 'get_time_info', 'arguments': '{}'},
          },
        ]);
      },
    );
  });
}
