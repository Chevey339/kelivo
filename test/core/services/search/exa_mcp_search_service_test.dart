import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/services/search/providers/exa_mcp_search_service.dart';
import 'package:Kelivo/core/services/search/search_service.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _results = '''Title: 第一条结果
URL: https://example.com/one
Published: 2026-10-06
Author: Example
Highlights:
第一段摘录

第二段摘录

---

网页内部的分隔线应保留。

---

Title: Second result
URL: https://example.com/two
Published: N/A
Author: N/A
Text: First paragraph

Second paragraph
Text: This is part of the page.
''';

void main() {
  test('restores Exa MCP settings independently of Exa API settings', () {
    final options = ExaMcpOptions(
      id: 'mcp',
      apiKey: 'primary',
      url: ' https://example.com/mcp?tools=web_search_exa ',
      extraApiKeys: const ['extra'],
    );
    final snapshot = BusinessSettingsRouter.normalizeAndRoute({
      'search_services_v1': jsonEncode([
        ExaOptions(id: 'api', apiKey: 'api-key').toJson(),
        options.toJson(),
      ]),
    });
    final exported = BusinessSettingsRouter.exportSnapshot(snapshot);
    final services =
        jsonDecode(exported['search_services_v1']! as String) as List;
    final restored = SearchServiceOptions.fromJson(
      (services.last as Map).cast<String, dynamic>(),
    );
    expect(restored, isA<ExaMcpOptions>());
    expect(restored.toJson(), options.toJson());
    expect(SearchService.getService(restored), isA<ExaMcpSearchService>());
    expect(SearchService.getService(restored).name, 'Exa MCP');
    expect(services.first['type'], 'exa');
    expect(BrandAssets.assetForName('Exa MCP'), 'assets/icons/exa-color.svg');
  });

  test('allows a keyless configuration and defaults the endpoint', () {
    final snapshot = BusinessSettingsRouter.normalizeAndRoute({
      'search_services_v1': jsonEncode([
        {'type': 'exa_mcp', 'id': 'keyless'},
      ]),
    });
    final exported = BusinessSettingsRouter.exportSnapshot(snapshot);
    final services =
        jsonDecode(exported['search_services_v1']! as String) as List;
    final options =
        SearchServiceOptions.fromJson(
              (services.single as Map).cast<String, dynamic>(),
            )
            as ExaMcpOptions;
    expect(options.apiKey, isEmpty);
    expect(options.resolvedUrl, 'https://mcp.exa.ai/mcp');
    expect(
      ExaMcpOptions(id: 'blank', url: '  ').resolvedUrl,
      options.resolvedUrl,
    );
  });

  test('rejects invalid persisted credentials and endpoint types', () {
    for (final invalid in <Map<String, Object?>>[
      {'apiKey': 1},
      {'url': false},
      {
        'apiKeys': [1],
      },
    ]) {
      expect(
        () => BusinessSettingsRouter.normalizeAndRoute({
          'search_services_v1': jsonEncode([
            {'type': 'exa_mcp', 'id': 'mcp', ...invalid},
          ]),
        }),
        throwsFormatException,
      );
    }
  });

  for (final sse in [false, true]) {
    test(
      'initializes MCP and preserves complete ${sse ? 'SSE' : 'JSON'} results',
      () async {
        final methods = <String>[];
        final client = _McpHttpClient((request, message) async {
          expect(request.url.toString(), ExaMcpOptions.defaultUrl);
          expect(request.headers['x-api-key'], isNull);
          expect(request.headers['accept'], contains('text/event-stream'));
          expect(request.headers['mcp-protocol-version'], '2025-06-18');
          expect(message['params'], {
            'name': 'web_search_exa',
            'arguments': {'query': '查询', 'numResults': 2},
          });
          return _toolResponse(message, text: _results, sse: sse);
        }, methods: methods);

        final result = await ExaMcpSearchService(client: client).search(
          query: '查询',
          commonOptions: const SearchCommonOptions(resultSize: 2),
          serviceOptions: ExaMcpOptions(id: 'anonymous'),
        );

        expect(methods.first, 'initialize');
        expect(
          methods,
          containsAllInOrder(['notifications/initialized', 'tools/call']),
        );
        expect(result.items, hasLength(2));
        expect(result.items.first.title, '第一条结果');
        expect(result.items.first.url, 'https://example.com/one');
        expect(
          result.items.first.text,
          '第一段摘录\n\n第二段摘录\n\n---\n\n网页内部的分隔线应保留。',
        );
        expect(
          result.items.last.text,
          'First paragraph\n\nSecond paragraph\nText: This is part of the page.',
        );
        expect(client.closed, isFalse);
        client.close();
      },
    );
  }

  test('uses the custom endpoint and rotates keys once per search', () async {
    final keys = <String?>[];
    final client = _McpHttpClient((request, message) async {
      expect(
        request.url.toString(),
        'https://example.com/mcp?tools=web_search_exa',
      );
      keys.add(request.headers['x-api-key']);
      return _toolResponse(message, text: _results);
    });
    final options = ExaMcpOptions(
      id: 'rotation',
      url: ' https://example.com/mcp?tools=web_search_exa ',
      apiKey: ' primary ',
      extraApiKeys: const ['extra'],
    );
    for (var index = 0; index < 3; index++) {
      final result = await ExaMcpSearchService(client: client).search(
        query: 'test',
        commonOptions: const SearchCommonOptions(resultSize: 1),
        serviceOptions: options,
      );
      expect(result.items, hasLength(1));
    }
    expect(keys, ['primary', 'extra', 'primary']);
    expect(client.closed, isFalse);
    client.close();
  });

  test('preserves CRLF paragraphs and multiple text content blocks', () async {
    final client = _McpHttpClient((request, message) async {
      return _rpcResponse(message, {
        'content': [
          {'type': 'text', 'text': _results.replaceAll('\n', '\r\n')},
          {
            'type': 'text',
            'text':
                'Title: N/A\nURL: https://example.com/three\nPublished: N/A\nAuthor: N/A\nHighlights:\nThird excerpt',
          },
        ],
      });
    });
    final result = await _search(client);
    expect(result.items, hasLength(3));
    expect(result.items.first.text, contains('第一段摘录\n\n第二段摘录'));
    expect(result.items.last.title, 'https://example.com/three');
    expect(result.items.last.text, 'Third excerpt');
  });

  test('keeps header-like lines inside the page content', () async {
    const text =
        'Title: Actual result\nURL: https://example.com/page\n'
        'Published: N/A\nAuthor: N/A\n'
        'Highlights:\nA page describing the following fields:\n\n'
        'Title: A quoted example\nURL: https://example.com/quoted\n'
        'Text: Keep this in the actual result.';
    final client = _McpHttpClient(
      (request, message) async => _toolResponse(message, text: text),
    );
    final result = await _search(client);
    expect(result.items, hasLength(1));
    expect(result.items.single.url, 'https://example.com/page');
    expect(result.items.single.text, contains('Title: A quoted example'));
    expect(
      result.items.single.text,
      endsWith('Keep this in the actual result.'),
    );
  });

  test(
    'keeps result examples after a divider inside the actual excerpt',
    () async {
      const text =
          'Title: API documentation\nURL: https://example.com/docs\n'
          'Published: N/A\nAuthor: N/A\nHighlights:\nExample response:\n\n'
          '---\n\nTitle: Example result\nURL: https://example.com/example\n'
          'Text: An example, not another source.\n\n'
          '---\n\nTitle: Second result\nURL: https://example.com/second\n'
          'Published: N/A\nAuthor: N/A\nHighlights:\nActual second excerpt';
      final client = _McpHttpClient(
        (request, message) async => _toolResponse(message, text: text),
      );
      final result = await ExaMcpSearchService(client: client).search(
        query: 'API documentation',
        commonOptions: const SearchCommonOptions(resultSize: 2),
        serviceOptions: ExaMcpOptions(id: 'quoted-header'),
      );
      expect(result.items.map((item) => item.url), [
        'https://example.com/docs',
        'https://example.com/second',
      ]);
      expect(result.items.first.text, contains('Title: Example result'));
      expect(
        result.items.first.text,
        endsWith('An example, not another source.'),
      );
      expect(result.items.last.text, 'Actual second excerpt');
    },
  );

  test(
    'default client releases a connection stalled before response headers',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      final requested = Completer<void>();
      final disconnected = Completer<void>();
      server.listen((socket) {
        sockets.add(socket);
        final bytes = <int>[];
        socket.listen(
          (chunk) {
            bytes.addAll(chunk);
            if (utf8.decode(bytes).contains('initialize') &&
                !requested.isCompleted) {
              requested.complete();
            }
          },
          onDone: () {
            if (!disconnected.isCompleted) disconnected.complete();
          },
        );
      });
      try {
        final search = ExaMcpSearchService().search(
          query: 'stalled search',
          commonOptions: const SearchCommonOptions(timeout: 1000),
          serviceOptions: ExaMcpOptions(
            id: 'stalled',
            url: 'http://127.0.0.1:${server.port}/mcp',
          ),
        );
        final failure = expectLater(
          search,
          throwsA(
            predicate(
              (error) => error.toString().toLowerCase().contains('timed out'),
            ),
          ),
        );
        await requested.future.timeout(const Duration(seconds: 5));
        await failure;
        await disconnected.future.timeout(const Duration(seconds: 2));
      } finally {
        for (final socket in sockets) {
          socket.destroy();
        }
        await server.close();
      }
    },
  );

  for (final text in [
    '',
    'No search results found. Please try a different query.',
  ]) {
    test('accepts an empty search response: $text', () async {
      final client = _McpHttpClient(
        (request, message) async => _toolResponse(message, text: text),
      );
      expect((await _search(client)).items, isEmpty);
    });
  }

  test('reports MCP tool errors instead of empty results', () async {
    final client = _McpHttpClient(
      (request, message) async => _toolResponse(
        message,
        text: 'Anonymous search rate limit exceeded',
        isError: true,
      ),
    );
    await expectLater(
      _search(client),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('Anonymous search rate limit exceeded'),
        ),
      ),
    );
  });

  test('reports JSON-RPC errors instead of empty results', () async {
    final client = _McpHttpClient(
      (request, message) async => http.Response(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': message['id'],
          'error': {'code': -32602, 'message': 'Invalid search arguments'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await expectLater(
      _search(client),
      throwsA(
        predicate(
          (error) => error.toString().contains('Invalid search arguments'),
        ),
      ),
    );
  });

  test('preserves HTTP failure status and detail', () async {
    final client = _McpHttpClient(
      (request, message) async => http.Response('Rate limit exceeded', 429),
    );
    await expectLater(
      _search(client),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('429') &&
              error.toString().contains('Rate limit exceeded'),
        ),
      ),
    );
  });

  for (final text in [
    'Service temporarily unavailable',
    "You've hit Exa's free MCP rate limit. To continue using without limits, create your own Exa API key.",
  ]) {
    test('reports unflagged server errors: $text', () async {
      final client = _McpHttpClient(
        (request, message) async => _toolResponse(message, text: text),
      );
      await expectLater(
        _search(client),
        throwsA(
          predicate(
            (error) =>
                error.toString() == 'Exception: Exa MCP search failed: $text',
          ),
        ),
      );
    });
  }

  test('rejects invalid result URLs', () async {
    final client = _McpHttpClient(
      (request, message) async => _toolResponse(
        message,
        text:
            'Title: Invalid\nURL: javascript:alert(1)\nPublished: N/A\nAuthor: N/A\nText: bad',
      ),
    );
    await expectLater(
      _search(client),
      throwsA(
        predicate((error) => error.toString().contains('invalid result URL')),
      ),
    );
  });

  for (final duringInitialization in [true, false]) {
    test(
      'times out and ignores a late ${duringInitialization ? 'initialize' : 'tool'} response',
      () async {
        final gate = Completer<void>();
        final client = _McpHttpClient((request, message) async {
          if (!duringInitialization) await gate.future;
          return _toolResponse(message, text: _results);
        }, initializeGate: duringInitialization ? gate.future : null);
        await expectLater(
          _search(client, timeout: 40),
          throwsA(
            predicate(
              (error) => error.toString().toLowerCase().contains('timed out'),
            ),
          ),
        );
        expect(client.closed, isFalse);
        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        client.close();
      },
    );
  }
}

Future<SearchResult> _search(http.Client client, {int timeout = 30000}) =>
    ExaMcpSearchService(client: client).search(
      query: 'test',
      commonOptions: SearchCommonOptions(timeout: timeout),
      serviceOptions: ExaMcpOptions(id: 'test'),
    );

http.Response _toolResponse(
  Map<String, dynamic> message, {
  required String text,
  bool sse = false,
  bool isError = false,
}) => _rpcResponse(message, {
  'content': [
    {'type': 'text', 'text': text},
  ],
  if (isError) 'isError': true,
}, sse: sse);

http.Response _rpcResponse(
  Map<String, dynamic> message,
  Map<String, dynamic> result, {
  bool sse = false,
}) {
  final json = const JsonEncoder.withIndent(
    '  ',
  ).convert({'jsonrpc': '2.0', 'id': message['id'], 'result': result});
  return http.Response(
    sse
        ? 'event: message\n${json.split('\n').map((line) => 'data: $line').join('\n')}\n\n'
        : json,
    200,
    headers: {
      'content-type': sse
          ? 'text/event-stream; charset=utf-8'
          : 'application/json; charset=utf-8',
    },
  );
}

class _McpHttpClient extends MockClient {
  _McpHttpClient(
    Future<http.Response> Function(http.Request, Map<String, dynamic>) onCall, {
    List<String>? methods,
    Future<void>? initializeGate,
  }) : super((request) async {
         if (request.method == 'GET') return http.Response('', 405);
         final message = jsonDecode(request.body) as Map<String, dynamic>;
         methods?.add(message['method'] as String);
         switch (message['method']) {
           case 'initialize':
             if (initializeGate != null) await initializeGate;
             return _rpcResponse(message, {
               'protocolVersion': '2025-06-18',
               'serverInfo': {'name': 'Exa', 'version': '1.0.0'},
               'capabilities': {'tools': {}},
             });
           case 'notifications/initialized':
             return http.Response('', 202);
           case 'tools/call':
             return onCall(request, message);
           default:
             throw StateError('Unexpected MCP method: ${message['method']}');
         }
       });

  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}
