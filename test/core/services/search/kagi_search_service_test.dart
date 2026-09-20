import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/kagi_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Kagi search provider', () {
    test('serializes options and resolves the service factory', () {
      final options = KagiOptions(
        id: 'kagi-1',
        apiKey: 'primary-key',
        extraApiKeys: const ['backup-key'],
      );

      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<KagiOptions>());
      final kagi = restored as KagiOptions;
      expect(kagi.id, 'kagi-1');
      expect(kagi.apiKey, 'primary-key');
      expect(kagi.extraApiKeys, ['backup-key']);
      expect(kagi.primaryApiKey, 'primary-key');
      expect(SearchService.getService(kagi), isA<KagiSearchService>());
    });

    test('posts the v1 request and parses web results', () async {
      http.Request? captured;
      final service = KagiSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'meta': {'trace': 'trace-1'},
              'data': {
                'search': [
                  {
                    'title': 'Kelivo',
                    'url': 'https://example.com/kelivo',
                    'snippet': 'A cross-platform LLM client.',
                  },
                  {'title': '', 'url': 'https://example.com/invalid'},
                  'unexpected',
                ],
                'news': [
                  {
                    'title': 'Not part of the search workflow',
                    'url': 'https://example.com/news',
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'kelivo search',
        commonOptions: const SearchCommonOptions(resultSize: 8, timeout: 1000),
        serviceOptions: KagiOptions(id: 'kagi-1', apiKey: 'kagi-key'),
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), KagiSearchService.endpoint);
      expect(captured?.headers['Authorization'], 'Bearer kagi-key');
      expect(captured?.headers['Content-Type'], contains('application/json'));
      expect(captured?.headers['Accept'], 'application/json');
      expect(jsonDecode(captured!.body), {
        'query': 'kelivo search',
        'workflow': 'search',
        'format': 'json',
        'limit': 8,
      });
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'Kelivo');
      expect(result.items.single.url, 'https://example.com/kelivo');
      expect(result.items.single.text, 'A cross-platform LLM client.');
    });

    test('clamps the requested result limit to the Kagi API range', () async {
      final limits = <int>[];
      final service = KagiSearchService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          limits.add(body['limit'] as int);
          return http.Response(
            jsonEncode({
              'data': {'search': []},
            }),
            200,
          );
        }),
      );
      final options = KagiOptions(id: 'kagi-limits', apiKey: 'kagi-key');

      for (final size in [-5, 0, 10, 2048]) {
        await service.search(
          query: 'kelivo',
          commonOptions: SearchCommonOptions(resultSize: size, timeout: 1000),
          serviceOptions: options,
        );
      }

      expect(limits, [1, 1, 10, 1024]);
    });

    test('rotates API keys between requests', () async {
      final keys = <String>[];
      final service = KagiSearchService(
        client: MockClient((request) async {
          keys.add(request.headers['Authorization'] ?? '');
          return http.Response(
            jsonEncode({
              'data': {'search': []},
            }),
            200,
          );
        }),
      );
      final options = KagiOptions(
        id: 'kagi-rotate',
        apiKey: 'key-a',
        extraApiKeys: const ['key-b'],
      );

      for (var i = 0; i < 2; i++) {
        await service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: options,
        );
      }

      expect(keys, ['Bearer key-a', 'Bearer key-b']);
    });

    test('includes Kagi error details for a failed request', () {
      final service = KagiSearchService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': [
                {
                  'code': 'usage_limit_exhausted',
                  'message': 'API usage limit exhausted',
                },
              ],
            }),
            429,
            headers: {'X-Kagi-Trace': 'trace-header'},
          ),
        ),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: KagiOptions(id: 'kagi-1', apiKey: 'kagi-key'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            allOf(
              contains('Kagi search failed'),
              contains('429'),
              contains('API usage limit exhausted'),
              contains('trace-header'),
            ),
          ),
        ),
      );
    });

    test('rejects an error envelope returned with HTTP 200', () {
      final service = KagiSearchService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'meta': {'trace': 'trace-body'},
              'data': <String, dynamic>{},
              'error': [
                {'code': 'usage_limit_exhausted'},
              ],
            }),
            200,
          ),
        ),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: KagiOptions(id: 'kagi-1', apiKey: 'kagi-key'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            allOf(contains('usage_limit_exhausted'), contains('trace-body')),
          ),
        ),
      );
    });
  });
}
