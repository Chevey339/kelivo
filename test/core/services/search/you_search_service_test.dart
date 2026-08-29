import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/you_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('You.com search service', () {
    test('serializes options and resolves factory/icon mapping', () {
      final options = YouSearchOptions(
        id: 'you-1',
        apiKey: 'you-test',
        contentMode: YouSearchOptions.snippetsMode,
        extraApiKeys: const ['extra-key'],
      );

      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<YouSearchOptions>());
      final you = restored as YouSearchOptions;
      expect(you.id, 'you-1');
      expect(you.apiKey, 'you-test');
      expect(you.contentMode, YouSearchOptions.snippetsMode);
      expect(you.extraApiKeys, ['extra-key']);
      expect(you.primaryApiKey, 'you-test');
      expect(SearchService.getService(you), isA<YouSearchService>());
      expect(BrandAssets.assetForName('you'), 'assets/icons/you.svg');
      expect(BrandAssets.assetForName('you.com'), 'assets/icons/you.svg');
    });

    test('defaults missing or invalid contentMode to highlights', () {
      final missing = SearchServiceOptions.fromJson({
        'type': 'you',
        'id': 'you-legacy',
        'apiKey': 'legacy-key',
      });
      final invalid = SearchServiceOptions.fromJson({
        'type': 'you',
        'id': 'you-invalid',
        'apiKey': 'legacy-key',
        'contentMode': 'full_page',
      });

      expect(
        (missing as YouSearchOptions).contentMode,
        YouSearchOptions.defaultContentMode,
      );
      expect(
        (invalid as YouSearchOptions).contentMode,
        YouSearchOptions.defaultContentMode,
      );
    });

    test('posts highlights extraction and parses web results', () async {
      http.Request? captured;
      final service = YouSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'results': {
                'web': [
                  {
                    'title': 'You.com Highlights',
                    'url': 'https://example.com/you',
                    'description': 'unused description',
                    'snippets': ['unused snippet'],
                    'contents': {
                      'highlights': ['Highlight one', 'Highlight two'],
                    },
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
        commonOptions: const SearchCommonOptions(resultSize: 5, timeout: 1000),
        serviceOptions: YouSearchOptions(id: 'you-1', apiKey: 'you-test'),
      );

      expect(captured?.url.toString(), YouSearchService.endpoint);
      expect(captured?.headers['X-API-Key'], 'you-test');
      expect(captured?.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(captured!.body), {
        'query': 'kelivo search',
        'count': 5,
        'extraction': {'extraction_mode': 'highlights'},
      });
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'You.com Highlights');
      expect(result.items.single.url, 'https://example.com/you');
      expect(result.items.single.text, 'Highlight one\n\nHighlight two');
    });

    test('omits extraction in snippets mode and falls back in order', () async {
      http.Request? captured;
      final service = YouSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'results': {
                'web': [
                  {
                    'title': 'Snippets first',
                    'url': 'https://example.com/snippets',
                    'description': 'unused description',
                    'snippets': ['Snippet one', 'Snippet two'],
                  },
                  {
                    'title': 'Description only',
                    'url': 'https://example.com/description',
                    'description': 'Just a description',
                    'snippets': [],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(resultSize: 10, timeout: 1000),
        serviceOptions: YouSearchOptions(
          id: 'you-1',
          apiKey: 'you-test',
          contentMode: YouSearchOptions.snippetsMode,
        ),
      );

      expect(jsonDecode(captured!.body), {'query': 'kelivo', 'count': 10});
      expect(captured!.body.contains('extraction'), isFalse);
      expect(result.items, hasLength(2));
      expect(result.items.first.text, 'Snippet one\n\nSnippet two');
      expect(result.items.last.text, 'Just a description');
    });

    test('merges web and news then limits to resultSize', () async {
      final service = YouSearchService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'results': {
                'web': [
                  {
                    'title': 'Web 1',
                    'url': 'https://example.com/web-1',
                    'description': 'web',
                  },
                  {
                    'title': 'Web 2',
                    'url': 'https://example.com/web-2',
                    'description': 'web',
                  },
                ],
                'news': [
                  {
                    'title': 'News 1',
                    'url': 'https://example.com/news-1',
                    'description': 'news',
                  },
                  {
                    'title': 'News 2',
                    'url': 'https://example.com/news-2',
                    'description': 'news',
                  },
                ],
              },
            }),
            200,
          ),
        ),
      );

      final result = await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(resultSize: 3, timeout: 1000),
        serviceOptions: YouSearchOptions(id: 'you-1', apiKey: 'you-test'),
      );

      expect(result.items.map((item) => item.title), [
        'Web 1',
        'Web 2',
        'News 1',
      ]);
    });

    test('returns an empty list when You.com has no results', () async {
      final service = YouSearchService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'results': {}}), 200),
        ),
      );

      final result = await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: YouSearchOptions(id: 'you-1', apiKey: 'you-test'),
      );

      expect(result.items, isEmpty);
    });

    test('rotates extra API keys across requests', () async {
      final keys = <String>[];
      final service = YouSearchService(
        client: MockClient((request) async {
          keys.add(request.headers['X-API-Key'] ?? '');
          return http.Response(jsonEncode({'results': {}}), 200);
        }),
      );
      final options = YouSearchOptions(
        id: 'you-rotate',
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

    test('throws when You.com returns a non-200 response', () async {
      final service = YouSearchService(
        client: MockClient((_) async => http.Response('unauthorized', 401)),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: YouSearchOptions(id: 'you-1', apiKey: 'you-test'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('You.com search failed'),
          ),
        ),
      );
    });
  });
}
