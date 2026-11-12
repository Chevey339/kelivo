import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/models/api_keys.dart';
import 'package:Kelivo/core/services/provider_balance_service.dart';

ProviderConfig _providerConfig(
  String baseUrl, {
  ProviderKind kind = ProviderKind.openai,
}) {
  return ProviderConfig(
    id: 'BalanceTest',
    enabled: true,
    name: 'BalanceTest',
    apiKey: 'balance-key',
    baseUrl: baseUrl,
    providerType: kind,
    balanceEnabled: true,
    balanceApiPath: '/credits',
    balanceResultPath: 'data.total_credits - data.total_usage',
  );
}

void main() {
  group('ProviderBalanceValueParser', () {
    test('reads dotted paths and array indexes', () {
      final body = jsonDecode('''
      {
        "balance_infos": [
          {"total_balance": 12.345}
        ]
      }
      ''');

      expect(
        ProviderBalanceValueParser.format(
          body,
          'balance_infos[0].total_balance',
        ),
        '12.35',
      );
    });

    test('subtracts two numeric JSON paths', () {
      final body = jsonDecode('''
      {
        "data": {
          "total_credits": 20,
          "total_usage": 7.755
        }
      }
      ''');

      expect(
        ProviderBalanceValueParser.format(
          body,
          'data.total_credits - data.total_usage',
        ),
        '12.25',
      );
    });

    test('returns non numeric values without numeric formatting', () {
      final body = jsonDecode('{"data":{"plan":"trial"}}');

      expect(ProviderBalanceValueParser.format(body, 'data.plan'), 'trial');
    });
  });

  group('ProviderBalanceService', () {
    test(
      'MaruCode defaults support manual balance queries while disabled',
      () async {
        final requests = <HttpRequest>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          requests.add(request);
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'remaining': 606.26}));
          await request.response.close();
        });

        final config = ProviderConfig.defaultsFor('MaruCode').copyWith(
          baseUrl: 'http://${server.address.address}:${server.port}/v1',
          apiKey: 'balance-key',
        );
        expect(config.enabled, isFalse);
        expect(config.balanceEnabled, isTrue);
        expect(await ProviderBalanceService.fetchBalance(config), '606.26');
        expect(requests, hasLength(1));
        expect(requests.single.uri.path, '/v1/usage');
        expect(
          requests.single.headers.value(HttpHeaders.authorizationHeader),
          'Bearer balance-key',
        );
      },
    );

    for (final kind in ProviderKind.values) {
      test(
        '${kind.name} requests configured balance path with bearer auth',
        () async {
          final requests = <HttpRequest>[];
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() async {
            await server.close(force: true);
          });

          server.listen((request) async {
            requests.add(request);
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'data': {'total_credits': 20, 'total_usage': 7.755},
              }),
            );
            await request.response.close();
          });

          final balance = await ProviderBalanceService.fetchBalance(
            _providerConfig(
              'http://${server.address.address}:${server.port}/v1',
              kind: kind,
            ),
          );

          expect(balance, '12.25');
          expect(requests, hasLength(1));
          expect(requests.single.method, 'GET');
          expect(requests.single.uri.path, '/v1/credits');
          expect(
            requests.single.headers.value(HttpHeaders.authorizationHeader),
            'Bearer balance-key',
          );
          expect(requests.single.headers.value('x-api-key'), isNull);
          expect(requests.single.headers.value('x-goog-api-key'), isNull);
        },
      );
    }

    test('throws useful error for non success responses', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        request.response.statusCode = HttpStatus.paymentRequired;
        request.response.write('quota unavailable');
        await request.response.close();
      });

      expect(
        () => ProviderBalanceService.fetchBalance(
          _providerConfig('http://${server.address.address}:${server.port}/v1'),
        ),
        throwsA(
          isA<ProviderBalanceException>().having(
            (e) => e.message,
            'message',
            contains('HTTP 402'),
          ),
        ),
      );
    });

    for (final kind in ProviderKind.values) {
      test('${kind.name} rejects disabled balance queries', () {
        expect(
          () => ProviderBalanceService.fetchBalance(
            _providerConfig(
              'https://example.test/v1',
              kind: kind,
            ).copyWith(balanceEnabled: false),
          ),
          throwsA(
            isA<ProviderBalanceException>().having(
              (error) => error.message,
              'message',
              'Balance query is disabled',
            ),
          ),
        );
      });
    }
  });

  group('ProviderConfig balance defaults', () {
    test(
      'uses provider specific balance endpoints for OpenAI compatible presets',
      () {
        final aihubmix = ProviderConfig.defaultsFor('AIhubmix');
        final openRouter = ProviderConfig.defaultsFor('OpenRouter');
        final siliconFlow = ProviderConfig.defaultsFor('SiliconFlow');
        final vercel = ProviderConfig.defaultsFor('Vercel');
        final deepSeek = ProviderConfig.defaultsFor('DeepSeek');
        final moonshot = ProviderConfig.defaultsFor('Moonshot');

        expect(aihubmix.balanceEnabled, isFalse);
        expect(aihubmix.balanceApiPath, '/user/balance');
        expect(aihubmix.balanceResultPath, 'balance_infos[0].total_balance');
        expect(openRouter.balanceEnabled, isFalse);
        expect(openRouter.balanceApiPath, '/credits');
        expect(
          openRouter.balanceResultPath,
          'data.total_credits - data.total_usage',
        );
        expect(siliconFlow.balanceEnabled, isFalse);
        expect(vercel.balanceEnabled, isFalse);
        expect(vercel.balanceApiPath, '/credits');
        expect(vercel.balanceResultPath, 'balance');
        expect(deepSeek.balanceEnabled, isFalse);
        expect(deepSeek.balanceApiPath, '/user/balance');
        expect(deepSeek.balanceResultPath, 'balance_infos[0].total_balance');
        expect(moonshot.balanceEnabled, isFalse);
        expect(moonshot.balanceApiPath, '/users/me/balance');
        expect(moonshot.balanceResultPath, 'data.available_balance');
      },
    );
  });

  for (final kind in ProviderKind.values) {
    group('${kind.name} custom balance requests', () {
      late HttpServer server;
      late ProviderConfig config;
      final requests =
          <({String method, Uri uri, HttpHeaders headers, String body})>[];

      setUp(() async {
        requests.clear();
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        config = _providerConfig(
          'http://${server.address.address}:${server.port}/v1',
          kind: kind,
        ).copyWith(balanceResultPath: 'usd_balance');
        server.listen((request) async {
          requests.add((
            method: request.method,
            uri: request.uri,
            headers: request.headers,
            body: await utf8.decoder.bind(request).join(),
          ));
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'usd_balance': '19.25'}));
          await request.response.close();
        });
      });
      tearDown(() => server.close(force: true));

      test(
        'NanoGPT style POST uses an absolute URL, x-api-key and no body',
        () async {
          config = config.copyWith(
            balanceMethod: 'POST',
            balanceApiPath:
                'http://${server.address.address}:${server.port}/api/check-balance?account=main',
            balanceHeaders: const [
              {'name': 'x-api-key', 'value': '{{apiKey}}'},
              {'name': 'authorization', 'value': ''},
            ],
            customHeaders: const [
              {'name': 'X-Chat-Only', 'value': 'chat'},
            ],
            customBody: const [
              {'key': 'chat_only', 'value': 'true'},
            ],
          );

          expect(await ProviderBalanceService.fetchBalance(config), '19.25');
          final request = requests.single;
          expect(request.method, 'POST');
          expect(request.uri.path, '/api/check-balance');
          expect(request.uri.queryParameters, {'account': 'main'});
          expect(request.headers.value('x-api-key'), 'balance-key');
          expect(request.headers.value('authorization'), isNull);
          expect(request.headers.value('X-Chat-Only'), isNull);
          expect(request.headers.contentType, isNull);
          expect(request.body, isEmpty);
        },
      );

      test(
        'POST sends UTF-8 JSON with key substitution and header overrides',
        () async {
          config = config.copyWith(
            balanceMethod: 'POST',
            balanceHeaders: const [
              {'name': 'AUTHORIZATION', 'value': 'Token {{apiKey}}'},
              {'name': '', 'value': 'ignored unfinished row'},
              {'name': 'X-Account', 'value': 'first'},
              {'name': 'x-account', 'value': 'second'},
            ],
            balanceBody:
                '{"api_key":"{{apiKey}}","account":"中文","extra":{"include":true}}',
          );

          expect(await ProviderBalanceService.fetchBalance(config), '19.25');
          final request = requests.single;
          expect(request.headers['authorization'], ['Token balance-key']);
          expect(request.headers['x-account'], ['second']);
          expect(request.headers.contentType?.mimeType, 'application/json');
          expect(jsonDecode(request.body), {
            'api_key': 'balance-key',
            'account': '中文',
            'extra': {'include': true},
          });
        },
      );

      test('custom content type preserves a raw request body', () async {
        config = config.copyWith(
          balanceMethod: 'POST',
          balanceHeaders: const [
            {
              'name': 'content-type',
              'value': 'application/x-www-form-urlencoded',
            },
          ],
          balanceBody: 'api_key={{apiKey}}&account=main',
        );
        await ProviderBalanceService.fetchBalance(config);
        expect(
          requests.single.headers.contentType?.mimeType,
          'application/x-www-form-urlencoded',
        );
        expect(requests.single.body, 'api_key=balance-key&account=main');
      });

      test(
        'GET omits a saved POST body and still applies custom headers',
        () async {
          await ProviderBalanceService.fetchBalance(
            config.copyWith(
              balanceHeaders: const [
                {'name': 'X-Key', 'value': '{{apiKey}}'},
              ],
              balanceBody: '{"secret":"{{apiKey}}"}',
            ),
          );
          expect(requests.single.method, 'GET');
          expect(requests.single.body, isEmpty);
          expect(requests.single.headers.contentType, isNull);
          expect(requests.single.headers.value('X-Key'), 'balance-key');
        },
      );

      test(
        'selects a multi-key once for auth, headers and body per request',
        () async {
          config = config.copyWith(
            id: 'multi-key-balance-substitution-${kind.name}',
            balanceMethod: 'POST',
            multiKeyEnabled: true,
            apiKeys: const [
              ApiKeyConfig(id: 'a', key: 'key-a', createdAt: 0, updatedAt: 0),
              ApiKeyConfig(id: 'b', key: 'key-b', createdAt: 0, updatedAt: 0),
            ],
            balanceHeaders: const [
              {'name': 'x-api-key', 'value': '{{apiKey}}'},
            ],
            balanceBody: '{"api_key":"{{apiKey}}"}',
          );
          await ProviderBalanceService.fetchBalance(config);
          await ProviderBalanceService.fetchBalance(config);
          expect(requests, hasLength(2));
          for (var i = 0; i < requests.length; i++) {
            final key = i == 0 ? 'key-a' : 'key-b';
            expect(requests[i].headers.value('authorization'), 'Bearer $key');
            expect(requests[i].headers.value('x-api-key'), key);
            expect(jsonDecode(requests[i].body), {'api_key': key});
          }
        },
      );

      test('rejects unsupported methods before sending a request', () async {
        await expectLater(
          ProviderBalanceService.fetchBalance(
            config.copyWith(balanceMethod: 'DELETE'),
          ),
          throwsA(
            isA<ProviderBalanceException>().having(
              (error) => error.message,
              'message',
              contains('Unsupported balance HTTP method'),
            ),
          ),
        );
        expect(requests, isEmpty);
      });
    });
  }
}
