import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/oauth_pkce.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/business_test_harness.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'browser login opens once and exchanges a code using the original PKCE verifier',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      addTearDown(settings.dispose);
      late Uri authorization;
      var launches = 0;
      var prompts = 0;
      var exchanges = 0;
      final service = ProviderOAuthService(
        clientFactory: (_) => MockClient((request) async {
          exchanges++;
          expect(request.url.toString(), OAuthProvider.chatgpt.tokenEndpoint);
          expect(request.bodyFields['code'], 'browser-code');
          expect(
            request.bodyFields['redirect_uri'],
            'http://localhost:1455/auth/callback',
          );
          expect(
            oauthPkceChallenge(request.bodyFields['code_verifier']!),
            authorization.queryParameters['code_challenge'],
          );
          final claims = base64UrlEncode(
            utf8.encode(
              jsonEncode({
                'https://api.openai.com/profile': {'email': 'test@example.com'},
              }),
            ),
          );
          return http.Response(
            jsonEncode({
              'access_token': 'e30.$claims.signature',
              'refresh_token': 'refresh',
              'expires_in': 3600,
            }),
            200,
          );
        }),
      )..bind(settings);
      final saved = await service.login(
        provider: OAuthProvider.chatgpt,
        cancellation: OAuthCancellation(),
        deviceCode: false,
        onPrompt: (prompt) {
          prompts++;
          expect(prompt.browserAuthorization, true);
          expect(prompt.userCode, isNull);
        },
        launcher: (url) async {
          launches++;
          authorization = url;
          expect(url.host, 'auth.openai.com');
          final client = HttpOverrides.runWithHttpOverrides(
            HttpClient.new,
            _RealHttpOverrides(),
          )..findProxy = (_) => 'DIRECT';
          try {
            final request = await client.getUrl(
              Uri.parse(url.queryParameters['redirect_uri']!).replace(
                queryParameters: {
                  'code': 'browser-code',
                  'state': url.queryParameters['state']!,
                },
              ),
            );
            final response = await request.close();
            await response.drain<void>();
          } finally {
            client.close(force: true);
          }
          return true;
        },
      );
      expect(launches, 1);
      expect(prompts, 1);
      expect(exchanges, 1);
      expect(saved.oauthCredentials!.email, 'test@example.com');
      final rebound = await HttpServer.bind(InternetAddress.loopbackIPv4, 1455);
      await rebound.close(force: true);
    },
  );
}
