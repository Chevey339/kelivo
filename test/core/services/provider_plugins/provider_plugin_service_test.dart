import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/models/provider_plugin.dart';
import 'package:Kelivo/core/services/auth/oauth_cancellation.dart';
import 'package:Kelivo/core/services/provider_plugins/provider_plugin_service.dart';

import 'plugin_test_support.dart';

http.Response tokenResponse(String access, {String refresh = 'refresh-new'}) =>
    http.Response(
      jsonEncode({
        'access_token': access,
        'refresh_token': refresh,
        'token_type': 'Bearer',
        'expires_in': 3600,
      }),
      200,
    );

Matcher get cancelled => throwsA(
  isA<ProviderOAuthException>().having(
    (error) => error.kind,
    'kind',
    ProviderOAuthFailure.cancelled,
  ),
);

void main() {
  test(
    'install is offline and repeated plugin installs create separate accounts',
    () async {
      var network = 0;
      final store = MemoryPluginStore();
      final service = ProviderPluginService(
        store: store,
        clientFactory: (_) {
          network++;
          return MockClient((_) async => tokenResponse('new'));
        },
      );
      final manifest = ProviderPluginManifest.fromJson(manifestJson());
      final first = await service.install(manifest);
      final second = await service.install(manifest);
      expect(first.id, isNot(second.id));
      expect(first.providerPluginSession, isNull);
      expect(first.models, ['example-model']);
      expect(network, 0);
    },
  );

  test(
    'concurrent expiry refreshes are coalesced and rotation is persisted',
    () async {
      final original = pluginConfig(expired: true);
      final store = MemoryPluginStore([original]);
      final pending = Completer<http.Response>();
      var calls = 0;
      final service = ProviderPluginService(
        store: store,
        clock: () => testNow,
        clientFactory: (_) => MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      final requests = List.generate(10, (_) => service.resolve(original));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      pending.complete(tokenResponse('rotated'));
      for (final result in await Future.wait(requests)) {
        expect(
          result.providerPluginSession!.credentials.accessToken,
          'rotated',
        );
      }
      expect(
        store
            .read(original.id)!
            .providerPluginSession!
            .credentials
            .refreshToken,
        'refresh-new',
      );
      expect(store.read(original.id)!.apiKey, isEmpty);
    },
  );

  for (final remove in [false, true]) {
    test(
      '${remove ? 'uninstall' : 'logout'} cannot be undone by a late refresh',
      () async {
        final original = pluginConfig(expired: true);
        final store = MemoryPluginStore([original]);
        final response = Completer<http.Response>();
        final service = ProviderPluginService(
          store: store,
          clock: () => testNow,
          clientFactory: (_) => MockClient((_) => response.future),
        );
        final refreshing = service.resolve(original);
        final expectation = expectLater(refreshing, cancelled);
        await Future<void>.delayed(Duration.zero);
        if (remove) {
          await service.uninstall(original.id);
        } else {
          await service.logout(original.id);
        }
        response.complete(tokenResponse('must-not-persist'));
        await expectation;
        expect(store.read(original.id)?.providerPluginSession, isNull);
      },
    );
  }

  test('late refresh cannot overwrite a newly logged-in account', () async {
    final original = pluginConfig(expired: true);
    final store = MemoryPluginStore([original]);
    final refresh = Completer<http.Response>();
    final service = ProviderPluginService(
      store: store,
      clock: () => testNow,
      callbackFactory: (_, {loopbackRedirect, expectedState}) async =>
          TestCallback(),
      clientFactory: (_) => MockClient((request) async {
        if (request.bodyFields['grant_type'] == 'refresh_token') {
          return refresh.future;
        }
        return tokenResponse('new-login');
      }),
    );
    final refreshing = service.resolve(original);
    final expectation = expectLater(refreshing, cancelled);
    await Future<void>.delayed(Duration.zero);
    final loggedIn = await service.login(original.id, OAuthCancellation());
    refresh.complete(tokenResponse('stale-refresh'));
    await expectation;
    expect(
      loggedIn.providerPluginSession!.credentials.sessionId,
      isNot(original.providerPluginSession!.credentials.sessionId),
    );
    expect(
      store.read(original.id)!.providerPluginSession!.credentials.accessToken,
      'new-login',
    );
  });

  test(
    'edits to non-security settings made during refresh are preserved',
    () async {
      final original = pluginConfig(expired: true);
      final store = MemoryPluginStore([original]);
      final response = Completer<http.Response>();
      final service = ProviderPluginService(
        store: store,
        clock: () => testNow,
        clientFactory: (_) => MockClient((_) => response.future),
      );
      final refreshing = service.resolve(original);
      await store.save(
        original.copyWith(
          name: 'Changed while refreshing',
          models: ['new-model'],
        ),
      );
      response.complete(tokenResponse('updated'));
      await refreshing;
      expect(store.read(original.id)!.name, 'Changed while refreshing');
      expect(store.read(original.id)!.models, ['new-model']);
    },
  );

  test('changing an endpoint cannot redirect an existing login', () async {
    final original = pluginConfig();
    final store = MemoryPluginStore([original]);
    var requests = 0;
    final service = ProviderPluginService(
      store: store,
      clock: () => testNow,
      clientFactory: (_) {
        requests++;
        return MockClient((_) async => tokenResponse('x'));
      },
    );
    await store.save(original.copyWith(baseUrl: 'https://attacker.test/v1'));
    await expectLater(
      service.resolve(original),
      throwsA(isA<ProviderOAuthException>()),
    );
    expect(requests, 0);
  });

  test(
    'a session fingerprint cannot be reused for a modified manifest',
    () async {
      final original = pluginConfig();
      final changed = ProviderPluginManifest.fromJson(
        manifestJson()..['version'] = '2.0.0',
      );
      final tampered = original.copyWith(providerPlugin: changed);
      final store = MemoryPluginStore([tampered]);
      final service = ProviderPluginService(store: store, clock: () => testNow);
      await expectLater(
        service.resolve(tampered),
        throwsA(
          isA<ProviderOAuthException>().having(
            (error) => error.kind,
            'kind',
            ProviderOAuthFailure.loginRequired,
          ),
        ),
      );
    },
  );

  test(
    'invalid_grant marks a session for login without leaking server text',
    () async {
      final original = pluginConfig(expired: true);
      final store = MemoryPluginStore([original]);
      final service = ProviderPluginService(
        store: store,
        clock: () => testNow,
        clientFactory: (_) => MockClient(
          (_) async => http.Response(
            '{"error":"invalid_grant","error_description":"secret-token"}',
            400,
          ),
        ),
      );
      await expectLater(
        service.resolve(original),
        throwsA(
          isA<ProviderOAuthException>().having(
            (error) => error.message,
            'message',
            isNull,
          ),
        ),
      );
      expect(
        store
            .read(original.id)!
            .providerPluginSession!
            .credentials
            .requiresLogin,
        isTrue,
      );
    },
  );

  test('separate plugin instances never share refresh tokens', () async {
    final a = pluginConfig(id: 'a', expired: true, refreshToken: 'refresh-a');
    final b = pluginConfig(id: 'b', expired: true, refreshToken: 'refresh-b');
    final seen = <String>[];
    final store = MemoryPluginStore([a, b]);
    final service = ProviderPluginService(
      store: store,
      clock: () => testNow,
      clientFactory: (_) => MockClient((request) async {
        final token = request.bodyFields['refresh_token']!;
        seen.add(token);
        return tokenResponse('for-$token');
      }),
    );
    await Future.wait([service.resolve(a), service.resolve(b)]);
    expect(seen, unorderedEquals(['refresh-a', 'refresh-b']));
    expect(
      store.read('a')!.providerPluginSession!.credentials.accessToken,
      'for-refresh-a',
    );
    expect(
      store.read('b')!.providerPluginSession!.credentials.accessToken,
      'for-refresh-b',
    );
  });
}
