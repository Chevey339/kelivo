import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/mcp/kelivo_fetch/kelivo_fetch_server.dart';

void main() {
  group('Kelivo fetch MCP', () {
    late HttpServer httpServer;
    late KelivoFetchMcpServerEngine engine;
    late Uri baseUri;

    setUp(() async {
      httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUri = Uri.parse('http://127.0.0.1:${httpServer.port}');
      engine = KelivoFetchMcpServerEngine();
      httpServer.listen((request) async {
        if (request.uri.path == '/json') {
          request.response.headers.contentType = ContentType.json;
          request.response.write('''
{
  "items": [
    1,
    2
  ]
}
''');
        } else if (request.uri.path == '/unicode') {
          request.response.headers.contentType = ContentType.text;
          request.response.write('😀abc');
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.write('''
<!doctype html>
<html>
  <head><script>SCRIPT-NOISE-${List.filled(1000, 'x').join()}</script></head>
  <body>
    <nav>NAV-NOISE-${List.filled(1000, 'y').join()}</nav>
    <main><h1>Useful title</h1><p>${List.filled(6500, 'a').join()}</p></main>
    <footer>FOOTER-NOISE</footer>
  </body>
</html>
''');
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      engine.close();
      await httpServer.close(force: true);
    });

    test('advertises one compact, bounded fetch tool', () async {
      final response =
          await engine.handleMessage({
                'jsonrpc': '2.0',
                'id': 1,
                'method': 'tools/list',
              })
              as Map<String, dynamic>;

      final tools =
          (response['result'] as Map<String, dynamic>)['tools'] as List;
      expect(tools, hasLength(1));
      final tool = (tools.single as Map).cast<String, dynamic>();
      expect(tool['name'], 'kelivo_fetch');
      expect(tool['description'], contains('HTML is simplified'));
      expect(
        tool['description'],
        contains('already appears in the conversation'),
      );
      expect(tool['description'], contains('requires authentication'));

      final schema = (tool['inputSchema'] as Map).cast<String, dynamic>();
      final properties = (schema['properties'] as Map).cast<String, dynamic>();
      expect(properties['url']['description'], contains('do not add www'));
      expect(
        properties['url']['description'],
        contains('https://example.com is valid'),
      );
      expect(properties['max_length'], {
        'type': 'integer',
        'description': 'Maximum content characters to return',
        'default': 5000,
        'minimum': 1,
        'maximum': 20000,
      });
      expect(properties['start_index'], containsPair('default', 0));
      expect(properties['raw'], containsPair('default', false));
    });

    test(
      'simplifies HTML and limits default output to 5000 characters',
      () async {
        final result = await _callFetch(engine, baseUri.resolve('/html'));
        final text = _resultText(result);

        expect(text, contains('Useful title'));
        expect(text, isNot(contains('SCRIPT-NOISE')));
        expect(text, isNot(contains('NAV-NOISE')));
        expect(text, isNot(contains('FOOTER-NOISE')));
        expect(text, contains('start_index=5000'));
        expect(text.split('\n\n[Content truncated').first, hasLength(5000));
      },
    );

    test('continues a truncated response from start_index', () async {
      final result = await _callFetch(
        engine,
        baseUri.resolve('/html'),
        arguments: const {'start_index': 5000},
      );
      final text = _resultText(result);

      expect(text, isNotEmpty);
      expect(text, isNot(contains('Content truncated')));
      expect(text, matches(RegExp(r'^a+$')));
    });

    test('requires raw opt-in and still bounds raw HTML', () async {
      final result = await _callFetch(
        engine,
        baseUri.resolve('/html'),
        arguments: const {'raw': true, 'max_length': 200},
      );
      final text = _resultText(result);

      expect(text, contains('<!doctype html>'));
      expect(text, contains('SCRIPT-NOISE'));
      expect(text.split('\n\n[Content truncated').first.length, 200);
    });

    test('compacts JSON before returning it', () async {
      final result = await _callFetch(engine, baseUri.resolve('/json'));

      expect(_resultText(result), '{"items":[1,2]}');
    });

    test('does not split Unicode surrogate pairs at a boundary', () async {
      final first = await _callFetch(
        engine,
        baseUri.resolve('/unicode'),
        arguments: const {'max_length': 1},
      );
      final continued = await _callFetch(
        engine,
        baseUri.resolve('/unicode'),
        arguments: const {'max_length': 3, 'start_index': 2},
      );

      expect(_resultText(first), startsWith('😀'));
      expect(_resultText(first), contains('start_index=2'));
      expect(_resultText(continued), 'abc');
    });

    test('rejects attempts to exceed the hard output limit', () async {
      final result = await _callFetch(
        engine,
        baseUri.resolve('/html'),
        arguments: const {'max_length': 20001},
      );

      expect(result['isError'], isTrue);
      expect(_resultText(result), contains('Invalid max_length'));
    });
  });
}

Future<Map<String, dynamic>> _callFetch(
  KelivoFetchMcpServerEngine engine,
  Uri url, {
  Map<String, dynamic> arguments = const {},
}) async {
  final response =
      await engine.handleMessage({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'tools/call',
            'params': {
              'name': 'kelivo_fetch',
              'arguments': {'url': url.toString(), ...arguments},
            },
          })
          as Map<String, dynamic>;
  return ((response['result'] as Map).cast<String, dynamic>());
}

String _resultText(Map<String, dynamic> result) {
  final content = result['content'] as List;
  return ((content.single as Map)['text'] as String);
}
