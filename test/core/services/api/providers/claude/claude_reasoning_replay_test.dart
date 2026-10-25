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

String _thinkingRound() => sseRound('m1', [
  {
    'type': 'content_block_start',
    'index': 0,
    'content_block': {'type': 'thinking', 'thinking': '', 'signature': ''},
  },
  {
    'type': 'content_block_delta',
    'index': 0,
    'delta': {'type': 'thinking_delta', 'thinking': _thinking['thinking']},
  },
  for (final signature in ['opaque-', 'signature'])
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
  {
    'type': 'message_delta',
    'delta': {'stop_reason': 'end_turn'},
  },
  {'type': 'message_stop'},
]);

void main() {
  for (final deepseek in [false, true]) {
    final modelId = deepseek ? 'deepseek-flash' : 'claude-sonnet-4-6';
    final config = deepseek ? deepSeekClaudeConfig() : claudeConfig();
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
