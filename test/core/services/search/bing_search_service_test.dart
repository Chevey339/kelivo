import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/bing_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _oneResult = '''
  <ol id="b_results">
    <li class="b_algo">
      <h2><a href="https://flutter.dev/">Flutter</a></h2>
      <p>Build apps.</p>
    </li>
  </ol>
''';

Future<SearchResult> _searchHtml(String html, {int resultSize = 10}) {
  return BingSearchService(
    locale: const Locale('en', 'US'),
    client: MockClient(
      (_) async => http.Response(
        html,
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      ),
    ),
  ).search(
    query: 'Flutter SelectionArea 复制',
    commonOptions: SearchCommonOptions(resultSize: resultSize),
    serviceOptions: const BingLocalOptions(id: 'bing'),
  );
}

String _trackingUrl(String target, {String host = 'www.bing.com'}) {
  final encoded = base64Url.encode(utf8.encode(target)).replaceAll('=', '');
  return 'https://$host/ck/a?u=a1$encoded';
}

void main() {
  test('passes the search locale through the service factory', () {
    const options = BingLocalOptions(id: 'bing');
    final restored = SearchServiceOptions.fromJson(options.toJson());
    expect(restored, isA<BingLocalOptions>());
    expect(restored.toJson(), {'id': 'bing', 'type': 'bing_local'});
    final service = SearchService.getService(
      restored,
      locale: const Locale('de', 'DE'),
    );
    expect(service, isA<BingSearchService>());
    expect((service as BingSearchService).locale, const Locale('de', 'DE'));
  });

  test(
    'preserves the full query and uses Bing Web locale parameters',
    () async {
      const query = 'Flutter SelectionArea 复制 + C++ & "copy"';
      final service = BingSearchService(
        locale: const Locale('de', 'DE'),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'www.bing.com');
          expect(request.url.path, '/search');
          expect(request.url.queryParameters, {
            'q': query,
            'adlt': 'moderate',
            'setlang': 'de',
            'cc': 'de',
          });
          expect(request.headers['Accept-Language'], 'de,de-DE;q=0.7,en;q=0.3');
          expect(request.headers['Accept'], contains('text/html'));
          expect(request.headers['Sec-Fetch-User'], '?1');
          // Let Dart negotiate the compression it can actually decode.
          expect(request.headers.containsKey('Accept-Encoding'), isFalse);
          return http.Response(_oneResult, 200);
        }),
      );

      final result = await service.search(
        query: query,
        commonOptions: const SearchCommonOptions(),
        serviceOptions: const BingLocalOptions(id: 'bing'),
      );
      expect(result.items.single.url, 'https://flutter.dev/');
    },
  );

  for (final (locale, language, country) in <(Locale, String, String?)>[
    (const Locale('en', 'US'), 'en', null),
    (const Locale('zh', 'CN'), 'zh', null),
    (const Locale('ru', 'RU'), 'ru', null),
    (const Locale('en', 'GB'), 'en', 'gb'),
    (const Locale('zh', 'TW'), 'zh', 'tw'),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      'zh',
      'tw',
    ),
    (
      const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'HK',
      ),
      'en',
      'hk',
    ),
    (const Locale('fr'), 'fr', null),
    (const Locale('en', '001'), 'en', null),
    (const Locale('es', '419'), 'es', null),
  ]) {
    test('uses the appropriate region for ${locale.toLanguageTag()}', () async {
      final service = BingSearchService(
        locale: locale,
        client: MockClient((request) async {
          expect(request.url.queryParameters['setlang'], language);
          expect(request.url.queryParameters['cc'], country);
          expect(request.url.queryParameters.containsKey('mkt'), isFalse);
          expect(
            request.headers['Accept-Language'],
            startsWith(locale.languageCode),
          );
          return http.Response(_oneResult, 200);
        }),
      );
      await service.search(
        query: 'test',
        commonOptions: const SearchCommonOptions(),
        serviceOptions: const BingLocalOptions(id: 'bing'),
      );
    });
  }

  test(
    'reads only organic results and combines clean caption paragraphs',
    () async {
      final result = await _searchHtml('''
      <li class="b_algo"><h2><a href="https://outside.example/">Outside</a></h2></li>
      <ol id="b_results">
        <li class="b_ad"><h2><a href="https://ad.example/">Ad</a></h2></li>
        <li class="b_ans"><h2><a href="https://answer.example/">Answer card</a></h2></li>
        <li class="b_algo">
          <h2><a href="https://example.com/?a=1&amp;b=2">  Flutter <strong>选择</strong> &amp; 复制 </a>Extra label</h2>
          <div class="b_caption">
            <p><span class="algoSlug_icon extra">Web</span> 第一段&nbsp;摘要。 </p>
            <p>Second<br>paragraph, with <strong>inline</strong> text.</p>
          </div>
          <p>Third paragraph.</p>
        </li>
      </ol>
    ''');

      expect(result.items, hasLength(1));
      expect(result.items.single.title, 'Flutter 选择 & 复制');
      expect(result.items.single.url, 'https://example.com/?a=1&b=2');
      expect(
        result.items.single.text,
        '第一段 摘要。 Second paragraph, with inline text. Third paragraph.',
      );
    },
  );

  test('decodes unpadded Bing links without rewriting other hosts', () async {
    const target = 'https://example.com/文档?q=复制&x=1#section';
    final wwwLink = _trackingUrl(target);
    final cnLink = _trackingUrl('https://flutter.cn/', host: 'cn.bing.com');
    final otherLink = _trackingUrl(target, host: 'bing.com.example.org');
    final result = await _searchHtml('''
      <ol id="b_results">
        <li class="b_algo"><h2><a href="$wwwLink">WWW</a></h2></li>
        <li class="b_algo"><h2><a href="$cnLink">CN</a></h2></li>
        <li class="b_algo"><h2><a href="$otherLink">Other</a></h2></li>
        <li class="b_algo"><h2><a href="//example.org/direct">Direct</a></h2></li>
      </ol>
    ''');

    expect(result.items.map((item) => item.url), [
      Uri.parse(target).toString(),
      'https://flutter.cn/',
      otherLink,
      'https://example.org/direct',
    ]);
    expect(result.items.every((item) => item.text.isEmpty), isTrue);
  });

  test('applies the limit after invalid entries and duplicate URLs', () async {
    final duplicate = _trackingUrl('https://example.com/first');
    final unsafe = _trackingUrl('javascript:alert(1)');
    final result = await _searchHtml('''
      <ol id="b_results">
        <li class="b_algo"><h2>No anchor</h2></li>
        <li class="b_algo"><h2><a href="https://empty.example/"> </a></h2></li>
        <li class="b_algo"><h2><a href="">No URL</a></h2></li>
        <li class="b_algo"><h2><a href="javascript:alert(1)">Script</a></h2></li>
        <li class="b_algo"><h2><a href="$unsafe">Encoded script</a></h2></li>
        <li class="b_algo"><h2><a href="https://www.bing.com/ck/a?u=a1!invalid">Bad encoding</a></h2></li>
        <li class="b_algo"><h2><a href="https://example.com/first">Same title</a></h2></li>
        <li class="b_algo"><h2><a href="$duplicate">Duplicate link</a></h2></li>
        <li class="b_algo"><h2><a href="https://example.com/second">Same title</a></h2></li>
        <li class="b_algo"><h2><a href="https://example.com/third">Third</a></h2></li>
      </ol>
    ''', resultSize: 2);

    expect(result.items.map((item) => item.url), [
      'https://example.com/first',
      'https://example.com/second',
    ]);
  });

  test('reads caption variants without paragraphs', () async {
    final result = await _searchHtml('''
      <ol id="b_results"><li class="b_algo">
        <h2><a href="https://example.com/">Example</a></h2>
        <div class="b_algoSlug"><span class="algoSlug_icon">Web</span> A caption.</div>
      </li></ol>
    ''');
    expect(result.items.single.text, 'A caption.');
  });

  test('returns an empty list for an explicit no-results page', () async {
    final result = await _searchHtml('''
      <ol id="b_results"><li class="b_no">No results found.</li></ol>
    ''');
    expect(result.items, isEmpty);
  });

  for (final page in [
    '<html><body><form id="b_captcha">Verify you are human</form></body></html>',
    '<ol id="b_results"><li class="new-layout">Unknown layout</li></ol>',
    '<div class="b_no">Not a search results page</div>',
  ]) {
    test(
      'reports an unrecognized page instead of an empty success: $page',
      () async {
        await expectLater(
          _searchHtml(page),
          throwsA(
            predicate((e) => e.toString().contains('unrecognized search page')),
          ),
        );
      },
    );
  }

  test('reports HTTP failures', () async {
    final service = BingSearchService(
      locale: const Locale('en', 'US'),
      client: MockClient((_) async => http.Response('rate limited', 429)),
    );
    await expectLater(
      service.search(
        query: 'test',
        commonOptions: const SearchCommonOptions(),
        serviceOptions: const BingLocalOptions(id: 'bing'),
      ),
      throwsA(predicate((e) => e.toString().contains('429'))),
    );
  });
}
