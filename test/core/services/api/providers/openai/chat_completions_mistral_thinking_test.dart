import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/native_input_attachments.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_api.dart';
import 'package:Kelivo/core/services/api/providers/openai/mistral_thinking_replay.dart';

const _model = 'mistral-large-latest';

const _mistralReasoning = ReasoningSpec(
  levels: [ReasoningLevel.high],
  canDisable: true,
  dialect: ReasoningDialect.openaiReasoningEffort,
  replay: ReasoningReplayPolicy.all,
  replayField: ReasoningReplayField.reasoningContent,
  effortDefaultIsOff: true,
);

final _mistralSpec = ModelSpec(
  id: _model,
  displayName: _model,
  reasoning: _mistralReasoning,
);

const _openRouterReasoning = ReasoningSpec(
  dialect: ReasoningDialect.openrouterReasoning,
  replay: ReasoningReplayPolicy.all,
  replayField: ReasoningReplayField.reasoningContent,
);

final _openRouterSpec = ModelSpec(
  id: _model,
  displayName: _model,
  reasoning: _openRouterReasoning,
);

final _plainSpec = ModelSpec(id: _model, displayName: _model);

ProviderConfig _config({
  String id = 'Mistral',
  String name = 'Mistral',
  String baseUrl = 'https://api.mistral.ai/v1',
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: name,
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

NativeInputAttachments _inputs(ProviderConfig config, {ModelSpec? spec}) {
  return NativeInputAttachments(
    config: config,
    spec: spec ?? _mistralSpec,
    protocol: NativeInputProtocol.chatCompletions,
  );
}

Future<List<Map<String, dynamic>>> _build(
  List<Map<String, dynamic>> messages, {
  ProviderConfig? config,
  ModelSpec? spec,
  ReasoningReplayPolicy replay = ReasoningReplayPolicy.all,
  ReasoningReplayField field = ReasoningReplayField.reasoningContent,
  int? currentToolMessagesStart,
  bool canImageInput = false,
}) {
  return buildOpenAIChatCompletionMessages(
    messages,
    nativeInputs: _inputs(config ?? _config(), spec: spec),
    canImageInput: canImageInput,
    allowRemoteImages: false,
    reasoningReplay: replay,
    replayField: field,
    currentToolMessagesStart: currentToolMessagesStart,
  );
}

Map<String, dynamic> _thinking(String text) => {
  'type': 'thinking',
  'thinking': [
    {'type': 'text', 'text': text},
  ],
};

Map<String, dynamic> _text(String text) => {'type': 'text', 'text': text};

const _toolCall = {
  'id': 'call_1',
  'type': 'function',
  'function': {'name': 'lookup', 'arguments': '{"q":"x"}'},
};

void main() {
  group('Mistral-style spec gate', () {
    test('the official host does not override a non-Mistral spec', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': 'Let me think.',
        },
      ], spec: _plainSpec);

      expect(messages.single, {
        'role': 'assistant',
        'content': 'Answer',
        'reasoning_content': 'Let me think.',
      });
    });

    test('replays typed thinking on a loopback endpoint', () async {
      final messages = await _build(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Let me think.',
          },
        ],
        config: _config(
          id: 'local',
          name: 'Local',
          baseUrl: 'http://127.0.0.1:9/v1',
        ),
      );

      expect(messages.single['content'], [
        _thinking('Let me think.'),
        _text('Answer'),
      ]);
    });

    test('the provider name does not override a non-Mistral spec', () async {
      final messages = await _build(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Let me me\ncheck.',
            'reasoning_details': [
              {'type': 'reasoning.text', 'text': 'Let', 'index': 0},
              {'type': 'reasoning.text', 'text': ' me', 'index': 0},
              {'type': 'reasoning.text', 'text': ' me', 'index': 0},
              {'type': 'reasoning.text', 'text': '\ncheck.', 'index': 0},
            ],
          },
        ],
        config: _config(
          id: 'local',
          name: 'Mistral',
          baseUrl: 'https://openrouter.ai/api/v1',
        ),
        spec: _openRouterSpec,
      );

      expect(messages.single, {
        'role': 'assistant',
        'content': 'Answer',
        'reasoning_details': [
          {'type': 'reasoning.text', 'text': 'Let me me\ncheck.', 'index': 0},
        ],
      });
    });

    test('requires the effort dialect, not just the flag', () async {
      final messages = await _build(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Let me think.',
          },
        ],
        spec: ModelSpec(
          id: _model,
          displayName: _model,
          reasoning: const ReasoningSpec(
            dialect: ReasoningDialect.thinkingType,
            replay: ReasoningReplayPolicy.all,
            effortDefaultIsOff: true,
          ),
        ),
      );

      expect(messages.single, {
        'role': 'assistant',
        'content': 'Answer',
        'reasoning_content': 'Let me think.',
      });
    });
  });

  group('Mistral assistant history replay', () {
    test('turns scalar reasoning into a typed thinking part', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': 'Let me think.',
        },
      ]);

      expect(messages.single, {
        'role': 'assistant',
        'content': [_thinking('Let me think.'), _text('Answer')],
      });
    });

    test('null content with tool_calls keeps the calls', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': null,
          'reasoning_content': 'Need a tool.',
          'tool_calls': [_toolCall],
        },
      ]);

      expect(messages.single, {
        'role': 'assistant',
        'content': [_thinking('Need a tool.')],
        'tool_calls': [_toolCall],
      });
    });

    test('keeps every original list part after the thinking part', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': [_text('First'), _text(' second')],
          'reasoning_content': 'Let me think.',
        },
      ], canImageInput: true);

      expect(messages.single['content'], [
        _thinking('Let me think.'),
        _text('First'),
        _text(' second'),
      ]);
    });

    test('replaces an old thinking part without closed or signature', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': [
            {
              'type': 'thinking',
              'thinking': [
                {'type': 'text', 'text': 'Saved thought'},
              ],
              'closed': true,
              'signature': 'sig',
            },
            _text('Answer'),
          ],
          'reasoning_content': 'Saved thought',
        },
      ], canImageInput: true);

      expect(messages.single['content'], [
        _thinking('Saved thought'),
        _text('Answer'),
      ]);
    });

    test('drops an empty typed thinking part with closed metadata', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': [
            {
              'type': 'thinking',
              'thinking': <dynamic>[],
              'closed': true,
              'signature': 'sig',
            },
            _text('Answer'),
          ],
        },
      ], canImageInput: true);

      expect(messages.single, {
        'role': 'assistant',
        'content': [_text('Answer')],
      });
    });

    test('blank reasoning adds no part and no echo field', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': '   \n',
        },
      ]);

      expect(messages.single, {'role': 'assistant', 'content': 'Answer'});
    });

    test('reads prose from plain text and summary details', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_details': [
            {'type': 'reasoning.text', 'text': 'Let'},
            {'type': 'reasoning.text', 'text': ' me'},
            {'type': 'reasoning.summary', 'summary': ' think.'},
          ],
        },
      ]);

      expect(messages.single, {
        'role': 'assistant',
        'content': [_thinking('Let me think.'), _text('Answer')],
      });
    });

    test('scalar reasoning wins so the thought is sent once', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': 'Full thought',
          'reasoning_details': [
            {'type': 'reasoning.text', 'text': 'Full thought'},
          ],
        },
      ]);

      expect(messages.single['content'], [
        _thinking('Full thought'),
        _text('Answer'),
      ]);
    });

    test('drops a whitespace-only tool-round placeholder body', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': '\n\n',
          'reasoning_content': 'Need a tool.',
          'tool_calls': [_toolCall],
        },
      ]);

      expect(messages.single['content'], [_thinking('Need a tool.')]);
      expect(messages.single['tool_calls'], [_toolCall]);
    });

    test('none policy drops scalar reasoning without adding a part', () async {
      final messages = await _build([
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': 'Let me think.',
        },
      ], replay: ReasoningReplayPolicy.none);

      expect(messages.single, {'role': 'assistant', 'content': 'Answer'});
    });

    test('none policy drops reasoning and typed thinking parts', () async {
      final messages = await _build(
        [
          {
            'role': 'assistant',
            'content': [_thinking('Saved thought'), _text('Answer')],
            'reasoning_content': 'Saved thought',
          },
        ],
        replay: ReasoningReplayPolicy.none,
        canImageInput: true,
      );

      expect(messages.single, {
        'role': 'assistant',
        'content': [_text('Answer')],
      });
    });

    test('none policy turns a thinking-only list into an empty body', () async {
      final messages = await _build(
        [
          {
            'role': 'assistant',
            'content': [_thinking('Saved thought')],
            'tool_calls': [_toolCall],
          },
        ],
        replay: ReasoningReplayPolicy.none,
        canImageInput: true,
      );

      expect(messages.single['content'], '');
      expect(messages.single['tool_calls'], [_toolCall]);
    });

    test('toolTurns policy replays only tool turns', () async {
      final withoutTools = await _build([
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': 'Let me think.',
        },
      ], replay: ReasoningReplayPolicy.toolTurns);
      expect(withoutTools.single, {'role': 'assistant', 'content': 'Answer'});

      final withTools = await _build([
        {
          'role': 'assistant',
          'content': 'Answer',
          'reasoning_content': 'Let me think.',
          'tool_calls': [_toolCall],
        },
      ], replay: ReasoningReplayPolicy.toolTurns);
      expect(withTools.single['content'], [
        _thinking('Let me think.'),
        _text('Answer'),
      ]);
    });

    test('current tool rounds replay even under none policy', () async {
      final messages = await _build(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Let me think.',
          },
        ],
        replay: ReasoningReplayPolicy.none,
        currentToolMessagesStart: 0,
      );

      expect(messages.single['content'], [
        _thinking('Let me think.'),
        _text('Answer'),
      ]);
    });

    test('a non-Mistral provider keeps its structured replay', () async {
      final messages = await _build(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Let me me\ncheck.',
            'reasoning_details': [
              {'type': 'reasoning.text', 'text': 'Let', 'index': 0},
              {'type': 'reasoning.text', 'text': ' me', 'index': 0},
              {'type': 'reasoning.text', 'text': ' me', 'index': 0},
              {'type': 'reasoning.text', 'text': '\ncheck.', 'index': 0},
            ],
          },
        ],
        config: _config(
          id: 'OpenRouter',
          name: 'OpenRouter',
          baseUrl: 'https://openrouter.ai/api/v1',
        ),
        spec: _plainSpec,
      );

      expect(messages.single, {
        'role': 'assistant',
        'content': 'Answer',
        'reasoning_details': [
          {'type': 'reasoning.text', 'text': 'Let me me\ncheck.', 'index': 0},
        ],
      });
    });

    test('a scalar non-Mistral provider keeps its echo field', () async {
      final messages = await _build(
        [
          {
            'role': 'assistant',
            'content': 'Answer',
            'reasoning_content': 'Plain thinking',
          },
        ],
        config: _config(
          id: 'DeepSeek',
          name: 'DeepSeek',
          baseUrl: 'https://api.deepseek.com/v1',
        ),
        spec: _plainSpec,
      );

      expect(messages.single, {
        'role': 'assistant',
        'content': 'Answer',
        'reasoning_content': 'Plain thinking',
      });
    });
  });

  group('mistral thinking helpers', () {
    test('ignores details that carry no prose', () {
      expect(
        mistralReplayThinkingText({
          'reasoning_details': [
            {'type': 'reasoning.encrypted', 'data': 'opaque'},
            {'type': 'reasoning.text', 'signature': 'sig'},
          ],
        }),
        isNull,
      );
    });

    test('falls back to typed thinking already in content', () {
      expect(
        mistralReplayThinkingText({
          'content': [_thinking('Typed thought'), _text('Answer')],
        }),
        'Typed thought',
      );
    });

    test('wraps null and blank bodies without an empty text part', () {
      expect(mistralAssistantContentWithThinking(null, 'Thought'), [
        _thinking('Thought'),
      ]);
      expect(mistralAssistantContentWithThinking('  \n', 'Thought'), [
        _thinking('Thought'),
      ]);
    });

    test('wraps a visible body in a text part', () {
      expect(mistralAssistantContentWithThinking('Answer', 'Thought'), [
        _thinking('Thought'),
        _text('Answer'),
      ]);
    });

    test('replaces list thinking parts instead of returning the list', () {
      final old = {
        'type': 'thinking',
        'thinking': [
          {'type': 'text', 'text': 'Old'},
        ],
        'closed': true,
        'signature': 'sig',
      };
      expect(
        mistralAssistantContentWithThinking([old, _text('Answer')], 'New'),
        [_thinking('New'), _text('Answer')],
      );
    });

    test('drops thinking and reasoning parts when replay is disabled', () {
      expect(
        mistralAssistantContentWithoutThinking([
          _thinking('Old'),
          {'type': 'reasoning', 'text': 'Older'},
          _text('Answer'),
        ]),
        [_text('Answer')],
      );
      expect(mistralAssistantContentWithoutThinking([_thinking('Old')]), '');
      expect(mistralAssistantContentWithoutThinking('Answer'), 'Answer');
    });
  });

  group('openaiReasoningText', () {
    test('keeps the scalar echo', () {
      expect(openaiReasoningText({'reasoning_content': 'Plain'}), 'Plain');
      expect(openaiReasoningText({'reasoning': 'Plain'}), 'Plain');
    });

    test('reads typed thinking parts from a non-stream body', () {
      expect(
        openaiReasoningText({
          'content': [_thinking('Typed thought'), _text('Answer')],
        }),
        'Typed thought',
      );
    });

    test('prefers the scalar echo when both are present', () {
      expect(
        openaiReasoningText({
          'reasoning_content': 'Scalar',
          'content': [_thinking('Typed'), _text('Answer')],
        }),
        'Scalar',
      );
    });

    test('returns null without reasoning', () {
      expect(openaiReasoningText(null), isNull);
      expect(openaiReasoningText({'content': 'Answer'}), isNull);
      expect(
        openaiReasoningText({
          'content': [_text('Answer')],
        }),
        isNull,
      );
    });
  });

  group('openaiVisibleOutputFromMessage', () {
    test('joins typed text parts and ignores thinking', () {
      final visible = openaiVisibleOutputFromMessage({
        'content': [_thinking('Thought'), _text('Answer')],
      });

      expect(visible.content, 'Answer');
      expect(visible.images, isEmpty);
    });

    test('still collects image parts', () {
      final visible = openaiVisibleOutputFromMessage({
        'content': [
          _text('Answer'),
          {
            'type': 'image_url',
            'image_url': {'url': 'https://example.com/a.png'},
          },
        ],
      });

      expect(visible.content, 'Answer');
      expect(visible.images, hasLength(1));
      expect(visible.images.single.mimeType, 'image/png');
    });
  });
}
