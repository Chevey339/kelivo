import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/business_test_harness.dart';

ProviderConfig _config({bool expired = false}) => ProviderConfig(
  id: 'account',
  enabled: true,
  name: 'ChatGPT',
  apiKey: '',
  baseUrl: OAuthProvider.chatgpt.baseUrl,
  oauthProvider: OAuthProvider.chatgpt,
  oauthCredentials: ProviderOAuthCredentials(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.now().add(Duration(hours: expired ? -1 : 1)),
    sessionId: 'session-A',
    accountId: 'workspace',
  ),
);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

http.Response _rotated() => _json({
  'access_token': 'fresh',
  'refresh_token': 'rotated',
  'expires_in': 3600,
});

http.Response _usage() => _json({
  'rate_limit': {
    'allowed': true,
    'primary_window': {'used_percent': 10},
  },
});

Matcher _failure(ProviderOAuthFailure kind) =>
    isA<ProviderOAuthException>().having((e) => e.kind, 'kind', kind);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsProvider settings;
  setUp(() async {
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
  });
  tearDown(() => settings.dispose());

  for (final status in [401, 503]) {
    test('usage $status keeps cached usage and leaves chat usable', () async {
      final original = _config();
      await settings.setProviderConfig(original.id, original);
      var failUsage = false;
      var refreshes = 0;
      var failedProbes = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((request) async {
          if (request.url.host == 'auth.openai.com') {
            refreshes++;
            return _rotated();
          }
          if (!failUsage) return _usage();
          failedProbes++;
          return _json({'error': 'usage endpoint unavailable'}, status);
        }),
      )..bind(settings);
      addTearDown(service.dispose);
      final cached = await service.fetchUsage(original);
      failUsage = true;
      await expectLater(
        service.fetchUsage(original),
        throwsA(
          _failure(
            status == 401
                ? ProviderOAuthFailure.usageUnavailable
                : ProviderOAuthFailure.requestRejected,
          ),
        ),
      );
      expect(failedProbes, status == 401 ? 2 : 1);
      expect(refreshes, status == 401 ? 1 : 0);
      expect(service.cachedUsage(original), same(cached));
      expect(service.needsLogin(original.id), isFalse);
      final saved = settings.providerConfigs[original.id]!;
      expect(
        saved.oauthCredentials!.refreshToken,
        status == 401 ? 'rotated' : 'refresh',
      );

      var chats = 0;
      final client = service.authenticatedClient(
        MockClient((request) async {
          chats++;
          expect(
            request.headers['authorization'],
            'Bearer ${saved.oauthCredentials!.accessToken}',
          );
          return _json({});
        }),
        original,
      );
      addTearDown(client.close);
      await client.post(
        Uri.parse('${original.baseUrl}/responses'),
        body: jsonEncode({
          'input': [
            {'role': 'user', 'content': 'Hi'},
          ],
        }),
      );
      expect(chats, 1);
    });
  }

  test(
    'a probe cannot disable a revoked grant; an interactive request still can',
    () async {
      final original = _config(expired: true);
      await settings.setProviderConfig(original.id, original);
      final service = ProviderOAuthService(
        clientFactory: (_) =>
            MockClient((_) async => _json({'error': 'invalid_grant'}, 400)),
      )..bind(settings);
      addTearDown(service.dispose);
      await expectLater(
        service.fetchUsage(original),
        throwsA(_failure(ProviderOAuthFailure.usageUnavailable)),
      );
      expect(service.needsLogin(original.id), isFalse);
      await expectLater(
        service.resolve(original),
        throwsA(_failure(ProviderOAuthFailure.loginRequired)),
      );
      expect(service.needsLogin(original.id), isTrue);
    },
  );

  for (final probeFirst in [false, true]) {
    for (final revoked in [false, true]) {
      test('shared refresh: probeFirst=$probeFirst revoked=$revoked', () async {
        final original = _config(expired: true);
        await settings.setProviderConfig(original.id, original);
        final pending = Completer<http.Response>();
        var refreshes = 0;
        final service = ProviderOAuthService(
          clientFactory: (_) => MockClient((request) async {
            if (request.url.host != 'auth.openai.com') return _usage();
            refreshes++;
            return pending.future;
          }),
        )..bind(settings);
        addTearDown(service.dispose);
        late Future<ProviderUsageSnapshot> probe;
        late Future<ProviderConfig> interactive;
        if (probeFirst) {
          probe = service.fetchUsage(original);
          interactive = service.resolve(original);
        } else {
          interactive = service.resolve(original);
          probe = service.fetchUsage(original);
        }
        final probeCheck = expectLater(
          probe,
          revoked
              ? throwsA(_failure(ProviderOAuthFailure.usageUnavailable))
              : completes,
        );
        final interactiveCheck = expectLater(
          interactive,
          revoked
              ? throwsA(_failure(ProviderOAuthFailure.loginRequired))
              : completes,
        );
        pending.complete(
          revoked ? _json({'error': 'invalid_grant'}, 400) : _rotated(),
        );
        await Future.wait([probeCheck, interactiveCheck]);
        expect(refreshes, 1);
        expect(service.needsLogin(original.id), revoked);
        if (!revoked) {
          expect((await interactive).apiKey, 'fresh');
          expect(
            settings
                .providerConfigs[original.id]!
                .oauthCredentials!
                .refreshToken,
            'rotated',
          );
          expect(service.cachedUsage(original), same(await probe));
        }
      });
    }
  }

  for (final duringRefresh in [false, true]) {
    for (final switchAccount in [false, true]) {
      test(
        'late probe cannot restore or invalidate an account: refresh=$duringRefresh switch=$switchAccount',
        () async {
          final original = _config(expired: duringRefresh);
          await settings.setProviderConfig(original.id, original);
          final started = Completer<void>();
          final response = Completer<http.Response>();
          final service = ProviderOAuthService(
            clientFactory: (_) => MockClient((_) {
              started.complete();
              return response.future;
            }),
          )..bind(settings);
          addTearDown(service.dispose);
          final probe = service.fetchUsage(original);
          final check = expectLater(
            probe,
            throwsA(_failure(ProviderOAuthFailure.cancelled)),
          );
          await started.future;
          await service.logout(original.id);
          if (switchAccount) {
            await settings.setProviderConfig(
              original.id,
              original.copyWith(
                oauthCredentials: ProviderOAuthCredentials(
                  sessionId: 'session-B',
                  accessToken: 'account-B',
                  refreshToken: 'refresh-B',
                  expiresAt: DateTime.now().add(const Duration(hours: 1)),
                ),
              ),
            );
          }
          response.complete(duringRefresh ? _rotated() : _json({}, 401));
          await check;
          final credentials =
              settings.providerConfigs[original.id]!.oauthCredentials;
          if (switchAccount) {
            expect(credentials!.accessToken, 'account-B');
            expect(credentials.requiresLogin, isFalse);
          } else {
            expect(credentials, isNull);
          }
          expect(service.cachedUsage(original), isNull);
        },
      );
    }
  }
}
