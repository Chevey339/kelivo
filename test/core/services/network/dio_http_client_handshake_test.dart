import 'dart:io';
import 'dart:async';

import 'package:Kelivo/core/services/network/dio_http_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('cancellation interrupts a stalled TLS handshake', () async {
    final sockets = <Socket>[];
    final clientHello = Completer<void>();
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      for (final socket in sockets) {
        socket.destroy();
      }
      await server.close();
    });
    server.listen((socket) {
      sockets.add(socket);
      socket.listen((_) {
        if (!clientHello.isCompleted) clientHello.complete();
      }, onError: (Object _) {});
    });

    final token = CancelToken();
    final client = DioHttpClient(cancelToken: token, logRequests: false);
    addTearDown(client.close);
    final response = client.get(
      Uri.parse('https://127.0.0.1:${server.port}/stalled'),
    );
    await clientHello.future.timeout(const Duration(seconds: 3));
    token.cancel('stop during TLS');
    await expectLater(
      response.timeout(const Duration(seconds: 1)),
      throwsA(
        isA<http.ClientException>().having(
          (error) => error.message,
          'reason',
          contains('stop during TLS'),
        ),
      ),
    );
  });

  test('a terminated TLS handshake reports one client exception', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close());
    server.listen((socket) async {
      await socket.first;
      socket.destroy();
    });

    final client = DioHttpClient();
    addTearDown(client.close);

    await expectLater(
      client.get(Uri.parse('https://127.0.0.1:${server.port}/usage')),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('closing after an outer timeout has no secondary Dio error', () async {
    final sockets = <Socket>[];
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      for (final socket in sockets) {
        socket.destroy();
      }
      await server.close();
    });
    server.listen(sockets.add);

    final client = DioHttpClient();
    await expectLater(
      client
          .get(Uri.parse('https://127.0.0.1:${server.port}/usage'))
          .timeout(const Duration(milliseconds: 20)),
      throwsA(isA<TimeoutException>()),
    );
    client.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}
