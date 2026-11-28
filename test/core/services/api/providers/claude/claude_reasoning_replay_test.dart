import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

import '../../../../../support/claude_test_api.dart';

const _thinking = {
  'type': 'thinking',
  'thinking': ' original reasoning\n',
  'signature': 'opaque-signature',
};
const _text = {'type': 'text', 'text': 'First answer.'};
const _tools = [
  {
    'type': 'function',
    'function': {
      'name': 'create_memory',
      'parameters': {'type': 'object', 'properties': {}},
    },
  },
];

String _thinkingRound({
  bool signatureAtStart = false,
  bool toolCall = false,
  List<Map<String, dynamic>>? ending,
}) => sseRound('m1', [
  {
    'type': 'content_block_start',
    'index': 0,
    'content_block': {
      'type': 'thinking',
      'thinking': '',
      'signature': signatureAtStart ? _thinking['signature'] : '',
    },
  },
  {
    'type': 'content_block_delta',
    'index': 0,
    'delta': {'type': 'thinking_delta', 'thinking': _thinking['thinking']},
  },
  for (final signature
      in signatureAtStart ? <String>[] : ['opaque-', 'signature'])
    {
      'type': 'content_block_delta',
      'index': 0,
      'delta': {'type': 'signature_delta', 'signature': signature},
    },
  {'type': 'content_block_stop', 'index': 0},
  {
    'type': 'content_block_start',
    'index': 1,
    'content_block': {'type': 'text', 'text': ''},
  },
  {
    'type': 'content_block_delta',
    'index': 1,
    'delta': {'type': 'text_delta', 'text': _text['text']},
  },
  {'type': 'content_block_stop', 'index': 1},
  if (toolCall) ...[
    {
      'type': 'content_block_start',
      'index': 2,
      'content_block': {
        'type': 'tool_use',
        'id': 'call1',
        'name': 'create_memory',
        'input': {},
      },
    },
    {
      'type': 'content_block_delta',
      'index': 2,
      'delta': {
        'type': 'input_json_delta',
        'partial_json': '{"content":"remember"}',
      },
    },
    {'type': 'content_block_stop', 'index': 2},
  ],
  ...ending ??
      [
        {
          'type': 'message_delta',
          'delta': {'stop_reason': toolCall ? 'tool_use' : 'end_turn'},
        },
        {'type': 'message_stop'},
      ],
]);

