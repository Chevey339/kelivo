import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GeminiTest',
    enabled: true,
    name: 'GeminiTest',
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

Map<String, dynamic> _call(String name, {String? sig}) => {
  'functionCall': {'name': name, 'args': <String, dynamic>{}},
  if (sig != null) 'thoughtSignature': sig,
};

const _tools = [
  {
    'function_declarations': [
      {
        'name': 'read_file',
        'description': 'Read a file',
        'parameters': {'type': 'object', 'properties': {}},
      },
      {
        'name': 'status',
        'description': 'Get status',
        'parameters': {'type': 'object', 'properties': {}},
      },
    ],
  },
];

bool _signed(Map part) =>
    part.containsKey('thoughtSignature') ||
    part.containsKey('thought_signature');

/// Serves one scripted SSE response per request and records request bodies.
Future<(HttpServer, List<Map<String, dynamic>>)> _serve(
  List<List<Map<String, dynamic>>> rounds,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final bodies = <Map<String, dynamic>>[];
  server.listen((request) async {
    bodies.add(
      jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>,
    );
    final i = bodies.length - 1;
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType('text', 'event-stream');
    final parts = i < rounds.length
        ? rounds[i]
        : [
            {'text': 'done'},
          ];
    request.response.write(
      'data: ${jsonEncode(_streamChunk(parts, finishReason: 'STOP'))}\n\n',
    );
    request.response.write('data: [DONE]');
    await request.response.close();
  });
  return (server, bodies);
}

void main() {
  group('Gemini function call thought signatures in the tool loop', () {
    test(
      'replays parallel calls as one model turn so the first call keeps the signature',
      () async {
        // Gemini signs only the first functionCall of a parallel batch.
        final (server, bodies) = await _serve([
          [_call('read_file', sig: 'sig-batch'), _call('status')],
        ]);
        addTearDown(() => server.close(force: true));

        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-2.5-flash',
          messages: const [
            {'role': 'user', 'content': 'Check the status.'},
          ],
          tools: _tools,
          onToolCall: (name, args, {toolCallId}) async => '{"ok":true}',
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        expect(bodies, hasLength(2));
        final contents = (bodies[1]['contents'] as List).cast<Map>();
        // user prompt, one model turn with both calls, one user turn with both responses
        expect(contents.map((c) => c['role']), ['user', 'model', 'user']);
        final modelParts = (contents[1]['parts'] as List).cast<Map>();
        final userParts = (contents[2]['parts'] as List).cast<Map>();
        expect(modelParts.map((p) => (p['functionCall'] as Map)['name']), [
          'read_file',
          'status',
        ]);
        expect(modelParts.first['thoughtSignature'], 'sig-batch');
        expect(_signed(modelParts.last), isFalse);
        expect(userParts.map((p) => (p['functionResponse'] as Map)['name']), [
          'read_file',
          'status',
        ]);
      },
    );

    test(
      'fills the placeholder when a later step arrives without a signature',
      () async {
        final (server, bodies) = await _serve([
          [_call('read_file', sig: 'sig-step-1')],
          [_call('status')],
        ]);
        addTearDown(() => server.close(force: true));

        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-2.5-flash',
          messages: const [
            {'role': 'user', 'content': 'Check the status.'},
          ],
          tools: _tools,
          onToolCall: (name, args, {toolCallId}) async => '{"ok":true}',
        ).toList();

        expect(chunks.isGenerationDone, isTrue);
        expect(bodies, hasLength(3));
        final contents = (bodies[2]['contents'] as List).cast<Map>();
        final modelTurns = contents.where((c) => c['role'] == 'model').toList();
        expect(modelTurns, hasLength(2));
        final first = (modelTurns[0]['parts'] as List).cast<Map>().first;
        final second = (modelTurns[1]['parts'] as List).cast<Map>().first;
        expect(first['thoughtSignature'], 'sig-step-1');
        expect(_signed(second), isTrue);
      },
    );
  });
}
