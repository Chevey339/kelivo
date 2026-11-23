import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/openai/deepseek_server_tool_history.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ProviderConfig _config(String url, {String id = 'deepseek-test'}) =>
    ProviderConfig(
      id: id,
      enabled: true,
      name: 'DeepSeek',
      apiKey: 'test',
      baseUrl: url,
      providerType: ProviderKind.openai,
    );

void main() {
  const model = 'deepseek-flash';
  const official = 'https://api.deepseek.com';
  const blocks = [
    {
      'reasoning_content': 'Read the link',
      'calls': [
        {
          'id': 'srv_read',
          'kind': 'read_link',
          'signature': 'opaque+signed/page==',
        },
      ],
    },
  ];

  for (final streaming in [false, true]) {
    test('replays the signed assistant field (streaming: $streaming)', () async {
      final cfg = _config(official);
      final requests = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        final assistant = {
          'content': 'Page summary',
          'server_tool_calls': blocks,
        };
        Map<String, Object> response(String field, Map<String, Object> value) =>
            {
              'choices': [
                {'index': 0, 'finish_reason': 'stop', field: value},
              ],
            };
        return streaming
            ? http.Response(
                'data: ${jsonEncode(response('delta', assistant))}\n\ndata: [DONE]\n\n',
                200,
                headers: {'content-type': 'text/event-stream'},
              )
            : http.Response(jsonEncode(response('message', assistant)), 200);
      });
      addTearDown(client.close);
      final first = await sendOpenAIStream(client, cfg, model, [
        {'role': 'user', 'content': 'Read the page'},
      ], stream: streaming).toList();
      final artifact = first.whereType<ProviderArtifact>().single;
      expect(artifact.kind, deepSeekServerToolArtifactKind);
      final history = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'Read the page'},
        {
          'role': 'assistant',
          'content': 'Page summary',
          deepSeekServerToolHistoryKey: artifact.payload,
        },
        {'role': 'user', 'content': 'More detail?'},
      ];
      await sendOpenAIStream(
        client,
        cfg,
        model,
        history,
        stream: streaming,
      ).drain<void>();
      final sameProvider = (requests.last['messages'] as List)[1] as Map;
      expect(sameProvider['server_tool_calls'], blocks);
      expect(sameProvider, isNot(contains(deepSeekServerToolHistoryKey)));

      for (final (other, otherModel) in [
        (_config('https://relay.example/v1'), model),
        (_config(official, id: 'different-provider'), model),
        (cfg, 'deepseek-v4-pro'),
      ]) {
        await sendOpenAIStream(
          client,
          other,
          otherModel,
          history,
          stream: streaming,
        ).drain<void>();
        final assistant = (requests.last['messages'] as List)[1] as Map;
        expect(assistant, isNot(contains('server_tool_calls')));
        expect(assistant, isNot(contains(deepSeekServerToolHistoryKey)));
      }
    });
  }

  test('keeps server blocks on their matching client tool round', () {
    final cfg = _config(official);
    final recorder = DeepSeekServerToolRecorder(cfg, model);
    recorder.record(blocks, clientCallId: 'client-1');
    final finalRound = [
      {
        'calls': [
          {'id': 'different'},
        ],
      },
    ];
    final artifact = recorder.record(finalRound)!;
    expect(
      replayDeepSeekServerToolCalls(artifact.payload, cfg, model, [
        {'id': 'client-1'},
      ]),
      blocks,
    );
    expect(
      replayDeepSeekServerToolCalls(artifact.payload, cfg, model, [
        {'id': 'unrelated'},
      ]),
      isNull,
    );
    expect(
      replayDeepSeekServerToolCalls(artifact.payload, cfg, model, null),
      finalRound,
    );
  });
}
