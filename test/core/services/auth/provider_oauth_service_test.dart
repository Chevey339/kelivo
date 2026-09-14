import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/features/provider/widgets/share_provider_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/business_test_harness.dart';

ProviderConfig config({
  OAuthProvider provider = OAuthProvider.kimi,
  bool expired = true,
}) => ProviderConfig(
  id: 'account',
  enabled: true,
  name: provider.displayName,
  apiKey: '',
  baseUrl: provider.baseUrl,
  providerType: ProviderKind.openai,
  oauthProvider: provider,
  useResponseApi: provider != OAuthProvider.kimi,
  oauthCredentials: ProviderOAuthCredentials(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.now().add(
      expired ? const Duration(seconds: -1) : const Duration(hours: 1),
    ),
    sessionId: 'session',
    accountId: 'workspace',
    deviceId: 'device',
  ),
);

http.Response jsonResponse(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsProvider settings;
  setUp(() async {
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
  });
  tearDown(() => settings.dispose());

  test(
    'concurrent refresh is coalesced, preserves edits, and persists token rotation',
    () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) {
          calls++;
          return pending.future;
        }),
      )..bind(settings);
      await settings.setProviderConfig('account', config());
      final first = service.resolve(config());
      final second = service.resolve(config());
      await Future<void>.delayed(Duration.zero);
      await settings.setProviderConfig(
        'account',
        settings.providerConfigs['account']!.copyWith(
          name: 'Renamed',
          proxyHost: 'proxy.example',
        ),
      );
      pending.complete(
        jsonResponse({
          'access_token': 'new-access',
          'refresh_token': 'rotated',
          'expires_in': 3600,
        }),
      );
      final results = await Future.wait([first, second]);
      expect(calls, 1);
      expect(results.every((e) => e.apiKey == 'new-access'), isTrue);
      final saved = settings.providerConfigs['account']!;
      expect(saved.name, 'Renamed');
      expect(saved.proxyHost, 'proxy.example');
      expect(saved.apiKey, isEmpty);
      expect(saved.oauthCredentials!.refreshToken, 'rotated');
    },
  );

  test(
    'logout while refresh is in flight cannot restore credentials',
    () async {
      final pending = Completer<http.Response>();
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) => pending.future),
      )..bind(settings);
      await settings.setProviderConfig('account', config());
      final refresh = service.resolve(config());
      final expectation = expectLater(
        refresh,
        throwsA(isA<ProviderOAuthException>()),
      );
      await service.logout('account');
      pending.complete(
        jsonResponse({
          'access_token': 'new',
          'refresh_token': 'rotated',
          'expires_in': 3600,
        }),
      );
      await expectation;
      expect(settings.providerConfigs['account']!.oauthCredentials, isNull);
    },
  );

  test(
    'an old settings instance cannot invalidate a restored account',
    () async {
      final pending = Completer<http.Response>();
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) => pending.future),
      )..bind(settings);
      final original = config();
      await settings.setProviderConfig(original.id, original);
      final refresh = service.resolve(original);
      final expectation = expectLater(
        refresh,
        throwsA(isA<ProviderOAuthException>()),
      );
      final restoredHarness = await createBusinessTestHarness();
      final restored = SettingsProvider(restoredHarness.preferences);
      await restored.loaded;
      addTearDown(restored.dispose);
      await restored.setProviderConfig(original.id, original);
      service.bind(restored);
      pending.complete(
        jsonResponse({'access_token': 'fresh', 'expires_in': 3600}),
      );
      await expectation;
      expect(
        restored.providerConfigs[original.id]!.oauthCredentials!.requiresLogin,
        false,
      );
      expect(
        restored.providerConfigs[original.id]!.oauthCredentials!.accessToken,
        'access',
      );
    },
  );

  test(
    'revoked refresh marks login required; outages retain usable credentials',
    () async {
      for (final status in [503, 400]) {
        final service = ProviderOAuthService(
          clientFactory: (_) => MockClient(
            (_) async => jsonResponse({
              'error': status == 400 ? 'invalid_grant' : 'server_error',
            }, status),
          ),
        )..bind(settings);
        await settings.setProviderConfig('account', config());
        await expectLater(
          service.resolve(config()),
          throwsA(isA<ProviderOAuthException>()),
        );
        expect(
          settings.providerConfigs['account']!.oauthCredentials!.requiresLogin,
          status == 400,
        );
        expect(
          settings.providerConfigs['account']!.oauthCredentials!.refreshToken,
          'refresh',
        );
      }
    },
  );

  test(
    'settings, share export, and serialized restore retain OAuth credentials',
    () async {
      final original = config(expired: false);
      await settings.setProviderConfig('account', original);
      expect(original.toJson()['oauthCredentials']['expiresAt'], endsWith('Z'));
      final restored = ProviderConfig.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.oauthProvider, OAuthProvider.kimi);
      expect(
        restored.oauthCredentials!.expiresAt.isAtSameMomentAs(
          original.oauthCredentials!.expiresAt,
        ),
        true,
      );
      expect(restored.oauthCredentials!.refreshToken, 'refresh');
      expect(
        restored.copyWith(name: 'Other').oauthCredentials!.sessionId,
        'session',
      );
      expect(
        restored.copyWith(oauthCredentials: null).oauthCredentials,
        isNull,
      );
      final shared =
          jsonDecode(
                utf8.decode(
                  base64Decode(
                    encodeProviderConfig(
                      original,
                    ).substring('ai-provider:v1:'.length),
                  ),
                ),
              )
              as Map;
      expect(
        (shared['config'] as Map)['oauthCredentials']['refreshToken'],
        'refresh',
      );
    },
  );

  test(
    'model sync refreshes first, applies metadata and keeps existing per-model settings',
    () async {
      var calls = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((request) async {
          calls++;
          if (request.method == 'POST') {
            return jsonResponse({'access_token': 'fresh', 'expires_in': 3600});
          }
          expect(request.headers['Authorization'], 'Bearer fresh');
          return jsonResponse({
            'data': [
              {
                'id': 'kimi-k2.5',
                'display_name': 'Kimi 2.5',
                'supports_image_in': true,
                'protocol': 'anthropic',
                'supports_thinking_type': 'only',
                'think_efforts': {'support': true},
              },
            ],
          });
        }),
      )..bind(settings);
      await settings.setProviderConfig(
        'account',
        config().copyWith(
          modelOverrides: {
            'kimi-k2.5': {'temperature': .7},
          },
        ),
      );
      await service.syncModels('account');
      final saved = settings.providerConfigs['account']!;
      expect(calls, 2);
      expect(saved.models, ['kimi-k2.5']);
      expect(saved.modelOverrides['kimi-k2.5']['input'], contains('image'));
      expect(saved.modelOverrides['kimi-k2.5']['temperature'], .7);
      expect(saved.modelOverrides['kimi-k2.5']['oauthProtocol'], 'anthropic');
      expect(
        saved.modelOverrides['kimi-k2.5']['oauthThinkingMode'],
        'adaptive',
      );
      expect(saved.modelOverrides['kimi-k2.5']['oauthThinkingRequired'], true);
      expect(
        saved.modelOverrides['kimi-k2.5']['abilities'],
        contains('reasoning'),
      );
      expect(saved.oauthModelsSyncedAt, isNotNull);
    },
  );

  test(
    'exported business settings restore OAuth credentials into a fresh database',
    () async {
      final source = await createBusinessTestHarness();
      final original = config(expired: false);
      await source.preferences.setString(
        'provider_configs_v1',
        jsonEncode({'account': original.toJson()}),
      );
      final backup = BusinessSettingsRouter.exportSnapshotWithRowIds(
        await source.repository.readSnapshot(),
      );
      final target = await createBusinessTestHarness();
      await target.repository.replaceSnapshot(
        BusinessSettingsRouter.normalizeAndRoute(backup.settings),
      );
      final restored = SettingsProvider(BusinessPreferences(target.repository));
      await restored.loaded;
      expect(
        restored.providerConfigs['account']!.oauthCredentials!.refreshToken,
        'refresh',
      );
      expect(
        restored.providerConfigs['account']!.oauthProvider,
        OAuthProvider.kimi,
      );
      restored.dispose();
      final invalid = original.toJson();
      invalid['oauthCredentials'] = {
        ...original.oauthCredentials!.toJson(),
        'expiresAt': 'bad date',
      };
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'provider_configs_v1': jsonEncode({'account': invalid}),
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'Codex streaming applies subscription contract after user overrides',
    () async {
      final service = ProviderOAuthService()..bind(settings);
      final original = config(provider: OAuthProvider.chatgpt, expired: false)
          .copyWith(
            customHeaders: [
              {'name': 'Authorization', 'value': 'Bearer wrong'},
            ],
            customBody: [
              {'key': 'store', 'value': 'true'},
              {'key': 'max_output_tokens', 'value': '10'},
              {'key': 'top_k', 'value': '50'},
              {'key': 'min_p', 'value': '0.1'},
              {'key': 'presence_penalty', 'value': '0.1'},
              {'key': 'repetition_penalty', 'value': '1.1'},
              {'key': 'frequency_penalty', 'value': '0.1'},
              {'key': 'stop', 'value': '["END"]'},
              {'key': 'service_tier', 'value': 'priority'},
            ],
          );
      await settings.setProviderConfig(original.id, original);
      final resolved = await service.resolve(original);
      final requests = <http.Request>[];
      final client = service.authenticatedClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response(
            'data: {"type":"response.output_text.delta","delta":"Hello"}\n\ndata: {"type":"response.completed","response":{"id":"resp","output":[]}}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
        resolved,
      );
      final chunks = await sendOpenAIStream(
        client,
        resolved,
        'gpt-5.4',
        [
          {'role': 'user', 'content': 'Hi'},
        ],
        temperature: .7,
        maxTokens: 32,
        thinkingBudget: 0,
      ).toList();
      expect(chunks.whereType<TextDelta>().map((e) => e.text).join(), 'Hello');
      final sent = requests.single;
      expect(sent.headers['Authorization'], 'Bearer access');
      expect(sent.headers['chatgpt-account-id'], 'workspace');
      expect(sent.url.toString(), '${OAuthProvider.chatgpt.baseUrl}/responses');
      final body = jsonDecode(sent.body) as Map;
      expect(body['stream'], true);
      expect(body['store'], false);
      expect(body['instructions'], '');
      expect(body.containsKey('temperature'), false);
      expect(body.containsKey('max_output_tokens'), false);
      for (final key in [
        'top_k',
        'min_p',
        'presence_penalty',
        'repetition_penalty',
        'frequency_penalty',
        'stop',
      ]) {
        expect(
          body.containsKey(key),
          false,
          reason: '$key is unsupported by Codex',
        );
      }
      expect(body['reasoning'], {'effort': 'none'});
      expect(
        sent.headers['x-codex-routing-hint'],
        'model=gpt-5.4;tier=priority',
      );
      expect(body['include'], contains('reasoning.encrypted_content'));
    },
  );

  test(
    'Codex tool continuation preserves encrypted reasoning without server item references',
    () async {
      final service = ProviderOAuthService()..bind(settings);
      final original = config(provider: OAuthProvider.chatgpt, expired: false);
      await settings.setProviderConfig(original.id, original);
      final requests = <http.Request>[];
      final toolCalls = <String>[];
      final call = {
        'type': 'function_call',
        'id': 'fc_temporary',
        'call_id': 'call_weather',
        'name': 'weather',
        'arguments': '{}',
        'status': 'completed',
      };
      final client = service.authenticatedClient(
        MockClient((request) async {
          requests.add(request);
          final events = requests.length == 1
              ? [
                  {
                    'type': 'response.output_item.done',
                    'output_index': 1,
                    'item': call,
                  },
                  {
                    'type': 'response.completed',
                    'response': {
                      'output': [
                        {
                          'type': 'reasoning',
                          'id': 'rs_temporary',
                          'summary': [],
                          'encrypted_content': 'opaque',
                        },
                        call,
                      ],
                    },
                  },
                ]
              : [
                  {'type': 'response.output_text.delta', 'delta': 'Sunny'},
                  {
                    'type': 'response.completed',
                    'response': {'output': []},
                  },
                ];
          return http.Response(
            events.map((e) => 'data: ${jsonEncode(e)}\n\n').join(),
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
        await service.resolve(original),
      );
      final chunks = await sendOpenAIStream(
        client,
        await service.resolve(original),
        'gpt-5.4',
        [
          {'role': 'user', 'content': 'Weather?'},
        ],
        tools: [
          {
            'type': 'function',
            'function': {
              'name': 'weather',
              'parameters': {'type': 'object', 'properties': {}},
            },
          },
        ],
        onToolCall: (name, args, {toolCallId}) async {
          toolCalls.add(name);
          return 'sunny';
        },
      ).toList();
      expect(toolCalls, ['weather']);
      expect(chunks.whereType<TextDelta>().map((e) => e.text).join(), 'Sunny');
      expect(requests.length, 2);
      final body = jsonDecode(requests.last.body) as Map;
      final input = (body['input'] as List).cast<Map>();
      expect(input.any((item) => item.containsKey('id')), false);
      expect(
        input
            .where((item) => item['type'] == 'reasoning')
            .single['encrypted_content'],
        'opaque',
      );
      expect(
        input
            .where((item) => item['type'] == 'function_call_output')
            .single['call_id'],
        'call_weather',
      );
      expect(body['store'], false);
      expect(body['instructions'], '');
      expect(body['include'], contains('reasoning.encrypted_content'));
    },
  );

  test(
    'Kimi Messages honor model thinking metadata and rotate both auth headers',
    () async {
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient(
          (_) async =>
              jsonResponse({'access_token': 'fresh', 'expires_in': 3600}),
        ),
      )..bind(settings);
      for (final scenario in [
        (
          mode: 'enabled',
          required: false,
          budget: null,
          thinking: {'type': 'enabled', 'budget_tokens': 2048},
          effort: null,
        ),
        (
          mode: 'enabled',
          required: false,
          budget: 64000,
          thinking: {'type': 'enabled', 'budget_tokens': 31999},
          effort: null,
        ),
        (
          mode: 'adaptive',
          required: false,
          budget: 64000,
          thinking: {'type': 'adaptive'},
          effort: 'high',
        ),
        (
          mode: 'adaptive',
          required: false,
          budget: 0,
          thinking: {'type': 'disabled'},
          effort: null,
        ),
        (
          mode: 'adaptive',
          required: true,
          budget: 0,
          thinking: {'type': 'adaptive'},
          effort: 'low',
        ),
      ]) {
        final original = config(expired: false).copyWith(
          modelOverrides: {
            'kimi-display-id': {
              'apiModelId': 'kimi-k2.5',
              'abilities': ['tool', 'reasoning'],
              'oauthThinkingMode': scenario.mode,
              'oauthThinkingRequired': scenario.required,
            },
          },
        );
        await settings.setProviderConfig(original.id, original);
        final resolved = await service.resolve(original);
        final requests = <http.Request>[];
        final client = service.authenticatedClient(
          MockClient((request) async {
            requests.add(request);
            if (requests.length == 1) return http.Response('', 401);
            return jsonResponse({
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': 'OK'},
              ],
              'stop_reason': 'end_turn',
            });
          }),
          resolved,
        );
        final chunks = await sendClaudeStream(
          client,
          resolved,
          'kimi-display-id',
          [
            {'role': 'user', 'content': 'Hi'},
          ],
          stream: false,
          thinkingBudget: scenario.budget,
        ).toList();
        expect(chunks.whereType<TextDelta>().map((e) => e.text).join(), 'OK');
        expect(requests.length, 2);
        expect(requests.last.url.path, '/coding/v1/messages');
        expect(requests.last.headers['Authorization'], 'Bearer fresh');
        expect(requests.last.headers['x-api-key'], 'fresh');
        expect(requests.last.headers['X-Msh-Device-Id'], 'device');
        final body = jsonDecode(requests.last.body) as Map;
        expect(body['model'], 'kimi-k2.5');
        expect(body['max_tokens'], 32000);
        expect(body['thinking'], scenario.thinking);
        expect((body['output_config'] as Map?)?['effort'], scenario.effort);
      }
    },
  );

  for (final switchDuring in ['response', 'refresh']) {
    test(
      '401 retry cancels if the account changes during $switchDuring',
      () async {
        final firstResponse = Completer<http.Response>();
        final firstSent = Completer<void>();
        final refreshStarted = Completer<void>();
        final refreshResponse = Completer<http.Response>();
        var refreshes = 0;
        final service = ProviderOAuthService(
          clientFactory: (_) => MockClient((request) async {
            refreshes++;
            if (!refreshStarted.isCompleted) refreshStarted.complete();
            if (switchDuring == 'refresh') return refreshResponse.future;
            return jsonResponse({
              'access_token': 'refreshed-B',
              'expires_in': 3600,
            });
          }),
        )..bind(settings);
        final original = config(expired: false);
        await settings.setProviderConfig(original.id, original);
        final requests = <http.Request>[];
        final client = service.authenticatedClient(
          MockClient((request) async {
            requests.add(request);
            if (requests.length == 1) {
              firstSent.complete();
              return firstResponse.future;
            }
            return jsonResponse({'choices': []});
          }),
          original,
        );
        final url = Uri.parse('${original.baseUrl}/chat/completions');
        final pending = client.post(
          url,
          body:
              '{"messages":[{"role":"user","content":"A private conversation"}]}',
        );
        final expectation = expectLater(
          pending,
          throwsA(
            isA<ProviderOAuthException>().having(
              (e) => e.kind,
              'kind',
              ProviderOAuthFailure.cancelled,
            ),
          ),
        );
        await firstSent.future;
        if (switchDuring == 'refresh') {
          firstResponse.complete(http.Response('', 401));
          await refreshStarted.future;
        }
        await service.logout(original.id);
        final accountB = original.copyWith(
          oauthCredentials: ProviderOAuthCredentials(
            accessToken: 'account-B-access',
            refreshToken: 'account-B-refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            sessionId: 'account-B-session',
          ),
        );
        await settings.setProviderConfig(original.id, accountB);
        if (switchDuring == 'response') {
          firstResponse.complete(http.Response('', 401));
        } else {
          refreshResponse.complete(
            jsonResponse({'access_token': 'refreshed-A', 'expires_in': 3600}),
          );
        }
        await expectation;
        expect(requests.length, 1);
        expect(requests.single.headers['Authorization'], 'Bearer access');
        expect(refreshes, switchDuring == 'refresh' ? 1 : 0);
        expect(
          settings.providerConfigs[original.id]!.oauthCredentials!.accessToken,
          'account-B-access',
        );
        expect(
          settings
              .providerConfigs[original.id]!
              .oauthCredentials!
              .requiresLogin,
          false,
        );
        // A cancelled client must remain bound to A even when it is reused.
        await expectLater(
          client.post(url, body: '{}'),
          throwsA(
            isA<ProviderOAuthException>().having(
              (e) => e.kind,
              'kind',
              ProviderOAuthFailure.cancelled,
            ),
          ),
        );
        expect(requests.length, 1);
      },
    );
  }

  test(
    'Kimi OpenAI models use discovered native thinking on initial and tool requests',
    () async {
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient(
          (_) async => jsonResponse({
            'data': [
              for (final entry in [('k3', 'only'), ('optional-model', 'both')])
                {
                  'id': entry.$1,
                  'protocol': null,
                  'supports_thinking_type': entry.$2,
                  'think_efforts': {
                    'support': true,
                    'valid_efforts': ['max', 'low', 'high'],
                    'default_effort': 'max',
                  },
                },
            ],
          }),
        ),
      )..bind(settings);
      final original = config(expired: false);
      await settings.setProviderConfig(original.id, original);
      await service.syncModels(original.id);
      final synced = settings.providerConfigs[original.id]!;
      expect(synced.modelOverrides['k3']['oauthProtocol'], 'openai');
      for (final scenario in [
        (
          model: 'k3',
          budget: 0,
          overrideThinking: null,
          thinking: {'type': 'enabled', 'effort': 'low'},
        ),
        (
          model: 'k3',
          budget: 8000,
          overrideThinking: null,
          thinking: {'type': 'enabled', 'effort': 'low'},
        ),
        (
          model: 'k3',
          budget: 64000,
          overrideThinking: null,
          thinking: {'type': 'enabled', 'effort': 'high'},
        ),
        (
          model: 'k3',
          budget: 128000,
          overrideThinking: null,
          thinking: {'type': 'enabled', 'effort': 'max'},
        ),
        (
          model: 'k3',
          budget: null,
          overrideThinking: null,
          thinking: {'type': 'enabled', 'effort': 'max'},
        ),
        (
          model: 'optional-model',
          budget: 0,
          overrideThinking: null,
          thinking: {'type': 'disabled'},
        ),
        (
          model: 'optional-model',
          budget: 64000,
          overrideThinking: null,
          thinking: {'type': 'enabled', 'effort': 'high'},
        ),
        (
          model: 'k3',
          budget: 0,
          overrideThinking: {
            'type': 'enabled',
            'effort': 'high',
            'keep': 'all',
          },
          thinking: {'type': 'enabled', 'effort': 'high', 'keep': 'all'},
        ),
      ]) {
        final requests = <http.Request>[];
        final client = service.authenticatedClient(
          MockClient((request) async {
            requests.add(request);
            final delta = requests.length == 1
                ? {
                    'role': 'assistant',
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call_id',
                        'type': 'function',
                        'function': {'name': 'lookup', 'arguments': '{}'},
                      },
                    ],
                  }
                : {'content': 'OK'};
            return http.Response(
              'data: ${jsonEncode({
                'choices': [
                  {'index': 0, 'delta': delta, 'finish_reason': requests.length == 1 ? 'tool_calls' : 'stop'},
                ],
              })}\n\ndata: [DONE]\n\n',
              200,
              headers: {'content-type': 'text/event-stream'},
            );
          }),
          synced,
        );
        final chunks = await sendOpenAIStream(
          client,
          await service.resolve(synced),
          scenario.model,
          [
            {'role': 'user', 'content': 'Lookup'},
          ],
          thinkingBudget: scenario.budget,
          extraBody: {
            if (scenario.overrideThinking != null)
              'thinking': scenario.overrideThinking,
          },
          tools: [
            {
              'type': 'function',
              'function': {
                'name': 'lookup',
                'parameters': {'type': 'object', 'properties': {}},
              },
            },
          ],
          onToolCall: (name, args, {toolCallId}) async => 'result',
        ).toList();
        expect(chunks.whereType<TextDelta>().map((e) => e.text).join(), 'OK');
        expect(requests.length, 2);
        for (final request in requests) {
          expect(request.url.path, '/coding/v1/chat/completions');
          final body = jsonDecode(request.body) as Map;
          expect(
            body['thinking'],
            scenario.thinking,
            reason: '${scenario.model}, budget=${scenario.budget}',
          );
          expect(body.containsKey('reasoning_effort'), false);
          expect(body.containsKey('output_config'), false);
        }
      }
    },
  );

  for (final stream in [true, false]) {
    for (final aliased in [false, true]) {
      test(
        'Kimi OpenAI reasoning survives history and two tool rounds (stream=$stream, alias=$aliased)',
        () async {
          final service = ProviderOAuthService(
            clientFactory: (_) => MockClient(
              (_) async => jsonResponse({
                'data': [
                  {
                    'id': 'k3',
                    'protocol': null,
                    'supports_thinking_type': 'only',
                    'think_efforts': {
                      'support': true,
                      'valid_efforts': ['low', 'high', 'max'],
                      'default_effort': 'max',
                    },
                  },
                ],
              }),
            ),
          )..bind(settings);
          final original = config(expired: false);
          await settings.setProviderConfig(original.id, original);
          await service.syncModels(original.id);
          var synced = settings.providerConfigs[original.id]!;
          final modelId = aliased ? 'my-model-label' : 'k3';
          if (aliased) {
            synced = synced.copyWith(
              modelOverrides: {
                ...synced.modelOverrides,
                modelId: {
                  ...(synced.modelOverrides['k3'] as Map),
                  'apiModelId': 'k3',
                },
              },
            );
            await settings.setProviderConfig(synced.id, synced);
          }
          final requests = <Map<String, dynamic>>[];
          final calls = <String>[];
          final client = service.authenticatedClient(
            MockClient((request) async {
              requests.add(
                (jsonDecode(request.body) as Map).cast<String, dynamic>(),
              );
              final round = requests.length;
              final message = <String, dynamic>{
                'role': 'assistant',
                'content': round < 3 ? 'Step $round' : 'OK',
                'reasoning_content': 'Thought $round\nContinue $round',
                if (round < 3)
                  'tool_calls': [
                    {
                      if (stream) 'index': 0,
                      'id': 'call_$round',
                      'type': 'function',
                      'function': {'name': 'lookup', 'arguments': '{}'},
                    },
                  ],
              };
              final body = {
                'choices': [
                  {
                    'index': 0,
                    stream ? 'delta' : 'message': message,
                    'finish_reason': round < 3 ? 'tool_calls' : 'stop',
                  },
                ],
              };
              return stream
                  ? http.Response(
                      'data: ${jsonEncode(body)}\n\ndata: [DONE]\n\n',
                      200,
                      headers: {'content-type': 'text/event-stream'},
                    )
                  : jsonResponse(body);
            }),
            synced,
          );
          final chunks = await sendOpenAIStream(
            client,
            await service.resolve(synced),
            modelId,
            [
              {'role': 'user', 'content': 'Previous question'},
              {
                'role': 'assistant',
                'content': 'Previous answer',
                'reasoning_content': 'Previous thought\nKeep exactly',
              },
              {'role': 'user', 'content': 'Continue with two lookups'},
            ],
            stream: stream,
            thinkingBudget: 0,
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
              calls.add(toolCallId!);
              return 'result';
            },
          ).toList();
          expect(
            chunks.whereType<TextDelta>().map((e) => e.text).join(),
            contains('OK'),
          );
          expect(calls, ['call_1', 'call_2']);
          expect(requests.length, 3);
          // Fresh tool results must retain their matching, unmodified reasoning.
          for (
            var requestIndex = 1;
            requestIndex < requests.length;
            requestIndex++
          ) {
            final messages = (requests[requestIndex]['messages'] as List)
                .cast<Map>();
            final assistants = messages
                .where((message) => message['tool_calls'] is List)
                .toList();
            expect(assistants.length, requestIndex);
            for (var round = 1; round <= requestIndex; round++) {
              expect(
                assistants[round - 1]['reasoning_content'],
                'Thought $round\nContinue $round',
              );
              expect(assistants[round - 1]['content'], 'Step $round');
            }
          }
          // Preserved Thinking also retains earlier non-tool assistant turns.
          for (final request in requests) {
            expect(request['model'], 'k3');
            final history = (request['messages'] as List)
                .cast<Map>()
                .singleWhere(
                  (message) => message['content'] == 'Previous answer',
                );
            expect(
              history['reasoning_content'],
              'Previous thought\nKeep exactly',
            );
          }
        },
      );
    }
  }

  test(
    '401 refreshes and retries once; logout prevents a tool follow-up',
    () async {
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient(
          (_) async => jsonResponse({
            'access_token': 'fresh',
            'refresh_token': 'next',
            'expires_in': 3600,
          }),
        ),
      )..bind(settings);
      final original = config(expired: false);
      await settings.setProviderConfig(original.id, original);
      var calls = 0;
      final client = service.authenticatedClient(
        MockClient((request) async {
          calls++;
          if (calls == 1) return http.Response('', 401);
          expect(request.headers['Authorization'], 'Bearer fresh');
          return jsonResponse({'choices': []});
        }),
        await service.resolve(original),
      );
      final result = await client.post(
        Uri.parse('${original.baseUrl}/chat/completions'),
        body: '{"messages":[]}',
      );
      expect(result.statusCode, 200);
      expect(calls, 2);
      await service.logout(original.id);
      await expectLater(
        client.post(
          Uri.parse('${original.baseUrl}/chat/completions'),
          body: '{}',
        ),
        throwsA(isA<ProviderOAuthException>()),
      );
      expect(calls, 2);
    },
  );
}
