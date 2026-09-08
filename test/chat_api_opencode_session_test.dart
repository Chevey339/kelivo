import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/provider_request_headers.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProxyHttpOverrides extends HttpOverrides {
  _ProxyHttpOverrides(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'PROXY 127.0.0.1:$port';
    return client;
  }
}

ProviderConfig _config({
  String host = 'opencode.ai',
  ProviderKind kind = ProviderKind.openai,
  bool responses = false,
}) => ProviderConfig(
  id: 'Custom',
  name: 'Custom',
  enabled: true,
  apiKey: 'test-key',
  baseUrl: 'http://$host/zen/go/v1',
  providerType: kind,
  useResponseApi: responses,
);

const _reply = {
  'choices': [
    {
      'message': {'role': 'assistant', 'content': 'ok'},
      'finish_reason': 'stop',
    },
  ],
  'content': [
    {'type': 'text', 'text': 'ok'},
  ],
  'output': [
    {
      'type': 'message',
      'role': 'assistant',
      'content': [
        {'type': 'output_text', 'text': 'ok'},
      ],
    },
  ],
};

void main() {
  test('automatic session header is limited to the official host', () {
    for (final host in [
      'example.com',
      'opencode.ai.example.com',
      'fakeopencode.ai',
    ]) {
      expect(
        providerSessionHeaders(_config(host: host), conversationId: 'chat'),
        isNull,
      );
    }
    expect(
      providerSessionHeaders(
        _config(host: 'OPENCODE.AI'),
        conversationId: 'chat',
      ),
      {'x-opencode-session': 'chat'},
    );
  });

  for (final route in [
    (kind: ProviderKind.openai, responses: false, path: 'chat/completions'),
    (kind: ProviderKind.openai, responses: true, path: 'responses'),
    (kind: ProviderKind.claude, responses: false, path: 'messages'),
  ]) {
    test(
      '${route.path} uses stable conversation IDs and separate task IDs',
      () async {
        final headers = <String?>[];
        final paths = <String>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          headers.add(request.headers.value('x-opencode-session'));
          paths.add(request.uri.path);
          await request.drain<void>();
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(_reply));
          await request.response.close();
        });
        final config = _config(kind: route.kind, responses: route.responses);
        await HttpOverrides.runZoned(() async {
          for (final id in ['chat-a', 'chat-a', 'chat-b', null, null]) {
            final result = await ChatApiService.generateText(
              config: config,
              modelId: 'test-model',
              prompt: 'hello',
              conversationId: id,
            );
            expect(result, 'ok');
          }
          await ChatApiService.generateText(
            config: config.copyWith(
              customHeaders: const [
                {'name': 'X-OPENCODE-SESSION', 'value': 'manual'},
              ],
            ),
            modelId: 'test-model',
            prompt: 'hello',
            conversationId: 'chat-a',
          );
        }, createHttpClient: _ProxyHttpOverrides(server.port).createHttpClient);
        expect(headers.take(3), ['chat-a', 'chat-a', 'chat-b']);
        final uuid = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        );
        expect(headers[3], matches(uuid));
        expect(headers[4], matches(uuid));
        expect(headers[3], isNot(headers[4]));
        expect(headers.last, 'manual');
        expect(paths, everyElement('/zen/go/v1/${route.path}'));
      },
    );
  }

  for (final conversationId in ['chat-a', null]) {
    test(
      'stream tool follow-up and retry reuse session $conversationId',
      () async {
        final headers = <String?>[];
        var toolCalls = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          headers.add(request.headers.value('x-opencode-session'));
          await request.drain<void>();
          // Retry both the initial model round and the tool follow-up round.
          if (headers.length == 1 || headers.length == 3) {
            request.response.statusCode = 429;
            request.response.write('retry');
          } else {
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            final toolRound = headers.length == 2;
            final delta = toolRound
                ? {
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call_1',
                        'type': 'function',
                        'function': {'name': 'get_time', 'arguments': '{}'},
                      },
                    ],
                  }
                : {'content': 'ok'};
            final event = {
              'choices': [
                {
                  'index': 0,
                  'delta': delta,
                  'finish_reason': toolRound ? 'tool_calls' : 'stop',
                },
              ],
            };
            request.response.write(
              'data: ${jsonEncode(event)}\n\ndata: [DONE]\n\n',
            );
          }
          await request.response.close();
        });
        final chunks = await HttpOverrides.runZoned(
          () => ChatApiService.sendMessageStream(
            config: _config(),
            modelId: 'test-model',
            conversationId: conversationId,
            messages: const [
              {'role': 'user', 'content': 'hello'},
            ],
            tools: const [
              {
                'type': 'function',
                'function': {
                  'name': 'get_time',
                  'parameters': {
                    'type': 'object',
                    'properties': <String, dynamic>{},
                  },
                },
              },
            ],
            onToolCall: (name, args, {toolCallId}) async {
              toolCalls++;
              return '12:34';
            },
            retryOverride: AutoRetryOptions(
              enabled: true,
              maxRetries: 2,
              initialDelayMs: 0,
              multiplier: 1,
              maxDelayMs: 0,
              jitter: false,
              retryOnNetworkError: true,
              retryStatusCodes: {429},
              retryKeywords: const [],
              stopKeywords: const [],
            ),
          ).toList(),
          createHttpClient: _ProxyHttpOverrides(server.port).createHttpClient,
        );
        expect(headers, hasLength(4));
        expect(headers.first, isNotEmpty);
        expect(headers, everyElement(conversationId ?? headers.first));
        expect(toolCalls, 1);
        expect(chunks.whereType<TextDelta>().map((e) => e.text).join(), 'ok');
      },
    );
  }
}
