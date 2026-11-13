@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_client/mcp_client.dart';
import 'package:mcp_client/src/transport/event_source.dart';
import 'package:test/test.dart';

void main() {
  group('Native SSE transport', () {
    test(
      'preserves HTTP connection errors for the retry and authorization policy',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.write('Access denied');
          await request.response.close();
        });
        await expectLater(
          SseClientTransport.create(
            serverUrl: 'http://${server.address.address}:${server.port}/sse',
          ),
          throwsA(
            isA<McpHttpError>().having(
              (error) => error.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );

    test('shared parser preserves opaque IDs and rejects malformed retry', () {
      final parser = SseParser();
      final events = <SseEvent>[
        ...parser.add(
          'id:  opaque\t \r'
          'retry:  0 \r'
          'data: {}\r\r',
        ),
        ...parser.close(),
      ];

      expect(events, hasLength(1));
      expect(events.single.id, ' opaque\t ');
      expect(events.single.retry, isNull);

      final invalidId = SseParser();
      final nulEvents = <SseEvent>[
        ...invalidId.add('id: bad\u0000id\rdata: {}\r\r'),
        ...invalidId.close(),
      ];
      expect(nulEvents.single.hasId, isFalse);
    });

    test(
      'keeps an event intact when its fields arrive in separate chunks',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final eventSource = EventSource();
        final endpoint = Completer<String?>();

        addTearDown(() async {
          eventSource.close();
          await server.close(force: true);
        });

        server.listen((request) async {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write('event: endpoint\r\n');
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 25));
          request.response.write(
            'data: /messages/?session_id=server-session\n',
          );
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 25));
          request.response.write('\r\n');
          await request.response.close();
        });

        await eventSource.connect(
          'http://${server.address.address}:${server.port}/sse',
          onEndpoint: (value) {
            if (!endpoint.isCompleted) {
              endpoint.complete(value);
            }
          },
        );

        expect(
          await endpoint.future.timeout(const Duration(seconds: 1)),
          '/messages/?session_id=server-session',
        );
      },
    );

    test('sends legacy SSE messages as exact application/json', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final receivedContentType = Completer<String?>();
      SseClientTransport? transport;

      addTearDown(() async {
        transport?.close();
        await server.close(force: true);
      });

      server.listen((request) async {
        if (request.method == 'GET') {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'event: endpoint\n'
            'data: /messages/?session_id=server-session\n\n',
          );
          await request.response.close();
          return;
        }

        receivedContentType.complete(
          request.headers.value(HttpHeaders.contentTypeHeader),
        );
        await request.drain<void>();
        request.response.statusCode = HttpStatus.accepted;
        await request.response.close();
      });

      transport = await SseClientTransport.create(
        serverUrl: 'http://${server.address.address}:${server.port}/sse',
      );
      final send = transport.send({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
      });

      expect(
        await receivedContentType.future.timeout(const Duration(seconds: 1)),
        'application/json',
      );
      await send.done;
    });

    test('sends Unicode tool arguments as UTF-8 JSON', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received =
          Completer<({String? contentType, int? length, String body})>();
      SseClientTransport? transport;

      addTearDown(() async {
        transport?.close();
        await server.close(force: true);
      });

      server.listen((request) async {
        if (request.method == 'GET') {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'event: endpoint\n'
            'data: /messages/?session_id=server-session\n\n',
          );
          await request.response.close();
          return;
        }

        final body = await utf8.decoder.bind(request).join();
        received.complete((
          contentType: request.headers.value(HttpHeaders.contentTypeHeader),
          length: request.headers.contentLength,
          body: body,
        ));
        request.response.statusCode = HttpStatus.accepted;
        await request.response.close();
      });

      transport = await SseClientTransport.create(
        serverUrl: 'http://${server.address.address}:${server.port}/sse',
      );
      const query = '中文搜索';
      final message = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/call',
        'params': {
          'name': 'diary_write',
          'arguments': {'content': query},
        },
      };
      final send = transport.send(message);

      final posted = await received.future.timeout(const Duration(seconds: 1));
      expect(posted.contentType, 'application/json');
      expect(posted.length, utf8.encode(posted.body).length);
      expect(jsonDecode(posted.body), message);
      await send.done;
    });
  });
}
