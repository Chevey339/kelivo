import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/google_gemini.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/features/home/services/assistant_tool_history.dart';

void main() {
  for (final stream in [false, true]) {
    test('code executions survive tool rounds (stream=$stream)', () async {
      var round = 0;
      final client = MockClient((request) async {
        final current = ++round;
        final reply = {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  for (final value in current == 1 ? [1, 2] : [3]) ...[
                    {
                      'executableCode': {
                        'language': 'PYTHON',
                        'code': 'print($value)',
                      },
                    },
                    {
                      'codeExecutionResult': {
                        'outcome': 'OUTCOME_OK',
                        'output': '$value',
                      },
                    },
                  ],
                  {'text': current == 1 ? 'Checking.' : 'Done.'},
                  if (current == 1)
                    {
                      'functionCall': {
                        'id': 'lookup-a',
                        'name': 'lookup',
                        'args': {'q': 'check'},
                      },
                      'thoughtSignature': 'sig-a',
                    },
                ],
              },
              'finishReason': 'STOP',
            },
          ],
        };
        return http.Response(
          stream ? 'data: ${jsonEncode(reply)}\n\n' : jsonEncode(reply),
          200,
        );
      });
      addTearDown(client.close);

      final chunks = await sendGoogleGeminiStream(
        client,
        ProviderConfig(
          id: 'Gemini',
          enabled: true,
          name: 'Gemini',
          apiKey: 'test',
          baseUrl: 'https://example.test/v1beta',
          providerType: ProviderKind.google,
          modelOverrides: const {
            'gemini-3.8-flash': {
              'builtInTools': ['code_execution'],
            },
          },
        ),
        'gemini-3.8-flash',
        const [
          {'role': 'user', 'content': 'Compute, look up, then compute again.'},
        ],
        tools: const [
          {
            'type': 'function',
            'function': {
              'name': 'lookup',
              'parameters': {'type': 'object', 'properties': {}},
            },
          },
        ],
        onToolCall: (_, _, {toolCallId}) async => '{"found":true}',
        stream: stream,
      ).toList();

      final parts = [
        for (final part in StreamChunkHandler.collect(chunks).parts)
          MessagePart.fromRow(part.kind, part.encodePayload()),
      ];
      final codeCards = parts
          .whereType<ToolCallPart>()
          .map((part) => jsonDecode(part.payloadJson) as Map)
          .where((part) => part['name'] == 'code_execution')
          .toList();
      final expectedArguments = [
        for (final value in [1, 2, 3])
          {'language': 'python', 'code': 'print($value)'},
      ];

      expect(round, 2);
      expect(chunks.whereType<Finish>(), hasLength(1));
      expect(codeCards.map((card) => card['content']), ['1', '2', '3']);
      expect(codeCards.map((card) => card['arguments']), expectedArguments);
      expect(codeCards.map((card) => card['id']).toSet(), hasLength(3));

      final history = buildAssistantToolHistory(parts);
      final results = history.messages.where(
        (message) =>
            message['role'] == 'tool' && message['name'] == 'code_execution',
      );
      expect(results.map((message) => message['content']), ['1', '2', '3']);
      final calls = history.messages
          .expand((message) => (message['tool_calls'] as List?) ?? [])
          .where((call) => call['function']['name'] == 'code_execution');
      expect(
        calls.map(
          (call) => jsonDecode(call['function']['arguments'] as String),
        ),
        expectedArguments,
      );
      expect(history.content, 'Done.');
    });
  }
}
