import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/core/services/search/providers/tavily_search_service.dart';
import 'package:Kelivo/core/services/search/web_fetch.dart';
import 'package:Kelivo/core/services/search/web_fetch_service.dart';
import 'package:Kelivo/core/services/search/web_fetch_tool_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/business_test_harness.dart';

const _common = SearchCommonOptions(timeout: 5000);

MockClient _html(String body, {int status = 200, List<Uri>? requested}) {
  return MockClient((request) async {
    requested?.add(request.url);
    return http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  });
}

void main() {
  final bing = BingLocalOptions(id: 'bing');
  final tavily = TavilyOptions(id: 'tavily', apiKey: 'k');
  final jina = JinaOptions(id: 'jina', apiKey: '');

  setUp(WebFetchService.clearCache);

  for (final provider in [false, true]) {
    for (final streaming in [false, true]) {
      test(
        '${provider ? 'provider' : 'local'} timeout closes ${streaming ? 'streaming' : 'unresponsive'} connections',
        () async {
          final server = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final received = Completer<void>();
          final disconnected = Completer<void>();
          final sockets = <Socket>[];
          Timer? stream;
          addTearDown(() async {
            stream?.cancel();
            for (final socket in sockets) {
              socket.destroy();
            }
            await server.close();
          });
          server.listen((socket) {
            sockets.add(socket);
            socket.listen(
              (_) {
                if (received.isCompleted) return;
                received.complete();
                if (streaming) {
                  socket.write(
                    'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n',
                  );
                  stream = Timer.periodic(const Duration(milliseconds: 20), (
                    _,
                  ) {
                    socket.write('1\r\nx\r\n');
                  });
                }
              },
              onDone: () {
                stream?.cancel();
                socket.destroy();
                if (!disconnected.isCompleted) disconnected.complete();
              },
            );
          });
          final url = 'http://${server.address.address}:${server.port}';
          const common = SearchCommonOptions(timeout: 300);
          final request = provider
              ? TavilySearchService().fetch(
                  url: 'https://example.com',
                  commonOptions: common,
                  serviceOptions: TavilyOptions(
                    id: 'timeout',
                    apiKey: 'test-key',
                    url: '$url/search',
                  ),
                )
              : WebFetchService.fetch(
                  const LocalWebFetchSource(),
                  url,
                  commonOptions: common,
                );
          final failed = expectLater(
            request,
            throwsA(
              predicate((e) => e.toString().toLowerCase().contains('timeout')),
            ),
          );
          await received.future.timeout(const Duration(seconds: 5));
          await failed;
          await expectLater(
            disconnected.future.timeout(const Duration(seconds: 2)),
            completes,
          );
        },
      );
    }
  }

  group('capability', () {
    test('marks providers and types that can read pages', () {
      expect(WebFetchService.supports(tavily), isTrue);
      expect(WebFetchService.supports(bing), isFalse);
      expect(WebFetchService.supportsType('exa_mcp'), isTrue);
      expect(WebFetchService.supportsType('querit'), isTrue);
      expect(WebFetchService.supportsType('searxng'), isFalse);
      expect(WebFetchService.supportsType('bing_local'), isFalse);
    });
  });

  group('resolve', () {
    WebFetchSource? resolve(String mode, int selected) =>
        WebFetchService.resolve(
          mode: mode,
          services: [bing, tavily, jina],
          selectedIndex: selected,
        );

    test('follows the selected search service when it can read pages', () {
      final source = resolve(WebFetchMode.follow, 1);
      expect(source, isA<ProviderWebFetchSource>());
      expect((source as ProviderWebFetchSource).options.id, 'tavily');
    });

    test('falls back to local when the selected service cannot read', () {
      expect(resolve(WebFetchMode.follow, 0), isA<LocalWebFetchSource>());
    });

    test('honors local, off, and a pinned service', () {
      expect(resolve(WebFetchMode.local, 1), isA<LocalWebFetchSource>());
      expect(resolve(WebFetchMode.off, 1), isNull);
      final pinned = resolve('jina', 0) as ProviderWebFetchSource;
      expect(pinned.options.id, 'jina');
    });

    test('a removed or non-reading pin follows the search selection', () {
      expect(
        (resolve('deleted', 1) as ProviderWebFetchSource).options.id,
        'tavily',
      );
      expect(resolve('bing', 0), isA<LocalWebFetchSource>());
    });

    test('reads locally without any configured service', () {
      expect(
        WebFetchService.resolve(
          mode: WebFetchMode.follow,
          services: const [],
          selectedIndex: 0,
        ),
        isA<LocalWebFetchSource>(),
      );
    });
  });

  group('local fetch', () {
    test('returns the page title and main content as Markdown', () async {
      final requested = <Uri>[];
      final page = await WebFetchService.fetch(
        const LocalWebFetchSource(),
        'example.com/post',
        commonOptions: _common,
        client: _html(
          '<html><head><title> Post\n Title </title></head><body>'
          '<nav>Menu</nav><article><h1>Heading</h1><p>Body text</p></article>'
          '</body></html>',
          requested: requested,
        ),
      );
      expect(requested.single.toString(), 'https://example.com/post');
      expect(page.title, 'Post Title');
      expect(page.content, contains('Body text'));
      expect(page.content, isNot(contains('Menu')));
    });

    test('reports HTTP failures and empty pages', () async {
      await expectLater(
        WebFetchService.fetch(
          const LocalWebFetchSource(),
          'https://example.com',
          commonOptions: _common,
          client: _html('nope', status: 404),
        ),
        throwsA(predicate((e) => e.toString().contains('HTTP 404'))),
      );
      await expectLater(
        WebFetchService.fetch(
          const LocalWebFetchSource(),
          'https://example.com',
          commonOptions: _common,
          client: _html('<html><body></body></html>'),
        ),
        throwsA(predicate((e) => e.toString().contains('no readable'))),
      );
    });

    test('rejects URLs without a host', () async {
      await expectLater(
        WebFetchService.fetch(
          const LocalWebFetchSource(),
          'https://',
          commonOptions: _common,
          client: _html('<p>x</p>'),
        ),
        throwsA(predicate((e) => e.toString().contains('Invalid URL'))),
      );
    });

    test('caps very long content', () async {
      final page = await WebFetchService.fetch(
        const LocalWebFetchSource(),
        'https://example.com',
        commonOptions: _common,
        client: MockClient(
          (_) async => http.Response(
            'x' * (webFetchMaxContentLength + 50),
            200,
            headers: {'content-type': 'text/plain'},
          ),
        ),
      );
      expect(page.content.length, webFetchMaxContentLength);
    });

    test('serves a repeated read from the cache', () async {
      final requested = <Uri>[];
      final client = _html('<p>Cached body</p>', requested: requested);
      for (var i = 0; i < 2; i++) {
        final page = await WebFetchService.fetchCached(
          const LocalWebFetchSource(),
          'https://example.com/a',
          commonOptions: _common,
          client: client,
        );
        expect(page.content, contains('Cached body'));
      }
      expect(requested, hasLength(1));
    });

    test('coalesces concurrent reads of the same normalized URL', () async {
      var requests = 0;
      final response = Completer<http.Response>();
      final client = MockClient((_) {
        requests++;
        return response.future;
      });
      final reads = [
        for (final url in ['example.com/post', 'https://example.com/post'])
          WebFetchService.fetchCached(
            const LocalWebFetchSource(),
            url,
            commonOptions: _common,
            client: client,
          ),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
      response.complete(http.Response('Body', 200));
      expect((await Future.wait(reads)).map((p) => p.content), [
        'Body',
        'Body',
      ]);
    });

    test('does not cache failures or repopulate a cleared cache', () async {
      final stale = Completer<http.Response>();
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        if (requests == 1) return http.Response('failed', 503);
        if (requests == 2) return stale.future;
        return http.Response('new', 200);
      });
      Future<WebFetchPage> read() => WebFetchService.fetchCached(
        const LocalWebFetchSource(),
        'https://example.com/post',
        commonOptions: _common,
        client: client,
      );
      await expectLater(read(), throwsException);
      final pending = read();
      WebFetchService.clearCache();
      expect((await read()).content, 'new');
      stale.complete(http.Response('old', 200));
      expect((await pending).content, 'old');
      expect((await read()).content, 'new');
      expect(requests, 3);
    });

    test('rejects non-web schemes before requesting a URL', () async {
      final requested = <Uri>[];
      for (final url in [
        '',
        'file:/etc/passwd',
        'mailto:user@example.com',
        'ftp://example.com',
      ]) {
        await expectLater(
          WebFetchService.fetch(
            const LocalWebFetchSource(),
            url,
            commonOptions: _common,
            client: _html('x', requested: requested),
          ),
          throwsFormatException,
        );
      }
      expect(requested, isEmpty);
    });

    test('does not split a surrogate pair at the content limit', () async {
      final page = await WebFetchService.fetch(
        const LocalWebFetchSource(),
        'https://example.com',
        commonOptions: _common,
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode('${'x' * (webFetchMaxContentLength - 1)}😀tail'),
            200,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          ),
        ),
      );
      expect(page.content, 'x' * (webFetchMaxContentLength - 1));
    });
  });

  test(
    'changing a provider key or endpoint does not reuse old content',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      server.listen((request) async {
        requests++;
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'results': [
              {
                'url': 'https://example.com/post',
                'raw_content':
                    '${request.uri.path}: ${request.headers.value('authorization')}',
              },
            ],
          }),
        );
        await request.response.close();
      });
      Future<WebFetchPage> read(
        String key,
        String path,
      ) => WebFetchService.fetchCached(
        ProviderWebFetchSource(
          TavilyOptions(
            id: 'same',
            apiKey: key,
            url: 'http://${server.address.address}:${server.port}/$path/search',
          ),
        ),
        'https://example.com/post',
        commonOptions: _common,
      );
      final alias = await WebFetchService.fetchCached(
        ProviderWebFetchSource(
          TavilyOptions(
            id: 'same',
            apiKey: 'a',
            url: 'http://${server.address.address}:${server.port}/first/search',
          ),
        ),
        'https://example.com/redirecting',
        commonOptions: _common,
      );
      expect(alias.url, 'https://example.com/post');
      expect((await read('a', 'first')).content, '/first/extract: Bearer a');
      expect((await read('b', 'first')).content, '/first/extract: Bearer b');
      expect((await read('b', 'second')).content, '/second/extract: Bearer b');
      await read('b', 'second');
      expect(requests, 3);
    },
  );

  group('fetch_url tool', () {
    test('pages long content with next_start_index', () {
      final content = 'a' * (WebFetchToolService.pageSize + 5);
      final first = WebFetchToolService.window('u', 't', content, 0);
      expect(first['content'], hasLength(WebFetchToolService.pageSize));
      expect(first['total_length'], content.length);
      expect(first['next_start_index'], WebFetchToolService.pageSize);

      final rest = WebFetchToolService.window(
        'u',
        't',
        content,
        WebFetchToolService.pageSize,
      );
      expect(rest['content'], 'aaaaa');
      expect(rest.containsKey('next_start_index'), isFalse);

      final past = WebFetchToolService.window('u', 't', content, 1 << 20);
      expect(past['content'], isEmpty);
    });

    test('keeps a surrogate pair together across a page cut', () {
      final content = '${'a' * (WebFetchToolService.pageSize - 1)}😀tail';
      final first = WebFetchToolService.window('u', 't', content, 0);
      expect(first['next_start_index'], WebFetchToolService.pageSize - 1);
      final next = WebFetchToolService.window(
        'u',
        't',
        content,
        first['next_start_index'] as int,
      );
      expect(next['content'], '😀tail');
    });

    test('reports when reading pages is off', () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.setWebFetchMode(WebFetchMode.off);
      final result = jsonDecode(
        await WebFetchToolService.executeFetch({
          'url': 'https://example.com',
        }, settings),
      );
      expect(result['error'], contains('turned off'));
    });

    test('returns an error object for a bad URL', () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      final result = jsonDecode(
        await WebFetchToolService.executeFetch({'url': 'https://'}, settings),
      );
      expect(result['error'], contains('Invalid URL'));
    });

    test('persists the selected mode', () async {
      final preferences = createBusinessTestPreferences();
      final settings = SettingsProvider(preferences);
      await settings.loaded;
      expect(settings.webFetchMode, WebFetchMode.follow);
      await settings.setSearchServices([bing, jina]);
      await settings.setWebFetchMode('jina');
      expect(preferences.getString('search_web_fetch_v1'), 'jina');
      final reloaded = SettingsProvider(preferences);
      await reloaded.loaded;
      expect(reloaded.webFetchMode, 'jina');
      await settings.updateSettings(settings.copyWith(searchServices: [bing]));
      expect(settings.webFetchMode, WebFetchMode.follow);
      expect(preferences.getString('search_web_fetch_v1'), WebFetchMode.follow);
    });
  });
}
