import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/models/provider_plugin.dart';
import 'package:Kelivo/core/services/provider_plugins/plugin_http_client.dart';
import 'package:Kelivo/core/services/provider_plugins/provider_plugin_service.dart';

import 'plugin_test_support.dart';

void main() {
  test(
    'injects bearer at transport boundary and removes native key headers/query',
    () async {
      final config = pluginConfig();
      final service = ProviderPluginService(
        store: MemoryPluginStore([config]),
        clock: () => testNow,
      );
      final client = PluginHttpClient(
        MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer access-old');
          expect(request.headers['x-api-key'], isNull);
          expect(request.headers['x-goog-api-key'], isNull);
          expect(request.headers['cookie'], isNull);
          expect(request.url.queryParameters, {'alt': 'sse'});
          expect(request.followRedirects, isFalse);
          expect(request.body, '{"model":"example-model"}');
          return http.Response('data: hello\n\n', 200);
        }),
        config,
        service,
      );
      addTearDown(client.close);
      final response = await client.post(
        Uri.parse(
          'https://api.example.test/v1/chat/completions?key=old&alt=sse',
        ),
        headers: {
          'x-api-key': 'wrong',
          'x-goog-api-key': 'wrong',
          'cookie': 'wrong',
        },
        body: '{"model":"example-model"}',
      );
      expect(response.body, 'data: hello\n\n');
    },
  );

  test(
    '401 refresh retries exactly once with the unchanged request body',
    () async {
      final config = pluginConfig();
      final store = MemoryPluginStore([config]);
      var refreshes = 0;
      final service = ProviderPluginService(
        store: store,
        clock: () => testNow,
        clientFactory: (_) => MockClient((_) async {
          refreshes++;
          return http.Response(
            jsonEncode({
              'access_token': 'access-new',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
          );
        }),
      );
      final tokens = <String>[];
      final client = PluginHttpClient(
        MockClient((request) async {
          tokens.add(request.headers['authorization']!);
          expect(request.body, 'request-body');
          return http.Response('unauthorized', 401);
        }),
        config,
        service,
      );
      addTearDown(client.close);
      final response = await client.post(
        Uri.parse('https://api.example.test/v1/chat/completions'),
        body: 'request-body',
      );
      expect(response.statusCode, 401);
      expect(tokens, ['Bearer access-old', 'Bearer access-new']);
      expect(refreshes, 1);
      expect(
        store.read(config.id)!.providerPluginSession!.credentials.requiresLogin,
        isTrue,
      );
    },
  );

  test(
    'cross-origin and out-of-prefix calls are rejected before network access',
    () async {
      final config = pluginConfig();
      var calls = 0;
      final service = ProviderPluginService(
        store: MemoryPluginStore([config]),
        clock: () => testNow,
      );
      final client = PluginHttpClient(
        MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
        config,
        service,
      );
      addTearDown(client.close);
      for (final url in [
        'https://evil.test/v1/models',
        'https://api.example.test/admin',
      ]) {
        await expectLater(
          client.get(Uri.parse(url)),
          throwsA(isA<ProviderOAuthException>()),
        );
      }
      expect(calls, 0);
    },
  );

  test('redirect responses are not followed with credentials', () async {
    final config = pluginConfig();
    var calls = 0;
    final service = ProviderPluginService(
      store: MemoryPluginStore([config]),
      clock: () => testNow,
    );
    final client = PluginHttpClient(
      MockClient((request) async {
        calls++;
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          307,
          headers: {'location': 'https://evil.test/steal'},
        );
      }),
      config,
      service,
    );
    addTearDown(client.close);
    expect(
      (await client.get(
        Uri.parse('https://api.example.test/v1/models'),
      )).statusCode,
      307,
    );
    expect(calls, 1);
  });

  test('multipart requests are forwarded but never replayed on 401', () async {
    final config = pluginConfig();
    var sends = 0;
    var refreshes = 0;
    final service = ProviderPluginService(
      store: MemoryPluginStore([config]),
      clock: () => testNow,
      clientFactory: (_) {
        refreshes++;
        return MockClient((_) async => http.Response('', 500));
      },
    );
    final client = PluginHttpClient(
      MockClient((request) async {
        sends++;
        expect(request.headers['authorization'], 'Bearer access-old');
        return http.Response('', 401);
      }),
      config,
      service,
    );
    addTearDown(client.close);
    final upload = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.example.test/v1/images/edits'),
    )..fields['prompt'] = 'a picture';
    final response = await client.send(upload);
    await response.stream.drain<void>();
    expect(response.statusCode, 401);
    expect(sends, 1);
    expect(refreshes, 0);
  });

  test(
    'API-key plugins preserve protocol headers and still disable redirects',
    () async {
      final config = pluginConfig(
        manifest: ProviderPluginManifest.fromJson(manifestJson(oauth: false)),
      );
      final client = PluginHttpClient(
        MockClient((request) async {
          expect(request.headers['x-api-key'], 'user-key');
          expect(request.followRedirects, isFalse);
          return http.Response('', 200);
        }),
        config,
        ProviderPluginService(store: MemoryPluginStore([config])),
      );
      addTearDown(client.close);
      await client.get(
        Uri.parse('https://api.example.test/v1/models'),
        headers: {'x-api-key': 'user-key'},
      );
    },
  );

  test('closed clients do not acquire tokens or send requests', () async {
    final config = pluginConfig();
    final client = PluginHttpClient(
      MockClient((_) async => throw StateError('must not send')),
      config,
      ProviderPluginService(store: MemoryPluginStore([config])),
    );
    client.close();
    await expectLater(
      client.get(Uri.parse('https://api.example.test/v1/models')),
      throwsA(isA<ProviderOAuthException>()),
    );
  });
}
