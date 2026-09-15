import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_adapter.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:Kelivo/core/services/auth/claude_oauth_request.dart';
import 'package:Kelivo/core/services/auth/oauth_pkce.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/provider_request_headers.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/business_test_harness.dart';

class _RealHttpOverrides extends HttpOverrides {}

Future<int> sendLoopbackCallback(Uri uri) async {
  final client = HttpOverrides.runWithHttpOverrides(
    HttpClient.new,
    _RealHttpOverrides(),
  )..findProxy = (_) => 'DIRECT';
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

http.Response response(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, Object> tokenResponse({String access = 'sk-ant-oat-access'}) => {
  'access_token': access,
  'refresh_token': 'rotated-refresh',
  'expires_in': 7200,
  'account': {'uuid': 'account-uuid', 'email_address': 'user@example.com'},
  'organization': {'uuid': 'org-original', 'name': 'Personal'},
};

ProviderConfig claudeConfig({String ttl = '1h', bool cache = true}) =>
    ProviderConfig(
      id: 'claude-account',
      name: 'Claude',
      enabled: true,
      apiKey: '',
      baseUrl: OAuthProvider.claude.baseUrl,
      providerType: ProviderKind.claude,
      oauthProvider: OAuthProvider.claude,
      useResponseApi: false,
      claudePromptCachingEnabled: cache,
      claudePromptCachingTtl: ttl,
      models: ['claude-sonnet-4-6'],
      oauthCredentials: ProviderOAuthCredentials(
        accessToken: 'sk-ant-oat-access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        sessionId: 'login-session',
        accountId: 'account-uuid',
        email: 'user@example.com',
        organizationId: 'org-original',
        organizationName: 'Personal',
        deviceId:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
    );

List<Map> cacheMarkers(Object? value) {
  if (value is Map) {
    return [
      if (value['cache_control'] is Map) value['cache_control'] as Map,
      for (final child in value.values) ...cacheMarkers(child),
    ];
  }
  if (value is List) return [for (final child in value) ...cacheMarkers(child)];
  return [];
}

http.Response messageResponse(
  List<Map<String, dynamic>> blocks, {
  required bool stream,
  required bool tool,
}) {
  if (!stream) {
    return response({
      'id': 'reply',
      'type': 'message',
      'role': 'assistant',
      'content': blocks,
      'stop_reason': tool ? 'tool_use' : 'end_turn',
      'usage': {'input_tokens': 4, 'output_tokens': 3},
    });
  }
  final events = <Map<String, dynamic>>[
    {
      'type': 'message_start',
      'message': {
        'id': 'reply',
        'role': 'assistant',
        'content': [],
        'usage': {'input_tokens': 4},
      },
    },
    for (var index = 0; index < blocks.length; index++) ...[
      {
        'type': 'content_block_start',
        'index': index,
        'content_block': {
          ...blocks[index],
          if (blocks[index]['type'] == 'text') 'text': '',
          if (blocks[index]['type'] == 'thinking') ...{
            'thinking': '',
            'signature': '',
          },
        },
      },
      if (blocks[index]['type'] == 'text')
        {
          'type': 'content_block_delta',
          'index': index,
          'delta': {'type': 'text_delta', 'text': blocks[index]['text']},
        },
      if (blocks[index]['type'] == 'thinking') ...[
        {
          'type': 'content_block_delta',
          'index': index,
          'delta': {
            'type': 'thinking_delta',
            'thinking': blocks[index]['thinking'],
          },
        },
        {
          'type': 'content_block_delta',
          'index': index,
          'delta': {
            'type': 'signature_delta',
            'signature': blocks[index]['signature'],
          },
        },
      ],
      {'type': 'content_block_stop', 'index': index},
    ],
    {
      'type': 'message_delta',
      'delta': {'stop_reason': tool ? 'tool_use' : 'end_turn'},
      'usage': {'output_tokens': 3},
    },
    {'type': 'message_stop'},
  ];
  return http.Response(
    events
        .map(
          (event) => 'event: ${event['type']}\ndata: ${jsonEncode(event)}\n\n',
        )
        .join(),
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

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
    'Claude manual login uses OMP PKCE, scopes and JSON code exchange',
    () async {
      late OAuthLoginPrompt prompt;
      final requests = <http.Request>[];
      final adapter = ClaudeOAuthAdapter();
      final result = await adapter.login(
        OAuthWire(
          MockClient((request) async {
            requests.add(request);
            return response(tokenResponse());
          }),
        ),
        OAuthCancellation(),
        (value) async {
          prompt = value;
          expect(value.url.origin, 'https://claude.ai');
          expect(value.url.path, '/oauth/authorize');
          expect(
            value.url.queryParameters['scope'],
            OAuthProvider.claude.scope,
          );
          expect(value.url.queryParameters['code'], 'true');
          expect(value.submitAuthorizationCode!('wrong#other-state'), isFalse);
          expect(
            value.submitAuthorizationCode!(
              'valid-code#${value.url.queryParameters['state']}',
            ),
            isTrue,
          );
        },
        launcher: (_) async =>
            throw StateError('manual entry already completed'),
      );
      expect(requests, hasLength(1));
      final body = jsonDecode(requests.single.body) as Map;
      expect(
        requests.single.url.toString(),
        OAuthProvider.claude.tokenEndpoint,
      );
      expect(
        requests.single.headers['content-type'],
        contains('application/json'),
      );
      expect(body['code'], 'valid-code');
      expect(body['state'], prompt.url.queryParameters['state']);
      expect(body['redirect_uri'], prompt.url.queryParameters['redirect_uri']);
      expect(body['client_id'], '9d1c250a-e61b-44d9-88ed-5944d1962f5e');
      expect(
        oauthPkceChallenge(body['code_verifier'] as String),
        prompt.url.queryParameters['code_challenge'],
      );
      expect(result.organizationId, 'org-original');
      expect(result.email, 'user@example.com');
    },
  );

  test(
    'Claude automatic browser callback completes through the loopback listener',
    () async {
      final adapter = ClaudeOAuthAdapter();
      final value = await adapter.login(
        OAuthWire(MockClient((_) async => response(tokenResponse()))),
        OAuthCancellation(),
        (_) async {},
        launcher: (url) async {
          final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
          final client = HttpOverrides.runWithHttpOverrides(
            HttpClient.new,
            _RealHttpOverrides(),
          )..findProxy = (_) => 'DIRECT';
          try {
            final request = await client.getUrl(
              redirect.replace(
                queryParameters: {
                  'code': 'auto-code',
                  'state': url.queryParameters['state']!,
                },
              ),
            );
            final reply = await request.close();
            await reply.drain<void>();
            expect(reply.statusCode, 200);
          } finally {
            client.close(force: true);
          }
          return true;
        },
      );
      expect(value.accessToken, 'sk-ant-oat-access');
    },
  );

  test(
    'Claude falls back to an available port and preserves cancellation',
    () async {
      final occupied = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        54545,
      );
      final cancellation = OAuthCancellation();
      var exchanged = false;
      try {
        await expectLater(
          ClaudeOAuthAdapter().login(
            OAuthWire(
              MockClient((_) async {
                exchanged = true;
                return response(tokenResponse());
              }),
            ),
            cancellation,
            (prompt) async {
              final redirect = Uri.parse(
                prompt.url.queryParameters['redirect_uri']!,
              );
              expect(redirect.port, isNot(anyOf(0, 54545)));
              expect(redirect.path, '/callback');
              cancellation.cancel();
            },
          ),
          throwsA(
            isA<ProviderOAuthException>().having(
              (e) => e.kind,
              'kind',
              ProviderOAuthFailure.cancelled,
            ),
          ),
        );
        expect(exchanged, isFalse);
      } finally {
        await occupied.close(force: true);
      }
    },
  );

  for (final beforeBrowserLaunch in [true, false]) {
    test(
      'Claude ignores cancelled login callbacks beforeBrowserLaunch=$beforeBrowserLaunch',
      () async {
        final requests = <http.Request>[];
        final wire = OAuthWire(
          MockClient((request) async {
            requests.add(request);
            return response(tokenResponse());
          }),
        );
        final adapter = ClaudeOAuthAdapter();
        final cancellationA = OAuthCancellation();
        final launchedA = Completer<Uri>();
        final loginA = adapter.login(
          wire,
          cancellationA,
          (_) async {},
          launcher: (url) async {
            launchedA.complete(url);
            return true;
          },
        );
        final cancelledA = expectLater(
          loginA,
          throwsA(
            isA<ProviderOAuthException>().having(
              (error) => error.kind,
              'kind',
              ProviderOAuthFailure.cancelled,
            ),
          ),
        );
        final urlA = await launchedA.future;
        cancellationA.cancel();
        await cancelledA;

        final rejected = <int>[];
        Future<void> sendStaleCallbacks(Uri urlB) async {
          final redirect = Uri.parse(urlB.queryParameters['redirect_uri']!);
          for (final query in [
            {'code': 'old-code', 'state': urlA.queryParameters['state']!},
            {'error': 'access_denied', 'state': urlA.queryParameters['state']!},
            {'code': 'missing-state'},
          ]) {
            rejected.add(
              await sendLoopbackCallback(
                redirect.replace(queryParameters: query),
              ),
            );
          }
        }

        final cancellationB = OAuthCancellation();
        addTearDown(cancellationB.cancel);
        final credentials = await adapter
            .login(
              wire,
              cancellationB,
              (prompt) async {
                if (beforeBrowserLaunch) await sendStaleCallbacks(prompt.url);
              },
              launcher: (urlB) async {
                if (!beforeBrowserLaunch) await sendStaleCallbacks(urlB);
                expect(
                  await sendLoopbackCallback(
                    Uri.parse(urlB.queryParameters['redirect_uri']!).replace(
                      queryParameters: {
                        'code': 'new-code',
                        'state': urlB.queryParameters['state']!,
                      },
                    ),
                  ),
                  HttpStatus.ok,
                );
                return true;
              },
            )
            .timeout(const Duration(seconds: 3));

        expect(rejected, everyElement(HttpStatus.badRequest));
        expect(credentials.accessToken, 'sk-ant-oat-access');
        expect(requests, hasLength(1));
        expect(jsonDecode(requests.single.body)['code'], 'new-code');
      },
    );
  }

  test(
    'Claude surfaces a denial only when the callback state matches',
    () async {
      var exchanged = false;
      final login = ClaudeOAuthAdapter().login(
        OAuthWire(
          MockClient((_) async {
            exchanged = true;
            return response(tokenResponse());
          }),
        ),
        OAuthCancellation(),
        (_) async {},
        launcher: (url) async {
          final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
          await sendLoopbackCallback(
            redirect.replace(
              queryParameters: {
                'error': 'access_denied',
                'state': url.queryParameters['state']!,
              },
            ),
          );
          return true;
        },
      );
      await expectLater(
        login.timeout(const Duration(seconds: 3)),
        throwsA(
          isA<ProviderOAuthException>().having(
            (error) => error.kind,
            'kind',
            ProviderOAuthFailure.denied,
          ),
        ),
      );
      expect(exchanged, isFalse);
    },
  );

  test(
    'bootstrap fills identity and refresh keeps the original organization and device',
    () async {
      final adapter = ClaudeOAuthAdapter();
      var count = 0;
      final initial = await adapter.login(
        OAuthWire(
          MockClient((request) async {
            if (++count == 1) {
              return response({
                'access_token': 'sk-ant-oat-access',
                'refresh_token': 'refresh',
                'expires_in': 7200,
              });
            }
            expect(request.url.path, '/api/claude_cli/bootstrap');
            expect(request.url.queryParameters['model'], 'claude-opus-4-8');
            return response({
              'oauth_account': {
                'account_uuid': 'a',
                'account_email': 'a@example.com',
                'organization_uuid': 'original',
                'organization_name': 'Original',
              },
            });
          }),
        ),
        OAuthCancellation(),
        (prompt) async {
          prompt.submitAuthorizationCode!('code');
        },
      );
      final refreshed = await adapter.refresh(
        OAuthWire(
          MockClient((request) async {
            expect(request.headers['anthropic-beta'], 'oauth-2025-04-20');
            expect(
              request.headers['user-agent'],
              'anthropic-sdk-typescript/0.112.1 userOAuthProvider',
            );
            expect(jsonDecode(request.body), {
              'grant_type': 'refresh_token',
              'client_id': OAuthProvider.claude.clientId,
              'refresh_token': 'refresh',
            });
            return response(tokenResponse(access: 'sk-ant-oat-new'));
          }),
        ),
        initial,
      );
      expect(refreshed.organizationId, 'original');
      expect(refreshed.organizationName, 'Original');
      expect(refreshed.deviceId, initial.deviceId);
      expect(refreshed.sessionId, initial.sessionId);
      expect(refreshed.refreshToken, 'rotated-refresh');
    },
  );

  test(
    'invalid_grant requests login while usage permission failures retain the server reason',
    () async {
      await expectLater(
        ClaudeOAuthAdapter().refresh(
          OAuthWire(
            MockClient(
              (_) async => response({
                'error': 'invalid_grant',
                'error_description': 'Refresh token expired',
              }, 400),
            ),
          ),
          claudeConfig().oauthCredentials!,
        ),
        throwsA(
          isA<ProviderOAuthException>().having(
            (error) => error.kind,
            'kind',
            ProviderOAuthFailure.loginRequired,
          ),
        ),
      );
      await expectLater(
        ClaudeOAuthAdapter().usage(
          OAuthWire(
            MockClient(
              (_) async => response({
                'error': {
                  'type': 'permission_error',
                  'message': 'Subscription required',
                },
              }, 403),
            ),
          ),
          claudeConfig().oauthCredentials!,
        ),
        throwsA(
          isA<ProviderOAuthException>().having(
            (error) => error.message,
            'message',
            contains('Subscription required'),
          ),
        ),
      );
    },
  );

  test(
    'Claude login defaults to Messages and 1h caching, with five minute refresh leeway',
    () async {
      final service = ProviderOAuthService(
        clientFactory: (_) =>
            MockClient((_) async => response(tokenResponse())),
      )..bind(settings);
      final created = await service.login(
        provider: OAuthProvider.claude,
        cancellation: OAuthCancellation(),
        onPrompt: (prompt) {
          prompt.submitAuthorizationCode!('manual');
        },
      );
      expect(created.providerType, ProviderKind.claude);
      expect(created.useResponseApi, isFalse);
      expect(created.claudePromptCachingEnabled, isTrue);
      expect(created.claudePromptCachingTtl, '1h');
      final expiring = created.copyWith(
        oauthCredentials: created.oauthCredentials!.copyWith(
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
        ),
      );
      await settings.setProviderConfig(created.id, expiring);
      final resolved = await service.resolve(expiring);
      expect(
        resolved.oauthCredentials!.expiresAt.isAfter(
          DateTime.now().add(const Duration(minutes: 60)),
        ),
        isTrue,
      );
      final restored = ProviderConfig.fromJson(resolved.toJson());
      expect(restored.oauthCredentials!.organizationId, 'org-original');
      expect(
        restored.oauthCredentials!.deviceId,
        created.oauthCredentials!.deviceId,
      );
      expect(restored.claudePromptCachingTtl, '1h');
    },
  );

  test(
    'Claude discovery reads all cursor pages and preserves cache settings',
    () async {
      var page = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((request) async {
          expect(request.url.path, '/v1/models');
          expect(request.headers['authorization'], 'Bearer sk-ant-oat-access');
          expect(
            request.headers['anthropic-beta'],
            contains('redact-thinking-2026-02-12'),
          );
          expect(request.headers, isNot(contains('x-api-key')));
          if (++page == 1) {
            return response({
              'data': [
                {'id': 'claude-sonnet-4-6', 'display_name': 'Sonnet 4.6'},
              ],
              'has_more': true,
              'last_id': 'claude-sonnet-4-6',
            });
          }
          expect(request.url.queryParameters['after_id'], 'claude-sonnet-4-6');
          return response({
            'data': [
              {'id': 'claude-opus-4-8', 'display_name': 'Opus 4.8'},
            ],
            'has_more': false,
          });
        }),
      )..bind(settings);
      final config = claudeConfig(ttl: '5m');
      await settings.setProviderConfig(config.id, config);
      await service.syncModels(config.id);
      final saved = settings.getProviderConfig(config.id);
      expect(saved.models, ['claude-sonnet-4-6', 'claude-opus-4-8']);
      expect(saved.modelOverrides['claude-opus-4-8']['name'], 'Opus 4.8');
      expect(saved.claudePromptCachingTtl, '5m');
    },
  );

  test(
    'usage retains inactive scoped rows and parses current USD spend amounts',
    () {
      final usage = parseClaudeOAuthUsage({
        'five_hour': {'utilization': 23, 'resets_at': '2026-09-15T12:00:00Z'},
        'seven_day_opus': null,
        'limits': [
          {'kind': 'weekly_all', 'percent': 77, 'is_active': false},
          {
            'kind': 'weekly_scoped',
            'percent': 100,
            'scope': {
              'model': {'display_name': 'Fable'},
            },
          },
          {
            'kind': 'weekly_scoped',
            'percent': 5,
            'is_active': false,
            'scope': {
              'model': {'display_name': 'Sonnet'},
            },
          },
        ],
        'spend': {
          'enabled': true,
          'used': {'amount_minor': 1250, 'currency': 'USD', 'exponent': 2},
          'limit': {'amount_minor': 10000, 'currency': 'USD', 'exponent': 2},
        },
      });
      expect(usage.windows.map((window) => window.usedPercent), [
        23,
        77,
        100,
        5,
        12.5,
      ]);
      expect(usage.windows.last.used, 12.5);
      expect(usage.windows.last.limit, 100);
      expect(usage.windows.last.unit, 'usd');
      expect(usage.limitReached, isNull);
    },
  );

  test(
    'legacy extra usage and unlimited spend preserve units without inventing a percentage',
    () {
      final legacy = parseClaudeOAuthUsage({
        'extra_usage': {
          'is_enabled': true,
          'used_credits': 500,
          'monthly_limit': 10000,
        },
      });
      expect(legacy.windows.single.used, 5);
      expect(legacy.windows.single.usedPercent, 5);
      final unlimited = parseClaudeOAuthUsage({
        'spend': {
          'enabled': true,
          'used': {'amount_minor': 249, 'currency': 'USD', 'exponent': 2},
          'limit': null,
        },
      });
      expect(unlimited.windows.single.used, 2.49);
      expect(unlimited.windows.single.usedPercent, isNull);
      expect(parseClaudeOAuthUsage({'five_hour': null}).hasData, isFalse);
    },
  );

  test(
    'Claude usage retries transient and empty responses with OMP headers',
    () async {
      var calls = 0;
      final usage = await ClaudeOAuthAdapter().usage(
        OAuthWire(
          MockClient((request) async {
            expect(
              request.url.toString(),
              'https://api.anthropic.com/api/oauth/usage',
            );
            expect(
              request.headers['anthropic-beta'],
              contains('redact-thinking-2026-02-12'),
            );
            expect(
              request.headers['anthropic-beta'],
              isNot(contains('context-1m')),
            );
            expect(
              request.headers['user-agent'],
              'claude-cli/2.1.257 (external, cli)',
            );
            calls++;
            if (calls == 1) {
              return http.Response('{}', 503, headers: {'retry-after': '0'});
            }
            if (calls == 2) return response({'five_hour': null});
            return response({
              'five_hour': {'utilization': 42},
            });
          }),
        ),
        claudeConfig().oauthCredentials!,
      );
      expect(calls, 3);
      expect(usage.windows.single.usedPercent, 42);
    },
  );

  for (final status in [401, 403, 404, 429, 501]) {
    test('Claude usage does not retry HTTP $status', () async {
      var calls = 0;
      await expectLater(
        ClaudeOAuthAdapter().usage(
          OAuthWire(
            MockClient((_) async {
              calls++;
              return response({
                'error': {'type': 'rate_limit_error', 'message': 'Try later'},
              }, status);
            }),
          ),
          claudeConfig().oauthCredentials!,
        ),
        throwsA(
          isA<ProviderOAuthException>()
              .having((error) => error.statusCode, 'status', status)
              .having((error) => error.message, 'reason', 'Try later'),
        ),
      );
      expect(calls, 1);
    });
  }

  test(
    'Claude rejects malformed money and never substitutes legacy data for modern spend',
    () {
      for (final money in [
        {'amount_minor': '249', 'exponent': 2, 'currency': 'USD'},
        {'amount_minor': 249.5, 'exponent': 2, 'currency': 'USD'},
        {'amount_minor': -1, 'exponent': 2, 'currency': 'USD'},
        {'amount_minor': 9007199254740992, 'exponent': 2, 'currency': 'USD'},
        {'amount_minor': 249, 'exponent': 309, 'currency': 'USD'},
        {'amount_minor': 249, 'exponent': 2.5, 'currency': 'USD'},
        {'amount_minor': 249, 'exponent': 2, 'currency': 'EUR'},
        {'amount_minor': 249, 'exponent': 2},
      ]) {
        expect(
          parseClaudeOAuthUsage({
            'spend': {'enabled': true, 'used': money, 'limit': null},
            'extra_usage': {
              'is_enabled': true,
              'used_credits': 500,
              'monthly_limit': null,
            },
          }).hasData,
          isFalse,
          reason: '$money',
        );
      }
    },
  );

  // Generated independently with Bun.hash.xxHash64 (OMP 6f2c14b3), including
  // a UTF-16 surrogate at fingerprint index 4 and a Unicode request body.
  for (final vector in [
    ('Hello', '468', '87936'),
    ('编码测试🙂cache校验字符串with emoji', 'edf', '4270f'),
  ]) {
    test(
      'Claude billing fingerprint and cch match the Bun oracle for ${vector.$1}',
      () {
        final encoded = encodeClaudeOAuthRequest(
          {
            'model': 'claude-sonnet-4-6',
            'messages': [
              <String, dynamic>{'role': 'user', 'content': vector.$1},
            ],
            'max_tokens': 64000,
            'stream': true,
          },
          claudeConfig(cache: false),
          {},
          'conversation-1',
        );
        expect(
          (jsonDecode(encoded)['system'] as List).first['text'],
          'x-anthropic-billing-header: cc_version=2.1.257.${vector.$2}; cc_entrypoint=cli; cch=${vector.$3};',
        );
      },
    );
  }

  for (final stream in [true, false]) {
    test(
      'Claude fingerprints only the first text block with a remote image stream=$stream',
      () async {
        final config = claudeConfig();
        await settings.setProviderConfig(config.id, config);
        final service = ProviderOAuthService()..bind(settings);
        final requests = <http.Request>[];
        final client = service.authenticatedClient(
          MockClient((request) async {
            requests.add(request);
            return messageResponse(
              [
                {'type': 'text', 'text': 'Done'},
              ],
              stream: stream,
              tool: false,
            );
          }),
          config,
        );
        await sendClaudeStream(
          client,
          config,
          'claude-sonnet-4-6',
          [
            {'role': 'user', 'content': 'hi'},
          ],
          userImagePaths: ['https://example.com/image.png'],
          stream: stream,
        ).drain<void>();
        final body = jsonDecode(requests.single.body) as Map;
        final blocks = (body['messages'] as List).first['content'] as List;
        expect(blocks.map((block) => block['text']), [
          'hi',
          'https://example.com/image.png',
        ]);
        // Independent SHA-256 vector from OMP: first text "hi" -> 9c3.
        expect(
          (body['system'] as List).first['text'],
          contains('cc_version=2.1.257.9c3;'),
        );
      },
    );
    for (final toolName in ['lookup', '_lookup', 'web_search']) {
      test(
        'Claude tool roundtrip stream=$stream name=$toolName retains signed thinking and wire prefixes',
        () async {
          final config = claudeConfig();
          await settings.setProviderConfig(config.id, config);
          final service = ProviderOAuthService()..bind(settings);
          final requests = <http.Request>[];
          final calls = <String>[];
          final client = service.authenticatedClient(
            MockClient((request) async {
              requests.add(request);
              return messageResponse(
                requests.length == 1
                    ? [
                        {
                          'type': 'thinking',
                          'thinking': 'Keep exactly',
                          'signature': 'opaque-signature',
                        },
                        {
                          'type': 'tool_use',
                          'id': 'call-1',
                          'name': encodeClaudeOAuthToolName(toolName),
                          'input': <String, dynamic>{},
                        },
                      ]
                    : [
                        {'type': 'text', 'text': 'Done'},
                      ],
                stream: stream,
                tool: requests.length == 1,
              );
            }),
            config,
          );
          final chunks = await sendClaudeStream(
            client,
            config,
            'claude-sonnet-4-6',
            [
              {'role': 'system', 'content': 'Use the tool.'},
              {'role': 'user', 'content': 'Find an answer'},
            ],
            tools: [
              {
                'type': 'function',
                'function': {
                  'name': toolName,
                  'parameters': {'type': 'object', 'properties': {}},
                },
              },
            ],
            extraHeaders: providerSessionHeaders(
              config,
              conversationId: 'conversation-1',
            ),
            onToolCall: (name, args, {toolCallId}) async {
              calls.add(name);
              return 'Found it';
            },
            stream: stream,
          ).toList();
          expect(calls, [toolName]);
          expect(requests, hasLength(2));
          expect(
            chunks.whereType<TextDelta>().map((chunk) => chunk.text).join(),
            contains('Done'),
          );
          for (final request in requests) {
            final body = jsonDecode(request.body) as Map;
            expect(request.url.queryParameters['beta'], 'true');
            expect(
              request.headers['authorization'],
              'Bearer sk-ant-oat-access',
            );
            expect(request.headers, isNot(contains('x-api-key')));
            expect(
              request.headers['user-agent'],
              'claude-cli/2.1.257 (external, cli)',
            );
            expect(
              request.headers['anthropic-beta'],
              contains('extended-cache-ttl-2025-04-11'),
            );
            expect(
              (body['tools'] as List).single['name'],
              encodeClaudeOAuthToolName(toolName),
            );
            final system = body['system'] as List;
            expect(system[0]['text'], matches(RegExp(r'cch=[0-9a-f]{5};$')));
            expect(system[1]['text'], claudeCodeSystemInstruction);
            expect(system[2]['text'], 'Use the tool.');
            expect(cacheMarkers(body).length, lessThanOrEqualTo(4));
            expect(
              cacheMarkers(body).every((marker) => marker['ttl'] == '1h'),
              isTrue,
            );
            final identity =
                jsonDecode(body['metadata']['user_id'] as String) as Map;
            expect(identity['session_id'], 'conversation-1');
            expect(identity['account_uuid'], 'account-uuid');
          }
          final replay =
              (jsonDecode(requests.last.body)['messages'] as List)
                      .where((message) => message['role'] == 'assistant')
                      .first['content']
                  as List;
          expect(replay.first, {
            'type': 'thinking',
            'thinking': 'Keep exactly',
            'signature': 'opaque-signature',
          });
          expect(replay.last['name'], encodeClaudeOAuthToolName(toolName));
        },
      );
    }
  }

  test(
    '401 retries preserve the final OAuth body and multipart file uploads retain their content type',
    () async {
      final config = claudeConfig();
      await settings.setProviderConfig(config.id, config);
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient(
          (_) async => response(tokenResponse(access: 'sk-ant-oat-new')),
        ),
      )..bind(settings);
      final requests = <http.Request>[];
      final client = service.authenticatedClient(
        MockClient((request) async {
          requests.add(request);
          return requests.length == 1
              ? response({}, 401)
              : response({'id': 'file-id'});
        }),
        config,
      );
      final upload =
          http.MultipartRequest('POST', Uri.parse('${config.baseUrl}/files'))
            ..headers['anthropic-beta'] = 'files-api-2025-04-14'
            ..fields['purpose'] = 'tool-execution'
            ..files.add(
              http.MultipartFile.fromString(
                'file',
                'hello',
                filename: 'test.txt',
              ),
            );
      await client.send(upload);
      expect(requests, hasLength(2));
      expect(requests.first.bodyBytes, requests.last.bodyBytes);
      expect(requests.last.headers['authorization'], 'Bearer sk-ant-oat-new');
      expect(
        requests.last.headers['anthropic-beta'],
        contains('files-api-2025-04-14'),
      );
      expect(
        requests.last.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
    },
  );

  test(
    'Claude Messages 401 retry keeps attribution, cch and exactly one tool prefix',
    () async {
      final config = claudeConfig();
      await settings.setProviderConfig(config.id, config);
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient(
          (_) async => response(tokenResponse(access: 'sk-ant-oat-new')),
        ),
      )..bind(settings);
      final requests = <http.Request>[];
      final client = service.authenticatedClient(
        MockClient((request) async {
          requests.add(request);
          return response({}, requests.length == 1 ? 401 : 200);
        }),
        config,
      );
      await client.post(
        Uri.parse('${config.baseUrl}/messages'),
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'messages': [
            {'role': 'user', 'content': 'Use the tool'},
          ],
          'tools': [
            {
              'name': '_lookup',
              'input_schema': {'type': 'object'},
            },
          ],
          'tool_choice': {'type': 'tool', 'name': '_lookup'},
        }),
      );
      expect(requests, hasLength(2));
      expect(requests.first.bodyBytes, requests.last.bodyBytes);
      expect(
        requests.first.headers['x-claude-code-session-id'],
        requests.last.headers['x-claude-code-session-id'],
      );
      expect(requests.last.headers['authorization'], 'Bearer sk-ant-oat-new');
      final body = jsonDecode(requests.last.body) as Map;
      expect((body['tools'] as List).single['name'], '__lookup');
      expect(body['tool_choice']['name'], '__lookup');
    },
  );

  for (final ttl in ['1h', '5m', 'off']) {
    test('cache TTL $ttl shapes transport markers and preserves user text', () {
      final config = claudeConfig(ttl: ttl, cache: ttl != 'off');
      final input = <String, dynamic>{
        'model': 'claude-sonnet-4-6',
        'messages': [
          <String, dynamic>{
            'role': 'user',
            'content': 'cch=00000 is user text',
          },
        ],
        'system': 'Be concise.',
        'max_tokens': 128000,
        'stream': true,
      };
      final body =
          jsonDecode(
                encodeClaudeOAuthRequest(input, config, {}, 'conversation-1'),
              )
              as Map;
      final markers = cacheMarkers(body);
      expect(body['max_tokens'], 64000);
      expect(body['cache_control'], isNull);
      if (ttl == 'off') {
        expect(markers, isEmpty);
      } else {
        expect(markers, isNotEmpty);
        expect(
          markers.every(
            (marker) => marker['ttl'] == (ttl == '1h' ? '1h' : null),
          ),
          isTrue,
        );
      }
      expect(jsonEncode(body['messages']), contains('cch=00000 is user text'));
    });
  }

  test(
    'Claude raises output allowance for thinking and reserves OMP output buffer',
    () {
      for (final (budget, maximum, expectedMax, expectedBudget) in [
        (16000, 4096, 20000, 16000),
        (64000, 128000, 64000, 60000),
      ]) {
        final body =
            jsonDecode(
                  encodeClaudeOAuthRequest(
                    {
                      'model': 'claude-sonnet-4-5',
                      'messages': [
                        <String, dynamic>{'role': 'user', 'content': 'Think'},
                      ],
                      'max_tokens': maximum,
                      'thinking': <String, dynamic>{
                        'type': 'enabled',
                        'budget_tokens': budget,
                      },
                    },
                    claudeConfig(),
                    {},
                    'conversation-1',
                  ),
                )
                as Map;
        expect(body['max_tokens'], expectedMax);
        expect(body['thinking']['budget_tokens'], expectedBudget);
      }
    },
  );

  test(
    'Claude caches stable head, latest turn and the thirtieth user checkpoint',
    () {
      final body =
          jsonDecode(
                encodeClaudeOAuthRequest(
                  {
                    'model': 'claude-sonnet-4-6',
                    'messages': [
                      for (var turn = 1; turn <= 31; turn++) ...[
                        <String, dynamic>{
                          'role': 'user',
                          'content': 'User $turn',
                        },
                        <String, dynamic>{
                          'role': 'assistant',
                          'content': [
                            <String, dynamic>{
                              'type': 'text',
                              'text': 'Answer $turn',
                            },
                            <String, dynamic>{
                              'type': 'thinking',
                              'thinking': 'Reason',
                              'signature': 'signed',
                            },
                            <String, dynamic>{'type': 'fallback'},
                            <String, dynamic>{'type': 'tool_addition'},
                            <String, dynamic>{'type': 'tool_removal'},
                          ],
                        },
                      ],
                      <String, dynamic>{
                        'role': 'user',
                        'content': 'Temporary',
                        'clear_at': 'next_user_message',
                      },
                    ],
                    'tools': [
                      <String, dynamic>{
                        'name': 'lookup',
                        'input_schema': {'type': 'object'},
                      },
                    ],
                  },
                  claudeConfig(),
                  {},
                  'conversation-1',
                ),
              )
              as Map;
      final messages = body['messages'] as List;
      expect(cacheMarkers(body), hasLength(4));
      expect(cacheMarkers(messages[58]), hasLength(1));
      expect((messages[61]['content'] as List).first['cache_control'], {
        'type': 'ephemeral',
        'ttl': '1h',
      });
      expect(cacheMarkers(messages[28]), isEmpty);
      expect(cacheMarkers(messages.last), isEmpty);
      expect(
        (messages[61]['content'] as List)
            .skip(1)
            .every((block) => block['cache_control'] == null),
        isTrue,
      );
    },
  );
}
