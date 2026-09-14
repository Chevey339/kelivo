import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/services/auth/oauth_cancellation.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_adapter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String jwt(Map<String, dynamic> claims) =>
    'e30.${base64UrlEncode(utf8.encode(jsonEncode(claims)))}.signature';
http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);

void main() {
  final adapter = ChatGptOAuthAdapter();
  final stored = ProviderOAuthCredentials(
    accessToken: 'old-access',
    refreshToken: 'old-refresh',
    expiresAt: DateTime.now(),
    sessionId: 'session',
    accountId: 'workspace',
    email: 'person@example.com',
    plan: 'plus',
  );

  test('ChatGPT requests the same scopes as OMP', () {
    expect(OAuthProvider.chatgpt.scope.split(' '), [
      'openid',
      'profile',
      'email',
      'offline_access',
      'api.connectors.read',
      'api.connectors.invoke',
    ]);
  });

  test('email-only identity is accepted without using sub as a workspace', () {
    final credentials = adapter.credentials({
      'access_token': jwt({
        'sub': 'user-id-is-not-a-workspace',
        'https://api.openai.com/profile': {'email': ' Person@Example.com '},
      }),
      'refresh_token': 'refresh',
      'expires_in': 3600,
    });
    expect(credentials.email, 'person@example.com');
    expect(credentials.accountId, isNull);
    expect(
      adapter.headers(credentials).containsKey('chatgpt-account-id'),
      false,
    );
    expect(
      () => adapter.credentials({
        'access_token': jwt({'sub': 'user-only'}),
        'refresh_token': 'refresh',
        'expires_in': 3600,
      }),
      throwsA(isA<ProviderOAuthException>()),
    );
  });

  test('refresh retains identity and rotates tokens like OMP', () async {
    final credentials = await adapter.refresh(
      OAuthWire(
        MockClient((request) async {
          expect(request.url.toString(), OAuthProvider.chatgpt.tokenEndpoint);
          expect(request.bodyFields, {
            'grant_type': 'refresh_token',
            'client_id': OAuthProvider.chatgpt.clientId,
            'refresh_token': stored.refreshToken,
          });
          return json({
            'access_token': jwt({'sub': 'user-is-not-a-workspace'}),
            'refresh_token': 'rotated',
            'expires_in': 3600,
          });
        }),
      ),
      stored,
    );
    expect(credentials.accountId, stored.accountId);
    expect(credentials.email, stored.email);
    expect(credentials.plan, stored.plan);
    expect(credentials.refreshToken, 'rotated');
    expect(credentials.sessionId, stored.sessionId);
  });

  test('token requests time out after OMP 15-second limit', () {
    fakeAsync((async) {
      Object? failure;
      adapter
          .refresh(
            OAuthWire(MockClient((_) => Completer<http.Response>().future)),
            stored,
          )
          .then<void>(
            (_) {},
            onError: (Object e) {
              failure = e;
            },
          );
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 14));
      expect(failure, isNull);
      async.elapse(const Duration(seconds: 1));
      expect(
        failure,
        isA<ProviderOAuthException>().having(
          (e) => e.kind,
          'kind',
          ProviderOAuthFailure.timeout,
        ),
      );
    });
  });

  test(
    'refresh rejection exposes the reason without exposing credentials',
    () async {
      await expectLater(
        adapter.refresh(
          OAuthWire(
            MockClient(
              (_) async => json({
                'error': {
                  'code': 'refresh_token_expired',
                  'message': 'Token expired: old-refresh',
                },
              }, 400),
            ),
          ),
          stored,
        ),
        throwsA(
          isA<ProviderOAuthException>()
              .having((e) => e.kind, 'kind', ProviderOAuthFailure.loginRequired)
              .having((e) => e.code, 'code', 'refresh_token_expired')
              .having((e) => e.message, 'message', 'Token expired: [redacted]'),
        ),
      );
    },
  );

  test(
    'device auth polls at 5s then interval + 3s, bounded to 120 attempts',
    () {
      fakeAsync((async) {
        var polls = 0;
        Object? failure;
        adapter
            .login(
              OAuthWire(
                MockClient((request) async {
                  if (request.url.path.endsWith('/usercode')) {
                    return json({
                      'device_auth_id': 'device',
                      'user_code': 'CODE',
                      'interval': '5',
                    });
                  }
                  expect(request.url.path, '/api/accounts/deviceauth/token');
                  expect(jsonDecode(request.body), {
                    'device_auth_id': 'device',
                    'user_code': 'CODE',
                  });
                  polls++;
                  return json({}, polls.isOdd ? 403 : 404);
                }),
              ),
              OAuthCancellation(),
              (_) async {},
            )
            .then<void>(
              (_) {},
              onError: (Object e) {
                failure = e;
              },
            );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        expect(polls, 0);
        async.elapse(const Duration(seconds: 1));
        expect(polls, 1);
        async.elapse(const Duration(seconds: 7));
        expect(polls, 1);
        async.elapse(const Duration(seconds: 1));
        expect(polls, 2);
        async.elapse(const Duration(seconds: 8 * 118));
        expect(polls, 120);
        expect(
          failure,
          isA<ProviderOAuthException>().having(
            (e) => e.kind,
            'kind',
            ProviderOAuthFailure.timeout,
          ),
        );
        expect(async.pendingTimers, isEmpty);
      });
    },
  );

  test(
    'model discovery retains subscription models and respects hidden entries',
    () async {
      final rows = await adapter.models(
        OAuthWire(
          MockClient((request) async {
            expect(request.url.path, '/backend-api/codex/models');
            expect(
              request.url.queryParameters['client_version'],
              codexClientVersion,
            );
            return json({
              'models': [
                {
                  'slug': 'subscription-model',
                  'supported_in_api': false,
                  'priority': 2,
                },
                {'id': 'id-only-model', 'priority': 1},
                {'slug': 'hidden-model', 'visibility': 'hidden'},
                {'slug': 'hidden-uppercase', 'visibility': 'HIDE'},
                {'display_name': 'missing id'},
              ],
            });
          }),
        ),
        stored,
      );
      expect(rows.map((row) => row['id']), [
        'id-only-model',
        'subscription-model',
      ]);
    },
  );

  test('usage clamps percentages and ignores windows with no usage fields', () {
    final usage = parseChatGptUsage({
      'rate_limit': {
        'primary_window': {
          'used_percent': 120,
          'reset_at': 1800000000,
          'reset_after_seconds': 10,
        },
        'secondary_window': {'used_percent': -1},
      },
      'additional_rate_limits': [
        {
          'rate_limit': {
            'primary_window': {'unrelated': 10},
          },
        },
      ],
    });
    expect(usage.windows.map((window) => window.usedPercent), [100, 0]);
    expect(usage.windows.first.resetsAt!.millisecondsSinceEpoch, 1800000000000);
  });

  test('usage preserves explicit meter state even without numeric windows', () {
    final unavailable = parseChatGptUsage({
      'rate_limit': {'allowed': false, 'limit_reached': true},
      'additional_rate_limits': {'unexpected': 'shape'},
    });
    expect(unavailable.hasData, true);
    expect(unavailable.allowed, false);
    expect(unavailable.limitReached, true);
    expect(unavailable.windows, isEmpty);
    expect(parseChatGptUsage({}).hasData, false);
  });

  for (final detailStatus in [200, 503]) {
    test(
      'reset-credit details are read-only and optional (HTTP $detailStatus)',
      () async {
        final paths = <String>[];
        final usage = await adapter.usage(
          OAuthWire(
            MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.headers['authorization'], 'Bearer old-access');
              expect(request.headers['chatgpt-account-id'], 'workspace');
              paths.add(request.url.path);
              if (request.url.path.endsWith('/usage')) {
                return json({
                  'rate_limit': {
                    'allowed': true,
                    'limit_reached': false,
                    'primary_window': {'used_percent': 100},
                  },
                  'rate_limit_reset_credits': {'available_count': 2},
                });
              }
              return json({'available_count': 0, 'credits': []}, detailStatus);
            }),
          ),
          stored,
        );
        expect(paths, [
          '/backend-api/wham/usage',
          '/backend-api/wham/rate-limit-reset-credits',
        ]);
        expect(usage.resetCredits, detailStatus == 200 ? 0 : 2);
        expect(usage.windows.single.usedPercent, 100);
        expect(usage.allowed, true);
        expect(usage.limitReached, false);
      },
    );
  }
}
