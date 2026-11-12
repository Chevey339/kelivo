import 'dart:convert';

import 'package:Kelivo/core/models/image_generation_options.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/auth/codex_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ProviderConfig _config({
  Object? options,
  bool enabled = true,
  bool router = false,
}) => ProviderConfig(
  id: router ? 'OpenRouter' : 'OpenAI',
  enabled: true,
  name: 'Test',
  apiKey: 'mock-only',
  baseUrl: router
      ? 'https://openrouter.ai/api/v1'
      : 'https://api.openai.com/v1',
  providerType: ProviderKind.openai,
  useResponseApi: true,
  modelOverrides: {
    'gpt-6-astra': {
      'builtInTools': [if (enabled) BuiltInToolNames.imageGeneration],
      'imageGeneration': options,
    },
  },
);

List<Map<String, dynamic>> _tools(ProviderConfig cfg) =>
    BuiltInToolsHelper.buildResponsesTools(
      cfg: cfg,
      modelId: 'gpt-6-astra',
      upstreamModelId: 'gpt-6-astra',
    ).tools;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('automatic image model and complexity omit optional fields', () {
    for (final options in [
      null,
      {},
      {'model': 'auto', 'complexity': 'default'},
    ]) {
      expect(_tools(_config(options: options)), [
        {'type': 'image_generation'},
      ]);
    }
  });

  test(
    'only supported models and valid explicit complexities reach the tool',
    () {
      for (final model in ImageGenerationOptions.models.keys) {
        for (final level in [null, 'low', 'medium', 'high', 'xhigh']) {
          expect(
            _tools(_config(options: {'model': model, 'complexity': level})),
            [
              {
                'type': 'image_generation',
                'model': model,
                if (model.startsWith('gpt-image-2.6-') &&
                    ['low', 'medium', 'high'].contains(level))
                  'complexity': level,
              },
            ],
          );
        }
      }
      expect(_tools(_config(options: {'complexity': 'high'})), [
        {'type': 'image_generation'},
      ]);
      expect(
        _tools(
          _config(options: {'model': 'custom-image', 'complexity': 'high'}),
        ),
        [
          {'type': 'image_generation', 'model': 'custom-image'},
        ],
      );
    },
  );

  test('disabled tool and OpenRouter do not consume native image options', () {
    const options = {'model': 'gpt-image-2.6-sunburst', 'complexity': 'high'};
    expect(_tools(_config(options: options, enabled: false)), isEmpty);
    expect(_tools(_config(options: options, router: true)), [
      {'type': 'openrouter:image_generation'},
    ]);
  });

  for (final stream in [false, true]) {
    for (final level in [ReasoningLevel.auto, ReasoningLevel.xhigh]) {
      test(
        'image options survive tool rounds; stream=$stream reasoning=$level',
        () async {
          final bodies = <Map<String, dynamic>>[];
          final client = MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            // The OAuth transport must preserve the independently selected values.
            applyCodexRequest(body, {}, 'mock-token');
            bodies.add(body);
            expect(bodies.length, lessThanOrEqualTo(2));
            final item = bodies.length == 1
                ? {
                    'type': 'function_call',
                    'id': 'fc_lookup',
                    'call_id': 'call_lookup',
                    'name': 'lookup',
                    'arguments': '{}',
                  }
                : {
                    'type': 'message',
                    'role': 'assistant',
                    'content': [
                      {'type': 'output_text', 'text': 'Done'},
                    ],
                  };
            final response = {
              'status': 'completed',
              'output': [item],
            };
            return http.Response(
              stream
                  ? [
                      {
                        'type': 'response.output_item.done',
                        'output_index': 0,
                        'item': item,
                      },
                      {'type': 'response.completed', 'response': response},
                    ].map((event) => 'data: ${jsonEncode(event)}\n\n').join()
                  : jsonEncode(response),
              200,
            );
          });
          addTearDown(client.close);
          await sendOpenAIStream(
            client,
            _config(
              options: {'model': 'gpt-image-2.6-sunburst', 'complexity': 'low'},
            ),
            'gpt-6-astra',
            [
              {'role': 'user', 'content': 'Look up the subject and draw it'},
            ],
            reasoning: ReasoningRequest(level),
            tools: [
              {
                'type': 'function',
                'function': {
                  'name': 'lookup',
                  'parameters': {
                    'type': 'object',
                    'properties': <String, dynamic>{},
                  },
                },
              },
            ],
            onToolCall: (_, _, {toolCallId}) async => 'black cat',
            stream: stream,
          ).toList();
          expect(bodies, hasLength(2));
          for (final body in bodies) {
            expect(
              (body['tools'] as List)
                  .where((t) => t['type'] == 'image_generation')
                  .single,
              {
                'type': 'image_generation',
                'model': 'gpt-image-2.6-sunburst',
                'complexity': 'low',
              },
            );
            expect(
              body['reasoning']['effort'],
              level == ReasoningLevel.auto ? isNull : 'xhigh',
            );
          }
        },
      );
    }
  }
}
