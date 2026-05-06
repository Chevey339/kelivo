import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/grok_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Grok search service', () {
    test('serializes options and resolves factory/icon mapping', () {
      final options = GrokOptions(
        id: 'grok-1',
        apiKey: 'xai-test',
        model: 'grok-test',
        customUrl: 'https://example.com/responses',
        systemPrompt: 'Search carefully.',
      );

      final restored = SearchServiceOptions.fromJson(options.toJson());

      expect(restored, isA<GrokOptions>());
      final grok = restored as GrokOptions;
      expect(grok.id, 'grok-1');
      expect(grok.apiKey, 'xai-test');
      expect(grok.model, 'grok-test');
      expect(grok.customUrl, 'https://example.com/responses');
      expect(grok.systemPrompt, 'Search carefully.');
      expect(SearchService.getService(grok), isA<GrokSearchService>());
      expect(BrandAssets.assetForName('grok'), 'assets/icons/grok.svg');
    });

    test('posts responses request and parses distinct url citations', () async {
      http.Request? captured;
      final service = GrokSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'output': [
                {'type': 'web_search_call', 'status': 'completed'},
                {
                  'type': 'message',
                  'role': 'assistant',
                  'content': [
                    {
                      'type': 'output_text',
                      'text': 'Kelivo is a Flutter chat client.',
                      'annotations': [
                        {
                          'type': 'url_citation',
                          'url': 'https://example.com/a',
                          'title': 'Example A',
                        },
                        {
                          'type': 'url_citation',
                          'url': 'https://example.com/a',
                          'title': 'Duplicate',
                        },
                        {
                          'type': 'url_citation',
                          'url': 'https://example.com/b',
                          'title': 'Example B',
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'kelivo',
        commonOptions: const SearchCommonOptions(resultSize: 1, timeout: 1000),
        serviceOptions: GrokOptions(
          id: 'grok-1',
          apiKey: 'xai-test',
          model: 'grok-test',
          customUrl: 'https://example.com/responses',
          systemPrompt: 'Search carefully.',
        ),
      );

      expect(captured?.url.toString(), 'https://example.com/responses');
      expect(captured?.headers['Authorization'], 'Bearer xai-test');
      expect(captured?.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(captured!.body), {
        'model': 'grok-test',
        'input': [
          {'role': 'system', 'content': 'Search carefully.'},
          {'role': 'user', 'content': 'kelivo'},
        ],
        'tools': [
          {'type': 'web_search'},
          {'type': 'x_search'},
        ],
        'store': false,
      });
      expect(result.answer, 'Kelivo is a Flutter chat client.');
      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'Example A');
      expect(result.items.single.url, 'https://example.com/a');
      expect(result.items.single.text, isEmpty);
    });

    test('throws before request when API key is empty', () async {
      var called = false;
      final service = GrokSearchService(
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: GrokOptions(id: 'grok-1', apiKey: ''),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Grok API key is required'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('throws when Grok returns non-200 response', () async {
      final service = GrokSearchService(
        client: MockClient((_) async => http.Response('rate limited', 429)),
      );

      expect(
        () => service.search(
          query: 'kelivo',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: GrokOptions(id: 'grok-1', apiKey: 'xai-test'),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Grok search failed'),
          ),
        ),
      );
    });
  });
}
