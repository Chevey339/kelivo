import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_thinking_recovery.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

import '../../../../../support/claude_test_api.dart';

Map<String, dynamic> _thinking(String signature) => {
  'type': 'thinking',
  'thinking': '',
  'signature': signature,
};

Map<String, dynamic> _assistant(String signature, String text) => {
  'role': 'assistant',
  'content': text,
  multimodalInternalClaudeTurnKey: encodeClaudeTurn([
    [
      _thinking(signature),
      {'type': 'text', 'text': text},
    ],
  ]),
};

List<Map<String, dynamic>> _history() => [
  {'role': 'user', 'content': 'First question'},
  _assistant('first', 'First answer'),
  {'role': 'user', 'content': 'Edited second question'},
  {
    ..._assistant('second', 'Second answer'),
    multimodalInternalClaudeTurnKey: encodeClaudeTurn([
      [
        _thinking('second'),
        {'type': 'redacted_thinking', 'data': 'redacted-second'},
        {'type': 'text', 'text': 'Second answer'},
      ],
    ]),
  },
  {'role': 'user', 'content': 'Continue'},
];

String _error(String path, {bool prefixMismatch = true}) => jsonEncode({
  'type': 'error',
  'error': {
    'type': 'invalid_request_error',
    'message':
        '$path: Invalid `signature` in `thinking` block.'
        '${prefixMismatch ? ' The block is bound to a different conversation. Remove the block.' : ''}',
  },
});

http.Response _answer({String signature = 'fresh', bool stream = false}) {
  if (!stream) {
    return http.Response(
      jsonEncode({
        'content': [
          _thinking(signature),
          {'type': 'text', 'text': 'New answer'},
        ],
        'stop_reason': 'end_turn',
      }),
      200,
    );
  }
  return http.Response(
    sseRound('fresh', [
      {
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'thinking', 'thinking': '', 'signature': ''},
      },
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
        'delta': {'type': 'text_delta', 'text': 'New answer'},
      },
      {'type': 'content_block_stop', 'index': 1},
      {
        'type': 'message_delta',
        'delta': {'stop_reason': 'end_turn'},
      },
      {'type': 'message_stop'},
    ]),
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

Future<
  ({List<Map<String, dynamic>> bodies, List<StreamChunk> chunks, Object? error})
>
_run({
  required List<Map<String, dynamic>> messages,
  required http.Response Function(int, Map<String, dynamic>) reply,
  bool stream = false,
  Map<String, dynamic>? extraBody,
  bool withTool = false,
  void Function()? onTool,
}) async {
  final bodies = <Map<String, dynamic>>[];
  final chunks = <StreamChunk>[];
  final client = MockClient((request) async {
    final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
    bodies.add(body);
    expect(request.headers.containsKey('anthropic-beta'), isFalse);
    expect(jsonEncode(body), isNot(contains('_kelivo_')));
    return reply(bodies.length, body);
  });
  addTearDown(client.close);
  Object? error;
  try {
    await for (final chunk in sendClaudeStream(
      client,
      claudeConfig(),
      'claude-fable-5-1',
      messages,
      stream: stream,
      extraBody: extraBody,
      tools: withTool
          ? [
              {
                'type': 'function',
                'function': {
                  'name': 'create_memory',
                  'parameters': {'type': 'object'},
                },
              },
            ]
          : null,
      onToolCall: withTool
          ? (name, args, {toolCallId}) async {
              onTool?.call();
              return 'saved';
            }
          : null,
    )) {
      chunks.add(chunk);
    }
  } catch (e) {
    error = e;
  }
  return (bodies: bodies, chunks: chunks, error: error);
}

List<Map> _thinkingBlocks(Map body) => [
  for (final message in body['messages'] as List)
    if (message['content'] is List)
      for (final block in message['content'] as List)
        if (block['type'] == 'thinking' || block['type'] == 'redacted_thinking')
          block as Map,
];

String _artifact(List<StreamChunk> chunks, String kind) => chunks
    .whereType<ProviderArtifact>()
    .lastWhere((chunk) => chunk.kind == kind)
    .payload;

