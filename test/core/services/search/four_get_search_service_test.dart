import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/four_get_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const publicInstance = FourGetOptions(
    id: 'public',
    url: 'https://search.example',
  );

  test('restores the selected provider and its settings', () {
    const options = FourGetOptions(
      id: 'private',
      url: 'https://search.example/4get',
      scraper: 'brave',
      passToken: 'test-pass',
    );

    final restored = SearchServiceOptions.fromJson(options.toJson());

    expect(restored.toJson(), options.toJson());
    expect(SearchService.getService(restored), isA<FourGetSearchService>());
  });

  test('queries the mounted instance and maps usable web results', () async {
    const query = 'Flutter & 中文';
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.origin, 'https://search.example');
      expect(request.url.path, '/private/4get/api/v1/web');
      expect(request.url.queryParameters, {'s': query, 'scraper': 'brave'});
      expect(request.headers['cookie'], 'pass=test-pass');
      expect(request.followRedirects, isFalse);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'status': 'ok',
            'web': [
              {'title': 'Missing link', 'url': null},
              {
                'title': 'Flutter 文档',
                'url': 'https://docs.flutter.dev/',
                'description': '中文摘要',
              },
              {
                'title': 'Dart',
                'url': 'https://dart.dev/',
                'description': null,
              },
              {'title': 'Another result', 'url': 'https://example.com/'},
            ],
          }),
        ),
        200,
      );
    });
    addTearDown(client.close);

    final result = await FourGetSearchService(client: client).search(
      query: query,
      commonOptions: const SearchCommonOptions(resultSize: 2),
      serviceOptions: const FourGetOptions(
        id: 'private',
        url: ' https://search.example/private/4get/ ',
        scraper: ' brave ',
        passToken: ' test-pass ',
      ),
    );

    expect(result.items.map((item) => item.toJson()), [
      {
        'title': 'Flutter 文档',
        'url': 'https://docs.flutter.dev/',
        'text': '中文摘要',
      },
      {'title': 'Dart', 'url': 'https://dart.dev/', 'text': ''},
    ]);
  });

  test('uses the instance default and accepts an empty web response', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/web');
      expect(request.url.queryParameters, {'s': 'flutter'});
      expect(request.headers, isNot(contains('cookie')));
      return http.Response('{"status":"ok","web":[]}', 200);
    });
    addTearDown(client.close);

    final result = await FourGetSearchService(client: client).search(
      query: 'flutter',
      commonOptions: const SearchCommonOptions(),
      serviceOptions: publicInstance,
    );

    expect(result.items, isEmpty);
  });

  for (final (code, body, detail) in [
    (200, '{"status":"The API is disabled"}', 'API is disabled'),
    (401, '{"status":"The pass token has expired"}', 'pass token has expired'),
    (502, '<html>Bad gateway</html>', 'HTTP 502'),
  ]) {
    test('reports the instance error for HTTP $code', () async {
      final client = MockClient((_) async => http.Response(body, code));
      addTearDown(client.close);

      await expectLater(
        FourGetSearchService(client: client).search(
          query: 'flutter',
          commonOptions: const SearchCommonOptions(),
          serviceOptions: publicInstance,
        ),
        throwsA(predicate((error) => error.toString().contains(detail))),
      );
    });
  }

  test('rejects a malformed cookie value without exposing it', () async {
    final client = MockClient(
      (_) async => throw StateError('Unexpected request'),
    );
    addTearDown(client.close);

    await expectLater(
      FourGetSearchService(client: client).search(
        query: 'flutter',
        commonOptions: const SearchCommonOptions(),
        serviceOptions: const FourGetOptions(
          id: 'private',
          url: 'https://search.example',
          passToken: 'test-pass;another=value',
        ),
      ),
      throwsA(isA<FormatException>().having((e) => e.source, 'source', isNull)),
    );
  });
}
