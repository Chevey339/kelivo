import 'dart:convert';

import 'package:Kelivo/core/services/search/providers/anysearch_search_service.dart';
import 'package:Kelivo/core/services/search/providers/exa_search_service.dart';
import 'package:Kelivo/core/services/search/providers/firecrawl_search_service.dart';
import 'package:Kelivo/core/services/search/providers/jina_search_service.dart';
import 'package:Kelivo/core/services/search/providers/linkup_search_service.dart';
import 'package:Kelivo/core/services/search/providers/metaso_search_service.dart';
import 'package:Kelivo/core/services/search/providers/ollama_search_service.dart';
import 'package:Kelivo/core/services/search/providers/parallel_search_service.dart';
import 'package:Kelivo/core/services/search/providers/querit_search_service.dart';
import 'package:Kelivo/core/services/search/providers/tavily_search_service.dart';
import 'package:Kelivo/core/services/search/providers/tinyfish_search_service.dart';
import 'package:Kelivo/core/services/search/providers/you_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/search/web_fetch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _url = 'https://example.com/post';
const _common = SearchCommonOptions(timeout: 5000);

/// Captures the single request a fetch makes and answers with [body].
({MockClient client, List<http.Request> requests}) _respond(
  Object body, {
  int status = 200,
}) {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    return http.Response.bytes(
      utf8.encode(body is String ? body : jsonEncode(body)),
      status,
    );
  });
  return (client: client, requests: requests);
}