void main() {
  for (final stream in [false, true]) {
    test(
      'repairs only the rejected suffix and resumes: stream=$stream',
      () async {
        final messages = _history();
        final original = jsonEncode(messages);
        final first = await _run(
          messages: messages,
          stream: stream,
          reply: (round, _) => round == 1
              ? http.Response(_error('messages.3.content.0'), 400)
              : _answer(stream: stream),
        );
        expect(first.error, isNull);
        expect(first.bodies, hasLength(2));
        expect(_thinkingBlocks(first.bodies.first), hasLength(3));
        expect(_thinkingBlocks(first.bodies.last), [_thinking('first')]);
        expect((first.bodies.last['messages'] as List)[3], {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'Second answer'},
          ],
        });
        expect(jsonEncode(messages), original);
        final recovery = _artifact(
          first.chunks,
          claudeThinkingRecoveryArtifactKind,
        );
        expect(jsonDecode(recovery), hasLength(2));
        expect(recovery, isNot(contains('redacted-second')));

        final next = await _run(
          messages: [
            ...messages,
            {
              'role': 'assistant',
              'content': 'New answer',
              multimodalInternalClaudeTurnKey: _artifact(
                first.chunks,
                claudeTurnArtifactKind,
              ),
            },
            {
              'role': 'user',
              'content': 'Another question',
              multimodalInternalClaudeThinkingRecoveryKey: recovery,
            },
          ],
          reply: (_, _) => _answer(signature: 'newest'),
        );
        expect(next.error, isNull);
        expect(next.bodies, hasLength(1));
        expect(_thinkingBlocks(next.bodies.single), [
          _thinking('first'),
          _thinking('fresh'),
        ]);
        expect(
          _artifact(next.chunks, claudeThinkingRecoveryArtifactKind),
          recovery,
        );
      },
    );
  }

  for (final edit in ['user', 'assistant', 'truncate', 'system', 'tools']) {
    test(
      'recovers after editing $edit without changing the edited input',
      () async {
        final messages = _history();
        Map<String, dynamic>? extra;
        var path = 'messages.1.content.0';
        switch (edit) {
          case 'user':
            messages.first['content'] = 'Edited first question';
          case 'assistant':
            messages[1]['content'] = 'Edited first answer';
            path = 'messages.3.content.0';
          case 'truncate':
            messages.removeRange(0, 2);
          case 'system':
            messages.insert(0, {'role': 'system', 'content': 'Changed system'});
          case 'tools':
            extra = {
              'tools': [
                {
                  'name': 'new_tool',
                  'input_schema': {'type': 'object'},
                },
              ],
            };
        }
        final run = await _run(
          messages: messages,
          extraBody: extra,
          reply: (round, _) =>
              round == 1 ? http.Response(_error(path), 400) : _answer(),
        );
        expect(run.error, isNull);
        expect(run.bodies, hasLength(2));
        expect(_thinkingBlocks(run.bodies.last), isEmpty);
        expect(
          {...run.bodies.last}..remove('messages'),
          {...run.bodies.first}..remove('messages'),
        );
        expect(
          (run.bodies.last['messages'] as List).last['content'],
          'Continue',
        );
        if (edit == 'assistant') {
          expect(
            (run.bodies.last['messages'] as List)[1]['content'],
            'Edited first answer',
          );
        }
        if (edit == 'user') {
          expect(
            (run.bodies.last['messages'] as List).first['content'],
            'Edited first question',
          );
        }
      },
    );
  }

  test(
    'a recovery keeps tool pairs and executes the new call only once',
    () async {
      var toolCalls = 0;
      final run = await _run(
        messages: _history(),
        withTool: true,
        onTool: () => toolCalls++,
        reply: (round, _) => switch (round) {
          1 => http.Response(_error('messages.3.content.0'), 400),
          2 => http.Response(
            jsonEncode({
              'content': [
                _thinking('tool-round'),
                clientCall('call1', 'remember'),
              ],
              'stop_reason': 'tool_use',
            }),
            200,
          ),
          _ => _answer(),
        },
      );
      expect(run.error, isNull);
      expect(run.bodies, hasLength(3));
      expect(toolCalls, 1);
      expect(_thinkingBlocks(run.bodies.last), [
        _thinking('first'),
        _thinking('tool-round'),
      ]);
      final messages = run.bodies.last['messages'] as List;
      expect(messages[messages.length - 2]['content'], [
        _thinking('tool-round'),
        clientCall('call1', 'remember'),
      ]);
      expect(messages.last['content'], [
        {'type': 'tool_result', 'tool_use_id': 'call1', 'content': 'saved'},
      ]);
    },
  );

  test(
    'redacted failure keeps preceding thinking in the same response',
    () async {
      final run = await _run(
        messages: _history(),
        reply: (round, _) => round == 1
            ? http.Response(_error('messages.3.content.1'), 400)
            : _answer(),
      );
      expect(run.error, isNull);
      expect(run.bodies, hasLength(2));
      expect(_thinkingBlocks(run.bodies.last), [
        _thinking('first'),
        _thinking('second'),
      ]);
    },
  );

  test('an edited tool result keeps the tool pair during recovery', () async {
    final run = await _run(
      messages: [
        {'role': 'user', 'content': 'Remember'},
        storedTurn(
          [
            [_thinking('before-tool'), clientCall('old-call', 'remember')],
            [
              _thinking('after-tool'),
              {'type': 'text', 'text': 'Saved'},
            ],
          ],
          [card('old-call', 'create_memory')],
        ),
        toolResult('old-call', 'create_memory', 'Edited tool result'),
        {'role': 'assistant', 'content': 'Saved'},
        {'role': 'user', 'content': 'Continue'},
      ],
      reply: (round, _) => round == 1
          ? http.Response(_error('messages.3.content.0'), 400)
          : _answer(),
    );
    expect(run.error, isNull);
    expect(run.bodies, hasLength(2));
    expect(_thinkingBlocks(run.bodies.last), [_thinking('before-tool')]);
    final messages = run.bodies.last['messages'] as List;
    expect(messages[1]['content'], [
      _thinking('before-tool'),
      clientCall('old-call', 'remember'),
    ]);
    expect(messages[2]['content'], [
      {
        'type': 'tool_result',
        'tool_use_id': 'old-call',
        'content': 'Edited tool result',
      },
    ]);
    expect(messages[3]['content'], [
      {'type': 'text', 'text': 'Saved'},
    ]);
  });

  test(
    'error locations refer to custom messages and empty thinking turns vanish',
    () async {
      final custom = [
        {'role': 'user', 'content': 'Custom question'},
        {
          'role': 'assistant',
          'content': [_thinking('custom')],
        },
        {'role': 'user', 'content': 'Continue'},
      ];
      final before = jsonEncode(custom);
      final run = await _run(
        messages: _history(),
        extraBody: {'messages': custom},
        reply: (round, _) => round == 1
            ? http.Response(_error('messages.1.content.0'), 400)
            : _answer(),
      );
      expect(run.error, isNull);
      expect(run.bodies, hasLength(2));
      expect(run.bodies.last['messages'], [custom.first, custom.last]);
      expect(jsonEncode(custom), before);
    },
  );

  for (final failure in [
    'signature',
    'bad-path',
    'non-thinking',
    'non-json',
    'auth',
    'server',
  ]) {
    test('does not suppress an unrelated $failure error', () async {
      final response = switch (failure) {
        'signature' => http.Response(
          _error('messages.3.content.0', prefixMismatch: false),
          400,
        ),
        'bad-path' => http.Response(_error('messages.99.content.0'), 400),
        'non-thinking' => http.Response(_error('messages.1.content.1'), 400),
        'non-json' => http.Response('gateway failed', 400),
        'auth' => http.Response(_error('messages.3.content.0'), 401),
        _ => http.Response(_error('messages.3.content.0'), 500),
      };
      final run = await _run(messages: _history(), reply: (_, _) => response);
      expect(run.error, isA<HttpException>());
      expect(run.bodies, hasLength(1));
      expect(run.chunks.whereType<ProviderArtifact>(), isEmpty);
    });
  }

  test('retries once and saves recovery even when the retry fails', () async {
    final run = await _run(
      messages: _history(),
      reply: (_, _) => http.Response(_error('messages.3.content.0'), 400),
    );
    expect(run.error, isA<HttpException>());
    expect(run.bodies, hasLength(2));
    expect(
      jsonDecode(_artifact(run.chunks, claudeThinkingRecoveryArtifactKind)),
      hasLength(2),
    );
  });
}
