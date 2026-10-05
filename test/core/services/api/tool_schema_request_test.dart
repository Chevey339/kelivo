import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';

import '../../../support/tool_schema_reference_cases.dart';

const _schema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'nullable': {
      'type': ['string', 'null'],
    },
    'batch': {
      'type': 'array',
      'allOf': [
        {
          'items': {'type': 'integer'},
        },
      ],
    },
  },
  'required': ['value'],
  'allOf': [
    {
      'properties': {
        'value': {
          'anyOf': [
            {'type': 'string'},
            {'type': 'integer'},
          ],
        },
      },
    },
    {
      'properties': {
        'mode': {
          'oneOf': [
            {'type': 'string'},
            {'type': 'boolean'},
          ],
        },
      },
    },
  ],
};

const _arguments = <String, dynamic>{
  'value': 123,
  'nullable': null,
  'batch': [1],
};

const _constraintsSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'text': {
      'oneOf': [
        {'type': 'string', 'pattern': '^a'},
        {'type': 'string', 'pattern': '^b'},
      ],
    },
    'number': {
      'oneOf': [
        {'type': 'number', 'maximum': 0},
        {'type': 'number', 'minimum': 10},
      ],
    },
    'values': {
      'type': 'array',
      'contains': {'type': 'integer', 'minimum': 1},
    },
  },
  'required': ['limit'],
  'patternProperties': {
    r'^limit$': {'type': 'integer', 'minimum': 1},
  },
};

Map<String, dynamic> _response(String transport, bool first) {
  if (transport == 'claude') {
    return {
      'id': 'msg',
      'type': 'message',
      'role': 'assistant',
      'content': [
        if (first)
          {
            'type': 'tool_use',
            'id': 'call-1',
            'name': 'submit',
            'input': _arguments,
          }
        else
          {'type': 'text', 'text': 'done'},
      ],
      'stop_reason': first ? 'tool_use' : 'end_turn',
    };
  }
  if (transport == 'responses') {
    return {
      'id': 'resp',
      'status': 'completed',
      'output': [
        if (first)
          {
            'id': 'fc-1',
            'type': 'function_call',
            'call_id': 'call-1',
            'name': 'submit',
            'arguments': jsonEncode(_arguments),
          }
        else
          {
            'id': 'msg',
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'done'},
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
          'content': first ? '' : 'done',
          if (first)
            'tool_calls': [
              {
                'id': 'call-1',
                'type': 'function',
                'function': {
                  'name': 'submit',
                  'arguments': jsonEncode(_arguments),
                },
              },
            ],
        },
        'finish_reason': first ? 'tool_calls' : 'stop',
      },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final schemas = {
    'submit': _schema,
    'constraints': _constraintsSchema,
    for (final (index, example) in toolSchemaReferenceCases().indexed)
      'reference_$index': example.schema,
  };

  for (final transport in ['chat', 'responses', 'claude']) {
    test(
      '$transport preserves composed MCP schemas across tool rounds',
      () async {
        final requests = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode(_response(transport, requests.length == 1)),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        addTearDown(client.close);
        final kind = transport == 'claude'
            ? ProviderKind.claude
            : ProviderKind.openai;
        final config = ProviderConfig(
          id: 'DeepSeek',
          enabled: true,
          name: 'DeepSeek',
          apiKey: 'test-key',
          baseUrl: 'https://example.test/v1',
          providerType: kind,
          useResponseApi: transport == 'responses',
        );
        var calls = 0;
        final send = transport == 'claude'
            ? sendClaudeStream
            : sendOpenAIStream;
        await send(
          client,
          config,
          'deepseek-v4-flash',
          [
            {'role': 'user', 'content': 'Submit value 123'},
          ],
          tools: [
            for (final entry in schemas.entries)
              {
                'type': 'function',
                'function': {
                  'name': entry.key,
                  'parameters':
                      ToolHandlerService.sanitizeToolParametersForProvider(
                        entry.value,
                        kind,
                      ),
                },
              },
          ],
          onToolCall: (name, args, {toolCallId}) async {
            calls++;
            expect(name, 'submit');
            expect(args, _arguments);
            return 'ok';
          },
          stream: false,
        ).toList();

        expect(calls, 1);
        expect(requests, hasLength(2));
        for (final request in requests) {
          final tools = request['tools'] as List;
          expect(tools, hasLength(schemas.length));
          for (final tool in tools) {
            final function = transport == 'chat' ? tool['function'] : tool;
            final parameters = transport == 'claude'
                ? function['input_schema']
                : function['parameters'];
            expect(parameters, schemas[function['name']]);
          }
        }
      },
    );
  }
}
