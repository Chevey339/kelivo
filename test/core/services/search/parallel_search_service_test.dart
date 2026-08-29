import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/parallel_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Parallel search service', () {
    test('serializes options and resolves factory/icon mapping', () {
      final options = ParallelOptions(
        id: 'parallel-1',
        apiKey: 'parallel-test',
        mode: 'fast',
        extraApiKeys: const ['extra-key'],
      );

      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<ParallelOptions>());
      final parallel = restored as ParallelOptions;
      expect(parallel.id, 'parallel-1');
      expect(parallel.apiKey, 'parallel-test');
      expect(parallel.mode, 'fast');
      expect(parallel.extraApiKeys, ['extra-key']);
      expect(parallel.primaryApiKey, 'parallel-test');
      expect(SearchService.getService(parallel), isA<ParallelSearchService>());
      expect(BrandAssets.assetForName('parallel'), 'assets/icons/parallel.svg');
    });

    test('defaults missing or invalid mode to advanced', () {
      final missing = SearchServiceOptions.fromJson({
        'type': 'parallel',
        'id': 'parallel-legacy',
        'apiKey': 'legacy-key',
      });
      final invalid = SearchServiceOptions.fromJson({
        'type': 'parallel',
        'id': 'parallel-invalid',
        'apiKey': 'legacy-key',
        'mode': 'unknown',
      });

      expect(missing, isA<ParallelOptions>());
      expect((missing as ParallelOptions).mode, ParallelOptions.defaultMode);
      expect((invalid as ParallelOptions).mode, ParallelOptions.defaultMode);
    });

    test('posts objective, queries, and mode then joins excerpts', () async {
      http.Request? captured;
      final service = ParallelSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'url': 'https://example.com/parallel',
                  'title': 'Parallel Search',
                  'excerpts': ['First excerpt', 'Second excerpt'],
                },
                {
                  'url': 'https://example.com/ignored',
                  'title': 'Ignored by resultSize',
                  'excerpts': ['ignored'],
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'kelivo search',
        commonOptions: const SearchCommonOptions(resultSize: 1, timeout: 1000),
        serviceOptions: ParallelOptions(
          id: 'parallel-1',
          apiKey: 'parallel-test',
          mode: 'turbo',
        ),
      );

      expect(captured?.url.toString(), ParallelSearchService.endpoint);
      expect(captured?.headers['x-api-key'], 'parallel-test');
      expect(captured?.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(captured!.body), {
        'objective': 'kelivo search',
        'search_queries': ['kelivo search'],
        'mode': 'turbo',
      });
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'Parallel Search');
      expect(result.items.single.url, 'https://example.com/parallel');
      expect(result.items.single.text, 'First excerpt\n\nSecond excerpt');
    });

    test('returns an empty list when Parallel has no results', () async {
      final service = ParallelSearchService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'results': []}), 200),
        ),
      );

      final result = await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: ParallelOptions(
          id: 'parallel-1',
          apiKey: 'parallel-test',
        ),
      );

      expect(result.items, isEmpty);
    });

    test('rotates extra API keys across requests', () async {
      final keys = <String>[];
      final service = ParallelSearchService(
        client: MockClient((request) async {
          keys.add(request.headers['x-api-key'] ?? '');
          return http.Response(jsonEncode({'results': []}), 200);
        }),
      );
      final options = ParallelOptions(
        id: 'parallel-rotate',
        apiKey: 'key-a',
        extraApiKeys: const ['key-b'],
      );

      await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: options,
      );
      await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: options,
      );

      expect(keys, ['key-a', 'key-b']);
    });

    test('throws when Parallel returns a non-200 response', () async {
      final service = ParallelSearchService(
        client: MockClient((_) async => http.Response('rate limited', 429)),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: ParallelOptions(
            id: 'parallel-1',
            apiKey: 'parallel-test',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Parallel search failed'),
          ),
        ),
      );
    });
  });
}
