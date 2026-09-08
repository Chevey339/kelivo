import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _openAIConfig(
  String baseUrl, {
  Map<String, dynamic> modelOverrides = const <String, dynamic>{},
}) {
  return ProviderConfig(
    id: 'AutoRetryApiTest',
    enabled: true,
    name: 'AutoRetryApiTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    modelOverrides: modelOverrides,
  );
}

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'Gemini',
    enabled: true,
    name: 'Gemini',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
  );
}

AutoRetryOptions _retryTwice() {
  return AutoRetryOptions(
    enabled: true,
    maxRetries: 2,
    initialDelayMs: 0,
    multiplier: 2,
    maxDelayMs: 0,
    jitter: false,
    retryOnNetworkError: true,
    retryStatusCodes: AutoRetryOptions.defaultRetryStatusCodes,
    retryKeywords: AutoRetryOptions.defaultRetryKeywords,
    stopKeywords: AutoRetryOptions.defaultStopKeywords,
  );
}

Future<HttpServer> _dropConnectionServer(void Function() onRequest) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    onRequest();
    await request.drain();
    final socket = await request.response.detachSocket();
    socket.destroy();
  });
  return server;
}

void main() {
  test('image generation does not retry status-less network errors', () async {
    var requests = 0;
    final server = await _dropConnectionServer(() => requests++);
    addTearDown(() async {
      await server.close(force: true);
    });
    final baseUrl = 'http://${server.address.address}:${server.port}/v1';

    await expectLater(
      ChatApiService.sendMessageStream(
        config: _openAIConfig(baseUrl),
        modelId: 'dall-e-3',
        messages: [
          {'role': 'user', 'content': 'a cat'},
        ],
        retryOverride: _retryTwice(),
      ).toList(),
      throwsA(anything),
    );
    expect(requests, 1);
  });

  test('chat text still retries status-less network errors', () async {
    var requests = 0;
    final server = await _dropConnectionServer(() => requests++);
    addTearDown(() async {
      await server.close(force: true);
    });
    final baseUrl = 'http://${server.address.address}:${server.port}/v1';

    await expectLater(
      ChatApiService.sendMessageStream(
        config: _openAIConfig(baseUrl),
        modelId: 'gpt-4o-mini',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
        retryOverride: _retryTwice(),
      ).toList(),
      throwsA(anything),
    );
    expect(requests, 3);
  });

  test('cancelRequest aborts backoff wait', () async {
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
    });
    server.listen((request) async {
      requests++;
      await request.drain();
      request.response.statusCode = HttpStatus.tooManyRequests;
      request.response.write('HTTP 429: 访问量过大');
      await request.response.close();
    });
    final baseUrl = 'http://${server.address.address}:${server.port}/v1';
    final options = AutoRetryOptions(
      enabled: true,
      maxRetries: 3,
      initialDelayMs: 8000,
      multiplier: 2,
      maxDelayMs: 8000,
      jitter: false,
      retryOnNetworkError: true,
      retryStatusCodes: AutoRetryOptions.defaultRetryStatusCodes,
      retryKeywords: AutoRetryOptions.defaultRetryKeywords,
      stopKeywords: AutoRetryOptions.defaultStopKeywords,
    );
    const requestId = 'translate-test-1';
    final sw = Stopwatch()..start();
    final done = ChatApiService.sendMessageStream(
      config: _openAIConfig(baseUrl),
      modelId: 'gpt-4o-mini',
      messages: [
        {'role': 'user', 'content': 'hi'},
      ],
      requestId: requestId,
      retryOverride: options,
    ).toList();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    ChatApiService.cancelRequest(requestId);
    await expectLater(done, throwsA(anything));
    expect(sw.elapsedMilliseconds, lessThan(1500));
    expect(requests, 1);
  });

  test('generateMessage forwards RetryPending during aggregation', () async {
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
    });
    server.listen((request) async {
      requests++;
      await request.drain();
      if (requests == 1) {
        request.response.statusCode = HttpStatus.tooManyRequests;
        request.response.write('HTTP 429: 访问量过大');
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'content': 'hello'},
            },
          ],
        }),
      );
      await request.response.close();
    });
    final baseUrl = 'http://${server.address.address}:${server.port}/v1';
    final pending = <RetryPending?>[];
    final result = await ChatApiService.generateMessage(
      config: _openAIConfig(baseUrl),
      modelId: 'gpt-4o-mini',
      messages: [
        {'role': 'user', 'content': 'hi'},
      ],
      retryOverride: _retryTwice(),
      onRetry: pending.add,
    );
    expect(requests, 2);
    expect(pending, hasLength(2));
    expect(pending.first, isA<RetryPending>());
    expect(pending.first!.attempt, 1);
    expect(pending.first!.retryAt, isNotNull);
    expect(pending.last, isNull);
    expect(result.text, 'hello');
  });

  test('retries an empty tool follow-up without rerunning the tool', () async {
    var requests = 0;
    var toolCalls = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
    });
    server.listen((request) async {
      requests++;
      await request.drain<void>();
      if (requests == 2) {
        request.response.statusCode = HttpStatus.tooManyRequests;
        request.response.write(
          '{"error":{"code":"1305","message":"该模型当前访问量过大，请您稍后再试"}}',
        );
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      final data = requests == 1
          ? {
              'choices': [
                {
                  'index': 0,
                  'delta': {
                    'role': 'assistant',
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call_1',
                        'type': 'function',
                        'function': {'name': 'get_time', 'arguments': '{}'},
                      },
                    ],
                  },
                  'finish_reason': 'tool_calls',
                },
              ],
            }
          : {
              'choices': [
                {
                  'index': 0,
                  'delta': {'content': 'recovered'},
                  'finish_reason': 'stop',
                },
              ],
            };
      request.response.write('data: ${jsonEncode(data)}\n\n');
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });
    final baseUrl = 'http://${server.address.address}:${server.port}/v1';

    final chunks = await ChatApiService.sendMessageStream(
      config: _openAIConfig(baseUrl),
      modelId: 'gpt-4o-mini',
      messages: [
        {'role': 'user', 'content': 'what time is it?'},
      ],
      tools: const [
        {
          'type': 'function',
          'function': {
            'name': 'get_time',
            'description': 'Get the current time',
            'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
          },
        },
      ],
      onToolCall: (name, arguments, {toolCallId}) async {
        toolCalls++;
        return '12:34';
      },
      retryOverride: _retryTwice(),
    ).toList();

    expect(requests, 3);
    expect(toolCalls, 1);
    expect(chunks.whereType<RetryPending>(), hasLength(1));
    expect(chunks.whereType<RetryAttemptStart>(), hasLength(1));
    expect(
      chunks.whereType<TextDelta>().map((chunk) => chunk.text).join(),
      'recovered',
    );
    expect(chunks.whereType<Finish>(), hasLength(1));
  });

  test(
    'Gemini native image-output models do not retry status-less disconnects',
    () async {
      var requests = 0;
      final server = await _dropConnectionServer(() => requests++);
      addTearDown(() async {
        await server.close(force: true);
      });
      final baseUrl = 'http://${server.address.address}:${server.port}';

      await expectLater(
        ChatApiService.sendMessageStream(
          config: _geminiConfig(baseUrl),
          modelId: 'gemini-2.0-flash-preview-image-generation',
          messages: [
            {'role': 'user', 'content': 'a cat'},
          ],
          retryOverride: _retryTwice(),
        ).toList(),
        throwsA(anything),
      );
      expect(requests, 1);
    },
  );

  test(
    'OpenAI-compatible image-output chat does not retry status-less disconnects',
    () async {
      var requests = 0;
      final server = await _dropConnectionServer(() => requests++);
      addTearDown(() async {
        await server.close(force: true);
      });
      final baseUrl = 'http://${server.address.address}:${server.port}/v1';

      await expectLater(
        ChatApiService.sendMessageStream(
          config: _openAIConfig(
            baseUrl,
            modelOverrides: const {
              'gpt-4o-mini': {
                'output': ['text', 'image'],
              },
            },
          ),
          modelId: 'gpt-4o-mini',
          messages: [
            {'role': 'user', 'content': 'a cat'},
          ],
          retryOverride: _retryTwice(),
        ).toList(),
        throwsA(anything),
      );
      expect(requests, 1);
    },
  );
}
