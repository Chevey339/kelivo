import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/anysearch_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AnySearch search provider', () {
    test('sends an authenticated request and parses nested results', () async {
      http.Request? captured;
      final service = AnySearchSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': {
                'results': [
                  {
                    'title': 'Snippet result',
                    'url': 'https://example.com/snippet',
                    'snippet': 'Short context',
                    'content': 'Long context',
                  },
                  {
                    'title': 'Content result',
                    'url': 'https://example.com/content',
                    'snippet': '',
                    'content': 'Content fallback',
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
        commonOptions: const SearchCommonOptions(resultSize: 50, timeout: 1000),
        serviceOptions: AnySearchOptions(
          id: 'anysearch',
          apiKey: 'any-key',
          url: 'https://search.example/v1/search',
        ),
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), 'https://search.example/v1/search');
      expect(captured?.headers['Authorization'], 'Bearer any-key');
      expect(jsonDecode(captured!.body), {
        'query': 'kelivo',
        'max_results': 20,
        'format': 'json',
      });
      expect(result.items, hasLength(2));
      expect(result.items.first.text, 'Short context');
      expect(result.items.last.text, 'Content fallback');
    });

    test('supports anonymous requests and option serialization', () async {
      http.Request? captured;
      final options = AnySearchOptions(
        id: 'anonymous',
        apiKey: '',
        extraApiKeys: const ['backup-key'],
      );
      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<AnySearchOptions>());
      final anySearch = restored as AnySearchOptions;
      expect(anySearch.resolvedUrl, AnySearchOptions.defaultUrl);
      expect(anySearch.extraApiKeys, ['backup-key']);
      expect(
        SearchService.getService(anySearch),
        isA<AnySearchSearchService>(),
      );

      final service = AnySearchSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'data': {'results': []},
            }),
            200,
          );
        }),
      );
      await service.search(
        query: 'anonymous',
        commonOptions: const SearchCommonOptions(resultSize: 1, timeout: 1000),
        serviceOptions: AnySearchOptions(id: 'anonymous-only', apiKey: ''),
      );

      expect(captured?.headers.containsKey('Authorization'), isFalse);
    });

    test('rejects an HTTP 200 response with a non-zero business code', () {
      final service = AnySearchSearchService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': -1,
              'message': 'Invalid search parameters',
              'request_id': 'request-123',
            }),
            200,
          ),
        ),
      );

      expect(
        () => service.search(
          query: 'broken',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: AnySearchOptions(id: 'anysearch', apiKey: ''),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            allOf(
              contains('Invalid search parameters'),
              contains('request-123'),
            ),
          ),
        ),
      );
    });
  });
}
