import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/search/search_service_usage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SearchServiceUsageService', () {
    test('queries Tavily usage and calculates remaining credits', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.tavily.com/usage');
        expect(request.headers['Authorization'], 'Bearer tvly-test');
        return http.Response('''
          {
            "key": {"usage": 150, "limit": 1000},
            "account": {"current_plan": "Bootstrap"}
          }
          ''', 200);
      });

      final usage = await SearchServiceUsageService.fetch(
        TavilyOptions(id: 'tavily', apiKey: 'tvly-test'),
        client: client,
      );

      expect(usage.remaining, 850);
      expect(usage.used, 150);
      expect(usage.limit, 1000);
    });

    test('uses account totals when the Tavily key has no limit', () async {
      final client = MockClient((_) async {
        return http.Response('''
          {
            "key": {"usage": 42, "limit": null},
            "account": {
              "current_plan": "Researcher",
              "plan_usage": 75,
              "plan_limit": 1000,
              "paygo_usage": 0,
              "paygo_limit": null
            }
          }
          ''', 200);
      });

      final usage = await SearchServiceUsageService.fetch(
        TavilyOptions(id: 'tavily', apiKey: 'tvly-test'),
        client: client,
      );

      expect(usage.remaining, 925);
      expect(usage.used, 75);
      expect(usage.limit, 1000);
    });

    test('derives Tavily usage path from a custom search URL', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://proxy.example/api/usage');
        return http.Response(
          '{"key":{"usage":2,"limit":10},"account":{}}',
          200,
        );
      });

      final usage = await SearchServiceUsageService.fetch(
        TavilyOptions(
          id: 'tavily',
          apiKey: 'key',
          url: 'https://proxy.example/api/search?source=kelivo',
        ),
        client: client,
      );

      expect(usage.remaining, 8);
    });

    test('queries LinkUp credit balance', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.linkup.so/v1/credits/balance',
        );
        expect(request.headers['Authorization'], 'Bearer linkup-test');
        return http.Response('{"balance":123.456}', 200);
      });

      final usage = await SearchServiceUsageService.fetch(
        LinkUpOptions(id: 'linkup', apiKey: 'linkup-test'),
        client: client,
      );

      expect(usage.remaining, 123.456);
      expect(usage.used, isNull);
      expect(usage.limit, isNull);
    });

    test('estimates DeepSeek requests from the account balance', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.deepseek.com/user/balance');
        expect(request.headers['Authorization'], 'Bearer sk-test');
        return http.Response('''
          {
            "is_available": true,
            "balance_infos": [
              {
                "currency": "CNY",
                "total_balance": "110.00",
                "granted_balance": "10.00",
                "topped_up_balance": "100.00"
              },
              {
                "currency": "USD",
                "total_balance": "1.50",
                "granted_balance": "0.00",
                "topped_up_balance": "1.50"
              }
            ]
          }
          ''', 200);
      });

      final usage = await SearchServiceUsageService.fetch(
        DeepSeekOptions(id: 'deepseek', apiKey: ' sk-test '),
        client: client,
      );

      // CNY 110 / (5 per 1,000) + USD 1.50 / (0.75 per 1,000).
      expect(usage.remaining, 24000);
      expect(usage.balances, {'CNY': 110, 'USD': 1.5});
      expect(usage.used, isNull);
      expect(usage.limit, isNull);
    });

    test('does not count a negative DeepSeek balance', () async {
      final client = MockClient((_) async {
        return http.Response('''
          {
            "is_available": false,
            "balance_infos": [
              {"currency": "CNY", "total_balance": "-0.50"}
            ]
          }
          ''', 200);
      });

      final usage = await SearchServiceUsageService.fetch(
        DeepSeekOptions(id: 'deepseek', apiKey: 'sk-test'),
        client: client,
      );

      expect(usage.remaining, 0);
      expect(usage.balances, {'CNY': -0.5});
    });

    test('rejects a DeepSeek balance without a priced currency', () async {
      final client = MockClient((_) async {
        return http.Response(
          '{"balance_infos":[{"currency":"EUR","total_balance":"5.00"}]}',
          200,
        );
      });

      expect(
        () => SearchServiceUsageService.fetch(
          DeepSeekOptions(id: 'deepseek', apiKey: 'sk-test'),
          client: client,
        ),
        throwsA(isA<SearchServiceUsageException>()),
      );
    });

    test('retries a transient Tavily TLS handshake failure', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        if (attempts == 1) {
          throw http.ClientException(
            'HandshakeException: Connection terminated during handshake',
          );
        }
        return http.Response(
          '{"account":{"plan_usage":25,"plan_limit":100}}',
          200,
        );
      });

      final usage = await SearchServiceUsageService.fetch(
        TavilyOptions(id: 'tavily', apiKey: 'tvly-test'),
        client: client,
      );

      expect(attempts, 2);
      expect(usage.remaining, 75);
    });

    test('does not expose provider response bodies on HTTP failure', () async {
      final client = MockClient(
        (_) async => http.Response('{"secret":"details"}', 401),
      );

      expect(
        () => SearchServiceUsageService.fetch(
          LinkUpOptions(id: 'linkup', apiKey: 'bad-key'),
          client: client,
        ),
        throwsA(
          isA<SearchServiceUsageException>().having(
            (error) => error.toString(),
            'message',
            allOf(contains('HTTP 401'), isNot(contains('secret'))),
          ),
        ),
      );
    });
  });
}
