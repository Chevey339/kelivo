import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GeminiMalformedResponseTest',
    enabled: true,
    name: 'GeminiMalformedResponseTest',
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
        'content': {'role': 'model', 'parts': parts},
        if (finishReason != null) 'finishReason': finishReason,
      },
    ],
  };
}

void _writeSse(HttpRequest request, List<Map<String, dynamic>> events) {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.contentType = ContentType('text', 'event-stream')
    ..headers.set('Transfer-Encoding', 'chunked');
  for (final event in events) {
    request.response.write('data: ${jsonEncode(event)}\n\n');
  }
  request.response.write('data: [DONE]');
}

const _tools = [
  {
    'type': 'function',
    'function': {
      'name': 'search_first',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'search_second',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'search_follow_up',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      },
    },
  },
];

void main() {
  test(
    'retries one malformed tool round and continues with the serial call',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      String? malformedRequestBody;
      final toolCalls = <String>[];
      server.listen((request) async {
        requestCount++;
        final body = await utf8.decoder.bind(request).join();

        if (requestCount == 1) {
          _writeSse(request, [
            _streamChunk([
              {'text': 'Starting the two searches.'},
              {
                'functionCall': {
                  'name': 'search_first',
                  'args': {'query': 'first'},
                  'id': 'first-id',
                },
                'thoughtSignature': 'first-signature',
              },
              {
                'functionCall': {
                  'name': 'search_second',
                  'args': {'query': 'second'},
                  'id': 'second-id',
                },
              },
            ], finishReason: 'STOP'),
          ]);
        } else if (requestCount == 2) {
          malformedRequestBody = body;
          _writeSse(request, [
            _streamChunk([
              {'text': 'Planning the follow-up.', 'thought': true},
            ]),
            _streamChunk([
              {'text': '', 'thoughtSignature': 'malformed-signature'},
            ], finishReason: 'MALFORMED_RESPONSE'),
          ]);
        } else if (requestCount == 3) {
          expect(body, malformedRequestBody);
          _writeSse(request, [
            _streamChunk([
              {
                'functionCall': {
                  'name': 'search_follow_up',
                  'args': {'query': 'follow-up'},
                  'id': 'follow-up-id',
                },
                'thoughtSignature': 'follow-up-signature',
              },
            ], finishReason: 'STOP'),
          ]);
        } else if (requestCount == 4) {
          _writeSse(request, [
            _streamChunk([
              {'text': 'Finished after the follow-up search.'},
            ], finishReason: 'STOP'),
          ]);
        } else {
          fail('Unexpected request count: $requestCount');
        }
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.5-flash-lite',
        messages: const [
          {
            'role': 'user',
            'content':
                'Run two searches in parallel, then one follow-up search.',
          },
        ],
        tools: _tools,
        onToolCall: (name, args, {toolCallId}) async {
          toolCalls.add(name);
          return '{"result":"$name result"}';
        },
      ).toList();

      expect(requestCount, 4);
      expect(toolCalls, ['search_first', 'search_second', 'search_follow_up']);
      expect(
        chunks.map((chunk) => chunk.content).join(),
        contains('Finished after the follow-up search.'),
      );
      expect(chunks.last.isDone, isTrue);
    },
  );

  test('fails after one malformed-response retry', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
    });

    var requestCount = 0;
    server.listen((request) async {
      requestCount++;
      await utf8.decoder.bind(request).join();
      _writeSse(request, [
        _streamChunk([
          {'text': '', 'thoughtSignature': 'malformed-signature'},
        ], finishReason: 'MALFORMED_RESPONSE'),
      ]);
      await request.response.close();
    });

    await expectLater(
      ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.5-flash-lite',
        messages: const [
          {'role': 'user', 'content': 'Call a tool.'},
        ],
        tools: _tools,
      ).toList(),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          contains('MALFORMED_RESPONSE'),
        ),
      ),
    );
    expect(requestCount, 2);
  });
}
