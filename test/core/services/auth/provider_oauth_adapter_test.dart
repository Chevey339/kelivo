import 'dart:convert';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/services/auth/oauth_cancellation.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_adapter.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
String jwt(Map<String, dynamic> data) =>
    'e30.${base64UrlEncode(utf8.encode(jsonEncode(data))).replaceAll('=', '')}.signature';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Grok device code respects slow_down, then returns account identity',
    () {
      fakeAsync((async) {
        var polls = 0;
        ProviderOAuthCredentials? result;
        OAuthLoginPrompt? prompt;
        final wire = OAuthWire(
          MockClient((request) async {
            if (request.url.path.contains('openid-configuration')) {
              return response({
                'token_endpoint': 'https://auth.x.ai/oauth2/token',
              });
            }
            if (request.url.path.endsWith('device/code')) {
              expect(
                request.bodyFields['client_id'],
                OAuthProvider.grok.clientId,
              );
              expect(request.bodyFields['scope'], contains('grok-cli:access'));
              return response({
                'device_code': 'device-secret',
                'user_code': 'ABCD',
                'verification_uri_complete':
                    'https://auth.x.ai/device?user_code=ABCD',
                'expires_in': 60,
                'interval': 1,
              });
            }
            if (request.url.path.endsWith('/token')) {
              expect(request.bodyFields['device_code'], 'device-secret');
              polls++;
              if (polls == 1) return response({'error': 'slow_down'}, 400);
              return response({
                'access_token': jwt({'sub': 'account'}),
                'refresh_token': 'refresh-secret',
                'expires_in': 3600,
              });
            }
            return response({'sub': 'account', 'email': 'test@example.com'});
          }),
        );
        GrokOAuthAdapter()
            .login(wire, OAuthCancellation(), (value) async => prompt = value)
            .then((value) => result = value);
        async.flushMicrotasks();
        expect(prompt!.userCode, 'ABCD');
        async.elapse(const Duration(seconds: 1));
        expect(polls, 1);
        async.elapse(const Duration(seconds: 5));
        expect(polls, 1);
        async.elapse(const Duration(seconds: 1));
        expect(result!.email, 'test@example.com');
        expect(result!.accountId, 'account');
      });
    },
  );

  test('cancelled polling has no remaining delay timer or token request', () {
    fakeAsync((async) {
      final cancellation = OAuthCancellation();
      Object? failure;
      var requests = 0;
      final wire = OAuthWire(
        MockClient((request) async {
          requests++;
          return response({
            'device_code': 'device',
            'user_code': 'CODE',
            'verification_uri': 'https://auth.kimi.com/device',
            'expires_in': 60,
            'interval': 5,
          });
        }),
      );
      KimiOAuthAdapter()
          .login(wire, cancellation, (_) async {})
          .then(
            (_) {},
            onError: (Object e) {
              failure = e;
            },
          );
      async.flushMicrotasks();
      cancellation.cancel();
      async.flushMicrotasks();
      expect(
        failure,
        isA<ProviderOAuthException>().having(
          (e) => e.kind,
          'kind',
          ProviderOAuthFailure.cancelled,
        ),
      );
      async.elapse(const Duration(minutes: 2));
      expect(requests, 1);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test(
    'ChatGPT device flow exchanges server verifier and preserves workspace identity',
    () {
      fakeAsync((async) {
        ProviderOAuthCredentials? result;
        final wire = OAuthWire(
          MockClient((request) async {
            if (request.url.path.endsWith('/usercode')) {
              return response({
                'device_auth_id': 'device',
                'user_code': 'CODE',
                'interval': '1',
              });
            }
            if (request.url.path.endsWith('deviceauth/token')) {
              return response({
                'authorization_code': 'code',
                'code_verifier': 'verifier',
              });
            }
            expect(
              request.bodyFields['redirect_uri'],
              'https://auth.openai.com/deviceauth/callback',
            );
            expect(request.bodyFields['code_verifier'], 'verifier');
            return response({
              'access_token': jwt({
                'https://api.openai.com/auth': {
                  'chatgpt_account_id': 'workspace',
                },
              }),
              'refresh_token': 'refresh',
              'expires_in': 3600,
              'id_token': jwt({
                'email': 'person@example.com',
                'https://api.openai.com/auth': {'chatgpt_plan_type': 'plus'},
              }),
            });
          }),
        );
        ChatGptOAuthAdapter()
            .login(wire, OAuthCancellation(), (_) async {})
            .then((value) => result = value);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        expect(result!.accountId, 'workspace');
        expect(result!.email, 'person@example.com');
        expect(result!.plan, 'plus');
      });
    },
  );

  test(
    'untrusted discovery endpoints never receive the refresh token',
    () async {
      var requests = 0;
      final wire = OAuthWire(
        MockClient((request) async {
          requests++;
          return response({'token_endpoint': 'https://example.com/token'});
        }),
      );
      final stored = ProviderOAuthCredentials(
        accessToken: 'access',
        refreshToken: 'secret',
        expiresAt: DateTime.now(),
        sessionId: 'session',
      );
      await expectLater(
        GrokOAuthAdapter().refresh(wire, stored),
        throwsA(isA<ProviderOAuthException>()),
      );
      expect(requests, 1);
    },
  );

  test(
    'refresh distinguishes a revoked grant from a temporary outage and keeps rotation',
    () async {
      final stored = ProviderOAuthCredentials(
        accessToken: 'access',
        refreshToken: 'secret',
        expiresAt: DateTime.now(),
        sessionId: 'session',
        deviceId: 'device',
      );
      final adapter = KimiOAuthAdapter();
      for (final entry in [
        (400, 'invalid_grant', ProviderOAuthFailure.loginRequired),
        (503, 'server_error', ProviderOAuthFailure.requestRejected),
      ]) {
        final wire = OAuthWire(
          MockClient(
            (_) async =>
                response({'error': entry.$2, 'private': 'secret'}, entry.$1),
          ),
        );
        await expectLater(
          adapter.refresh(wire, stored),
          throwsA(
            isA<ProviderOAuthException>()
                .having((e) => e.kind, 'kind', entry.$3)
                .having(
                  (e) => e.toString(),
                  'redaction',
                  isNot(contains('secret')),
                ),
          ),
        );
      }
      final refreshed = await adapter.refresh(
        OAuthWire(
          MockClient((request) async {
            expect(request.headers['X-Msh-Device-Id'], 'device');
            return response({
              'access_token': 'next',
              'refresh_token': 'rotated',
              'expires_in': 3600,
            });
          }),
        ),
        stored,
      );
      expect(refreshed.refreshToken, 'rotated');
      expect(refreshed.sessionId, stored.sessionId);
    },
  );

  test(
    'missing usage stays unknown; provider-specific windows and resets are preserved',
    () {
      final chatgpt = parseChatGptUsage({
        'plan_type': 'pro',
        'rate_limit': {
          'primary_window': {
            'used_percent': 35,
            'limit_window_seconds': 18000,
            'reset_at': 1800000000,
          },
          'secondary_window': {'limit_window_seconds': 604800},
        },
        'additional_rate_limits': [
          {
            'limit_name': 'Other models',
            'rate_limit': {
              'primary_window': {'used_percent': 12},
            },
          },
        ],
      });
      expect(chatgpt.windows[0].duration, const Duration(hours: 5));
      expect(chatgpt.windows[1].usedPercent, isNull);
      expect(chatgpt.windows[2].label, 'Other models');
      final grok = parseGrokUsage({
        'config': {
          'monthlyLimit': {'val': 1000},
          'used': {'val': 400},
          'billingPeriodEnd': '2026-10-01T00:00:00Z',
        },
      });
      expect(grok.windows.single.usedPercent, 40);
      final kimi = parseKimiUsage({
        'usage': {'limit': '100', 'remaining': '80'},
        'limits': [
          {
            'window': {'duration': 300, 'timeUnit': 'TIME_UNIT_MINUTE'},
            'detail': {
              'limit': 100,
              'remaining': 35,
              'resetTime': '2026-10-01T12:00:00Z',
            },
          },
        ],
      });
      expect(kimi.windows[0].usedPercent, 20);
      expect(kimi.windows[1].duration, const Duration(hours: 5));
      expect(kimi.windows[1].resetsAt, DateTime.utc(2026, 10, 1, 12));
    },
  );

  test(
    'Grok unified billing queries the monthly endpoint even with weekly data',
    () async {
      final requests = <Uri>[];
      final stored = ProviderOAuthCredentials(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now(),
        sessionId: 'session',
      );
      final result = await GrokOAuthAdapter().usage(
        OAuthWire(
          MockClient((request) async {
            requests.add(request.url);
            expect(request.headers['X-XAI-Token-Auth'], 'xai-grok-cli');
            return response({
              'config': request.url.hasQuery
                  ? {
                      'isUnifiedBillingUser': true,
                      'creditUsagePercent': 10,
                      'currentPeriod': {'end': '2026-10-01'},
                    }
                  : {
                      'monthlyLimit': {'val': 100},
                      'used': {'val': 20},
                      'billingPeriodEnd': '2026-10-01',
                    },
            });
          }),
        ),
        stored,
      );
      expect(requests, hasLength(2));
      expect(result.windows.single.usedPercent, 20);
    },
  );

  test(
    'Grok unified billing with zero monthly quota uses its active weekly window',
    () async {
      final end = DateTime.now().toUtc().add(const Duration(days: 7));
      final result = await GrokOAuthAdapter().usage(
        OAuthWire(
          MockClient(
            (request) async => response({
              'config': request.url.hasQuery
                  ? {
                      'isUnifiedBillingUser': true,
                      'currentPeriod': {
                        'type': 'USAGE_PERIOD_TYPE_WEEKLY',
                        'start': end
                            .subtract(const Duration(days: 7))
                            .toIso8601String(),
                        'end': end.toIso8601String(),
                      },
                    }
                  : {
                      'monthlyLimit': {'val': 0},
                      'used': {'val': 0},
                    },
            }),
          ),
        ),
        ProviderOAuthCredentials(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: end,
          sessionId: 'session',
        ),
      );
      expect(result.windows.single.id, 'weekly');
      expect(result.windows.single.usedPercent, 0);
      expect(result.windows.single.resetsAt, end);
    },
  );

  test(
    'Grok does not infer zero usage when monthly lookup fails or the weekly window expired',
    () async {
      final end = DateTime.now().toUtc().add(const Duration(days: 1));
      final stored = ProviderOAuthCredentials(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: end,
        sessionId: 'session',
      );
      await expectLater(
        GrokOAuthAdapter().usage(
          OAuthWire(
            MockClient(
              (request) async => request.url.hasQuery
                  ? response({
                      'config': {
                        'isUnifiedBillingUser': true,
                        'currentPeriod': {
                          'type': 'WEEKLY',
                          'start': end
                              .subtract(const Duration(days: 7))
                              .toIso8601String(),
                          'end': end.toIso8601String(),
                        },
                      },
                    })
                  : response({'message': 'unavailable'}, 503),
            ),
          ),
          stored,
        ),
        throwsA(
          isA<ProviderOAuthException>().having(
            (e) => e.statusCode,
            'HTTP status',
            503,
          ),
        ),
      );
      final expired = parseGrokUsage({
        'config': {
          'isUnifiedBillingUser': true,
          'currentPeriod': {
            'type': 'WEEKLY',
            'start': '2020-01-01',
            'end': '2020-01-08',
          },
          'monthlyLimit': {'val': 0},
          'used': {'val': 0},
        },
      }, allowInferredWeekly: true);
      expect(expired.windows, isEmpty);
    },
  );

  test(
    'Kimi quota denial retains HTTP status and the server explanation without credentials',
    () async {
      final stored = ProviderOAuthCredentials(
        accessToken: 'access-secret',
        refreshToken: 'refresh-secret',
        expiresAt: DateTime.now(),
        sessionId: 'session',
      );
      for (final scenario in [
        (
          status: 429,
          body: {
            'code': 'resource_exhausted',
            'message': 'insufficient balance',
            'details': [
              {
                'debug': {
                  'reason': 'REASON_QUOTA_EXCEEDED',
                  'localizedMessage': {'message': 'Credits used up.'},
                },
              },
            ],
          },
          kind: ProviderOAuthFailure.quotaExceeded,
        ),
        (
          status: 429,
          body: {'code': 'rate_limit', 'message': 'Too many requests'},
          kind: ProviderOAuthFailure.requestRejected,
        ),
        (
          status: 403,
          body: {
            'error': {
              'code': 'permission_denied',
              'message': 'No access for access-secret / refresh-secret',
            },
          },
          kind: ProviderOAuthFailure.requestRejected,
        ),
      ]) {
        await expectLater(
          KimiOAuthAdapter().usage(
            OAuthWire(
              MockClient((_) async => response(scenario.body, scenario.status)),
            ),
            stored,
          ),
          throwsA(
            isA<ProviderOAuthException>()
                .having((e) => e.kind, 'classification', scenario.kind)
                .having((e) => e.statusCode, 'HTTP status', scenario.status)
                .having((e) => e.message, 'server explanation', isNotEmpty)
                .having(
                  (e) => e.message,
                  'no access token',
                  isNot(contains('access-secret')),
                )
                .having(
                  (e) => e.message,
                  'no refresh token',
                  isNot(contains('refresh-secret')),
                ),
          ),
        );
      }
    },
  );

  test(
    'OAuth error parts survive persistence and reject malformed payloads',
    () {
      const part = ProviderAuthErrorPart(providerId: 'provider');
      expect(MessagePart.fromRow(part.kind, part.encodePayload()), part);
      for (final payload in ['[]', '{}', '{"providerId":4}', '{']) {
        expect(
          () => MessagePart.fromRow(part.kind, payload),
          throwsFormatException,
        );
      }
    },
  );
}
