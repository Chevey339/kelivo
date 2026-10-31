import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';

class _LocalHttpOverrides extends HttpOverrides {}

/// Keep the authenticated URL intact until the native transport opens it.
class _LocalHttpClient implements HttpClient {
  _LocalHttpClient(this.inner, this.port);

  final HttpClient inner;
  final int port;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => inner.openUrl(
    method,
    url.replace(scheme: 'http', host: '127.0.0.1', port: port),
  );

  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;

  @override
  set idleTimeout(Duration value) => inner.idleTimeout = value;

  @override
  void close({bool force = false}) => inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Claude OAuth connection tests apply model ceilings and thinking budgets',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      final oauth = ProviderOAuthService.instance..bind(settings);
      addTearDown(() {
        oauth.unbind(settings);
        settings.dispose();
      });
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final bodies = <Map>[];
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        bodies.add(body);
        final thinking = body['thinking'];
        if (thinking is Map && thinking['type'] == 'enabled') {
          final budget = thinking['budget_tokens'] as int;
          if (budget < 1024 || budget >= (body['max_tokens'] as int)) {
            request.response.statusCode = HttpStatus.badRequest;
          }
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write('{}');
        await request.response.close();
      });

      for (final (ceiling, budget, maximum, expectedMax, expectedBudget) in [
        (128000, null, null, 8, null),
        (128000, 4096, null, 8096, 4096),
        (4096, 4096, null, 4096, 1024),
        (128000, null, 999999, 128000, null),
      ]) {
        final config = ProviderConfig(
          id: 'claude-oauth-probe',
          enabled: true,
          name: 'Claude',
          apiKey: '',
          baseUrl: OAuthProvider.claude.baseUrl,
          providerType: ProviderKind.claude,
          oauthProvider: OAuthProvider.claude,
          oauthCredentials: ProviderOAuthCredentials(
            accessToken: 'sk-ant-oat-test',
            refreshToken: 'test-refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            sessionId: 'session',
          ),
          modelOverrides: {
            'local-alias': {
              'apiModelId': 'claude-sonnet-4-5',
              'maxOutput': ceiling,
              'body': [
                if (budget != null)
                  {
                    'key': 'thinking',
                    'value': jsonEncode({
                      'type': 'enabled',
                      'budget_tokens': budget,
                    }),
                  },
                if (maximum != null) {'key': 'max_tokens', 'value': '$maximum'},
              ],
            },
          },
        );
        await settings.setProviderConfig(config.id, config);
        await HttpOverrides.runZoned(
          () => ProviderManager.testConnection(config, 'local-alias'),
          createHttpClient: (context) => _LocalHttpClient(
            _LocalHttpOverrides().createHttpClient(context),
            server.port,
          ),
        );
        final body = bodies.last;
        expect(body['model'], 'claude-sonnet-4-5');
        expect(body['max_tokens'], expectedMax);
        expect((body['thinking'] as Map?)?['budget_tokens'], expectedBudget);
      }
      expect(bodies, hasLength(4));
    },
  );
}
