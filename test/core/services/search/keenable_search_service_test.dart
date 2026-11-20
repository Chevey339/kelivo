import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/keenable_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Keenable search service', () {
    test('serializes options and resolves the factory', () {
      final options = KeenableOptions(
        id: 'keenable-1',
        apiKey: 'keenable-test',
        extraApiKeys: const ['extra-key'],
      );

      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<KeenableOptions>());
      final keenable = restored as KeenableOptions;
      expect(keenable.id, 'keenable-1');
      expect(keenable.apiKey, 'keenable-test');
      expect(keenable.extraApiKeys, ['extra-key']);
      expect(keenable.primaryApiKey, 'keenable-test');
      expect(SearchService.getService(keenable), isA<KeenableSearchService>());
    });

    test(
      'posts to the public endpoint with the title header when no key is set',
      () async {
        http.Request? captured;
        final service = KeenableSearchService(
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'url': 'https://example.com/keenable',
                    'title': 'Keenable Search',
                    'snippet': 'A result',
                  },
                  {'title': 'Missing url'},
                ],
              }),
              200,
            );
          }),
        );

        final result = await service.search(
          query: 'kelivo search',
          commonOptions: const SearchCommonOptions(
            resultSize: 5,
            timeout: 1000,
          ),
          serviceOptions: KeenableOptions(id: 'keenable-1'),
        );

        expect(captured?.url.toString(), KeenableSearchService.publicSearchUrl);
        expect(
          captured?.headers['X-Keenable-Title'],
          KeenableSearchService.appTitle,
        );
        expect(captured?.headers['X-API-Key'], isNull);
        expect(jsonDecode(captured!.body), {
          'query': 'kelivo search',
          'max_results': 5,
        });
        expect(result.items, hasLength(1));
        expect(result.items.single.title, 'Keenable Search');
        expect(result.items.single.url, 'https://example.com/keenable');
        expect(result.items.single.text, 'A result');
      },
    );

    test('posts to the keyed endpoint when an API key is set', () async {
      http.Request? captured;
      final service = KeenableSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'results': []}), 200);
        }),
      );

      await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: KeenableOptions(id: 'keenable-1', apiKey: 'secret-key'),
      );

      expect(captured?.url.toString(), KeenableSearchService.keyedSearchUrl);
      expect(captured?.headers['X-API-Key'], 'secret-key');
      expect(
        captured?.headers['X-Keenable-Title'],
        KeenableSearchService.appTitle,
      );
    });
    test('uses one rotated key per request for endpoint and header', () async {
      final requests = <http.Request>[];
      final service = KeenableSearchService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({'url': 'https://example.com', 'content': 'Body'}),
              200,
            );
          }
          return http.Response(jsonEncode({'results': []}), 200);
        }),
      );
      final options = KeenableOptions(
        id: 'keenable-rotation',
        apiKey: 'key-1',
        extraApiKeys: const ['key-2'],
      );
      const common = SearchCommonOptions(timeout: 1000);

      for (var i = 0; i < 2; i++) {
        await service.search(
          query: 'kelivo',
          commonOptions: common,
          serviceOptions: options,
        );
        await service.fetch(
          url: 'https://example.com',
          commonOptions: common,
          serviceOptions: options,
        );
      }

      expect(requests.map((r) => r.headers['X-API-Key']), [
        'key-1',
        'key-2',
        'key-1',
        'key-2',
      ]);
      expect(requests[0].url.toString(), KeenableSearchService.keyedSearchUrl);
      expect(
        requests[1].url.toString(),
        startsWith(KeenableSearchService.keyedFetchUrl),
      );
    });
  });
}
