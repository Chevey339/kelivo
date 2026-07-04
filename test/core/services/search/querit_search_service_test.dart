import 'dart:convert';

import 'package:Cuplivo/core/services/search/providers/querit_search_service.dart';
import 'package:Cuplivo/core/services/search/search_service.dart';
import 'package:Cuplivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Querit search service', () {
    test('serializes options and resolves factory/icon mapping', () {
      final options = QueritOptions(
        id: 'querit-1',
        apiKey: 'querit-test',
        sitesInclude: 'example.com',
        sitesExclude: 'excluded.example',
        timeRange: 'd7',
        countries: 'united states',
        languages: 'english',
      );

      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<QueritOptions>());
      final querit = restored as QueritOptions;
      expect(querit.id, 'querit-1');
      expect(querit.apiKey, 'querit-test');
      expect(querit.sitesInclude, 'example.com');
      expect(querit.sitesExclude, 'excluded.example');
      expect(querit.timeRange, 'd7');
      expect(querit.countries, 'united states');
      expect(querit.languages, 'english');
      expect(SearchService.getService(querit), isA<QueritSearchService>());
      expect(
        BrandAssets.assetForName('querit'),
        'assets/icons/querit-color.svg',
      );
    });

    test('posts filters and parses Querit results', () async {
      http.Request? captured;
      final service = QueritSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'took': '120ms',
              'error_code': 200,
              'error_msg': '',
              'search_id': 1,
              'query_context': {'query': 'kelivo'},
              'results': {
                'result': [
                  {
                    'title': 'Kelivo',
                    'url': 'https://example.com/kelivo',
                    'snippet': 'A Flutter chat client.',
                    'site_name': 'Example',
                    'site_icon': 'https://example.com/favicon.ico',
                    'snippets': ['A Flutter chat client.', 'Supports search.'],
                  },
                  {
                    'title': 'Ignored by resultSize',
                    'url': 'https://example.com/ignored',
                    'snippet': 'ignored',
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
        commonOptions: const SearchCommonOptions(resultSize: 1, timeout: 1000),
        serviceOptions: QueritOptions(
          id: 'querit-1',
          apiKey: 'querit-test',
          sitesInclude: 'example.com, docs.example.com',
          sitesExclude: 'excluded.example',
          timeRange: 'd7',
          countries: 'united states\njapan',
          languages: 'english, japanese',
        ),
      );

      expect(captured?.url.toString(), QueritSearchService.endpoint);
      expect(captured?.headers['Authorization'], 'Bearer querit-test');
      expect(captured?.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(captured!.body), {
        'query': 'kelivo',
        'count': 1,
        'filters': {
          'sites': {
            'include': ['example.com', 'docs.example.com'],
            'exclude': ['excluded.example'],
          },
          'timeRange': {'date': 'd7'},
          'geo': {
            'countries': {
              'include': ['united states', 'japan'],
            },
          },
          'languages': {
            'include': ['english', 'japanese'],
          },
        },
      });
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'Kelivo');
      expect(result.items.single.url, 'https://example.com/kelivo');
      expect(
        result.items.single.text,
        'A Flutter chat client.\n\nSupports search.',
      );
    });

    test('omits filters when optional values are empty', () async {
      http.Request? captured;
      final service = QueritSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'error_code': 200,
              'results': {'result': []},
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(resultSize: 5, timeout: 1000),
        serviceOptions: QueritOptions(id: 'querit-1', apiKey: 'querit-test'),
      );

      expect(jsonDecode(captured!.body), {'query': 'kelivo', 'count': 5});
      expect(result.items, isEmpty);
    });

    test('parses sentence field when snippets are absent', () async {
      final service = QueritSearchService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error_code': 200,
              'results': {
                'result': [
                  {
                    'title': '',
                    'url': 'https://example.com/kelivo',
                    'snippet': '',
                    'sentence': ['Sentence one.', 'Sentence two.'],
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
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: QueritOptions(id: 'querit-1', apiKey: 'querit-test'),
      );

      expect(result.items.single.title, 'https://example.com/kelivo');
      expect(result.items.single.text, 'Sentence one.\n\nSentence two.');
    });

    test('throws before request when API key is empty', () async {
      var called = false;
      final service = QueritSearchService(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: QueritOptions(id: 'querit-1', apiKey: ''),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Querit API key is required'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('throws when Querit returns non-200 response', () async {
      final service = QueritSearchService(
        client: MockClient((_) async => http.Response('rate limited', 429)),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: QueritOptions(id: 'querit-1', apiKey: 'querit-test'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Querit search failed'),
          ),
        ),
      );
    });

    test('throws when Querit returns an error code in response body', () async {
      final service = QueritSearchService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error_code': 401, 'error_msg': 'Unauthorized'}),
            200,
          ),
        ),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: QueritOptions(id: 'querit-1', apiKey: 'querit-test'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Querit search failed'),
          ),
        ),
      );
    });
  });
}
