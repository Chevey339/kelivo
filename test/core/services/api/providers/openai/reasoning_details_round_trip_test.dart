import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/native_input_attachments.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_api.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/features/home/services/assistant_tool_history.dart';

const _model = 'moonshotai/kimi-k3.1-pro';
final _config = ProviderConfig(
  id: 'OpenRouter',
  enabled: true,
  name: 'OpenRouter',
  apiKey: 'test-key',
  baseUrl: 'https://openrouter.ai/api/v1',
  providerType: ProviderKind.openai,
);
final _nativeInputs = NativeInputAttachments(
  config: _config,
  spec: ModelSpec(id: _model, displayName: _model),
  protocol: NativeInputProtocol.chatCompletions,
);
final _deepSeekConfig = _config.copyWith(
  id: 'DeepSeek',
  baseUrl: 'https://api.deepseek.com/v1',
);
final _scalarInputs = NativeInputAttachments(
  config: _deepSeekConfig,
  spec: ModelSpec(id: 'deepseek-flash', displayName: 'DeepSeek'),
  protocol: NativeInputProtocol.chatCompletions,
);

const _plainFragments = [
  {'type': 'reasoning.text', 'text': 'Let', 'format': 'unknown', 'index': 0},
  {'type': 'reasoning.text', 'text': ' me', 'format': 'unknown', 'index': 0},
  {'type': 'reasoning.text', 'text': ' me', 'format': 'unknown', 'index': 0},
  {
    'type': 'reasoning.text',
    'text': '\ncheck.',
    'format': 'unknown',
    'index': 0,
  },
];
const _plainBlocks = [
  {
    'type': 'reasoning.text',
    'text': 'Let me me\ncheck.',
    'format': 'unknown',
    'index': 0,
  },
];
const _opaqueBlock = {
  'type': 'reasoning.encrypted',
  'data': 'opaque-data',
  'id': 'encrypted-id',
  'format': 'openai-responses-v1',
  'index': 2,
};
const _structuredFragments = [
  {'type': 'reasoning.text', 'text': 'First', 'index': 0},
  {'type': 'reasoning.text', 'text': ' thought', 'index': 0},
  {'type': 'reasoning.text', 'signature': 'sig-0', 'index': 0},
  {'type': 'reasoning.text', 'text': 'Second', 'index': 1},
  {
    'type': 'reasoning.text',
    'text': ' thought',
    'signature': 'sig-1',
    'index': 1,
  },
  _opaqueBlock,
  _opaqueBlock,
  {'type': 'reasoning.summary', 'summary': 'Short', 'index': 3},
  {'type': 'reasoning.summary', 'summary': ' summary.', 'index': 3},
];
const _structuredBlocks = [
  {
    'type': 'reasoning.text',
    'text': 'First thought',
    'index': 0,
    'signature': 'sig-0',
  },
  {
    'type': 'reasoning.text',
    'text': 'Second thought',
    'signature': 'sig-1',
    'index': 1,
  },
  _opaqueBlock,
  _opaqueBlock,
  {'type': 'reasoning.summary', 'summary': 'Short summary.', 'index': 3},
];

void _expectReplay(Map message, List<Map<String, Object>> blocks) {
  expect(message['reasoning_details'], blocks);
  expect(message.containsKey('reasoning_content'), isFalse);
  expect(message.containsKey('reasoning'), isFalse);
}