void main() {
  test('block-start signature survives a streamed tool continuation', () async {
    var toolsExecuted = 0;
    final exchange = await captureClaudeExchange(
      modelId: 'claude-sonnet-4-6',
      stream: true,
      tools: _tools,
      onToolCall: (name, args, {toolCallId}) async {
        toolsExecuted++;
        return 'saved';
      },
      sseRounds: [
        _thinkingRound(signatureAtStart: true, toolCall: true),
        plainRound,
      ],
    );
    expect(toolsExecuted, 1);
    expect(exchange.bodies, hasLength(2));
    expect((exchange.bodies.last['messages'] as List)[1]['content'], [
      _thinking,
      _text,
      clientCall('call1', 'remember'),
    ]);
    final artifact = exchange.chunks.whereType<ProviderArtifact>().firstWhere(
      (chunk) => chunk.kind == claudeTurnArtifactKind,
    );
    expect(decodeClaudeTurn(artifact.payload)!.first.first, _thinking);
  });

  for (final (backend, config, model, requiresSignature) in [
    (
      'Anthropic',
      claudeConfig(baseUrl: officialBaseUrl),
      'claude-sonnet-4-6',
      true,
    ),
    ('Vertex', vertexClaudeConfig(), 'claude-sonnet-4-6@20260217', true),
    ('compatible', deepSeekClaudeConfig(), 'deepseek-flash', false),
  ]) {
    for (final eof in [false, true]) {
      test(
        '$backend replays a truncated tool round with a result, eof=$eof',
        () async {
          final exchange = await captureClaudeExchange(
            config: config,
            modelId: model,
            stream: true,
            tools: _tools,
            onToolCall: (name, args, {toolCallId}) async => 'saved',
            sseRounds: [
              _thinkingRound(
                toolCall: true,
                ending: [
                  {
                    'type': 'content_block_start',
                    'index': 3,
                    'content_block': {'type': 'thinking', 'thinking': ''},
                  },
                  {
                    'type': 'content_block_delta',
                    'index': 3,
                    'delta': {
                      'type': 'thinking_delta',
                      'thinking': 'unfinished',
                    },
                  },
                  if (!eof) ...[
                    {'type': 'content_block_stop', 'index': 3},
                    {
                      'type': 'message_delta',
                      'delta': {'stop_reason': 'max_tokens'},
                    },
                    {'type': 'message_stop'},
                  ],
                ],
              ),
              plainRound,
            ],
          );
          final artifact = exchange.chunks
              .whereType<ProviderArtifact>()
              .firstWhere((chunk) => chunk.kind == claudeTurnArtifactKind);
          final recorded = decodeClaudeTurn(artifact.payload)!;
          final unsigned = recorded.single.last;
          expect(unsigned['type'], 'thinking');
          expect(unsigned['signature'], '');
          // A closed block has its full text even if no signature arrived.
          if (!eof) expect(unsigned['thinking'], 'unfinished');
          final replay = await captureClaudeRequestBody(
            config: config,
            modelId: model,
            messages: [
              {'role': 'user', 'content': 'hello'},
              storedTurn(recorded, [card('call1', 'create_memory')]),
              toolResult('call1', 'create_memory', 'saved'),
              {'role': 'assistant', 'content': _text['text']},
              {'role': 'user', 'content': 'Continue.'},
            ],
          );
          expect(exchange.bodies, hasLength(2));
          for (final body in [exchange.bodies.last, replay]) {
            final messages = body['messages'] as List;
            expect(messages[1]['content'], [
              _thinking,
              _text,
              clientCall('call1', 'remember'),
              if (!requiresSignature) unsigned,
            ]);
            expect(messages[2]['content'], [
              {
                'type': 'tool_result',
                'tool_use_id': 'call1',
                'content': 'saved',
              },
            ]);
          }
        },
      );
    }
  }

  test(
    'a pause with only unsigned thinking cannot resume an empty turn',
    () async {
      final exchange = await captureClaudeExchange(
        config: claudeConfig(baseUrl: officialBaseUrl),
        modelId: 'claude-sonnet-4-6',
        tools: _tools,
        replies: const [
          {
            'content': [
              {'type': 'thinking', 'thinking': 'missing'},
              {'type': 'thinking', 'thinking': 'blank', 'signature': '  '},
            ],
            'stop_reason': 'pause_turn',
          },
          {
            'content': [_text],
            'stop_reason': 'end_turn',
          },
        ],
      );
      expect(exchange.bodies, hasLength(1));
    },
  );

  for (final backend in ['claude', 'deepseek', 'vertex']) {
    final deepseek = backend == 'deepseek';
    final vertex = backend == 'vertex';
    final modelId = vertex
        ? 'claude-sonnet-4-6@20260217'
        : deepseek
        ? 'deepseek-flash'
        : 'claude-sonnet-4-6';
    final config = vertex
        ? vertexClaudeConfig()
        : deepseek
        ? deepSeekClaudeConfig()
        : claudeConfig();
    for (final stream in [false, true]) {
      test('records a no-tool response: $modelId, stream=$stream', () async {
        final exchange = await captureClaudeExchange(
          config: config,
          modelId: modelId,
          stream: stream,
          replies: const [
            {
              'content': [_thinking, _text],
              'stop_reason': 'end_turn',
            },
          ],
          sseRounds: stream ? [_thinkingRound()] : null,
        );
        final artifact = exchange.chunks.whereType<ProviderArtifact>().where(
          (chunk) => chunk.kind == claudeTurnArtifactKind,
        );
        expect(artifact, hasLength(1));
        expect(decodeClaudeTurn(artifact.single.payload), [
          [_thinking, _text],
        ]);
      });
    }

    test('default replays a no-tool thinking block: $modelId', () async {
      final body = await captureClaudeRequestBody(
        config: config,
        modelId: modelId,
        messages: [
          {'role': 'user', 'content': 'First question.'},
          {
            'role': 'assistant',
            'content': 'First answer.',
            multimodalInternalClaudeTurnKey: encodeClaudeTurn([
              [_thinking, _text],
            ]),
          },
          {'role': 'user', 'content': 'Next question.'},
        ],
      );
      expect((body['messages'] as List)[1], {
        'role': 'assistant',
        'content': [_thinking, _text],
      });
      expect(jsonEncode(body), isNot(contains('_kelivo_')));
    });
  }

  for (final policy in ReasoningReplayPolicy.values) {
    for (final hadTools in [false, true]) {
      test(
        'explicit $policy filters thinking only, hadTools=$hadTools',
        () async {
          const redacted = {'type': 'redacted_thinking', 'data': 'opaque-data'};
          final blocks = <Map<String, dynamic>>[
            _thinking,
            redacted,
            if (hadTools) clientCall('call1', 'remember'),
            _text,
          ];
          final body = await captureClaudeRequestBody(
            config: claudeConfig(
              modelOverrides: {
                'claude-sonnet-4-6': {
                  'reasoning': {'replay': policy.name},
                },
              },
            ),
            modelId: 'claude-sonnet-4-6',
            messages: [
              {'role': 'user', 'content': 'First question.'},
              if (hadTools) ...[
                storedTurn([blocks], [card('call1', 'create_memory')]),
                toolResult('call1', 'create_memory', 'saved'),
                {'role': 'assistant', 'content': 'First answer.'},
              ] else
                {
                  'role': 'assistant',
                  'content': 'First answer.',
                  multimodalInternalClaudeTurnKey: encodeClaudeTurn([blocks]),
                },
              {'role': 'user', 'content': 'Next question.'},
            ],
          );
          final history = body['messages'] as List;
          final keep =
              policy == ReasoningReplayPolicy.all ||
              (policy == ReasoningReplayPolicy.toolTurns && hadTools);
          expect(history[1]['content'], [
            if (keep) ...[_thinking, redacted],
            if (hadTools) clientCall('call1', 'remember'),
            _text,
          ]);
          if (hadTools) {
            expect(history[2]['content'], [
              {
                'type': 'tool_result',
                'tool_use_id': 'call1',
                'content': 'saved',
              },
            ]);
          }
        },
      );
    }
  }

  test(
    'an edited ordinary reply does not restore its original blocks',
    () async {
      final body = await captureClaudeRequestBody(
        modelId: 'claude-sonnet-4-6',
        messages: [
          {'role': 'user', 'content': 'First question.'},
          {
            'role': 'assistant',
            'content': 'Edited answer.',
            multimodalInternalClaudeTurnKey: encodeClaudeTurn([
              [_thinking, _text],
            ]),
          },
          {'role': 'user', 'content': 'Next question.'},
        ],
      );
      expect((body['messages'] as List)[1], {
        'role': 'assistant',
        'content': 'Edited answer.',
      });
    },
  );

  for (final policy in [
    ReasoningReplayPolicy.none,
    ReasoningReplayPolicy.toolTurns,
  ]) {
    test(
      'current tool continuation keeps required thinking with $policy',
      () async {
        final call = clientCall('call1', 'remember');
        final exchange = await captureClaudeExchange(
          config: claudeConfig(
            modelOverrides: {
              'claude-sonnet-4-6': {
                'reasoning': {'replay': policy.name},
              },
            },
          ),
          modelId: 'claude-sonnet-4-6',
          tools: const [
            {
              'type': 'function',
              'function': {
                'name': 'create_memory',
                'parameters': {
                  'type': 'object',
                  'properties': <String, dynamic>{},
                },
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async => 'saved',
          replies: [
            {
              'content': [_thinking, call],
              'stop_reason': 'tool_use',
            },
            {
              'content': [_thinking, _text],
              'stop_reason': 'end_turn',
            },
          ],
        );
        expect(exchange.bodies, hasLength(2));
        expect((exchange.bodies.last['messages'] as List)[1]['content'], [
          _thinking,
          call,
        ]);
      },
    );
  }
}
