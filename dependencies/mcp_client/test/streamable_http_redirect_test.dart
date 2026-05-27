@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_client/mcp_client.dart';
import 'package:test/test.dart';

void main() {
  test('follows 307 redirect for streamable HTTP POST', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    final serving = _serveRedirectingMcp(server, requests);

    final transport = await StreamableHttpClientTransport.create(
      baseUrl: 'http://${server.address.host}:${server.port}/mcp',
    );
    final client = McpClient.createClient(
      McpClient.simpleConfig(
        name: 'Redirect Test Client',
        version: '1.0.0',
        requestTimeout: const Duration(seconds: 2),
      ),
    );

    addTearDown(() async {
      client.disconnect();
      await server.close(force: true);
      await serving;
    });

    await client.connect(transport);

    expect(requests, contains('POST /mcp'));
    expect(requests, contains('POST /mcp/'));
    expect(client.serverInfo?['name'], 'Redirect MCP Server');
  });
}

Future<void> _serveRedirectingMcp(
  HttpServer server,
  List<String> requests,
) async {
  await for (final request in server) {
    requests.add('${request.method} ${request.uri.path}');
    if (request.uri.path == '/mcp') {
      request.response
        ..statusCode = HttpStatus.temporaryRedirect
        ..headers.set(HttpHeaders.locationHeader, '/mcp/');
      await request.response.close();
      continue;
    }

    if (request.uri.path != '/mcp/') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    await request.drain<void>();
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('text', 'event-stream')
      ..headers.set('MCP-Session-Id', 'redirect-test-session')
      ..write(
        'event: message\n'
        'data: ${jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'protocolVersion': McpProtocol.v2025_11_25,
            'serverInfo': {'name': 'Redirect MCP Server', 'version': '1.0.0'},
            'capabilities': {'tools': {}},
          },
        })}\n\n',
      );
    await request.response.close();
  }
}
