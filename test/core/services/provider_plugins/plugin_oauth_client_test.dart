import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/models/provider_plugin.dart';
import 'package:Kelivo/core/services/auth/oauth_cancellation.dart';
import 'package:Kelivo/core/services/auth/oauth_pkce.dart';
import 'package:Kelivo/core/services/provider_plugins/plugin_oauth_client.dart';

import 'plugin_test_support.dart';

void main() {
  final oauth = ProviderPluginManifest.fromJson(manifestJson()).oauth!;
  final validBody = {
    'access_token': 'access-new',
    'refresh_token': 'refresh-new',
    'token_type': 'Bearer',
    'expires_in': 3600,
  };

  test(
    'browser login uses S256 PKCE, state, public client and exact redirect',
    () async {
      final callback = TestCallback();
      final client = MockClient((request) async {
        expect(request.url, oauth.tokenEndpoint);
        expect(request.followRedirects, isFalse);
        expect(request.bodyFields['grant_type'], 'authorization_code');
        expect(request.bodyFields['client_id'], oauth.clientId);
        expect(request.bodyFields['client_secret'], isNull);
        expect(request.bodyFields['code'], 'one-time-code');
        expect(
          request.bodyFields['redirect_uri'],
          callback.redirectUri.toString(),
        );
        final authorization = callback.authorization!.queryParameters;
        expect(authorization['code_challenge_method'], 'S256');
        expect(
          authorization['code_challenge'],
          oauthPkceChallenge(request.bodyFields['code_verifier']!),
        );
        expect(authorization['state']!.length, greaterThanOrEqualTo(43));
        return http.Response(jsonEncode(validBody), 200);
      });
      final api = PluginOAuthClient(
        client: client,
        clock: () => testNow,
        callbackFactory: (_, {loopbackRedirect, expectedState}) async =>
            callback,
      );
      final credentials = await api.login(oauth, OAuthCancellation());
      expect(credentials.accessToken, 'access-new');
      expect(credentials.expiresAt, testNow.add(const Duration(hours: 1)));
      expect(callback.closed, isTrue);
    },
  );

  test(
    'strict callbacks reject duplicated parameters and wrong destinations',
    () {
      final expected = Uri.parse('http://127.0.0.1:4521/oauth/callback');
      for (final suffix in [
        '?code=x&state=wrong',
        '?code=x&state=s&state=s',
        '?code=x&code=y&state=s',
        '?code=x&error=denied&state=s',
        '?error=denied&error=other&state=s',
        '?code=x&state=s#token',
        '?state=s',
      ]) {
        expect(
          () => PluginOAuthClient.validateCallback(
            Uri.parse('$expected$suffix'),
            expected,
            's',
          ),
          throwsA(isA<ProviderOAuthException>()),
        );
      }
      expect(
        () => PluginOAuthClient.validateCallback(
          Uri.parse('http://127.0.0.1:4522/oauth/callback?code=x&state=s'),
          expected,
          's',
        ),
        throwsA(isA<ProviderOAuthException>()),
      );
      expect(
        () => PluginOAuthClient.validateCallback(
          Uri.parse('$expected?code=x&state=s'),
          expected,
          's',
          issuer: Uri.parse('https://auth.example.test'),
        ),
        throwsA(isA<ProviderOAuthException>()),
      );
    },
  );

  test(
    'refresh retains omitted refresh token and preserves session id',
    () async {
      final previous = pluginConfig().providerPluginSession!.credentials;
      final api = PluginOAuthClient(
        clock: () => testNow,
        client: MockClient((request) async {
          expect(request.bodyFields['refresh_token'], previous.refreshToken);
          return http.Response(
            jsonEncode({
              'access_token': 'rotated',
              'token_type': 'bearer',
              'expires_in': '7200',
            }),
            200,
          );
        }),
      );
      final next = await api.refresh(oauth, previous);
      expect(next.refreshToken, previous.refreshToken);
      expect(next.sessionId, previous.sessionId);
      expect(next.accessToken, 'rotated');
    },
  );

  test('access-only grants are accepted but cannot be refreshed', () async {
    final callback = TestCallback();
    final api = PluginOAuthClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'access_token': 'access-only',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        ),
      ),
      callbackFactory: (_, {loopbackRedirect, expectedState}) async => callback,
    );
    final credentials = await api.login(oauth, OAuthCancellation());
    expect(credentials.refreshToken, isEmpty);
    await expectLater(
      api.refresh(oauth, credentials),
      throwsA(
        isA<ProviderOAuthException>().having(
          (e) => e.kind,
          'kind',
          ProviderOAuthFailure.loginRequired,
        ),
      ),
    );
  });

  var invalidCase = 0;
  for (final invalid in [
    {...validBody, 'token_type': 'MAC'},
    {...validBody, 'expires_in': 0},
    {...validBody, 'expires_in': 'NaN'},
    {...validBody, 'access_token': 'a\r\nb'},
    {...validBody, 'access_token': ''},
    {...validBody, 'refresh_token': 123},
  ]) {
    test('rejects malformed token response ${invalidCase++}', () async {
      final api = PluginOAuthClient(
        client: MockClient(
          (_) async => http.Response(jsonEncode(invalid), 200),
        ),
      );
      await expectLater(
        api.refresh(oauth, pluginConfig().providerPluginSession!.credentials),
        throwsA(isA<ProviderOAuthException>()),
      );
    });
  }

  test(
    'token redirects, oversized responses and server secrets are not accepted',
    () async {
      for (final response in [
        http.Response('', 302, headers: {'location': 'https://evil.test'}),
        http.Response('x' * (PluginOAuthClient.maxResponseBytes + 1), 200),
        http.Response(
          '{"error":"invalid_grant","error_description":"secret"}',
          400,
        ),
      ]) {
        final api = PluginOAuthClient(
          client: MockClient((_) async => response),
        );
        try {
          await api.refresh(
            oauth,
            pluginConfig().providerPluginSession!.credentials,
          );
          fail('Must reject response');
        } on ProviderOAuthException catch (error) {
          expect(error.toString(), isNot(contains('secret')));
          expect(error.message, isNull);
        }
      }
    },
  );

  test(
    'a pre-cancelled login does not open the browser or send a request',
    () async {
      var opened = false;
      var sent = false;
      final api = PluginOAuthClient(
        client: MockClient((_) async {
          sent = true;
          return http.Response('', 200);
        }),
        callbackFactory: (_, {loopbackRedirect, expectedState}) async {
          opened = true;
          return TestCallback();
        },
      );
      final cancellation = OAuthCancellation()..cancel();
      await expectLater(
        api.login(oauth, cancellation),
        throwsA(isA<ProviderOAuthException>()),
      );
      expect(opened, isFalse);
      expect(sent, isFalse);
    },
  );
}
