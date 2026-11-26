import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/services/api/native_compaction_context.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/carried_original.dart';
import 'package:Kelivo/core/models/native_compaction.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_request.dart';
import 'package:Kelivo/core/services/api/providers/openai/native_compaction.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/providers/google_gemini.dart';
import 'package:Kelivo/core/services/api/request_history_context.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final user = textWire('user', 'earlier user');
  const compact = {'type': 'compaction', 'encrypted_content': 'opaque'};
  final nativeConfig = ProviderConfig(
    id: 'codex',
    name: 'Codex',
    enabled: true,
    providerType: ProviderKind.openai,
    oauthProvider: OAuthProvider.chatgpt,
    baseUrl: OAuthProvider.chatgpt.baseUrl,
    apiKey: 'test',
  );
  test(
    'Codex exact frozen wire, reply, compaction and tail survive replay',
    () async {
      final payload = NativeCompactionPayload(
        protocol: NativeCompactionProtocol.codex,
        scope: nativeCompactionScope(nativeConfig),
        modelId: 'test',
        output: [compact],
      );
      final body = await buildOpenAIResponsesBody(
        nativeResponsesConfig(nativeConfig),
        'test',
        RequestHistoryContext.identify([
          {
            'role': 'user',
            'content': 'earlier user',
            carriedWireKey: user,
            imageContextOwnerKey: '${carriedPrefix}op:source',
          },
          {
            'role': 'assistant',
            'content': 'earlier reply',
            imageContextOwnerKey: '${carriedReplyPrefix}op:source',
          },
          {
            'role': 'user',
            'content': '',
            nativeCompactionMessageKey: payload.toJson(),
            imageContextOwnerKey: 'context-summary:op',
          },
          {'role': 'user', 'content': 'tail', imageContextOwnerKey: 'tail'},
        ]),
      );
      final input = RequestHistoryContext.stripSources(body)['input'] as List;
      expect(input.first, user);
      expect(input[1]['role'], 'assistant');
      expect(input[1]['content'], [
        {'type': 'output_text', 'text': 'earlier reply'},
      ]);
      expect(input[2], compact);
      expect(input.last['content'], 'tail');
      final retained = await retainCodexUsers(body['input'] as List);
      expect(retained.map((r) => carriedWireText(r.wire)), [
        'earlier user',
        'tail',
      ]);
      final none = await requestNativeCompaction(
        MockClient(
          (r) async => http.Response(
            'data: ${jsonEncode({'type': 'response.output_item.done', 'output_index': 0, 'item': compact})}\n\n'
            'data: ${jsonEncode({
              'type': 'response.completed',
              'response': {'status': 'completed'},
            })}\n\n',
            200,
          ),
        ),
        nativeConfig,
        'test',
        body,
        retention: NativeUserRetention.none,
      );
      expect(none.retained, isEmpty);
      expect(none.payload.output, [compact]);
    },
  );
  for (final kind in [ProviderKind.claude, ProviderKind.google]) {
    test(
      '$kind keeps consecutive carried user, summary and tail in order',
      () async {
        late Map<String, dynamic> sent;
        final client = MockClient((r) async {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              kind == ProviderKind.claude
                  ? {
                      'id': 'response',
                      'type': 'message',
                      'role': 'assistant',
                      'content': [
                        {'type': 'text', 'text': 'done'},
                      ],
                      'stop_reason': 'end_turn',
                      'usage': {'input_tokens': 10, 'output_tokens': 1},
                    }
                  : {
                      'candidates': [
                        {
                          'content': {
                            'role': 'model',
                            'parts': [
                              {'text': 'done'},
                            ],
                          },
                          'finishReason': 'STOP',
                        },
                      ],
                    },
            ),
            200,
          );
        });
        addTearDown(client.close);
        final config = ProviderConfig(
          id: kind.name,
          name: kind.name,
          enabled: true,
          providerType: kind,
          baseUrl: 'https://example.test/v1',
          apiKey: 'test',
        );
        final messages = [
          for (final t in [
            'carried original',
            'history summary',
            'recent tail',
          ])
            {'role': 'user', 'content': t},
        ];
        if (kind == ProviderKind.claude) {
          await sendClaudeStream(
            client,
            config,
            'claude-sonnet-4-20250514',
            messages,
            stream: false,
          ).toList();
        } else {
          await sendGoogleGeminiStream(
            client,
            config,
            'gemini-3.8-flash',
            messages,
            stream: false,
          ).toList();
        }
        final entries =
            sent[kind == ProviderKind.claude ? 'messages' : 'contents'] as List;
        final serialized = jsonEncode(entries);
        expect(
          serialized.indexOf('carried original'),
          lessThan(serialized.indexOf('history summary')),
        );
        expect(
          serialized.indexOf('history summary'),
          lessThan(serialized.indexOf('recent tail')),
        );
        for (final text in [
          'carried original',
          'history summary',
          'recent tail',
        ]) {
          expect(text.allMatches(serialized), hasLength(1));
        }
      },
    );
  }
}
