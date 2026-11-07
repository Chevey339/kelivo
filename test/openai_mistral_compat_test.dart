import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';
import 'support/legacy_reasoning.dart';

// Upstream id exercised against the real Mistral endpoint. The guesser already
// treats it as reasoning-capable, so the request side is what these tests
// isolate.
const String _mistralModelId = 'deepseek-v4-1-flash-1017';

ProviderConfig _mistralConfig(String baseUrl) {
  return ProviderConfig(
    id: 'Mistral',
    enabled: true,
    name: 'Mistral',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

String _baseUrl(HttpServer server) {
  return 'http://${server.address.address}:${server.port}/v1';
}

Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
  return jsonDecode(await utf8.decoder.bind(request).join())
      as Map<String, dynamic>;
}

ContentType get _eventStream =>
    ContentType('text', 'event-stream', charset: 'utf-8');

Map<String, dynamic> _thinkingPart(String text) {
  return <String, dynamic>{
    'type': 'thinking',
    'thinking': <dynamic>[
      <String, dynamic>{'type': 'text', 'text': text},
    ],
    'closed': true,
  };
}

Map<String, dynamic> _textPart(String text) {
  return <String, dynamic>{'type': 'text', 'text': text};
}

Map<String, dynamic> _chunk({
  Object? content,
  List<Map<String, dynamic>>? toolCalls,
  String? finishReason,
}) {
  return <String, dynamic>{
    'id': 'cmpl-mistral',
    'object': 'chat.completion.chunk',
    'created': 0,
    'model': _mistralModelId,
    'choices': <dynamic>[
      <String, dynamic>{
        'index': 0,
        'delta': <String, dynamic>{
          'role': 'assistant',
          if (content != null) 'content': content,
          if (toolCalls != null) 'tool_calls': toolCalls,
        },
        'finish_reason': finishReason,
      },
    ],
  };
}

void _writeSse(HttpResponse response, List<Map<String, dynamic>> chunks) {
  response.statusCode = HttpStatus.ok;
  response.headers.contentType = _eventStream;
  for (final chunk in chunks) {
    response.write('data: ${jsonEncode(chunk)}\n\n');
  }
  response.write('data: [DONE]\n\n');
}

void main() {
  group('Mistral OpenAI compatibility', () {
    test('streams typed thinking and text parts from the same delta', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await _readJsonBody(request);
        _writeSse(request.response, [
          _chunk(
            content: <dynamic>[_thinkingPart('先核对'), _textPart('9.8 更大。')],
          ),
          _chunk(
            content: <dynamic>[
              _thinkingPart('再看小数位'),
              _textPart('因为 9.8 = 9.80。'),
            ],
            finishReason: 'stop',
          ),
        ]);
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _mistralConfig(_baseUrl(server)),
        modelId: _mistralModelId,
        messages: const [
          {'role': 'user', 'content': '9.11 和 9.8 哪个大？'},
        ],
        reasoning: legacyBudget(1024),
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      // `closed: true` is not an end signal: the second frame still streams.
      expect(chunks.joinedReasoning, '先核对再看小数位');
      expect(chunks.joinedContent, '9.8 更大。因为 9.8 = 9.80。');
    });

    test('replays historical reasoning_content as typed parts', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody = await _readJsonBody(request);
        _writeSse(request.response, [
          _chunk(content: 'ok', finishReason: 'stop'),
        ]);
        await request.response.close();
      });

      await ChatApiService.sendMessageStream(
        config: _mistralConfig(_baseUrl(server)),
        modelId: _mistralModelId,
        messages: const [
          {'role': 'user', 'content': '第一问'},
          {
            'role': 'assistant',
            'content': '第一答',
            'reasoning_content': '先想一下',
            'reasoning': '旧字段推理',
            'reasoning_details': [
              {'type': 'reasoning.text', 'text': '结构化推理'},
            ],
          },
          {'role': 'user', 'content': '第二问'},
        ],
        reasoning: legacyBudget(1024),
      ).toList();

      final history = (requestBody['messages'] as List).cast<Map>();
      final assistant = history[1];
      expect(assistant['role'], 'assistant');
      expect(assistant.containsKey('reasoning_content'), isFalse);
      expect(assistant.containsKey('reasoning'), isFalse);
      expect(assistant.containsKey('reasoning_details'), isFalse);

      final content = (assistant['content'] as List).cast<Map>();
      expect(content.first, <String, dynamic>{
        'type': 'thinking',
        'thinking': <dynamic>[
          <String, dynamic>{'type': 'text', 'text': '先想一下'},
        ],
      });
      expect(
        content
            .where((part) => part['type'] == 'text')
            .map((part) => part['text'])
            .toList(),
        ['第一答'],
      );
    });

    test('converts tool-round reasoning echo, keeps tool_calls', () async {
      final requests = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requests.add(await _readJsonBody(request));
        if (requests.length == 1) {
          _writeSse(request.response, [
            _chunk(
              content: <dynamic>[_thinkingPart('先查日期'), _textPart('我去调用工具')],
              toolCalls: [
                {
                  'index': 0,
                  'id': 'call_date',
                  'type': 'function',
                  'function': {'name': 'date', 'arguments': '{}'},
                },
              ],
              finishReason: 'tool_calls',
            ),
          ]);
        } else {
          _writeSse(request.response, [
            _chunk(content: '今天是 2026-11-07', finishReason: 'stop'),
          ]);
        }
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _mistralConfig(_baseUrl(server)),
        modelId: _mistralModelId,
        messages: const [
          {'role': 'user', 'content': '今天几号？'},
        ],
        reasoning: legacyBudget(1024),
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
        onToolCall: (_, __, {toolCallId}) async => '2026-11-07',
      ).toList();

      expect(requests, hasLength(2));
      final secondMessages = (requests[1]['messages'] as List).cast<Map>();
      final assistantToolMessage = secondMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      expect(assistantToolMessage.containsKey('reasoning_content'), isFalse);
      expect(assistantToolMessage.containsKey('reasoning'), isFalse);
      expect(assistantToolMessage.containsKey('reasoning_details'), isFalse);

      final content = (assistantToolMessage['content'] as List).cast<Map>();
      expect(content.first, <String, dynamic>{
        'type': 'thinking',
        'thinking': <dynamic>[
          <String, dynamic>{'type': 'text', 'text': '先查日期'},
        ],
      });
      expect(
        content
            .where((part) => part['type'] == 'text')
            .map((part) => part['text'])
            .toList(),
        ['我去调用工具'],
      );
      expect(assistantToolMessage['tool_calls'], [
        {
          'id': 'call_date',
          'type': 'function',
          'function': {'name': 'date', 'arguments': '{}'},
        },
      ]);

      final toolMessage = secondMessages.firstWhere(
        (message) => message['role'] == 'tool',
      );
      expect(toolMessage['tool_call_id'], 'call_date');
      expect(toolMessage['content'], '2026-11-07');

      expect(chunks.joinedReasoning, '先查日期');
      expect(chunks.joinedContent, contains('今天是 2026-11-07'));
    });

    test('non-stream tool continuation replays typed thinking once', () async {
      final requestBodies = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBodies.add(await _readJsonBody(request));
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        if (requestBodies.length == 1) {
          request.response.write(
            jsonEncode({
              'id': 'cmpl-mistral-1',
              'object': 'chat.completion',
              'created': 0,
              'model': _mistralModelId,
              'choices': [
                {
                  'index': 0,
                  'message': {
                    'role': 'assistant',
                    'content': [
                      {
                        'type': 'thinking',
                        'thinking': [
                          {'type': 'text', 'text': '先查日期'},
                        ],
                        'closed': true,
                        'signature': 'sig-mistral',
                      },
                      {'type': 'text', 'text': '我去调用工具'},
                    ],
                    'tool_calls': [
                      {
                        'id': 'call_date',
                        'type': 'function',
                        'function': {'name': 'date', 'arguments': '{}'},
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
              'id': 'cmpl-mistral-2',
              'object': 'chat.completion',
              'created': 0,
              'model': _mistralModelId,
              'choices': [
                {
                  'index': 0,
                  'message': {'role': 'assistant', 'content': '今天是 2026-11-07'},
                  'finish_reason': 'stop',
                },
              ],
            }),
          );
        }
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _mistralConfig(_baseUrl(server)),
        modelId: _mistralModelId,
        messages: const [
          {'role': 'user', 'content': '今天几号？'},
        ],
        reasoning: legacyBudget(1024),
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
        onToolCall: (_, __, {toolCallId}) async => '2026-11-07',
        stream: false,
      ).toList();

      expect(requestBodies, hasLength(2));
      final secondMessages = (requestBodies[1]['messages'] as List).cast<Map>();
      final assistantToolMessage = secondMessages.firstWhere(
        (message) =>
            message['role'] == 'assistant' && message['tool_calls'] is List,
      );
      expect(assistantToolMessage.containsKey('reasoning_content'), isFalse);
      expect(assistantToolMessage.containsKey('reasoning'), isFalse);
      expect(assistantToolMessage.containsKey('reasoning_details'), isFalse);

      final content = (assistantToolMessage['content'] as List).cast<Map>();
      final thinkingParts = content
          .where((part) => part['type'] == 'thinking')
          .toList();
      expect(thinkingParts, hasLength(1));
      final thinkingPart = thinkingParts.single;
      expect(thinkingPart.containsKey('closed'), isFalse);
      expect(thinkingPart.containsKey('signature'), isFalse);
      expect(thinkingPart['thinking'], [
        {'type': 'text', 'text': '先查日期'},
      ]);
      expect(
        content
            .where((part) => part['type'] == 'text')
            .map((part) => part['text'])
            .toList(),
        ['我去调用工具'],
      );
      expect(assistantToolMessage['tool_calls'], [
        {
          'id': 'call_date',
          'type': 'function',
          'function': {'name': 'date', 'arguments': '{}'},
        },
      ]);

      final toolMessage = secondMessages.firstWhere(
        (message) => message['role'] == 'tool',
      );
      expect(toolMessage['tool_call_id'], 'call_date');
      expect(toolMessage['content'], '2026-11-07');

      expect(chunks.isGenerationDone, isTrue);
      expect(chunks.joinedReasoning, '先查日期');
      expect(chunks.joinedContent, contains('今天是 2026-11-07'));
    });

    test('maps effort requests without a thinking switch', () async {
      final requests = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requests.add(await _readJsonBody(request));
        _writeSse(request.response, [
          _chunk(content: 'ok', finishReason: 'stop'),
        ]);
        await request.response.close();
      });

      final baseUrl = _baseUrl(server);
      Future<Map<String, dynamic>> send(int? budget) async {
        await ChatApiService.sendMessageStream(
          config: _mistralConfig(baseUrl),
          modelId: _mistralModelId,
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          reasoning: legacyBudget(budget),
        ).toList();
        return requests.last;
      }

      final enabled = await send(1024);
      final disabled = await send(0);
      final auto = await send(null);

      // Mistral rejects a top-level thinking switch with 422 at every level.
      for (final body in [enabled, disabled, auto]) {
        expect(body.containsKey('thinking'), isFalse);
      }

      final effort = enabled['reasoning_effort'];
      expect(effort, isA<String>());
      expect(effort, isIn(const ['low', 'medium', 'high']));
      expect(effort, isNot('none'));

      // Omitting the effort is Mistral's portable "off".
      expect(disabled.containsKey('reasoning_effort'), isFalse);

      // No effort means "do not think", so `auto` must name one.
      expect(auto['reasoning_effort'], 'high');
    });
  });
}