void main() {
  for (final field in ReasoningReplayField.values) {
    test(
      'fragmented history uses one structured representation with $field',
      () async {
        final original = <String, dynamic>{
          'role': 'assistant',
          'content': 'Answer',
          'reasoning': 'Let me me\ncheck.',
          'reasoning_content': 'Let me me\ncheck.',
          'reasoning_details': _plainFragments,
        };
        final messages = await buildOpenAIChatCompletionMessages(
          [original],
          nativeInputs: _nativeInputs,
          canImageInput: false,
          allowRemoteImages: false,
          reasoningReplay: ReasoningReplayPolicy.all,
          replayField: field,
        );
        _expectReplay(messages.single, _plainBlocks);
        expect(original['reasoning_details'], _plainFragments);
        expect(original['reasoning_content'], 'Let me me\ncheck.');
      },
    );
  }

  test(
    'plain reasoning keeps its configured field when no details exist',
    () async {
      for (final rawDetails in [
        null,
        <dynamic>[null],
      ]) {
        final messages = await buildOpenAIChatCompletionMessages(
          [
            {
              'role': 'assistant',
              'content': 'Answer',
              'reasoning_content': 'Plain\nthinking',
              'reasoning_details': rawDetails,
            },
          ],
          nativeInputs: _nativeInputs,
          canImageInput: false,
          allowRemoteImages: false,
          reasoningReplay: ReasoningReplayPolicy.all,
          replayField: ReasoningReplayField.reasoning,
        );
        expect(messages.single['reasoning'], 'Plain\nthinking');
        expect(messages.single.containsKey('reasoning_content'), isFalse);
        expect(messages.single.containsKey('reasoning_details'), isFalse);
      }
    },
  );

  for (final field in [
    ReasoningReplayField.reasoningContent,
    ReasoningReplayField.reasoning,
  ]) {
    test('scalar endpoints use $field for unsigned imported details', () async {
      final messages = await buildOpenAIChatCompletionMessages(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Let me me\ncheck.',
            'reasoning_details': _plainFragments,
          },
        ],
        nativeInputs: _scalarInputs,
        canImageInput: false,
        allowRemoteImages: false,
        reasoningReplay: ReasoningReplayPolicy.all,
        replayField: field,
      );
      expect(messages.single, {
        'role': 'assistant',
        'content': 'Answer',
        field.wireName: 'Let me me\ncheck.',
      });
    });
  }

  test('an empty scalar echo never replaces nonempty details', () async {
    final messages = await buildOpenAIChatCompletionMessages(
      [
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': '',
          'reasoning_details': _plainFragments,
        },
      ],
      nativeInputs: _scalarInputs,
      canImageInput: false,
      allowRemoteImages: false,
      reasoningReplay: ReasoningReplayPolicy.all,
    );
    _expectReplay(messages.single, _plainBlocks);
  });

  test('empty preferred field does not hide a nonempty scalar echo', () async {
    final messages = await buildOpenAIChatCompletionMessages(
      [
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning': '',
          'reasoning_content': 'Let me me\ncheck.',
          'reasoning_details': _plainFragments,
        },
      ],
      nativeInputs: _scalarInputs,
      canImageInput: false,
      allowRemoteImages: false,
      reasoningReplay: ReasoningReplayPolicy.all,
      replayField: ReasoningReplayField.reasoning,
    );
    expect(messages.single, {
      'role': 'assistant',
      'content': 'Answer',
      'reasoning': 'Let me me\ncheck.',
    });
  });

  for (final block in [
    _opaqueBlock,
    {'type': 'reasoning.text', 'text': 'signed', 'signature': 'sig'},
    {'type': 'reasoning.future', 'data': 'unknown'},
  ]) {
    test('scalar preferences preserve structured metadata: $block', () async {
      final messages = await buildOpenAIChatCompletionMessages(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Plain echo',
            'reasoning_details': [block],
          },
        ],
        nativeInputs: _scalarInputs,
        canImageInput: false,
        allowRemoteImages: false,
        reasoningReplay: ReasoningReplayPolicy.all,
      );
      _expectReplay(messages.single, [block]);
    });
  }

  test('explicit structured replay works on a generic endpoint', () async {
    final messages = await buildOpenAIChatCompletionMessages(
      [
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': 'Let me me\ncheck.',
          'reasoning_details': _plainFragments,
        },
      ],
      nativeInputs: _scalarInputs,
      canImageInput: false,
      allowRemoteImages: false,
      reasoningReplay: ReasoningReplayPolicy.all,
      replayField: ReasoningReplayField.reasoningDetails,
    );
    _expectReplay(messages.single, _plainBlocks);
  });

  test(
    'keeps an explicitly empty reasoning_details marker in history',
    () async {
      final messages = await buildOpenAIChatCompletionMessages(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_details': <dynamic>[],
          },
        ],
        nativeInputs: _nativeInputs,
        canImageInput: false,
        allowRemoteImages: false,
        reasoningReplay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoningDetails,
      );
      expect(messages.single, {
        'role': 'assistant',
        'content': 'Answer',
        'reasoning_details': <dynamic>[],
      });
    },
  );

  test(
    'history replay can still be disabled for structured thinking',
    () async {
      final messages = await buildOpenAIChatCompletionMessages(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_details': _plainFragments,
          },
        ],
        nativeInputs: _nativeInputs,
        canImageInput: false,
        allowRemoteImages: false,
        reasoningReplay: ReasoningReplayPolicy.none,
      );
      expect(messages.single, {'role': 'assistant', 'content': 'Answer'});
    },
  );

  for (final stream in [true, false]) {
    test(
      'switching OpenRouter history to native DeepSeek keeps reasoning through tool follow-up: stream=$stream',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          final round = bodies.length;
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          final response = jsonEncode({
            'choices': [
              {
                stream ? 'delta' : 'message': {
                  'content': round == 1 ? '' : 'Answer',
                  'reasoning_content': round == 0
                      ? 'Let me me\ncheck.'
                      : 'Native thinking',
                  if (round == 0) 'reasoning_details': _plainFragments,
                  if (round == 1)
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call-native',
                        'type': 'function',
                        'function': {'name': 'lookup', 'arguments': '{}'},
                      },
                    ],
                },
                'finish_reason': round == 1 ? 'tool_calls' : 'stop',
              },
            ],
          });
          return http.Response(
            stream ? 'data: $response\n\ndata: [DONE]\n\n' : response,
            200,
          );
        });
        addTearDown(client.close);
        final saved = StreamChunkHandler.collect(
          await sendOpenAIStream(client, _config, _model, [
            {'role': 'user', 'content': 'Hello'},
          ], stream: stream).toList(),
        );
        final history = buildAssistantToolHistory([
          for (final part in saved.parts)
            MessagePart.fromRow(part.kind, part.encodePayload()),
        ]);
        await sendOpenAIStream(
          client,
          _deepSeekConfig,
          'deepseek-flash',
          [
            {'role': 'user', 'content': 'Hello'},
            {
              'role': 'assistant',
              'content': history.content,
              'reasoning_content': history.reasoning,
              'reasoning_details': jsonDecode(
                jsonEncode(saved.reasoningDetails),
              ),
            },
            {'role': 'user', 'content': 'Look up'},
          ],
          stream: stream,
          tools: [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {'type': 'object', 'properties': {}},
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async => 'Result',
        ).toList();

        expect(bodies, hasLength(3));
        for (final body in bodies.skip(1)) {
          final assistants = (body['messages'] as List)
              .cast<Map>()
              .where((m) => m['role'] == 'assistant')
              .toList();
          expect(assistants.first['reasoning_content'], 'Let me me\ncheck.');
          for (final assistant in assistants) {
            expect(assistant.containsKey('reasoning'), isFalse);
            expect(assistant.containsKey('reasoning_details'), isFalse);
          }
          if (assistants.length == 2) {
            expect(assistants.last['reasoning_content'], 'Native thinking');
          }
        }
        expect(saved.reasoningDetails, _plainBlocks);
      },
    );

    test(
      'orphan signature keeps the signed replay guard after persistence: stream=$stream',
      () async {
        const model = 'proxy-alias';
        final config = _config.copyWith(
          modelOverrides: {
            model: {
              'reasoning': {'replay': 'all'},
            },
          },
        );
        const signatureOnly = [
          {'type': 'reasoning.text', 'signature': 'orphan'},
        ];
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          final response = jsonEncode({
            'choices': [
              {
                stream ? 'delta' : 'message': {
                  'content': 'Answer',
                  'reasoning_content': 'Unsigned prose',
                  'reasoning_details': signatureOnly,
                },
                'finish_reason': 'stop',
              },
            ],
          });
          return http.Response(
            stream ? 'data: $response\n\ndata: [DONE]\n\n' : response,
            200,
          );
        });
        addTearDown(client.close);
        final chunks = await sendOpenAIStream(client, config, model, [
          {'role': 'user', 'content': 'Hello'},
        ], stream: stream).toList();
        final result = StreamChunkHandler.collect(chunks);
        expect(result.reasoningDetails, signatureOnly);
        await sendOpenAIStream(client, config, model, [
          {'role': 'user', 'content': 'Hello'},
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Unsigned prose',
            'reasoning_details': jsonDecode(
              jsonEncode(result.reasoningDetails),
            ),
          },
          {'role': 'user', 'content': 'Continue'},
        ], stream: stream).toList();
        final assistant = (bodies.last['messages'] as List)
            .cast<Map>()
            .firstWhere((m) => m['role'] == 'assistant');
        expect(assistant, {'role': 'assistant', 'content': 'Answer'});
      },
    );

    test(
      'thinking survives two tool rounds, persistence and history replay: stream=$stream',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          final round = bodies.length;
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          final fragments = round == 1 ? _structuredFragments : _plainFragments;
          final tail = <String, dynamic>{
            'content': round < 2 ? '' : 'Answer',
            if (round < 2)
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call-$round',
                  'type': 'function',
                  'function': {'name': 'lookup', 'arguments': '{}'},
                },
              ],
          };
          Map<String, dynamic> event(
            Map<String, dynamic> delta, [
            String? finish,
          ]) => {
            'choices': [
              {stream ? 'delta' : 'message': delta, 'finish_reason': finish},
            ],
          };
          final finish = round < 2 ? 'tool_calls' : 'stop';
          final response = stream
              ? [
                  for (final fragment in fragments)
                    'data: ${jsonEncode(event({
                      'reasoning': fragment['text'] ?? fragment['summary'] ?? '',
                      'reasoning_details': [fragment],
                    }))}\n\n',
                  'data: ${jsonEncode(event(tail, finish))}\n\n',
                  'data: [DONE]\n\n',
                ].join()
              : jsonEncode(
                  event({
                    ...tail,
                    'reasoning': fragments
                        .map((f) => f['text'] ?? f['summary'] ?? '')
                        .join(),
                    'reasoning_details': fragments,
                  }, finish),
                );
          return http.Response(response, 200);
        });
        addTearDown(client.close);
        var calls = 0;
        final chunks = await sendOpenAIStream(
          client,
          _config,
          _model,
          [
            {'role': 'user', 'content': 'Look up twice'},
          ],
          stream: stream,
          tools: [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {'type': 'object', 'properties': {}},
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async {
            calls++;
            return 'Result $calls';
          },
        ).toList();
        expect(calls, 2);
        expect(bodies, hasLength(3));
        final firstFollowUp = (bodies[1]['messages'] as List).cast<Map>();
        _expectReplay(
          firstFollowUp.firstWhere((m) => m['role'] == 'assistant'),
          _plainBlocks,
        );
        final secondFollowUp = (bodies[2]['messages'] as List)
            .cast<Map>()
            .where((m) => m['role'] == 'assistant')
            .toList();
        _expectReplay(secondFollowUp[0], _plainBlocks);
        _expectReplay(secondFollowUp[1], _structuredBlocks);

        final result = StreamChunkHandler.collect(chunks);
        final parts = [
          for (final part in result.parts)
            MessagePart.fromRow(part.kind, part.encodePayload()),
        ];
        expect(
          parts.whereType<AssistantRoundEndPart>().map(
            (p) => p.reasoningDetails,
          ),
          [_plainBlocks, _structuredBlocks],
        );
        expect(result.reasoningDetails, _plainBlocks);
        final history = buildAssistantToolHistory(parts);
        await sendOpenAIStream(client, _config, _model, [
          {'role': 'user', 'content': 'Look up twice'},
          ...history.messages,
          {
            'role': 'assistant',
            'content': history.content,
            'reasoning_content': history.reasoning,
            'reasoning_details': result.reasoningDetails,
          },
          {'role': 'user', 'content': 'Continue'},
        ], stream: stream).toList();
        final replayed = (bodies.last['messages'] as List)
            .cast<Map>()
            .where((m) => m['role'] == 'assistant')
            .toList();
        expect(replayed, hasLength(3));
        _expectReplay(replayed[0], _plainBlocks);
        _expectReplay(replayed[1], _structuredBlocks);
        _expectReplay(replayed[2], _plainBlocks);
      },
    );
  }
}
