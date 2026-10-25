import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _config(
  HttpServer server, {
  bool enabled = true,
  bool responses = false,
  ProviderKind kind = ProviderKind.openai,
}) => ProviderConfig.fromJson({
  ...ProviderConfig(
    id: 'PromptCacheTest',
    enabled: true,
    name: 'Prompt Cache Test',
    apiKey: 'test-key',
    baseUrl: 'http://${server.address.address}:${server.port}/v1',
    providerType: kind,
    useResponseApi: responses,
  ).toJson(),
  'promptCacheKeyEnabled': enabled,
});

Map<String, dynamic> _reply({bool responses = false, bool tool = false}) {
  final call = {
    'type': 'function_call',
    'call_id': 'call_1',
    'name': 'get_time',
    'arguments': '{}',
  };
  if (responses) {
    return {
      'id': 'response_1',
      'status': 'completed',
      'output': [
        if (tool)
          call
        else
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'ok'},
            ],
          },
      ],
    };
  }
  return {
    'choices': [
      {
        'index': 0,
        'message': {
          'role': 'assistant',
          'content': tool ? null : 'ok',
          if (tool)
            'tool_calls': [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {'name': 'get_time', 'arguments': '{}'},
              },
            ],
        },
        'finish_reason': tool ? 'tool_calls' : 'stop',
      },
    ],
  };
}

void _writeReply(
  HttpResponse response, {
  bool responses = false,
  bool stream = false,
  bool tool = false,
}) {
  final reply = _reply(responses: responses, tool: tool);
  if (!stream) {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(reply));
    return;
  }
  response.headers.contentType = ContentType('text', 'event-stream');
  void emit(Map<String, dynamic> event) =>
      response.write('data: ${jsonEncode(event)}\n\n');
  if (responses) {
    if (tool) {
      emit({
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': (reply['output'] as List).single,
      });
    } else {
      emit({'type': 'response.output_text.delta', 'delta': 'ok'});
    }
    emit({'type': 'response.completed', 'response': reply});
  } else {
    final choice = (reply['choices'] as List).single as Map;
    final message = Map<String, dynamic>.from(choice['message'] as Map);
    if (tool) {
      (message['tool_calls'] as List).single['index'] = 0;
    }
    emit({
      'choices': [
        {
          'index': 0,
          'delta': message,
          'finish_reason': choice['finish_reason'],
        },
      ],
    });
  }
  response.write('data: [DONE]\n\n');
}

