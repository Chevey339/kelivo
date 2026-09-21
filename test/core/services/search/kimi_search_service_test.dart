import 'dart:convert';

import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/services/search/providers/kimi_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Kimi search service', () {
    test(
      'preserves settings through persistence and resolves service/icon',
      () {
        final options = KimiOptions(
          id: 'kimi',
          apiKey: 'primary-key',
          mode: 'basic',
          extraApiKeys: const ['extra-key'],
        );
        final snapshot = BusinessSettingsRouter.normalizeAndRoute({
          'search_services_v1': jsonEncode([options.toJson()]),
        });
        final exported = BusinessSettingsRouter.exportSnapshot(snapshot);
        final services =
            jsonDecode(exported['search_services_v1']! as String) as List;
        final restored = SearchServiceOptions.fromJson(
          (services.single as Map).cast<String, dynamic>(),
        );

        expect(restored, isA<KimiOptions>());
        expect(restored.toJson(), options.toJson());
        expect(restored.primaryApiKey, 'primary-key');
        expect(SearchService.getService(restored), isA<KimiSearchService>());
        expect(BrandAssets.assetForName('kimi'), 'assets/icons/kimi-color.svg');
      },
    );

    test('defaults to Pro and normalizes unsupported modes', () {
      expect(KimiOptions(id: 'kimi', apiKey: '').mode, 'pro');
      for (final mode in [null, '', 'invalid']) {
        final restored =
            SearchServiceOptions.fromJson({
                  'type': 'kimi',
                  'id': 'kimi',
                  'apiKey': 'key',
                  if (mode != null) 'mode': mode,
                })
                as KimiOptions;
        expect(restored.mode, 'pro');
      }
    });

    test('settings validation rejects invalid field types', () {
      for (final invalid in <Map<String, Object?>>[
        {'apiKey': 1},
        {'mode': true},
        {
          'apiKeys': [1],
        },
      ]) {
        expect(
          () => BusinessSettingsRouter.normalizeAndRoute({
            'search_services_v1': jsonEncode([
              {'type': 'kimi', 'id': 'kimi', 'apiKey': 'key', ...invalid},
            ]),
          }),
          throwsFormatException,
        );
      }
    });

    test(
      'Pro sends the documented request and preserves content and sources',
      () async {
        http.Request? captured;
        final service = KimiSearchService(
          client: MockClient((request) async {
            captured = request;
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'search_results': [
                    {
                      'title': '月之暗面',
                      'url': 'https://example.com/kimi',
                      'snippet': '摘要',
                      'chunks': [
                        {'text': '第一段正文', 'score': 1.23},
                        {'text': ' ', 'score': 1.0},
                        {'text': '第二段正文', 'score': 0.98},
                      ],
                    },
                    {
                      'title': 'Snippet only',
                      'url': 'https://example.com/snippet',
                      'snippet': 'Available without page content',
                      'chunks': [],
                    },
                    {'title': 'Over the requested limit'},
                  ],
                }),
              ),
              200,
            );
          }),
        );

        final result = await service.search(
          query: 'Kimi 发布',
          commonOptions: const SearchCommonOptions(
            resultSize: 2,
            timeout: 30000,
          ),
          serviceOptions: KimiOptions(id: 'kimi', apiKey: 'test-key'),
        );

        expect(
          captured!.url.toString(),
          'https://api.moonshot.cn/v1/tools/search_pro',
        );
        expect(captured!.method, 'POST');
        expect(captured!.headers['Authorization'], 'Bearer test-key');
        expect(captured!.headers['Content-Type'], contains('application/json'));
        expect(jsonDecode(captured!.body), {
          'text_query': 'Kimi 发布',
          'limit': 2,
          'timeout_seconds': 30,
        });
        expect(result.items, hasLength(2));
        expect(result.items.first.title, '月之暗面');
        expect(result.items.first.url, 'https://example.com/kimi');
        expect(result.items.first.text, '第一段正文\n\n第二段正文');
        expect(result.items.last.text, 'Available without page content');
      },
    );

    test('Basic uses the search endpoint and returns snippets', () async {
      http.Request? captured;
      final service = KimiSearchService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'search_results': [
                {
                  'title': 'Basic result',
                  'url': 'https://example.com/basic',
                  'snippet': 'Search summary',
                  'text': '',
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.search(
        query: 'test',
        commonOptions: const SearchCommonOptions(resultSize: 5, timeout: 10000),
        serviceOptions: KimiOptions(id: 'kimi', apiKey: 'key', mode: 'basic'),
      );

      expect(
        captured!.url.toString(),
        'https://api.moonshot.cn/v1/tools/search',
      );
      expect(jsonDecode(captured!.body), {
        'text_query': 'test',
        'limit': 5,
        'timeout_seconds': 10,
      });
      expect(result.items.single.title, 'Basic result');
      expect(result.items.single.url, 'https://example.com/basic');
      expect(result.items.single.text, 'Search summary');
    });

    for (final (size, timeout, limit, seconds) in [
      (0, 500, 1, 1),
      (3, 1501, 3, 2),
      (100, 90000, 20, 60),
    ]) {
      test('clamps limit $size and converts timeout $timeout ms', () async {
        Map<String, dynamic>? body;
        final service = KimiSearchService(
          client: MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"search_results":[]}', 200);
          }),
        );

        final result = await service.search(
          query: 'test',
          commonOptions: SearchCommonOptions(
            resultSize: size,
            timeout: timeout,
          ),
          serviceOptions: KimiOptions(id: 'kimi', apiKey: 'key'),
        );

        expect(body!['limit'], limit);
        expect(body!['timeout_seconds'], seconds);
        expect(result.items, isEmpty);
      });
    }

    test('rotates configured API keys', () async {
      final keys = <String>[];
      final service = KimiSearchService(
        client: MockClient((request) async {
          keys.add(request.headers['Authorization']!);
          return http.Response('{"search_results":[]}', 200);
        }),
      );
      final options = KimiOptions(
        id: 'kimi-rotate',
        apiKey: 'key-a',
        extraApiKeys: const ['key-b'],
      );

      for (var i = 0; i < 3; i++) {
        await service.search(
          query: 'test',
          commonOptions: const SearchCommonOptions(),
          serviceOptions: options,
        );
      }

      expect(keys, ['Bearer key-a', 'Bearer key-b', 'Bearer key-a']);
    });

    for (final status in [401, 429, 504]) {
      test('reports HTTP $status with the provider request ID', () async {
        final service = KimiSearchService(
          client: MockClient(
            (_) async => http.Response(
              status == 401 ? '' : '{"error":{"message":"request failed"}}',
              status,
              headers: {'x-msh-track-id': 'track-123'},
            ),
          ),
        );

        await expectLater(
          service.search(
            query: 'test',
            commonOptions: const SearchCommonOptions(),
            serviceOptions: KimiOptions(id: 'kimi', apiKey: 'key'),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              allOf(
                contains('Kimi search failed'),
                contains('$status'),
                contains('track-123'),
              ),
            ),
          ),
        );
      });
    }

    test('does not silently accept a malformed success response', () async {
      final service = KimiSearchService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        service.search(
          query: 'test',
          commonOptions: const SearchCommonOptions(),
          serviceOptions: KimiOptions(id: 'kimi', apiKey: 'key'),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
