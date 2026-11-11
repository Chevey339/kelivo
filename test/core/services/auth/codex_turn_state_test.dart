import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/auth/codex_turn_state.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsProvider settings;
  late ProviderConfig config;
  setUp(() async {
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    addTearDown(settings.dispose);
    config = ProviderConfig(
      id: 'codex',
      enabled: true,
      name: 'Codex',
      apiKey: '',
      baseUrl: OAuthProvider.chatgpt.baseUrl,
      oauthProvider: OAuthProvider.chatgpt,
      oauthCredentials: ProviderOAuthCredentials(
        accessToken: 'access-A',
        refreshToken: 'refresh-A',
        sessionId: 'login-A',
        accountId: 'workspace-A',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await settings.setProviderConfig(config.id, config);
  });

  final url = Uri.parse('${OAuthProvider.chatgpt.baseUrl}/responses');
  http.Response response(String state, {int status = 200}) =>
      http.Response('{}', status, headers: {'x-codex-turn-state': state});

  test('401 refresh preserves turn state for the same account', () async {
    var refreshes = 0;
    final service = ProviderOAuthService(
      clientFactory: (_) => MockClient((request) async {
        refreshes++;
        return http.Response(
          jsonEncode({'access_token': 'fresh-A', 'expires_in': 3600}),
          200,
        );
      }),
    )..bind(settings);
    addTearDown(service.dispose);
    final requests = <http.Request>[];
    final client = service.authenticatedClient(
      MockClient((request) async {
        requests.add(request);
        return requests.length == 2
            ? response('ignore-401-state', status: 401)
            : response(
                requests.length == 1 ? 'ts-first' : 'ignore-later-state',
              );
      }),
      config,
    );
    addTearDown(client.close);
    await client.post(url, body: '{}');
    await client.post(url, body: '{}');
    await client.post(url, body: '{}');
    expect(refreshes, 1);
    expect(requests.map((r) => r.headers['x-codex-turn-state']), [
      null,
      'ts-first',
      'ts-first',
      'ts-first',
    ]);
    expect(requests.map((r) => r.headers['authorization']), [
      'Bearer access-A',
      'Bearer access-A',
      'Bearer fresh-A',
      'Bearer fresh-A',
    ]);
  });

  for (final change in ['login', 'workspace', 'provider']) {
    test(
      'turn state is cleared on $change ownership change and ignores late responses',
      () async {
        final service = ProviderOAuthService()..bind(settings);
        addTearDown(service.dispose);
        final state = CodexTurnState();
        final oldRequests = <http.Request>[];
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        final oldClient = service.authenticatedClient(
          MockClient((request) async {
            oldRequests.add(request);
            if (oldRequests.length == 1) return response('ts-A');
            started.complete();
            return pending.future;
          }),
          config,
          codexTurnState: state,
        );
        addTearDown(oldClient.close);
        await oldClient.post(url, body: '{}');
        final late = oldClient.post(url, body: '{}');
        await started.future;
        final next = config.copyWith(
          id: change == 'provider' ? 'codex-B' : config.id,
          oauthCredentials: ProviderOAuthCredentials(
            accessToken: 'access-B',
            refreshToken: 'refresh-B',
            sessionId: change == 'login' ? 'login-B' : 'login-A',
            accountId: change == 'workspace' ? 'workspace-B' : 'workspace-A',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        );
        await settings.setProviderConfig(next.id, next);
        final requests = <http.Request>[];
        final nextClient = service.authenticatedClient(
          MockClient((request) async {
            requests.add(request);
            return response('ts-B');
          }),
          next,
          codexTurnState: state,
        );
        addTearDown(nextClient.close);
        await nextClient.post(url, body: '{}');
        pending.complete(response('late-ts-A'));
        await late;
        await nextClient.post(url, body: '{}');
        expect(oldRequests.map((r) => r.headers['x-codex-turn-state']), [
          null,
          'ts-A',
        ]);
        expect(requests.map((r) => r.headers['x-codex-turn-state']), [
          null,
          'ts-B',
        ]);
        expect(
          requests.every(
            (r) => r.headers['authorization'] == 'Bearer access-B',
          ),
          true,
        );
      },
    );
  }

  test(
    'concurrent generations of one account keep independent routing',
    () async {
      final service = ProviderOAuthService()..bind(settings);
      addTearDown(service.dispose);
      final clients = <http.Client>[];
      final seen = <List<String?>>[];
      for (var i = 0; i < 2; i++) {
        final headers = <String?>[];
        seen.add(headers);
        final client = service.authenticatedClient(
          MockClient((request) async {
            headers.add(request.headers['x-codex-turn-state']);
            return response('ts-$i');
          }),
          config,
        );
        clients.add(client);
        addTearDown(client.close);
      }
      await Future.wait([
        for (final client in clients) client.post(url, body: '{}'),
      ]);
      await Future.wait([
        for (final client in clients) client.post(url, body: '{}'),
      ]);
      expect(seen, [
        [null, 'ts-0'],
        [null, 'ts-1'],
      ]);
    },
  );
}