void main() {
  for (final responses in [false, true]) {
    final route = responses ? 'responses' : 'chat/completions';
    test('$route sends stable conversation cache keys when enabled', () async {
      final bodies = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        bodies.add(
          (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
              .cast<String, dynamic>(),
        );
        expect(request.uri.path, '/v1/$route');
        _writeReply(request.response, responses: responses);
        await request.response.close();
      });
      final config = _config(server, responses: responses);
      for (final id in [' chat-a ', 'chat-a', 'chat-b', '123']) {
        expect(
          await ChatApiService.generateText(
            config: config,
            modelId: 'test-model',
            prompt: 'hello',
            conversationId: id,
          ),
          'ok',
        );
      }
      expect(bodies.map((body) => body['prompt_cache_key']), [
        'chat-a',
        'chat-a',
        'chat-b',
        '123',
      ]);
      for (final id in <String?>[null, '   ']) {
        await ChatApiService.generateText(
          config: config,
          modelId: 'test-model',
          prompt: 'hello',
          conversationId: id,
        );
        expect(bodies.last.containsKey('prompt_cache_key'), isFalse);
      }
      await ChatApiService.generateText(
        config: _config(server, enabled: false, responses: responses),
        modelId: 'test-model',
        prompt: 'hello',
        conversationId: 'chat-a',
      );
      expect(bodies.last.containsKey('prompt_cache_key'), isFalse);
    });

    test('$route preserves custom cache keys at every request level', () async {
      final bodies = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        bodies.add(
          (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
              .cast<String, dynamic>(),
        );
        _writeReply(request.response, responses: responses);
        await request.response.close();
      });
      final config = _config(server, responses: responses);
      for (final level in ['assistant', 'provider', 'model']) {
        await ChatApiService.generateText(
          config: config.copyWith(
            customBody: level == 'provider'
                ? [
                    {'key': 'prompt_cache_key', 'value': level},
                  ]
                : const [],
            modelOverrides: level == 'model'
                ? {
                    'test-model': {
                      'body': [
                        {'key': 'prompt_cache_key', 'value': level},
                      ],
                    },
                  }
                : const {},
          ),
          modelId: 'test-model',
          prompt: 'hello',
          conversationId: 'chat-a',
          extraBody: level == 'assistant' ? {'prompt_cache_key': level} : null,
        );
        expect(bodies.last['prompt_cache_key'], level);
      }
      await ChatApiService.generateText(
        config: _config(server, enabled: false, responses: responses),
        modelId: 'test-model',
        prompt: 'hello',
        conversationId: 'chat-a',
        extraBody: const {'prompt_cache_key': 'manual'},
      );
      expect(bodies.last['prompt_cache_key'], 'manual');
    });

    for (final stream in [false, true]) {
      test(
        '$route stream=$stream keeps cache keys through tools and retries',
        () async {
          final bodies = <Map<String, dynamic>>[];
          var toolCalls = 0;
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) async {
            bodies.add(
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                  .cast<String, dynamic>(),
            );
            if (bodies.length == 1 || bodies.length == 3) {
              request.response.statusCode = HttpStatus.tooManyRequests;
              request.response.write('retry');
            } else {
              _writeReply(
                request.response,
                responses: responses,
                stream: stream,
                tool: bodies.length == 2,
              );
            }
            await request.response.close();
          });
          final chunks = await ChatApiService.sendMessageStream(
            config: _config(server, responses: responses),
            modelId: 'test-model',
            conversationId: 'chat-a',
            stream: stream,
            messages: const [
              {'role': 'user', 'content': 'what time is it?'},
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
              maxDelayMs: 0,
              multiplier: 1,
              jitter: false,
              retryOnNetworkError: true,
              retryStatusCodes: {429},
              retryKeywords: const [],
              stopKeywords: const [],
            ),
          ).toList();
          expect(bodies, hasLength(4));
          expect(
            bodies.map((body) => body['prompt_cache_key']),
            everyElement('chat-a'),
          );
          expect(toolCalls, 1);
          expect(
            chunks.whereType<TextDelta>().map((chunk) => chunk.text).join(),
            'ok',
          );
        },
      );
    }
  }

  for (final kind in [ProviderKind.claude, ProviderKind.google]) {
    test('${kind.name} ignores the OpenAI cache key setting', () async {
      late Map<String, dynamic> body;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        body = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
            .cast<String, dynamic>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
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
      final result = await ChatApiService.generateText(
        config: _config(server, kind: kind),
        modelId: 'test-model',
        prompt: 'hello',
        conversationId: 'chat-a',
      );
      expect(result, 'ok');
      expect(body.containsKey('prompt_cache_key'), isFalse);
    });
  }

  test('image generation ignores the conversation cache key setting', () async {
    late Map<String, dynamic> body;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      body = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
          .cast<String, dynamic>();
      expect(request.uri.path, '/v1/images/generations');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': [
            {'url': 'https://example.test/generated.png'},
          ],
        }),
      );
      await request.response.close();
    });
    await ChatApiService.sendMessageStream(
      config: _config(server),
      modelId: 'gpt-image-2',
      conversationId: 'chat-a',
      messages: const [
        {'role': 'user', 'content': 'draw a cat'},
      ],
      stream: false,
    ).toList();
    expect(body.containsKey('prompt_cache_key'), isFalse);
  });

  test(
    'text-only requests add cache keys while still excluding custom bodies',
    () async {
      late Map<String, dynamic> body;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        body = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
            .cast<String, dynamic>();
        _writeReply(request.response);
        await request.response.close();
      });
      await ChatApiService.generateMessage(
        config: _config(server).copyWith(
          customBody: const [
            {'key': 'tools', 'value': '[{"type":"web_search"}]'},
          ],
        ),
        modelId: 'test-model',
        conversationId: 'chat-a',
        textOnly: true,
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        extraBody: const {
          'prompt_cache_key': 'manual',
          'tools': [
            {'type': 'web_search'},
          ],
        },
      );
      expect(body['prompt_cache_key'], 'chat-a');
      expect(body.containsKey('tools'), isFalse);
    },
  );
}
