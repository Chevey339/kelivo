import 'dart:convert';

import 'package:Cuplivo/core/services/search/providers/serper_search_service.dart';
import 'package:Cuplivo/core/services/search/search_service.dart';
import 'package:Cuplivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Serper search service', () {
    test('serializes options and resolves factory/icon mapping', () {
      final options = SerperOptions(
        id: 'serper-1',
        apiKey: 'sk-test',
        gl: 'cn',
        hl: 'zh-cn',
        tbs: 'qdr:d',
        page: 2,
      );

      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<SerperOptions>());
      final serper = restored as SerperOptions;
      expect(serper.id, 'serper-1');
      expect(serper.apiKey, 'sk-test');
      expect(serper.gl, 'cn');
      expect(serper.hl, 'zh-cn');
      expect(serper.tbs, 'qdr:d');
      expect(serper.page, 2);
      expect(SearchService.getService(serper), isA<SerperSearchService>());
      expect(BrandAssets.assetForName('serper'), 'assets/icons/serper.svg');
    });

    test('posts configured parameters and parses organic results', () async {
      http.Request? captured;
      final service = SerperSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'organic': [
                {
                  'title': 'Apple Inc.',
                  'link': 'https://example.com/apple',
                  'snippet': 'Apple company profile',
                },
                {
                  'title': 'Ignored by resultSize',
                  'link': 'https://example.com/ignored',
                  'snippet': 'ignored',
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'apple inc',
        commonOptions: const SearchCommonOptions(resultSize: 1, timeout: 1000),
        serviceOptions: SerperOptions(
          id: 'serper-1',
          apiKey: 'sk-test',
          gl: 'cn',
          hl: 'zh-cn',
          tbs: 'qdr:d',
          page: 2,
        ),
      );

      expect(captured?.url.toString(), SerperSearchService.endpoint);
      expect(captured?.headers['X-API-KEY'], 'sk-test');
      expect(captured?.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(captured!.body), {
        'q': 'apple inc',
        'gl': 'cn',
        'hl': 'zh-cn',
        'tbs': 'qdr:d',
        'page': 2,
      });
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'Apple Inc.');
      expect(result.items.single.url, 'https://example.com/apple');
      expect(result.items.single.text, 'Apple company profile');
    });

    test('omits optional defaults and returns empty organic list', () async {
      http.Request? captured;
      final service = SerperSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'organic': []}), 200);
        }),
      );

      final result = await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(timeout: 1000),
        serviceOptions: SerperOptions(id: 'serper-1', apiKey: 'sk-test'),
      );

      expect(jsonDecode(captured!.body), {'q': 'kelivo'});
      expect(result.items, isEmpty);
    });

    test('throws when Serper returns non-200 response', () async {
      final service = SerperSearchService(
        client: MockClient((_) async => http.Response('rate limited', 429)),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: SerperOptions(id: 'serper-1', apiKey: 'sk-test'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Serper search failed'),
          ),
        ),
      );
    });
  });
}
