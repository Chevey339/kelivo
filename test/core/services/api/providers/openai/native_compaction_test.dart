import 'package:Kelivo/core/models/request_budget.dart';
import 'dart:convert';
import 'dart:io';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/native_compaction.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/native_compaction_context.dart';
import 'package:Kelivo/core/services/api/providers/openai/native_compaction.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_request.dart';
import 'package:Kelivo/core/services/api/request_history_context.dart';
import 'package:Kelivo/core/services/auth/codex_request.dart';

void main() {
  final config = ProviderConfig(
    id: 'my relay',
    name: 'My relay',
    enabled: true,
    apiKey: 'test',
    baseUrl: 'https://relay.example/custom/v3?route=mine',
    useResponseApi: false,
    models: const ['my-private-model'],
  );
  final output = <Map<String, dynamic>>[
    {
      'type': 'message',
      'id': 'kept',
      'role': 'user',
      'content': [
        {'type': 'input_text', 'text': 'original'},
        {'type': 'input_image', 'image_url': 'data:image/png;base64,YWJj'},
      ],
    },
    {
      'type': 'compaction',
      'id': 'cmp',
      'encrypted_content': 'opaque',
      'vendor_field': {
        'nested': [1, 2],
      },
    },
    {
      'type': 'future_native_item',
      'id': 'unknown',
      'extra': {'keep': true},
    },
  ];
  final prepared = <String, dynamic>{
    'model': 'my-private-model',
    'instructions': 'same system prompt',
    'input': [
      {'role': 'user', 'content': 'earlier', historySourceKey: 'u1'},
      {
        'type': 'function_call',
        'call_id': 'tool-1',
        'name': 'read',
        'arguments': '{}',
      },
      {'type': 'function_call_output', 'call_id': 'tool-1', 'output': 'answer'},
    ],
    'stream': false,
    'tools': [
      {'type': 'function', 'name': 'read'},
    ],
  };

  test(
    'native plaintext images obey all hard budgets without rewriting the window',
    () async {
      final body = <String, dynamic>{
        'input': [
          {...output.first, nativeCompactionWireKey: true},
          {...output.first, nativeCompactionWireKey: true},
          {...output[1], nativeCompactionWireKey: true},
        ],
      };
      final original = jsonEncode(body);
      for (final (budget, kind, actual) in [
        (
          const RequestBudget(singleImageBytes: 3),
          ImageContextBudgetKind.singleImage,
          4,
        ),
        (
          const RequestBudget(totalImageBytes: 7),
          ImageContextBudgetKind.totalImages,
          8,
        ),
        (
          const RequestBudget(imageCount: 1),
          ImageContextBudgetKind.imageCount,
          2,
        ),
      ]) {
        final images = RequestImageContext(
          settings: const ImageContextSettings(),
          images: [],
          budget: budget,
        );
        await expectLater(
          images.project(body),
          throwsA(
            isA<ImageContextBudgetException>()
                .having((e) => e.kind, 'kind', kind)
                .having((e) => e.actual, 'actual', actual),
          ),
        );
        expect(jsonEncode(body), original);
      }
      final images = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        budget: const RequestBudget(
          singleImageBytes: 4,
          totalImageBytes: 8,
          imageCount: 2,
        ),
      );
      expect((await images.project(body))['input'], [
        output.first,
        output.first,
        output[1],
      ]);
      expect(jsonEncode(body), original);
    },
  );

  test(
    'manual compact validates added fields in the request budget scope before transport',
    () async {
      var sends = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        sends++;
        await request.drain<void>();
        request.response.write(jsonEncode({'output': output}));
        await request.response.close();
      });
      final images = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        budget: const RequestBudget(bodyBytes: 4096),
      );
      await expectLater(
        ChatApiService.compactHistory(
          config: config.copyWith(
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
            promptCacheKeyEnabled: true,
          ),
          modelId: 'my-private-model',
          messages: [
            {'role': 'user', 'content': 'hi'},
          ],
          requestId: 'manual-budget-check',
          conversationId: 'x' * 8192,
          imageContext: images,
        ),
        throwsA(
          isA<ImageContextBudgetException>()
              .having((e) => e.kind, 'kind', ImageContextBudgetKind.requestBody)
              .having((e) => e.actual, 'final JSON bytes', greaterThan(8192)),
        ),
      );
      expect(sends, 0);
    },
  );

  test(
    'custom relay needs no allowlist and keeps the complete compact output',
    () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'output': output,
            'usage': {'input_tokens': 900, 'output_tokens': 100},
          }),
          200,
        );
      });
      final result = await requestNativeCompaction(
        client,
        config,
        'my-private-model',
        prepared,
      );
      expect(
        sent.url.toString(),
        'https://relay.example/custom/v3/responses/compact?route=mine',
      );
      final body = jsonDecode(sent.body) as Map;
      expect(body['input'], hasLength(3));
      expect(body, isNot(contains('stream')));
      expect(body, isNot(contains('tools')));
      expect(sent.body, isNot(contains(historySourceKey)));
      expect(result.output, output);
      expect(result.usage!.promptTokens, 900);
      final restored = NativeCompactionPayload.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(restored.output, output);
      final replay = await buildOpenAIResponsesBody(
        nativeResponsesConfig(config),
        'my-private-model',
        [
          {
            'role': 'user',
            'content': '',
            nativeCompactionMessageKey: restored.toJson(),
          },
          {'role': 'user', 'content': 'recent unchanged'},
        ],
      );
      final projected = await RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        budget: const RequestBudget(totalImageBytes: 4),
      ).project(replay);
      final input =
          RequestHistoryContext.stripSources(projected)['input'] as List;
      expect(input.take(output.length).toList(), output);
      expect(input.last, containsPair('content', 'recent unchanged'));
      expect(result.output, output);
    },
  );

  test(
    'native output survives tool follow-ups and cannot be replaced by custom input',
    () async {
      final payload = NativeCompactionPayload(
        protocol: NativeCompactionProtocol.compact,
        scope: nativeCompactionScope(config),
        modelId: 'my-private-model',
        output: output,
      );
      final messages = [
        {
          'role': 'user',
          'content': '',
          nativeCompactionMessageKey: payload.toJson(),
        },
        {'role': 'user', 'content': 'recent unchanged'},
      ];
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(
          request.url.toString(),
          'https://relay.example/custom/v3/responses?route=mine',
        );
        final input = (jsonDecode(request.body) as Map)['input'] as List;
        expect(input.take(output.length).toList(), output);
        expect(request.body, isNot(contains(nativeCompactionWireKey)));
        return http.Response(
          jsonEncode({
            'output': requests == 1
                ? [
                    {
                      'type': 'function_call',
                      'call_id': 'live',
                      'name': 'lookup',
                      'arguments': '{}',
                    },
                  ]
                : [
                    {
                      'type': 'message',
                      'role': 'assistant',
                      'content': [
                        {'type': 'output_text', 'text': 'done'},
                      ],
                    },
                  ],
          }),
          200,
        );
      });
      var tools = 0;
      await sendOpenAIStream(
        client,
        nativeResponsesConfig(config),
        'another-model-on-same-connection',
        messages,
        stream: false,
        onToolCall: (name, args, {toolCallId}) async {
          tools++;
          return 'found';
        },
      ).toList();
      expect(requests, 2);
      expect(tools, 1);
      await expectLater(
        sendOpenAIStream(
          client,
          nativeResponsesConfig(config),
          'my-private-model',
          messages,
          stream: false,
          extraBody: {'input': []},
        ).toList(),
        throwsA(
          predicate(
            (Object e) =>
                e.toString().contains('native_compaction_input_overridden'),
          ),
        ),
      );
      expect(requests, 2);
    },
  );

  test(
    'opaque token measurement tracks plain deltas and rejects changed windows',
    () {
      Map<String, dynamic> body(String cipher, String text) => {
        'input': [
          {'type': 'compaction', 'id': 'cmp', 'encrypted_content': cipher},
          {'role': 'user', 'content': text},
        ],
      };
      final first = body('a very long encrypted value', 'hello');
      final anchor = NativeCompactionUsage.record(
        first,
        'connection/model',
        const TokenUsage(promptTokens: 1200),
      )!;
      expect(anchor.estimate(first, 'connection/model'), 1200);
      expect(
        anchor.estimate(
          body('a very long encrypted value', 'more words ' * 100),
          'connection/model',
        ),
        greaterThan(1200),
      );
      expect(
        anchor.estimate(
          body('another opaque window', 'hello'),
          'connection/model',
        ),
        isNull,
      );
      expect(anchor.estimate(first, 'other connection/model'), isNull);
      expect(
        NativeCompactionUsage.record(
          {'input': 'custom input'},
          'connection/model',
          const TokenUsage(promptTokens: 30),
        ),
        isNull,
      );
    },
  );

  test('native state cannot silently replay to another service', () async {
    final payload = NativeCompactionPayload(
      protocol: NativeCompactionProtocol.compact,
      scope: nativeCompactionScope(config),
      modelId: 'my-private-model',
      output: output,
    );
    expect(
      () => validateNativeCompactionScope([
        {nativeCompactionMessageKey: payload.toJson()},
      ], config.copyWith(baseUrl: 'https://different.example/v1')),
      throwsStateError,
    );
  });

  test(
    'invalid successful responses and unsupported endpoints do not create native state',
    () async {
      for (final response in [
        http.Response('<html>proxy login</html>', 200),
        http.Response(
          '{"output":[{"type":"message","role":"assistant","content":[]}]}',
          200,
        ),
        http.Response('not supported', 404),
      ]) {
        final client = MockClient((_) async => response);
        await expectLater(
          requestNativeCompaction(client, config, 'my-private-model', prepared),
          throwsA(anyOf(isA<Exception>(), isA<StateError>())),
        );
      }
    },
  );

  final oauth = ProviderConfig(
    id: 'subscription',
    name: 'Subscription',
    enabled: true,
    oauthProvider: OAuthProvider.chatgpt,
    baseUrl: OAuthProvider.chatgpt.baseUrl,
    apiKey: 'test',
  );
  String event(Map<String, dynamic> value) => 'data: ${jsonEncode(value)}\n\n';
  final compaction = {
    'type': 'compaction',
    'id': 'signed',
    'encrypted_content': 'do-not-change',
  };

  test(
    'Codex compaction trigger is included in the final local body budget',
    () async {
      var sends = 0;
      final client = MockClient((_) async {
        sends++;
        throw StateError('oversized compaction reached transport');
      });
      addTearDown(client.close);
      final rawBytes = utf8
          .encode(jsonEncode(RequestHistoryContext.stripSources(prepared)))
          .length;
      final images = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        budget: RequestBudget(bodyBytes: rawBytes),
      );
      await expectLater(
        images
            .run(
              () => Stream.fromFuture(
                requestNativeCompaction(client, oauth, 'plain-model', prepared),
              ),
            )
            .first,
        throwsA(
          isA<ImageContextBudgetException>()
              .having((e) => e.kind, 'kind', ImageContextBudgetKind.requestBody)
              .having(
                (e) => e.actual,
                'including trigger',
                greaterThan(rawBytes),
              ),
        ),
      );
      expect(sends, 0);
    },
  );

  test(
    'Codex uses a trigger on Responses and requires a completed compaction',
    () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          event({
                'type': 'response.output_item.done',
                'output_index': 0,
                'item': compaction,
              }) +
              event({
                'type': 'response.completed',
                'response': {
                  'status': 'completed',
                  'output': [compaction],
                  'usage': {'input_tokens': 900, 'output_tokens': 100},
                },
              }),
          200,
        );
      });
      final result = await requestNativeCompaction(
        client,
        oauth,
        'custom-codex-model',
        prepared,
      );
      expect(sent.url.toString(), '${OAuthProvider.chatgpt.baseUrl}/responses');
      expect(sent.headers['x-codex-beta-features'], 'remote_compaction_v2');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect((body['input'] as List).last, {'type': 'compaction_trigger'});
      expect(body['stream'], isTrue);
      expect(body['store'], isFalse);
      expect(result.output.last, compaction);
      expect(result.output.first, {'role': 'user', 'content': 'earlier'});
      final continuation = <String, dynamic>{
        'model': 'custom-codex-model',
        'input': result.output,
      };
      applyCodexRequest(continuation, {}, 'opaque-test-token');
      expect((continuation['input'] as List).last, compaction);
    },
  );

  test(
    'Codex retains real users after image projection and accepts response.done',
    () async {
      final body = await buildOpenAIResponsesBody(
        nativeResponsesConfig(oauth),
        'custom-codex-model',
        RequestHistoryContext.identify([
          {'role': 'user', 'content': 'INJECTED_REFERENCE'},
          {
            'role': 'user',
            'content': 'REAL_USER_HISTORY',
            imageContextOwnerKey: 'u1',
          },
        ]),
      );
      final projected = await RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
      ).project(body, preserveSources: true);
      final result = await requestNativeCompaction(
        MockClient((request) async {
          expect(request.body, contains('INJECTED_REFERENCE'));
          expect(request.body, contains('REAL_USER_HISTORY'));
          expect(request.body, isNot(contains(historySourceKey)));
          expect(request.body, isNot(contains(imageContextOwnerKey)));
          return http.Response(
            event({
                  'type': 'response.output_item.done',
                  'output_index': 0,
                  'item': compaction,
                }) +
                event({
                  'type': 'response.done',
                  'response': {'status': 'completed'},
                }),
            200,
          );
        }),
        oauth,
        'custom-codex-model',
        projected,
      );
      expect(result.output, hasLength(2));
      expect(jsonEncode(result.output.first), contains('REAL_USER_HISTORY'));
      expect(jsonEncode(result.output), isNot(contains('INJECTED_REFERENCE')));
      expect(jsonEncode(result.output), isNot(contains(historySourceKey)));
      expect(result.output.last, compaction);
    },
  );

  test(
    'Codex rejects a dropped stream, failed completion and normal reply without compaction',
    () async {
      for (final stream in [
        event({
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': compaction,
        }),
        event({
          'type': 'response.failed',
          'response': {
            'error': {'message': 'rejected'},
          },
        }),
        event({
          'type': 'response.completed',
          'response': {'status': 'completed', 'output': []},
        }),
        event({
          'type': 'response.completed',
          'response': {
            'status': 'incomplete',
            'output': [compaction],
          },
        }),
        event({
          'type': 'error',
          'message': 'unsupported trigger',
          'code': 'invalid_request',
        }),
      ]) {
        await expectLater(
          requestNativeCompaction(
            MockClient((_) async => http.Response(stream, 200)),
            oauth,
            'custom-codex-model',
            prepared,
          ),
          throwsA(anyOf(isA<Exception>(), isA<StateError>())),
        );
      }
    },
  );
}
