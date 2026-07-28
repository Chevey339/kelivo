import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _testConfig(
  String baseUrl,
  ProviderKind kind, {
  bool? useResponseApi,
}) {
  return ProviderConfig(
    id: 'SseErrorTest',
    enabled: true,
    name: 'SseErrorTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: kind,
    useResponseApi: useResponseApi,
  );
}

Future<HttpServer> _sseServer(List<String> frames) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    request.response.statusCode = 200;
    request.response.headers
      ..contentType = ContentType('text', 'event-stream')
      ..set('Transfer-Encoding', 'chunked');
    for (final frame in frames) {
      request.response.write(frame);
    }
    request.response.close();
  });
  return server;
}

Future<({List<ChatStreamChunk> chunks, Object? error})> _drain(
  Stream<ChatStreamChunk> stream,
) async {
  final chunks = <ChatStreamChunk>[];
  Object? error;
  try {
    await for (final c in stream) {
      chunks.add(c);
    }
  } catch (e) {
    error = e;
  }
  return (chunks: chunks, error: error);
}

void main() {
  group('OpenAI-compatible in-band SSE error', () {
    test('error frame ends stream with error, no fake isDone', () async {
      final delta = jsonEncode({
        'choices': [
          {
            'delta': {'content': 'Partial'},
            'finish_reason': null,
          },
        ],
      });
      final errorFrame = jsonEncode({
        'error': {'message': 'Rate limit exceeded', 'code': 429},
      });
      final server = await _sseServer([
        'data: $delta\n\n',
        'data: $errorFrame\n\n',
      ]);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}/v1',
            ProviderKind.openai,
          ),
          modelId: 'test-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('Rate limit exceeded'));
      expect(result.chunks.map((c) => c.content).join(), contains('Partial'));
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });

    test(
      'null/empty error placeholders on healthy chunks do not throw',
      () async {
        final delta = jsonEncode({
          'error': null,
          'choices': [
            {
              'delta': {'content': 'Hello'},
              'finish_reason': null,
            },
          ],
        });
        final emptyError = jsonEncode({
          'error': <String, dynamic>{},
          'choices': [
            {
              'delta': {'content': ' World'},
              'finish_reason': 'stop',
            },
          ],
        });
        final server = await _sseServer([
          'data: $delta\n\n',
          'data: $emptyError\n\n',
          'data: [DONE]\n\n',
        ]);
        addTearDown(() async {
          await server.close(force: true);
        });

        final result = await _drain(
          ChatApiService.sendMessageStream(
            config: _testConfig(
              'http://localhost:${server.port}/v1',
              ProviderKind.openai,
            ),
            modelId: 'test-model',
            messages: [
              {'role': 'user', 'content': 'hi'},
            ],
          ),
        );

        expect(result.error, isNull);
        expect(result.chunks.map((c) => c.content).join(), 'Hello World');
        expect(result.chunks.last.isDone, isTrue);
      },
    );

    test('OpenRouter mid-stream error frame with non-empty choices '
        'ends stream with error, no fake isDone', () async {
      final delta = jsonEncode({
        'choices': [
          {
            'delta': {'content': 'Partial'},
            'finish_reason': null,
          },
        ],
      });
      // Documented OpenRouter mid-stream failure shape: top-level `error`
      // together with a choices entry whose finish_reason is 'error'.
      final errorFrame = jsonEncode({
        'error': {'message': 'Provider ran out of capacity', 'code': 502},
        'choices': [
          {
            'index': 0,
            'delta': {'content': ''},
            'finish_reason': 'error',
          },
        ],
      });
      final server = await _sseServer([
        'data: $delta\n\n',
        'data: $errorFrame\n\n',
        'data: [DONE]\n\n',
      ]);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}/v1',
            ProviderKind.openai,
          ),
          modelId: 'test-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('Provider ran out of capacity'));
      expect(result.chunks.map((c) => c.content).join(), contains('Partial'));
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });
  });

  group('OpenAI follow-up tool-call errors', () {
    const toolSpec = <String, dynamic>{
      'type': 'function',
      'function': {
        'name': 'get_date',
        'description': 'Get current date',
        'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
      },
    };

    // First-round SSE: a single chunk that streams a tool_call delta together
    // with finish_reason 'tool_calls', which triggers the in-parser follow-up
    // request path (the one formerly swallowed by the per-event catch).
    final toolCallChunk = jsonEncode({
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
                'function': {'name': 'get_date', 'arguments': '{}'},
              },
            ],
          },
          'finish_reason': 'tool_calls',
        },
      ],
    });

    Future<HttpServer> twoRoundServer(
      Future<void> Function(HttpRequest request) onSecond,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        if (requestCount == 1) {
          request.response.statusCode = 200;
          request.response.headers
            ..contentType = ContentType('text', 'event-stream')
            ..set('Transfer-Encoding', 'chunked');
          request.response.write('data: $toolCallChunk\n\n');
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        } else {
          await onSecond(request);
        }
      });
      return server;
    }

    Future<({List<ChatStreamChunk> chunks, Object? error})> runTwoRounds(
      HttpServer server,
    ) {
      return _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}/v1',
            ProviderKind.openai,
          ),
          modelId: 'test-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
          tools: const [toolSpec],
          onToolCall: (name, args, {toolCallId}) async => '2026-07-26',
        ),
      );
    }

    test('follow-up non-2xx response propagates, no fake isDone', () async {
      final server = await twoRoundServer((request) async {
        request.response.statusCode = 500;
        request.response.write('server exploded');
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await runTwoRounds(server);

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('HTTP 500'));
      expect(result.chunks.any((c) => c.toolCalls != null), isTrue);
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });

    test(
      'follow-up request transport failure propagates, no fake isDone',
      () async {
        // Refuse the follow-up request by closing the server right after the
        // first round; client.send then fails with http.ClientException, which
        // the per-event catch used to swallow into a fake completion.
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var requestCount = 0;
        server.listen((request) async {
          requestCount++;
          request.response.statusCode = 200;
          request.response.headers
            ..contentType = ContentType('text', 'event-stream')
            ..set('Transfer-Encoding', 'chunked');
          request.response.write('data: $toolCallChunk\n\n');
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
          await server.close(force: true);
        });

        final result = await runTwoRounds(server);

        expect(requestCount, 1);
        expect(result.error, isA<HttpException>());
        expect(result.error.toString(), contains('Follow-up request failed'));
        expect(result.chunks.any((c) => c.isDone), isFalse);
      },
    );

    test('follow-up in-band error frame propagates, no fake isDone', () async {
      final errorFrame = jsonEncode({
        'error': {'message': 'Follow-up rate limited', 'code': 429},
      });
      final server = await twoRoundServer((request) async {
        request.response.statusCode = 200;
        request.response.headers
          ..contentType = ContentType('text', 'event-stream')
          ..set('Transfer-Encoding', 'chunked');
        request.response.write('data: $errorFrame\n\n');
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await runTwoRounds(server);

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('Follow-up rate limited'));
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });

    test('malformed JSON line is still skipped', () async {
      final hello = jsonEncode({
        'choices': [
          {
            'delta': {'content': 'Hel'},
            'finish_reason': null,
          },
        ],
      });
      final lo = jsonEncode({
        'choices': [
          {
            'delta': {'content': 'lo'},
            'finish_reason': 'stop',
          },
        ],
      });
      final server = await _sseServer([
        'data: $hello\n\n',
        'data: {not-json\n\n',
        'data: $lo\n\n',
        'data: [DONE]\n\n',
      ]);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}/v1',
            ProviderKind.openai,
          ),
          modelId: 'test-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isNull);
      expect(result.chunks.map((c) => c.content).join(), 'Hello');
      expect(result.chunks.last.isDone, isTrue);
    });
  });

  group('OpenAI Responses API in-band SSE error', () {
    test(
      'response.failed event ends stream with error, no fake isDone',
      () async {
        final delta = jsonEncode({
          'type': 'response.output_text.delta',
          'delta': 'Partial',
        });
        final failed = jsonEncode({
          'type': 'response.failed',
          'response': {
            'status': 'failed',
            'error': {'code': 'server_error', 'message': 'The model crashed'},
          },
        });
        final server = await _sseServer([
          'data: $delta\n\n',
          'data: $failed\n\n',
        ]);
        addTearDown(() async {
          await server.close(force: true);
        });

        final result = await _drain(
          ChatApiService.sendMessageStream(
            config: _testConfig(
              'http://localhost:${server.port}/v1',
              ProviderKind.openai,
              useResponseApi: true,
            ),
            modelId: 'test-model',
            messages: [
              {'role': 'user', 'content': 'hi'},
            ],
          ),
        );

        expect(result.error, isA<HttpException>());
        expect(result.error.toString(), contains('The model crashed'));
        expect(result.chunks.map((c) => c.content).join(), contains('Partial'));
        expect(result.chunks.any((c) => c.isDone), isFalse);
      },
    );

    test('response.incomplete event ends stream with error', () async {
      final incomplete = jsonEncode({
        'type': 'response.incomplete',
        'response': {
          'status': 'incomplete',
          'error': null,
          'incomplete_details': {'reason': 'content_filter'},
        },
      });
      final server = await _sseServer(['data: $incomplete\n\n']);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}/v1',
            ProviderKind.openai,
            useResponseApi: true,
          ),
          modelId: 'test-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('content_filter'));
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });

    test('event: error frame without top-level error key ends stream '
        'with error', () async {
      final errorFrame = jsonEncode({
        'type': 'error',
        'code': 'ERR_SOMETHING',
        'message': 'Stream exploded',
        'param': null,
        'sequence_number': 1,
      });
      final server = await _sseServer(['event: error\ndata: $errorFrame\n\n']);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}/v1',
            ProviderKind.openai,
            useResponseApi: true,
          ),
          modelId: 'test-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('Stream exploded'));
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });
  });

  group('Claude in-band SSE error', () {
    test('event: error frame ends stream with error, no fake isDone', () async {
      final start = jsonEncode({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'text', 'text': ''},
      });
      final delta = jsonEncode({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'Partial'},
      });
      final errorFrame = jsonEncode({
        'type': 'error',
        'error': {'type': 'overloaded_error', 'message': 'Overloaded'},
      });
      final server = await _sseServer([
        'event: content_block_start\ndata: $start\n\n',
        'event: content_block_delta\ndata: $delta\n\n',
        'event: error\ndata: $errorFrame\n\n',
      ]);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}',
            ProviderKind.claude,
          ),
          modelId: 'claude-test',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('Overloaded'));
      expect(result.chunks.map((c) => c.content).join(), contains('Partial'));
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });
  });

  group('Gemini in-band SSE error', () {
    test(
      'top-level error frame ends stream with error, no fake isDone',
      () async {
        final delta = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Partial'},
                ],
              },
            },
          ],
        });
        final errorFrame = jsonEncode({
          'error': {
            'code': 429,
            'message': 'Resource has been exhausted',
            'status': 'RESOURCE_EXHAUSTED',
          },
        });
        final server = await _sseServer([
          'data: $delta\n\n',
          'data: $errorFrame\n\n',
        ]);
        addTearDown(() async {
          await server.close(force: true);
        });

        final result = await _drain(
          ChatApiService.sendMessageStream(
            config: _testConfig(
              'http://localhost:${server.port}',
              ProviderKind.google,
            ),
            modelId: 'gemini-test',
            messages: [
              {'role': 'user', 'content': 'hi'},
            ],
          ),
        );

        expect(result.error, isA<HttpException>());
        expect(
          result.error.toString(),
          contains('Resource has been exhausted'),
        );
        expect(result.chunks.map((c) => c.content).join(), contains('Partial'));
        expect(result.chunks.any((c) => c.isDone), isFalse);
      },
    );

    test('promptFeedback.blockReason ends stream with error', () async {
      final blocked = jsonEncode({
        'promptFeedback': {'blockReason': 'SAFETY'},
      });
      final server = await _sseServer(['data: $blocked\n\n']);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}',
            ProviderKind.google,
          ),
          modelId: 'gemini-test',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('SAFETY'));
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });

    test('candidate finishReason SAFETY mid-generation ends stream with '
        'error, no fake isDone', () async {
      final delta = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Partial'},
              ],
            },
          },
        ],
      });
      final blockedFinish = jsonEncode({
        'candidates': [
          {
            'content': {'parts': <Map<String, dynamic>>[]},
            'finishReason': 'SAFETY',
          },
        ],
      });
      final server = await _sseServer([
        'data: $delta\n\n',
        'data: $blockedFinish\n\n',
      ]);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}',
            ProviderKind.google,
          ),
          modelId: 'gemini-test',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isA<HttpException>());
      expect(result.error.toString(), contains('SAFETY'));
      expect(result.chunks.map((c) => c.content).join(), contains('Partial'));
      expect(result.chunks.any((c) => c.isDone), isFalse);
    });

    test('finishReason STOP still completes normally', () async {
      final finish = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Done'},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      });
      final server = await _sseServer(['data: $finish\n\n']);
      addTearDown(() async {
        await server.close(force: true);
      });

      final result = await _drain(
        ChatApiService.sendMessageStream(
          config: _testConfig(
            'http://localhost:${server.port}',
            ProviderKind.google,
          ),
          modelId: 'gemini-test',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
        ),
      );

      expect(result.error, isNull);
      expect(result.chunks.map((c) => c.content).join(), contains('Done'));
      expect(result.chunks.any((c) => c.isDone), isTrue);
    });
  });
}
