import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/request_timeout.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';

import '../../../support/business_test_harness.dart';

class _RealHttpOverrides extends HttpOverrides {}

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
  late SettingsProvider settings;
  late ProviderConfig config;
  setUp(() async {
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    config = ProviderConfig(
      id: 'oauth-deadline',
      enabled: true,
      name: 'Codex',
      apiKey: '',
      baseUrl: OAuthProvider.chatgpt.baseUrl,
      providerType: ProviderKind.openai,
      oauthProvider: OAuthProvider.chatgpt,
      oauthCredentials: ProviderOAuthCredentials(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        accountId: 'test-account',
        sessionId: 'test-session',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await settings.setProviderConfig(config.id, config);
  });
  tearDown(() {
    ProviderOAuthService.instance.unbind(settings);
    settings.dispose();
  });

  for (final native in [false, true]) {
    for (final manualCancel in [false, true]) {
      test(
        'OAuth recovery obeys request cancellation: native=$native manual=$manualCancel',
        () async {
          final oauth = ProviderOAuthService.instance..bind(settings);
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          final refreshStarted = Completer<void>();
          final releaseRefresh = Completer<void>();
          var modelRequests = 0;
          server.listen((request) async {
            await request.drain<void>();
            if (request.uri.path.contains('oauth/token')) {
              refreshStarted.complete();
              await releaseRefresh.future;
              request.response.headers.contentType = ContentType.json;
              request.response.write(
                jsonEncode({'access_token': 'new-access', 'expires_in': 3600}),
              );
            } else {
              modelRequests++;
              request.response.statusCode = 401;
            }
            await request.response.close();
          });
          const timeout = Duration(milliseconds: 500);
          final call = HttpOverrides.runZoned(
            () => native
                ? ChatApiService.compactHistory(
                    config: config,
                    modelId: 'gpt-5.4',
                    messages: const [
                      {'role': 'user', 'content': 'history'},
                    ],
                    requestId: 'oauth-compression',
                    conversationId: 'chat',
                    requestTimeout: timeout,
                  )
                : ChatApiService.generateMessage(
                    config: config,
                    modelId: 'gpt-5.4',
                    messages: const [
                      {'role': 'user', 'content': 'history'},
                    ],
                    requestId: 'oauth-compression',
                    textOnly: true,
                    requestTimeout: timeout,
                  ),
            createHttpClient: (context) => _LocalHttpClient(
              _RealHttpOverrides().createHttpClient(context),
              server.port,
            ),
          );
          final expectation = expectLater(
            call.timeout(const Duration(seconds: 3)),
            throwsA(
              manualCancel
                  ? allOf(
                      isNot(isA<TimeoutException>()),
                      isNot(isA<RequestTimeoutException>()),
                    )
                  : isA<RequestTimeoutException>().having(
                      (e) => e.duration,
                      'deadline',
                      timeout,
                    ),
            ),
          );
          await refreshStarted.future.timeout(const Duration(seconds: 3));
          // A second consumer must still receive the refreshed credentials.
          final shared = oauth.resolve(config, force: true);
          try {
            if (manualCancel) ChatApiService.cancelRequest('oauth-compression');
            await expectation;
            expect(releaseRefresh.isCompleted, isFalse);
          } finally {
            releaseRefresh.complete();
            final refreshed = await shared;
            expect(refreshed.oauthCredentials!.accessToken, 'new-access');
          }
          expect(
            modelRequests,
            1,
            reason: 'Cancelled calls must not resend after refresh',
          );
        },
      );
    }
  }

  test(
    'authenticated client can stop waiting for its initial shared refresh',
    () async {
      config = config.copyWith(
        oauthCredentials: config.oauthCredentials!.copyWith(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      await settings.setProviderConfig(config.id, config);
      final started = Completer<void>();
      final refresh = Completer<http.Response>();
      final oauth = ProviderOAuthService(
        clientFactory: (_) => MockClient((_) {
          started.complete();
          return refresh.future;
        }),
      )..bind(settings);
      addTearDown(oauth.dispose);
      var sends = 0;
      final token = CancelToken();
      final client = oauth.authenticatedClient(
        MockClient((_) async {
          sends++;
          return http.Response('{}', 200);
        }),
        config,
        cancelToken: token,
      );
      addTearDown(client.close);
      final call = client.post(
        Uri.parse('${config.baseUrl}/responses'),
        body: '{}',
      );
      final expectation = expectLater(
        call.timeout(const Duration(seconds: 3)),
        throwsA(isNot(isA<TimeoutException>())),
      );
      await started.future;
      final shared = oauth.resolve(config, force: true);
      try {
        token.cancel('cancelled');
        await expectation;
        expect(refresh.isCompleted, isFalse);
      } finally {
        refresh.complete(
          http.Response(
            jsonEncode({'access_token': 'new-access', 'expires_in': 3600}),
            200,
          ),
        );
        expect((await shared).oauthCredentials!.accessToken, 'new-access');
      }
      expect(sends, 0);
    },
  );
}
