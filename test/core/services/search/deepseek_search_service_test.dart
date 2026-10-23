import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/deepseek_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/search/web_fetch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _common = SearchCommonOptions();
const _pageUrl = 'https://example.com/article';

http.Response _json(Object body, {int status = 200}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  test('restores credentials and registers search and fetch capabilities', () {
    final options = DeepSeekOptions(
      id: 'deepseek',
      apiKey: 'primary',
      extraApiKeys: const ['secondary'],
    );
    final restored = SearchServiceOptions.fromJson(options.toJson());
    expect(restored, isA<DeepSeekOptions>());
    expect(restored.toJson(), {
      'type': 'deepseek',
      'id': 'deepseek',
      'apiKey': 'primary',
      'apiKeys': ['secondary'],
    });
    expect(SearchService.getService(restored), isA<DeepSeekSearchService>());
    expect(WebFetchService.supportsType('deepseek'), isTrue);
    for (final mode in [WebFetchMode.follow, 'deepseek']) {
      final source = WebFetchService.resolve(
        mode: mode,
        services: [restored],
        selectedIndex: 0,
      );
      expect(source, isA<ProviderWebFetchSource>());
      expect((source! as ProviderWebFetchSource).options, same(restored));
    }
  });

  test(
    'search sends the official request and reads Unicode summaries',
    () async {
      final service = DeepSeekSearchService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://api.deepseek.com/v1/tools/search',
          );
          expect(request.headers['Authorization'], 'Bearer key');
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {
            'query': '模型 site:example.com lang:zh after:2026',
            'count': 5,
            'need_content': false,
          });
          return _json({
            'results': [
              {
                'title': '模型发布 🚀',
                'url': _pageUrl,
                'snippet': '简短摘要',
                'summary': '供模型阅读的较长摘要。',
                'content': '',
                'site_name': null,
                'site_icon': null,
                'date': '2026-10-17T00:00:00+00:00',
              },
              {
                'title': '另一结果',
                'url': 'https://example.com/other',
                'snippet': '仅有短摘要',
                'summary': '  ',
                'content': '',
              },
            ],
          });
        }),
      );
      final result = await service.search(
        query: '模型 site:example.com lang:zh after:2026',
        commonOptions: const SearchCommonOptions(resultSize: 5),
        serviceOptions: DeepSeekOptions(id: 'wire', apiKey: 'key'),
      );
      expect(result.items, hasLength(2));
      expect(result.items.first.title, '模型发布 🚀');
      expect(result.items.first.url, _pageUrl);
      expect(result.items.first.text, '[Published: 2026-10-17] 供模型阅读的较长摘要。');
      expect(result.items.last.text, '仅有短摘要');
    },
  );

  test(
    'search prefixes UTC publication dates without including scores',
    () async {
      final service = DeepSeekSearchService(
        client: MockClient(
          (_) async => _json({
            'results': [
              {
                'title': 'Snippet result',
                'url': _pageUrl,
                'summary': '  ',
                'snippet': '简短摘要',
                'date': '2026-10-17T23:59:59.123Z',
                'authority': 3,
                'rerank_score': 2.3,
              },
              {
                'title': 'Offset result',
                'url': _pageUrl,
                'summary': '较长摘要',
                'date': '2026-10-17T01:00:00+08:00',
              },
            ],
          }),
        ),
      );
      final result = await service.search(
        query: 'query',
        commonOptions: _common,
        serviceOptions: DeepSeekOptions(id: 'dates', apiKey: 'key'),
      );
      expect(result.items.first.text, '[Published: 2026-10-17] 简短摘要');
      expect(result.items.last.text, '[Published: 2026-10-16] 较长摘要');
      expect(
        (result.toJson()['items'] as List).first['text'],
        result.items.first.text,
      );
    },
  );

  test(
    'search preserves summaries when publication dates are unavailable',
    () async {
      final service = DeepSeekSearchService(
        client: MockClient(
          (_) async => _json({
            'results': [
              for (final date in [
                null,
                '',
                'not-a-date',
                123,
                '2026-10-17T12:00:00',
              ])
                {
                  'title': 'Undated result',
                  'url': _pageUrl,
                  'summary': '原始摘要',
                  'date': date,
                },
            ],
          }),
        ),
      );
      final result = await service.search(
        query: 'query',
        commonOptions: _common,
        serviceOptions: DeepSeekOptions(id: 'undated', apiKey: 'key'),
      );
      expect(result.items, hasLength(5));
      expect(result.items.map((item) => item.text), everyElement('原始摘要'));
    },
  );

  for (final (requested, expected) in [(0, 1), (10, 10), (100, 50)]) {
    test('search clamps result count $requested to $expected', () async {
      final service = DeepSeekSearchService(
        client: MockClient((request) async {
          expect(jsonDecode(request.body)['count'], expected);
          return _json({'results': []});
        }),
      );
      final result = await service.search(
        query: 'query',
        commonOptions: SearchCommonOptions(resultSize: requested),
        serviceOptions: DeepSeekOptions(id: 'count', apiKey: 'key'),
      );
      expect(result.items, isEmpty);
    });
  }

  test('fetch sends one URL and preserves Markdown and Unicode', () async {
    final service = DeepSeekSearchService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.deepseek.com/v1/tools/fetch',
        );
        expect(request.headers['Authorization'], 'Bearer key');
        expect(request.headers['Content-Type'], 'application/json');
        expect(jsonDecode(request.body), {'url': _pageUrl});
        return _json({'title': '网页标题', 'content': '# 网页标题\n\n正文 🚀'});
      }),
    );
    final page = await service.fetch(
      url: _pageUrl,
      commonOptions: _common,
      serviceOptions: DeepSeekOptions(id: 'fetch', apiKey: 'key'),
    );
    expect(page.url, _pageUrl);
    expect(page.title, '网页标题');
    expect(page.content, '# 网页标题\n\n正文 🚀');
  });

  test('rotates the same key pool across search and fetch', () async {
    final keys = <String?>[];
    final service = DeepSeekSearchService(
      client: MockClient((request) async {
        keys.add(request.headers['Authorization']);
        return request.url.path.endsWith('/search')
            ? _json({'results': []})
            : _json({'title': '', 'content': 'Body'});
      }),
    );
    final options = DeepSeekOptions(
      id: 'rotation',
      apiKey: 'primary',
      extraApiKeys: const ['extra'],
    );
    await service.search(
      query: 'query',
      commonOptions: _common,
      serviceOptions: options,
    );
    await service.fetch(
      url: _pageUrl,
      commonOptions: _common,
      serviceOptions: options,
    );
    await service.search(
      query: 'query',
      commonOptions: _common,
      serviceOptions: options,
    );
    expect(keys, ['Bearer primary', 'Bearer extra', 'Bearer primary']);
  });

  for (final fetch in [false, true]) {
    final operation = fetch ? 'fetch' : 'search';
    Future<Object> request(
      DeepSeekSearchService service, {
      SearchCommonOptions common = _common,
    }) {
      final options = DeepSeekOptions(id: operation, apiKey: 'key');
      return fetch
          ? service.fetch(
              url: _pageUrl,
              commonOptions: common,
              serviceOptions: options,
            )
          : service.search(
              query: 'query',
              commonOptions: common,
              serviceOptions: options,
            );
    }

    for (final status in [400, 401, 402, 403, 404, 429, 504]) {
      test(
        '$operation exposes HTTP $status and provider error details',
        () async {
          final service = DeepSeekSearchService(
            client: MockClient(
              (_) async => _json({
                'error': {'message': '请求失败：$status', 'type': 'api_error'},
              }, status: status),
            ),
          );
          await expectLater(
            request(service),
            throwsA(
              predicate(
                (e) => e.toString().contains(
                  'DeepSeek $operation failed: Exception: HTTP $status: 请求失败：$status',
                ),
              ),
            ),
          );
        },
      );
    }

    test('$operation rejects malformed responses', () async {
      for (final body in ['not json', '{}']) {
        final service = DeepSeekSearchService(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(request(service), throwsException);
      }
    });

    test('$operation respects the configured timeout', () async {
      final response = Completer<http.Response>();
      final service = DeepSeekSearchService(
        client: MockClient((_) => response.future),
      );
      try {
        await expectLater(
          request(service, common: const SearchCommonOptions(timeout: 10)),
          throwsA(predicate((e) => e.toString().contains('TimeoutException'))),
        );
      } finally {
        response.complete(
          _json({'results': [], 'title': '', 'content': 'Body'}),
        );
      }
    });
  }
}
