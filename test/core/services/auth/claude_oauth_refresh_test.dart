import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:Kelivo/core/services/network/provider_http_exception.dart';

import '../../../support/business_test_harness.dart';
import 'claude_oauth_test.dart' show claudeConfig, response, tokenResponse;

const _revoked =
    'OAuth token has been revoked. Please refresh your existing token.';
const _orgDenied =
    'OAuth authentication is currently not allowed for this organization';

class _PausedTokenWrite extends SettingsProvider {
  _PausedTokenWrite(super.preferences);
  final published = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> setProviderConfig(String key, ProviderConfig config) async {
    await super.setProviderConfig(key, config);
    if (config.oauthCredentials?.accessToken == 'token-B' &&
        !published.isCompleted) {
      published.complete();
      await release.future;
    }
  }
}

http.Response _denial(int status, String message) => http.Response(
  jsonEncode({
    'error': {'type': 'permission_error', 'message': message},
  }),
  status,
  headers: {'x-request-id': 'test-response'},
);

Future<http.Response> _chat(http.Client client, ProviderConfig config) =>
    client.post(
      Uri.parse('${config.baseUrl}/messages'),
      body: jsonEncode({
        'model': 'claude-sonnet-4-6',
        'messages': [
          {'role': 'user', 'content': 'Hi'},
        ],
      }),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsProvider settings;
  setUp(() async {
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
  });
  tearDown(() => settings.dispose());

  Future<ProviderConfig> account({
    Duration remaining = const Duration(hours: 1),
  }) async {
    final initial = claudeConfig();
    final config = initial.copyWith(
      oauthCredentials: initial.oauthCredentials!.copyWith(
        expiresAt: clock.now().add(remaining),
      ),
    );
    await settings.setProviderConfig(config.id, config);
    return config;
  }

  ProviderOAuthService serviceWith(MockClientHandler handler) {
    final service = ProviderOAuthService(
      clientFactory: (_) => MockClient(handler),
    )..bind(settings);
    addTearDown(service.dispose);
    return service;
  }

  for (final accepted in [true, false]) {
    test(
      'invalid_scope retries exactly once without scope, accepted=$accepted',
      () async {
        final config = await account(remaining: Duration.zero);
        final bodies = <Map>[];
        final service = serviceWith((request) async {
          expect(
            request.url.toString(),
            'https://platform.claude.com/v1/oauth/token',
          );
          bodies.add(jsonDecode(request.body) as Map);
          return bodies.length == 2 && accepted
              ? response(tokenResponse(access: 'new'))
              : response({
                  'error': {'type': 'invalid_scope'},
                }, 400);
        });
        if (accepted) {
          expect((await service.resolve(config)).apiKey, 'new');
          expect(
            settings.providerConfigs[config.id]!.oauthCredentials!.refreshToken,
            'rotated-refresh',
          );
        } else {
          await expectLater(
            service.resolve(config),
            throwsA(
              isA<ProviderOAuthException>().having(
                (e) => e.code,
                'code',
                'invalid_scope',
              ),
            ),
          );
        }
        expect(bodies, hasLength(2));
        expect(bodies.first['scope'], contains('user:plugins'));
        expect(bodies.last, Map.of(bodies.first)..remove('scope'));
        expect(service.needsLogin(config.id), isFalse);
      },
    );
  }

  for (final (status, body, dead) in [
    (401, <String, Object>{}, false),
    (401, {'error': 'invalid_scope'}, false),
    (
      400,
      {'error': 'invalid_grant', 'error_description': 'account_on_hold'},
      false,
    ),
    (
      401,
      {
        'error': {
          'type': 'invalid_grant',
          'error_description': 'account_on_hold',
        },
      },
      false,
    ),
    (503, {'error': 'invalid_grant'}, false),
    (400, {'error': 'invalid_grant'}, true),
    (
      401,
      {
        'error': {'type': 'invalid_grant'},
      },
      true,
    ),
  ]) {
    test(
      'refresh refusal $status $body marks login required only for a dead grant',
      () async {
        final config = await account(remaining: Duration.zero);
        var exchanges = 0;
        final service = serviceWith((_) async {
          exchanges++;
          return response(body, status);
        });
        await expectLater(
          service.resolve(config),
          throwsA(
            isA<ProviderOAuthException>()
                .having(
                  (e) => e.kind,
                  'kind',
                  dead
                      ? ProviderOAuthFailure.loginRequired
                      : ProviderOAuthFailure.requestRejected,
                )
                .having((e) => e.statusCode, 'status', status),
          ),
        );
        expect(exchanges, 1);
        expect(service.needsLogin(config.id), dead);
      },
    );
  }

  for (final networkError in [false, true]) {
    test(
      'a failed early renewal keeps chat working for ten seconds, networkError=$networkError',
      () async {
        var now = DateTime.now();
        await withClock(Clock(() => now), () async {
          final config = await account(remaining: const Duration(minutes: 4));
          var exchanges = 0;
          final service = serviceWith((_) async {
            if (++exchanges > 1) return response(tokenResponse(access: 'new'));
            if (networkError) throw http.ClientException('connection lost');
            return response({}, 503);
          });
          final bearers = <String?>[];
          final client = service.authenticatedClient(
            MockClient((request) async {
              bearers.add(request.headers['authorization']);
              return response({});
            }),
            config,
          );
          addTearDown(client.close);
          await _chat(client, config);
          now = now.add(const Duration(seconds: 9));
          await _chat(client, config);
          expect(exchanges, 1);
          now = now.add(const Duration(seconds: 1));
          await _chat(client, config);
          expect(exchanges, 2);
          expect(bearers, [
            'Bearer sk-ant-oat-access',
            'Bearer sk-ant-oat-access',
            'Bearer new',
          ]);
          expect(service.needsLogin(config.id), isFalse);
        });
      },
    );
  }

  test(
    'expiry cuts short a renewal backoff and a failed exchange cannot return an expired token',
    () async {
      var now = DateTime.now();
      await withClock(Clock(() => now), () async {
        final config = await account(remaining: const Duration(seconds: 3));
        var exchanges = 0;
        final service = serviceWith((_) async {
          exchanges++;
          return response({}, 503);
        });
        expect(
          (await service.resolve(config)).apiKey,
          config.oauthCredentials!.accessToken,
        );
        now = now.add(const Duration(seconds: 3));
        await expectLater(
          service.resolve(config),
          throwsA(isA<ProviderOAuthException>()),
        );
        expect(exchanges, 2);
      });
    },
  );

  for (final (firstStatus, firstMessage, lastStatus, lastMessage, recovers) in [
    (403, _revoked, 200, '', true),
    (403, _orgDenied, 403, _orgDenied, false),
    (403, _revoked, 403, _revoked, true),
    (401, 'Unauthorized', 401, 'Unauthorized', true),
    (401, 'Unauthorized', 403, _revoked, true),
  ]) {
    test(
      'resource $firstStatus $firstMessage then $lastStatus preserves the result and login',
      () async {
        final config = await account();
        var exchanges = 0;
        final service = serviceWith((_) async {
          exchanges++;
          return response(tokenResponse(access: 'new'));
        });
        final sent = <http.Request>[];
        final client = service.authenticatedClient(
          MockClient((request) async {
            sent.add(request);
            return sent.length == 1
                ? _denial(firstStatus, firstMessage)
                : _denial(lastStatus, lastMessage);
          }),
          config,
        );
        addTearDown(client.close);
        final result = await _chat(client, config);
        expect(result.statusCode, lastStatus);
        expect(result.body, _denial(lastStatus, lastMessage).body);
        expect(result.headers['x-request-id'], 'test-response');
        expect(exchanges, recovers ? 1 : 0);
        expect(sent, hasLength(recovers ? 2 : 1));
        if (recovers) {
          expect(sent.last.headers['authorization'], 'Bearer new');
          expect(sent.last.bodyBytes, sent.first.bodyBytes);
        }
        expect(service.needsLogin(config.id), isFalse);
      },
    );
  }

  test(
    'a rejected bearer cannot be served from the proactive backoff',
    () async {
      final config = await account(remaining: const Duration(minutes: 4));
      var exchanges = 0;
      final service = serviceWith((_) async {
        exchanges++;
        return response({}, 503);
      });
      var sends = 0;
      final client = service.authenticatedClient(
        MockClient((_) async {
          sends++;
          return _denial(403, _revoked);
        }),
        config,
      );
      addTearDown(client.close);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          _chat(client, config),
          throwsA(
            isA<ProviderOAuthException>().having(
              (e) => e.statusCode,
              'refresh failure',
              503,
            ),
          ),
        );
      }
      expect(exchanges, 3);
      expect(sends, 1);
      expect(service.needsLogin(config.id), isFalse);
    },
  );

  test(
    'a late revoked response adopts the token another request already rotated',
    () async {
      final config = await account();
      var exchanges = 0;
      final service = serviceWith((_) async {
        exchanges++;
        return response(tokenResponse(access: 'new'));
      });
      final first = Completer<http.Response>();
      final firstSent = Completer<void>();
      var newSends = 0;
      final client = service.authenticatedClient(
        MockClient((request) async {
          if (!firstSent.isCompleted) {
            firstSent.complete();
            return first.future;
          }
          if (request.headers['authorization'] == 'Bearer new') {
            newSends++;
            return response({});
          }
          return _denial(403, _revoked);
        }),
        config,
      );
      addTearDown(client.close);
      final pending = _chat(client, config);
      await firstSent.future;
      expect((await _chat(client, config)).statusCode, 200);
      first.complete(_denial(403, _revoked));
      expect((await pending).statusCode, 200);
      expect(exchanges, 1);
      expect(newSends, 2);
    },
  );

  for (final readBeforeSendReturns in [false, true]) {
    test(
      'a 401 rejects the bearer when the error body fails, pre-read=$readBeforeSendReturns',
      () async {
        final config = await account(remaining: const Duration(minutes: 4));
        var exchanges = 0;
        final service = serviceWith((_) async {
          return ++exchanges == 1
              ? response({}, 503)
              : response(tokenResponse(access: 'new'));
        });
        final cause = http.ClientException('disconnected');
        final failedBody = ProviderHttpException.bodyReadFailure(401, const {
          'x-should-retry': 'false',
        }, cause);
        final client = service.authenticatedClient(
          MockClient.streaming((_, _) async {
            if (readBeforeSendReturns) throw failedBody;
            return http.StreamedResponse(Stream.error(failedBody), 401);
          }),
          config,
        );
        addTearDown(client.close);
        await expectLater(_chat(client, config), throwsA(same(failedBody)));
        expect((await service.resolve(config)).apiKey, 'new');
        expect(exchanges, 2);
      },
    );
  }

  test(
    'a 401 delivered after logout releases the unused response stream',
    () async {
      final config = await account();
      final service = serviceWith(
        (_) async => fail('logged out request cannot refresh'),
      );
      final sent = Completer<void>();
      final deliver = Completer<http.StreamedResponse>();
      var released = false;
      final body = StreamController<List<int>>(onCancel: () => released = true);
      final client = service.authenticatedClient(
        MockClient.streaming((_, _) async {
          sent.complete();
          return deliver.future;
        }),
        config,
      );
      addTearDown(client.close);
      final result = expectLater(
        _chat(client, config),
        throwsA(
          isA<ProviderOAuthException>().having(
            (e) => e.kind,
            'kind',
            ProviderOAuthFailure.cancelled,
          ),
        ),
      );
      await sent.future;
      await service.logout(config.id);
      deliver.complete(http.StreamedResponse(body.stream, 401));
      await result;
      expect(released, isTrue);
      await body.close();
    },
  );

  test('a refusal of a newly published bearer renews that bearer', () async {
    final harness = await createBusinessTestHarness();
    final paused = _PausedTokenWrite(harness.preferences);
    await paused.loaded;
    addTearDown(paused.dispose);
    final config = claudeConfig();
    await paused.setProviderConfig(config.id, config);
    var exchanges = 0;
    final service = serviceWith(
      (_) async => response(
        tokenResponse(access: ++exchanges == 1 ? 'token-B' : 'token-C'),
      ),
    )..bind(paused);
    final rotation = service.resolve(config, force: true);
    await paused.published.future;
    final sent = <String?>[];
    final client = service.authenticatedClient(
      MockClient((request) async {
        sent.add(request.headers['authorization']);
        return sent.last == 'Bearer token-B'
            ? _denial(403, _revoked)
            : response({});
      }),
      paused.providerConfigs[config.id]!,
    );
    addTearDown(client.close);
    final result = _chat(client, config);
    await Future<void>.delayed(Duration.zero);
    paused.release.complete();
    await rotation;
    expect((await result).statusCode, 200);
    expect(sent, ['Bearer token-B', 'Bearer token-C']);
    expect(exchanges, 2);
  });

  test(
    'usage can probe with an unexpired token after a temporary renewal failure',
    () async {
      final config = await account(remaining: const Duration(minutes: 4));
      var exchanges = 0;
      final service = serviceWith((request) async {
        if (request.url.host == 'platform.claude.com') {
          return ++exchanges == 1
              ? response({}, 503)
              : response(tokenResponse(access: 'new'));
        }
        if (request.url.path == '/api/oauth/profile') return response({}, 403);
        expect(request.url.path, '/api/oauth/usage');
        expect(request.headers['authorization'], 'Bearer sk-ant-oat-access');
        return response({
          'five_hour': {'utilization': 42},
        });
      });
      final usage = await service.fetchUsage(config);
      expect(usage.windows.single.usedPercent, 42);
      expect(service.needsLogin(config.id), isFalse);
      expect((await service.resolve(config)).apiKey, 'new');
      expect(exchanges, 2);
    },
  );

  test(
    'a Claude account refresh updates its seat and tolerates a profile outage',
    () async {
      final config = await account();
      http.Response profile(String type, String tier) => response({
        'organization': {'organization_type': type, 'rate_limit_tier': tier},
      });
      final profiles = [
        profile('unknown', 'default_claude_max_5x'),
        profile('claude_team', 'default_claude_max_5x'),
        response({}, 401),
        response({}),
        profile('claude_team', 'default'),
        profile('claude_max', 'default_claude_max_5x'),
        profile('claude_max', 'default_claude_max_20x'),
        profile('unknown', 'default_claude_max_5x'),
        profile('claude_pro', 'default'),
        profile('claude_enterprise', 'default'),
        response({}, 503),
      ].iterator;
      var reads = 0;
      final service = serviceWith((request) async {
        if (request.url.path == '/api/oauth/usage') {
          return response({
            'five_hour': {'utilization': ++reads},
          });
        }
        expect(request.url.path, '/api/oauth/profile');
        expect(profiles.moveNext(), isTrue);
        return profiles.current;
      });
      for (final plan in [
        null,
        'Team 5x',
        'Team 5x',
        'Team 5x',
        'Team',
        'Max 5x',
        'Max 20x',
        null,
        'Pro',
        'Enterprise',
      ]) {
        final usage = await service.fetchUsage(config);
        expect(usage.plan, plan);
        expect(service.cachedUsage(config)?.plan, plan);
        expect(usage.windows.single.usedPercent, reads);
        expect(service.needsLogin(config.id), isFalse);
      }
      final replacement = config.copyWith(
        oauthCredentials: ProviderOAuthCredentials.fromJson({
          ...config.oauthCredentials!.toJson(),
          'sessionId': 'other-session',
        }),
      );
      await settings.setProviderConfig(config.id, replacement);
      expect((await service.fetchUsage(replacement)).plan, isNull);
      expect(profiles.moveNext(), isFalse);
    },
  );

  test(
    'model discovery rejects the bearer as soon as 401 headers arrive',
    () async {
      final config = await account(remaining: const Duration(minutes: 4));
      var exchanges = 0;
      final reading = Completer<void>();
      final body = StreamController<List<int>>(onListen: reading.complete);
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient.streaming((request, _) async {
          if (request.url.host == 'platform.claude.com') {
            final refresh = ++exchanges == 1
                ? response({}, 503)
                : response(tokenResponse(access: 'new'));
            return http.StreamedResponse(
              Stream.value(refresh.bodyBytes),
              refresh.statusCode,
            );
          }
          return http.StreamedResponse(body.stream, 401);
        }),
      )..bind(settings);
      addTearDown(service.dispose);
      final result = expectLater(
        service.models(config),
        throwsA(
          isA<ProviderOAuthException>().having(
            (e) => e.kind,
            'kind',
            ProviderOAuthFailure.network,
          ),
        ),
      );
      await reading.future;
      try {
        expect((await service.resolve(config)).apiKey, 'new');
      } finally {
        body.addError(http.ClientException('disconnected'));
        await body.close();
        await result;
      }
      expect(exchanges, 2);
    },
  );

  test(
    'logout during token persistence cancels a pending usage replay',
    () async {
      final harness = await createBusinessTestHarness();
      final paused = _PausedTokenWrite(harness.preferences);
      await paused.loaded;
      addTearDown(paused.dispose);
      final config = claudeConfig();
      await paused.setProviderConfig(config.id, config);
      var probes = 0;
      final service = serviceWith((request) async {
        if (request.url.host == 'platform.claude.com') {
          return response(tokenResponse(access: 'token-B'));
        }
        probes++;
        return probes == 1
            ? _denial(403, _revoked)
            : response({
                'five_hour': {'utilization': 42},
              });
      })..bind(paused);
      final result = expectLater(
        service.fetchUsage(config),
        throwsA(
          isA<ProviderOAuthException>().having(
            (e) => e.kind,
            'kind',
            ProviderOAuthFailure.cancelled,
          ),
        ),
      );
      await paused.published.future;
      await service.logout(config.id);
      paused.release.complete();
      await result;
      expect(probes, 1);
      expect(paused.providerConfigs[config.id]!.oauthCredentials, isNull);
    },
  );

  test('plain resource denials keep a sanitized server explanation', () async {
    final config = await account();
    var requests = 0;
    final service = serviceWith((_) async {
      requests++;
      return http.Response(
        '$_orgDenied [${config.oauthCredentials!.accessToken}]',
        403,
      );
    });
    await expectLater(
      service.fetchUsage(config),
      throwsA(
        isA<ProviderOAuthException>().having(
          (e) => e.message,
          'redacted reason',
          '$_orgDenied [[redacted]]',
        ),
      ),
    );
    expect(requests, 1);
    expect(service.needsLogin(config.id), isFalse);
  });

  for (final usage in [false, true]) {
    test(
      'metadata recovers a revoked response once and keeps the account, usage=$usage',
      () async {
        final config = await account();
        var exchanges = 0;
        var resources = 0;
        final service = serviceWith((request) async {
          if (request.url.host == 'platform.claude.com') {
            exchanges++;
            return response(tokenResponse(access: 'new'));
          }
          resources++;
          if (resources > 1) return _denial(401, 'Unauthorized');
          return usage
              ? http.Response(_revoked, 403)
              : response({'error': _revoked}, 403);
        });
        await expectLater(
          usage ? service.fetchUsage(config) : service.models(config),
          throwsA(
            isA<ProviderOAuthException>().having(
              (e) => e.kind,
              'kind',
              usage
                  ? ProviderOAuthFailure.usageUnavailable
                  : ProviderOAuthFailure.requestRejected,
            ),
          ),
        );
        expect(exchanges, 1);
        expect(resources, 2);
        expect(service.needsLogin(config.id), isFalse);
      },
    );
  }
}
