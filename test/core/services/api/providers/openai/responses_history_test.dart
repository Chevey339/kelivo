import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_emit.dart';
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