Map<String, dynamic> _json(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

void main() {
  group('fetch helpers', () {
    test('maps a search endpoint to its sibling fetch endpoint', () {
      expect(
        siblingFetchEndpoint(
          'https://proxy.example.com/tavily/search/',
          searchPath: '/search',
          fetchPath: '/extract',
        ),
        'https://proxy.example.com/tavily/extract',
      );
      expect(
        siblingFetchEndpoint(
          'https://proxy.example.com/search/?route=tavily',
          searchPath: '/search',
          fetchPath: '/extract',
        ),
        'https://proxy.example.com/extract?route=tavily',
      );
      expect(
        () => siblingFetchEndpoint(
          'https://proxy.example.com/custom',
          searchPath: '/search',
          fetchPath: '/extract',
        ),
        throwsFormatException,
      );
    });

    test('reads the first Markdown heading as a title', () {
      expect(firstMarkdownHeading('intro\n# Title here\n## Sub'), 'Title here');
      expect(firstMarkdownHeading('no heading'), isEmpty);
    });

    test('extracts provider error messages', () {
      expect(fetchErrorDetail('{"error":{"message":"bad key"}}'), 'bad key');
      expect(fetchErrorDetail('{"detail":"quota"}'), 'quota');
      expect(fetchErrorDetail('plain failure'), 'plain failure');
    });
  });

  test('Tavily extracts Markdown through the sibling endpoint', () async {
    final mock = _respond({
      'results': [
        {'url': _url, 'raw_content': '# Post\n\nBody'},
      ],
      'failed_results': [],
    });
    final page = await TavilySearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: TavilyOptions(
        id: 't',
        apiKey: 'tvly',
        url: 'https://gateway.example.com/search',
      ),
    );
    final request = mock.requests.single;
    expect(request.url.toString(), 'https://gateway.example.com/extract');
    expect(request.headers['Authorization'], 'Bearer tvly');
    expect(_json(request), {'urls': _url, 'format': 'markdown'});
    expect(page.title, 'Post');
    expect(page.content, '# Post\n\nBody');
  });

  test('Tavily surfaces failed_results errors', () async {
    final mock = _respond({
      'results': [],
      'failed_results': [
        {'url': _url, 'error': 'blocked'},
      ],
    });
    await expectLater(
      TavilySearchService(client: mock.client).fetch(
        url: _url,
        commonOptions: _common,
        serviceOptions: TavilyOptions(id: 't', apiKey: 'k'),
      ),
      throwsA(predicate((e) => e.toString().contains('blocked'))),
    );
  });

  test('Exa requests capped text from /contents', () async {
    final mock = _respond({
      'results': [
        {'url': _url, 'title': 'Post', 'text': 'Body'},
      ],
      'statuses': [
        {'id': _url, 'status': 'success'},
      ],
    });
    final page = await ExaSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: ExaOptions(id: 'e', apiKey: 'exa'),
    );
    final request = mock.requests.single;
    expect(request.url.toString(), 'https://api.exa.ai/contents');
    expect(_json(request), {
      'urls': [_url],
      'text': {'maxCharacters': webFetchMaxContentLength},
    });
    expect(page.title, 'Post');
    expect(page.content, 'Body');
  });

  test('Exa reports an error status tag', () async {
    final mock = _respond({
      'results': [],
      'statuses': [
        {
          'id': _url,
          'status': 'error',
          'error': {'tag': 'CRAWL_NOT_FOUND'},
        },
      ],
    });
    await expectLater(
      ExaSearchService(client: mock.client).fetch(
        url: _url,
        commonOptions: _common,
        serviceOptions: ExaOptions(id: 'e', apiKey: 'exa'),
      ),
      throwsA(predicate((e) => e.toString().contains('CRAWL_NOT_FOUND'))),
    );
  });

  test('Jina reads keyless and skips image links', () async {
    final mock = _respond({
      'code': 200,
      'data': {'title': 'Post', 'url': _url, 'content': 'Body'},
    });
    final page = await JinaSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: JinaOptions(id: 'j', apiKey: ''),
    );
    final request = mock.requests.single;
    expect(request.url.toString(), 'https://r.jina.ai/');
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(request.headers['X-Retain-Images'], 'none');
    expect(_json(request), {'url': _url});
    expect(page.title, 'Post');
    expect(page.content, 'Body');
  });

  test('Jina passes its readable error message through', () async {
    final mock = _respond({
      'code': 422,
      'readableMessage': 'Domain could not be resolved',
    }, status: 422);
    await expectLater(
      JinaSearchService(client: mock.client).fetch(
        url: _url,
        commonOptions: _common,
        serviceOptions: JinaOptions(id: 'j', apiKey: 'jina'),
      ),
      throwsA(
        predicate(
          (e) =>
              e.toString().contains('HTTP 422: Domain could not be resolved'),
        ),
      ),
    );
  });

  test('Firecrawl scrapes main-content Markdown', () async {
    final mock = _respond({
      'success': true,
      'data': {
        'markdown': 'Body',
        'metadata': {
          'title': ['Post', 'Alt'],
          'sourceURL': _url,
        },
      },
    });
    final page = await FirecrawlSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: FirecrawlOptions(id: 'f', apiKey: 'fc'),
    );
    final request = mock.requests.single;
    expect(request.url.toString(), 'https://api.firecrawl.dev/v2/scrape');
    expect(_json(request), {
      'url': _url,
      'formats': ['markdown'],
      'onlyMainContent': true,
    });
    expect(page.title, 'Post');
    expect(page.url, _url);
  });

  test('Ollama reads title and content', () async {
    final mock = _respond({'title': 'Post', 'content': 'Body', 'links': []});
    final page = await OllamaSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: OllamaOptions(id: 'o', apiKey: 'ol'),
    );
    expect(
      mock.requests.single.url.toString(),
      'https://ollama.com/api/web_fetch',
    );
    expect(page.title, 'Post');
    expect(page.content, 'Body');
  });

  test('Metaso reads the plain-text reader reply', () async {
    final mock = _respond('# Post\n\nBody');
    final page = await MetasoSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: MetasoOptions(id: 'm', apiKey: 'mk'),
    );
    final request = mock.requests.single;
    expect(request.url.toString(), 'https://metaso.cn/api/v1/reader');
    expect(request.headers['Accept'], 'text/plain');
    expect(_json(request), {'url': _url});
    expect(page.title, 'Post');
    expect(page.content, '# Post\n\nBody');
  });

  test('LinkUp returns its Markdown', () async {
    final mock = _respond({'markdown': '# Post\nBody', 'favicon': ''});
    final page = await LinkUpSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: LinkUpOptions(id: 'l', apiKey: 'lk'),
    );
    expect(
      mock.requests.single.url.toString(),
      'https://api.linkup.so/v1/fetch',
    );
    expect(page.title, 'Post');
  });

  test('Parallel asks for full content', () async {
    final mock = _respond({
      'results': [
        {'url': _url, 'title': 'Post', 'full_content': 'Body'},
      ],
      'errors': [],
    });
    final page = await ParallelSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: ParallelOptions(id: 'p', apiKey: 'pk'),
    );
    final request = mock.requests.single;
    expect(request.headers['x-api-key'], 'pk');
    expect(_json(request), {
      'urls': [_url],
      'advanced_settings': {'full_content': true},
    });
    expect(page.content, 'Body');
  });

  test('You.com reads Markdown from the contents array', () async {
    final mock = _respond([
      {'url': _url, 'title': 'Post', 'markdown': 'Body'},
    ]);
    final page = await YouSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: YouSearchOptions(id: 'y', apiKey: 'yk'),
    );
    final request = mock.requests.single;
    expect(request.url.toString(), 'https://ydc-index.io/v1/contents');
    expect(request.headers['X-API-Key'], 'yk');
    expect(page.title, 'Post');
    expect(page.content, 'Body');
  });

  test('TinyFish follows the final URL and reports errors', () async {
    final ok = _respond({
      'results': [
        {
          'url': _url,
          'final_url': 'https://example.com/final',
          'title': 'Post',
          'text': 'Body',
        },
      ],
      'errors': [],
    });
    final page = await TinyFishSearchService(client: ok.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: TinyFishOptions(id: 'tf', apiKey: 'tk'),
    );
    expect(ok.requests.single.url.toString(), 'https://api.fetch.tinyfish.ai');
    expect(page.url, 'https://example.com/final');

    final failed = _respond({
      'results': [],
      'errors': [
        {'url': _url, 'error': 'timeout'},
      ],
    });
    await expectLater(
      TinyFishSearchService(client: failed.client).fetch(
        url: _url,
        commonOptions: _common,
        serviceOptions: TinyFishOptions(id: 'tf', apiKey: 'tk'),
      ),
      throwsA(predicate((e) => e.toString().contains('timeout'))),
    );
  });

  test('TinyFish keeps fetching on a configured gateway', () async {
    final mock = _respond({
      'results': [
        {'url': _url, 'text': 'Body'},
      ],
    });
    await TinyFishSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: TinyFishOptions(
        id: 'gateway',
        apiKey: 'gateway-key',
        url: 'https://gateway.example.com/tinyfish/search?region=us',
      ),
    );
    expect(
      mock.requests.single.url.toString(),
      'https://gateway.example.com/tinyfish/fetch?region=us',
    );
    expect(mock.requests.single.headers['X-API-Key'], 'gateway-key');
  });

  test(
    'unrecognized custom endpoints fail without using the public API',
    () async {
      final mock = _respond({});
      await expectLater(
        TavilySearchService(client: mock.client).fetch(
          url: _url,
          commonOptions: _common,
          serviceOptions: TavilyOptions(
            id: 'custom',
            apiKey: 'key',
            url: 'https://gateway.example.com/custom',
          ),
        ),
        throwsA(
          predicate((e) => e.toString().contains('must end with /search')),
        ),
      );
      await expectLater(
        TinyFishSearchService(client: mock.client).fetch(
          url: _url,
          commonOptions: _common,
          serviceOptions: TinyFishOptions(
            id: 'custom',
            apiKey: 'key',
            url: 'https://gateway.example.com/custom',
          ),
        ),
        throwsA(
          predicate((e) => e.toString().contains('must end with /search')),
        ),
      );
      expect(mock.requests, isEmpty);
    },
  );

  test('AnySearch unwraps its code envelope', () async {
    final mock = _respond({
      'code': 0,
      'data': {'url': _url, 'title': 'Post', 'content': 'Body'},
    });
    final page = await AnySearchSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: AnySearchOptions(id: 'a', apiKey: ''),
    );
    final request = mock.requests.single;
    expect(request.url.toString(), 'https://api.anysearch.com/v1/extract');
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(page.content, 'Body');
  });

  test('Querit reads content and metadata title', () async {
    final mock = _respond({
      'error_code': 200,
      'results': [
        {
          'url': _url,
          'content': 'Body',
          'extrasMeta': {'title': 'Post'},
        },
      ],
      'statuses': [
        {'status': 'success'},
      ],
    });
    final page = await QueritSearchService(client: mock.client).fetch(
      url: _url,
      commonOptions: _common,
      serviceOptions: QueritOptions(id: 'q', apiKey: 'qk'),
    );
    final request = mock.requests.single;
    expect(request.url.toString(), 'https://api.querit.ai/v1/contents');
    expect(_json(request), {
      'urls': [_url],
      'format': 'markdown',
      'extrasMeta': true,
    });
    expect(page.title, 'Post');
  });
}
