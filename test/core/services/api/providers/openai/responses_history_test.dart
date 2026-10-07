import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_emit.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/context_assembly.dart';

const _scope = (
  providerId: 'provider',
  baseUrl: 'https://example.com',
  modelId: 'model',
);
const _reasoning = {
  'type': 'reasoning',
  'id': 'rs_1',
  'summary': <Object>[],
  'encrypted_content': 'opaque',
};

Map<String, dynamic> _text(String text) => {
  'type': 'message',
  'role': 'assistant',
  'content': [
    {'type': 'output_text', 'text': text, 'annotations': <Object>[]},
  ],
};

Map<String, dynamic> _call(String id) => {
  'type': 'function_call',
  'call_id': id,
  'name': 'lookup',
  'arguments': '{}',
};

void main() {
  for (final terminal in [false, true]) {
    test(
      'Responses retains completed items at EOF: terminal=$terminal',
      () async {
        final config = ProviderConfig(
          id: 'OpenAI',
          enabled: true,
          name: 'OpenAI',
          apiKey: 'fixture',
          baseUrl: 'https://api.openai.com/v1',
          providerType: ProviderKind.openai,
          useResponseApi: true,
        );
        final message = _text('Answer');
        final events = [
          {
            'type': 'response.output_item.done',
            'output_index': 0,
            'item': _reasoning,
          },
          {
            'type': 'response.output_text.delta',
            'output_index': 1,
            'delta': 'Answer',
          },
          {
            'type': 'response.output_item.done',
            'output_index': 1,
            'item': message,
          },
          if (terminal)
            {
              'type': 'response.completed',
              'response': {
                'output': [_reasoning, message],
              },
            },
        ];
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          bodies.add(jsonDecode(request.body));
          return http.Response(
            events.map((e) => 'data: ${jsonEncode(e)}\n\n').join(),
            200,
          );
        });
        addTearDown(client.close);
        final chunks = await sendOpenAIStream(client, config, 'gpt-5.4', [
          {'role': 'user', 'content': 'Hello'},
        ]).toList();
        final artifact = chunks.whereType<ProviderArtifact>().single;
        expect(
          chunks.whereType<TextDelta>().map((c) => c.text).join(),
          'Answer',
        );
        final rounds = jsonDecode(artifact.payload)['rounds'] as List;
        expect(rounds, hasLength(1));
        expect(rounds.single['output'], [_reasoning, message]);
        final history = buildResponsesHistory(
          payload: artifact.payload,
          scope: responsesReplayScope(config, 'gpt-5.4'),
          content: 'Answer',
          toolEvents: const [],
        );
        expect(history, isNotNull);
        await sendOpenAIStream(client, config, 'gpt-5.4', [
          {'role': 'user', 'content': 'Hello'},
          ...history!,
          {'role': 'user', 'content': 'Next'},
        ]).toList();
        expect(
          (bodies.last['input'] as List).where(
            (item) => item['type'] == 'reasoning',
          ),
          [_reasoning],
        );
      },
    );
  }

  test(
    'Responses EOF records no unfinished function call and runs no tool',
    () async {
      final config = ProviderConfig(
        id: 'OpenAI',
        enabled: true,
        name: 'OpenAI',
        apiKey: 'fixture',
        baseUrl: 'https://api.openai.com/v1',
        providerType: ProviderKind.openai,
        useResponseApi: true,
      );
      final events = [
        {
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': _reasoning,
        },
        {
          'type': 'response.output_item.added',
          'output_index': 1,
          'item': {
            'type': 'function_call',
            'id': 'fc_unfinished',
            'call_id': 'unfinished',
            'name': 'lookup',
            'arguments': '',
          },
        },
        {
          'type': 'response.function_call_arguments.delta',
          'output_index': 1,
          'delta': '{"q":',
        },
      ];
      final client = MockClient(
        (request) async => http.Response(
          events.map((e) => 'data: ${jsonEncode(e)}\n\n').join(),
          200,
        ),
      );
      addTearDown(client.close);
      var toolCalls = 0;
      final chunks = await sendOpenAIStream(
        client,
        config,
        'gpt-5.4',
        [
          {'role': 'user', 'content': 'Hello'},
        ],
        onToolCall: (name, args, {toolCallId}) async {
          toolCalls++;
          return 'unexpected';
        },
      ).toList();
      final artifact = chunks.whereType<ProviderArtifact>().single;
      expect(jsonDecode(artifact.payload)['rounds'].single['output'], [
        _reasoning,
      ]);
      expect(toolCalls, 0);
    },
  );

  test(
    'resumed native artifacts never merge another provider, endpoint or model',
    () {
      final prefix = ResponsesTurnRecorder(
        _scope,
      ).record([_reasoning], []).payload;
      for (final scope in [
        (providerId: 'other', baseUrl: _scope.baseUrl, modelId: _scope.modelId),
        (
          providerId: _scope.providerId,
          baseUrl: 'https://other.example',
          modelId: _scope.modelId,
        ),
        (
          providerId: _scope.providerId,
          baseUrl: _scope.baseUrl,
          modelId: 'other',
        ),
      ]) {
        final current = ResponsesTurnRecorder(
          scope,
        ).record([_text('Fresh')], []).payload;
        expect(appendResponsesTurn(prefix, current), current);
        expect(appendResponsesTurn('broken', current), current);
        expect(appendResponsesTurn(null, current), current);
      }
    },
  );

  for (final policy in [null, ...ReasoningReplayPolicy.values]) {
    for (final tool in ['none', 'function', 'hosted']) {
      test('Responses history replay=$policy, tool=$tool', () async {
        final config = ProviderConfig(
          id: 'OpenAI',
          enabled: true,
          name: 'OpenAI',
          apiKey: 'test',
          baseUrl: 'https://api.openai.com/v1',
          providerType: ProviderKind.openai,
          useResponseApi: true,
          modelOverrides: {
            if (policy != null)
              'gpt-5.4': {
                'reasoning': {'replay': policy.name},
              },
          },
        );
        final scope = responsesReplayScope(config, 'gpt-5.4');
        final output = [
          _reasoning,
          _text('Answer'),
          if (tool == 'function') _call('c1'),
          if (tool == 'hosted')
            {'type': 'web_search_call', 'id': 'ws1', 'status': 'completed'},
        ];
        final artifact = ResponsesTurnRecorder(scope).record(output, [
          if (tool == 'function')
            emitToolCall(id: 'c1', name: 'lookup', arguments: {}),
        ]);
        final history = buildResponsesHistory(
          payload: artifact.payload,
          scope: scope,
          content: 'Answer',
          toolEvents: [
            if (tool == 'function') {'id': 'c1', 'content': 'found'},
          ],
        )!;
        late Map<String, dynamic> body;
        final client = MockClient((request) async {
          body = jsonDecode(request.body);
          return http.Response('{"output":[]}', 200);
        });
        addTearDown(client.close);
        await sendOpenAIStream(client, config, 'gpt-5.4', [
          {'role': 'user', 'content': 'Question'},
          ...history,
          {'role': 'user', 'content': 'Next'},
        ], stream: false).toList();
        final keepReasoning =
            policy == null ||
            policy == ReasoningReplayPolicy.all ||
            (policy == ReasoningReplayPolicy.toolTurns && tool != 'none');
        expect(body['input'], [
          {'role': 'user', 'content': 'Question'},
          for (final item in output)
            if (item['type'] != 'reasoning' || keepReasoning) item,
          if (tool == 'function')
            {
              'type': 'function_call_output',
              'call_id': 'c1',
              'output': 'found',
            },
          {'role': 'user', 'content': 'Next'},
        ]);
      });
    }
  }

  for (final stream in [false, true]) {
    test(
      'Responses replay none preserves live tool reasoning: stream=$stream',
      () async {
        final config = ProviderConfig(
          id: 'OpenAI',
          enabled: true,
          name: 'OpenAI',
          apiKey: 'test',
          baseUrl: 'https://api.openai.com/v1',
          providerType: ProviderKind.openai,
          useResponseApi: true,
          modelOverrides: {
            'gpt-5.4': {
              'reasoning': {'replay': 'none'},
            },
          },
        );
        final bodies = <Map<String, dynamic>>[];
        final output = [_reasoning, _call('live-call')];
        final client = MockClient((request) async {
          bodies.add(jsonDecode(request.body));
          final response = {
            'output': bodies.length == 1 ? output : [_text('Done')],
          };
          final events = [
            for (final (index, item)
                in (response['output'] as List).indexed) ...[
              {
                'type': 'response.output_item.added',
                'output_index': index,
                'item': item,
              },
              {
                'type': 'response.output_item.done',
                'output_index': index,
                'item': item,
              },
            ],
            {'type': 'response.completed', 'response': response},
          ];
          return http.Response(
            stream
                ? '${events.map((event) => 'data: ${jsonEncode(event)}\n\n').join()}data: [DONE]\n\n'
                : jsonEncode(response),
            200,
            headers: {
              'content-type': stream ? 'text/event-stream' : 'application/json',
            },
          );
        });
        addTearDown(client.close);
        await sendOpenAIStream(
          client,
          config,
          'gpt-5.4',
          [
            {'role': 'user', 'content': 'Look it up'},
          ],
          stream: stream,
          tools: [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {'type': 'object'},
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async => 'found',
        ).toList();
        expect(bodies, hasLength(2));
        expect((bodies.last['input'] as List).skip(1), [
          ...output,
          {
            'type': 'function_call_output',
            'call_id': 'live-call',
            'output': 'found',
          },
        ]);
      },
    );
  }

  test(
    'toolTurns filters final response reasoning independently of tool rounds',
    () {
      final recorder = ResponsesTurnRecorder(_scope);
      recorder.record(
        [_reasoning, _call('c1')],
        [emitToolCall(id: 'c1', name: 'lookup', arguments: {})],
      );
      final artifact = recorder.record([
        {..._reasoning, 'id': 'final-reasoning'},
        _text('Done'),
      ], []);
      final history = buildResponsesHistory(
        payload: artifact.payload,
        scope: _scope,
        content: 'Done',
        toolEvents: [
          {'id': 'c1', 'content': 'found'},
        ],
      )!;
      final filtered = filterResponsesReasoningHistory(
        history,
        ReasoningReplayPolicy.toolTurns,
      );
      expect(
        filtered
            .map((m) => m[multimodalInternalResponsesItemKey])
            .whereType<Map>(),
        [_reasoning, _call('c1'), _text('Done')],
      );
      expect(history, hasLength(5));
    },
  );

  for (final official in [true, false]) {
    test(
      'ordinary Responses request retains its options, official=$official',
      () async {
        late Map<String, dynamic> requestBody;
        final client = MockClient((request) async {
          requestBody = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'output': [_text('Hi')],
            }),
            200,
          );
        });
        addTearDown(client.close);
        final config = ProviderConfig(
          id: official ? 'OpenAI' : 'DeepSeek',
          enabled: true,
          name: 'Fixture',
          apiKey: 'test',
          baseUrl: official
              ? 'https://api.openai.com/v1'
              : 'https://api.deepseek.com/v1',
          providerType: ProviderKind.openai,
          useResponseApi: true,
        );
        await sendOpenAIStream(
          client,
          config,
          official ? 'gpt-4.1' : 'deepseek-flash',
          [
            {'role': 'user', 'content': 'Hello'},
          ],
          stream: false,
          temperature: 0.4,
          topP: 0.8,
          maxTokens: 96,
        ).toList();
        expect(requestBody['input'], [
          {'role': 'user', 'content': 'Hello'},
        ]);
        expect(requestBody['temperature'], 0.4);
        expect(requestBody['top_p'], 0.8);
        expect(requestBody['max_output_tokens'], 96);
        expect(requestBody['tools'], isNull);
        expect(
          requestBody['include'],
          official ? ['reasoning.encrypted_content'] : isNull,
        );
      },
    );
  }

  test(
    'context preview still counts plain reasoning and function arguments',
    () {
      final artifact = ResponsesTurnRecorder(_scope).record(
        [
          {
            'type': 'reasoning',
            'content': [
              {'type': 'reasoning_text', 'text': 'Thinking\n'},
            ],
          },
          _call('a'),
        ],
        [emitToolCall(id: 'a', name: 'lookup', arguments: {})],
      );
      final history = buildResponsesHistory(
        payload: artifact.payload,
        scope: _scope,
        toolEvents: [
          {'id': 'a', 'content': 'result'},
        ],
        content: '',
      )!;
      final preview = ContextAssemblyPreview.fromApiMessages(
        apiMessages: history,
        tools: [],
        mcpToolNames: {},
        images: [],
      );
      expect(preview.historyText, contains('Thinking\n'));
      expect(preview.historyText, contains('lookup'));
      expect(preview.historyText, contains('arguments'));
      expect(preview.historyText, contains('result'));
    },
  );

  test('cancelled parallel batch keeps only earlier complete exchanges', () {
    final recorder = ResponsesTurnRecorder(_scope);
    recorder.record(
      [_reasoning, _call('a')],
      [emitToolCall(id: 'a', name: 'lookup', arguments: {})],
    );
    final artifact = recorder.record(
      [
        {..._reasoning, 'id': 'rs_2', 'encrypted_content': 'unfinished-batch'},
        _text('Checking more. '),
        _call('b'),
        _call('c'),
      ],
      [
        emitToolCall(id: 'b', name: 'lookup', arguments: {}),
        emitToolCall(id: 'c', name: 'lookup', arguments: {}),
      ],
    );
    final history = buildResponsesHistory(
      payload: artifact.payload,
      scope: _scope,
      content: 'Checking more. ',
      toolEvents: [
        {'id': 'a', 'content': 'result-a'},
        {'id': 'b', 'content': 'result-b'},
        {'id': 'c', 'content': null},
      ],
    )!;
    expect(history.map((message) => message['role']), [
      'assistant',
      'assistant',
      'tool',
      'assistant',
    ]);
    expect(responsesInputItem(history[0]), _reasoning);
    expect(responsesInputItem(history[1]), _call('a'));
    expect(history[2]['tool_call_id'], 'a');
    expect(history.last, {'role': 'assistant', 'content': 'Checking more. '});
  });

  test('native state is scoped to provider, endpoint, and upstream model', () {
    final artifact = ResponsesTurnRecorder(
      _scope,
    ).record([_reasoning, _text('Answer')], []);
    for (final scope in [
      (providerId: 'other', baseUrl: _scope.baseUrl, modelId: _scope.modelId),
      (
        providerId: _scope.providerId,
        baseUrl: 'https://other.com',
        modelId: _scope.modelId,
      ),
      (
        providerId: _scope.providerId,
        baseUrl: _scope.baseUrl,
        modelId: 'other',
      ),
    ]) {
      expect(
        buildResponsesHistory(
          payload: artifact.payload,
          scope: scope,
          toolEvents: [],
          content: 'Answer',
        ),
        isNull,
      );
    }
  });

  test(
    'text edits do not revive stale output, partial text remains visible',
    () {
      final artifact = ResponsesTurnRecorder(
        _scope,
      ).record([_text('Answer')], []);
      expect(
        buildResponsesHistory(
          payload: artifact.payload,
          scope: _scope,
          toolEvents: [],
          content: 'Edited',
        ),
        isNull,
      );
      final history = buildResponsesHistory(
        payload: artifact.payload,
        scope: _scope,
        toolEvents: [],
        content: 'Answer plus partial text',
      )!;
      expect(responsesInputItem(history.first), _text('Answer'));
      expect(history.last, {
        'role': 'assistant',
        'content': ' plus partial text',
      });
    },
  );

  test(
    'no-tool reasoning and hosted output items retain their exact order',
    () {
      final output = [
        _reasoning,
        _text('Before. '),
        {
          'type': 'web_search_call',
          'id': 'ws_1',
          'status': 'completed',
          'action': {'type': 'search', 'query': 'topic'},
        },
        _text('After.'),
      ];
      final artifact = ResponsesTurnRecorder(_scope).record(output, []);
      final history = buildResponsesHistory(
        payload: artifact.payload,
        scope: _scope,
        toolEvents: [
          {
            'id': 'ws_1',
            'server': true,
            'name': 'search_web',
            'content': 'completed',
          },
        ],
        content: 'Before. After.',
      )!;
      expect(history.map(responsesInputItem), output);
    },
  );

  test('thinking-only DeepSeek output remains a reasoning item', () {
    const output = {
      'type': 'reasoning',
      'content': [
        {'type': 'reasoning_text', 'text': ' Thinking\n'},
      ],
    };
    final artifact = ResponsesTurnRecorder(_scope).record([output], []);
    final history = buildResponsesHistory(
      payload: artifact.payload,
      scope: _scope,
      toolEvents: [],
      content: '',
    )!;
    expect(history.map(responsesInputItem), [output]);
  });

  test(
    'assistant regex output changes text without rewriting native reasoning',
    () {
      final artifact = ResponsesTurnRecorder(
        _scope,
      ).record([_reasoning, _text('Before')], []);
      final history = buildResponsesHistory(
        payload: artifact.payload,
        scope: _scope,
        toolEvents: [],
        content: 'Before',
      )!;
      history.last['content'] = 'After';
      expect(responsesInputItem(history.first), _reasoning);
      expect(responsesInputItem(history.last), _text('After'));
      expect(history.last[multimodalInternalResponsesItemKey], _text('Before'));
    },
  );
}
