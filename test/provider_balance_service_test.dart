import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/provider_balance_service.dart';

ProviderConfig _openAiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'BalanceTest',
    enabled: true,
    name: 'BalanceTest',
    apiKey: 'balance-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
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
    test('requests configured balance path with bearer auth', () async {
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
        _openAiConfig('http://${server.address.address}:${server.port}/v1'),
      );

      expect(balance, '12.25');
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.uri.path, '/v1/credits');
      expect(
        requests.single.headers.value(HttpHeaders.authorizationHeader),
        'Bearer balance-key',
      );
    });

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
          _openAiConfig('http://${server.address.address}:${server.port}/v1'),
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

    test('rejects non OpenAI compatible providers', () {
      final config = ProviderConfig(
        id: 'Gemini',
        enabled: true,
        name: 'Gemini',
        apiKey: 'key',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        providerType: ProviderKind.google,
        balanceEnabled: true,
      );

      expect(
        () => ProviderBalanceService.fetchBalance(config),
        throwsA(isA<ProviderBalanceException>()),
      );
    });
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

        expect(aihubmix.balanceEnabled, isTrue);
        expect(aihubmix.balanceApiPath, '/user/balance');
        expect(aihubmix.balanceResultPath, 'balance_infos[0].total_balance');
        expect(openRouter.balanceEnabled, isTrue);
        expect(openRouter.balanceApiPath, '/credits');
        expect(
          openRouter.balanceResultPath,
          'data.total_credits - data.total_usage',
        );
        expect(siliconFlow.balanceEnabled, isTrue);
        expect(siliconFlow.balanceApiPath, '/user/info');
        expect(siliconFlow.balanceResultPath, 'data.totalBalance');
        expect(vercel.balanceEnabled, isTrue);
        expect(vercel.balanceApiPath, '/credits');
        expect(vercel.balanceResultPath, 'balance');
        expect(deepSeek.balanceEnabled, isTrue);
        expect(deepSeek.balanceApiPath, '/user/balance');
        expect(deepSeek.balanceResultPath, 'balance_infos[0].total_balance');
        expect(moonshot.balanceEnabled, isTrue);
        expect(moonshot.balanceApiPath, '/users/me/balance');
        expect(moonshot.balanceResultPath, 'data.available_balance');
      },
    );
  });
}
