import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ProviderConfig _config({bool searchEnabled = true}) => ProviderConfig(
  id: 'GrokTest',
  enabled: true,
  name: 'GrokTest',
  apiKey: 'test-key',
  baseUrl: 'https://api.x.ai/v1',
  providerType: ProviderKind.openai,
  useResponseApi: true,
  modelOverrides: {
    'my-model': {
      'apiModelId': 'grok-4.5',
      if (searchEnabled) 'builtInTools': [BuiltInToolNames.search],
    },
  },
);

http.Response _events(List<Map<String, dynamic>> events) => http.Response(
  events.map((event) => 'data: ${jsonEncode(event)}\n\n').join(),
  200,
  headers: {'content-type': 'text/event-stream'},
);

void main() {
  test(
    'Grok search coexists with local tools across Responses rounds',
    () async {
      final requests = <http.Request>[];
      const searchCall = {
        'type': 'web_search_call',
        'id': 'search_1',
        'status': 'completed',
      };
      const shellCall = {
        'type': 'function_call',
        'id': 'fc_1',
        'call_id': 'call_1',
        'name': 'shell',
        'arguments': '{"command":"pwd"}',
        'status': 'completed',
      };
      final client = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return _events([
            {
              'type': 'response.output_item.done',
              'output_index': 0,
              'item': searchCall,
            },
            {
              'type': 'response.output_item.done',
              'output_index': 1,
              'item': shellCall,
            },
            {
              'type': 'response.completed',
              'response': {
                'output': [searchCall, shellCall],
              },
            },
          ]);
        }
        return _events([
          {'type': 'response.output_text.delta', 'delta': 'Done'},
          {
            'type': 'response.completed',
            'response': {'output': []},
          },
        ]);
      });
      addTearDown(client.close);
      final localCalls = <String>[];
      final chunks = await sendOpenAIStream(
        client,
        _config(),
        'my-model',
        [
          {'role': 'user', 'content': 'Search and check the local directory'},
        ],
        tools: [
          {
            'type': 'function',
            'function': {
              'name': 'shell',
              'description': 'Execute a local command',
              'parameters': {
                'type': 'object',
                'properties': {
                  'command': {'type': 'string'},
                },
                'required': ['command'],
              },
            },
          },
        ],
        onToolCall: (name, args, {toolCallId}) async {
          localCalls.add(name);
          expect(args, {'command': 'pwd'});
          return '/workspace';
        },
      ).toList();

      expect(localCalls, ['shell']);
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(request.url.toString(), 'https://api.x.ai/v1/responses');
        final body = jsonDecode(request.body) as Map;
        expect(body['model'], 'grok-4.5');
        expect(body.containsKey('search_parameters'), isFalse);
        final tools = (body['tools'] as List).cast<Map>();
        expect(tools.map((tool) => tool['type']), [
          'function',
          'web_search',
          'x_search',
        ]);
        expect(tools.first['name'], 'shell');
      }
      final followUp = jsonDecode(requests.last.body) as Map;
      final input = (followUp['input'] as List).cast<Map>();
      expect(
        input.singleWhere((item) => item['type'] == 'function_call_output'),
        containsPair('call_id', 'call_1'),
      );
      expect(chunks.whereType<TextDelta>().map((c) => c.text).join(), 'Done');
      expect(chunks.whereType<ServerToolEnd>(), hasLength(1));
    },
  );

  test('disabled Grok search adds no native tools or legacy fields', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return _events([
        {
          'type': 'response.completed',
          'response': {'output': []},
        },
      ]);
    });
    addTearDown(client.close);

    await sendOpenAIStream(client, _config(searchEnabled: false), 'my-model', [
      {'role': 'user', 'content': 'Hello'},
    ]).drain<void>();

    final body = jsonDecode(captured!.body) as Map;
    expect(body.containsKey('tools'), isFalse);
    expect(body.containsKey('search_parameters'), isFalse);
  });
}
