import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_helpers.dart';
import 'package:Kelivo/core/services/api/providers/google_gemini.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('removes additionalProperties only from Gemini schema nodes', () {
    final schema = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'additionalProperties': {'type': 'string'},
        'config': {
          'type': 'object',
          'additionalProperties': true,
          'properties': {
            'value': {'type': 'string'},
          },
          'default': {'additionalProperties': 'keep this data'},
        },
        'rows': {
          'type': 'array',
          'items': {
            'type': 'object',
            'additionalProperties': {'type': 'string'},
            'properties': {
              'value': {'type': 'string'},
            },
          },
        },
        'choice': {
          'anyOf': [
            {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'value': {'type': 'string'},
              },
            },
            {'type': 'string'},
          ],
        },
      },
    };
    final original = jsonEncode(schema);
    final expected = jsonDecode(original) as Map<String, dynamic>;
    expected.remove('additionalProperties');
    expected['properties']['config'].remove('additionalProperties');
    expected['properties']['rows']['items'].remove('additionalProperties');
    expected['properties']['choice']['anyOf'][0].remove('additionalProperties');

    expect(cleanSchemaForGemini(schema, stringEnumOnly: true), expected);
    expect(jsonEncode(schema), original);
  });

  for (final stream in [false, true]) {
    test(
      'Gemini sanitizes built-in schemas across tool rounds (stream=$stream)',
      () async {
        final tools = [
          ...WorkspaceToolsService.definitions(),
          LocalToolsService.definitionFor(LocalToolNames.phoneControl),
        ];
        final original = jsonEncode(tools);
        final requests = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          final response = {
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    if (requests.length == 1)
                      {
                        'functionCall': {
                          'name': 'read_file',
                          'args': {'path': '/workspace/sample.txt'},
                        },
                        'thoughtSignature': 'test-signature',
                      }
                    else
                      {'text': 'done'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          };
          return http.Response(
            stream ? 'data: ${jsonEncode(response)}\n\n' : jsonEncode(response),
            200,
            headers: {
              'content-type': stream ? 'text/event-stream' : 'application/json',
            },
          );
        });
        addTearDown(client.close);
        final config = ProviderConfig(
          id: 'GeminiSchemaTest',
          enabled: true,
          name: 'GeminiSchemaTest',
          apiKey: 'test-key',
          baseUrl: 'https://example.test/v1beta',
          providerType: ProviderKind.google,
        );
        var calls = 0;
        await sendGoogleGeminiStream(
          client,
          config,
          'gemini-2.5-flash',
          [
            {'role': 'user', 'content': 'Read sample'},
          ],
          tools: tools,
          stream: stream,
          onToolCall: (name, args, {toolCallId}) async {
            calls++;
            expect(name, 'read_file');
            expect(args, {'path': '/workspace/sample.txt'});
            return 'sample';
          },
        ).toList();

        expect(calls, 1);
        expect(requests, hasLength(2));
        for (final request in requests) {
          final declarations =
              request['tools'][0]['function_declarations'] as List;
          expect(declarations, hasLength(tools.length));
          for (final tool in tools) {
            final function = tool['function'] as Map;
            final declaration =
                declarations.singleWhere((d) => d['name'] == function['name'])
                    as Map;
            final expected = Map<String, dynamic>.from(
              function['parameters'] as Map,
            )..remove('additionalProperties');
            // Keep supported constraints such as shell timeout defaults/bounds
            // and phone-control text length/gesture duration limits intact.
            expect(declaration['parameters'], expected);
          }
        }
        expect(jsonEncode(tools), original);
      },
    );
  }
}
