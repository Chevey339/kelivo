import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/request_timeout.dart';

const _messages = [
  {'role': 'user', 'content': 'Summarize this history.'},
];

ProviderConfig _config(int port) => ProviderConfig(
  id: 'request-timeout',
  name: 'Request timeout',
  enabled: true,
  apiKey: 'test',
  baseUrl: 'http://127.0.0.1:$port/v1',
  providerType: ProviderKind.openai,
);

Future<Object> _request(
  ProviderConfig config, {
  required bool native,
  required Duration timeout,
}) => native
    ? ChatApiService.compactHistory(
        config: config,
        modelId: 'gpt-4o-mini',
        messages: _messages,
        requestId: 'compression',
        conversationId: 'chat',
        requestTimeout: timeout,
      )
    : ChatApiService.generateMessage(
        config: config,
        modelId: 'gpt-4o-mini',
        messages: _messages,
        requestId: 'compression',
        textOnly: true,
        requestTimeout: timeout,
      );

Map<String, dynamic> _response(bool native) => native
    ? {
        'output': [
          {'type': 'compaction', 'id': 'compact', 'encrypted_content': 'state'},
        ],
      }
    : {
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'summary'},
            'finish_reason': 'stop',
          },
        ],
      };

void main() {
  for (final native in [false, true]) {
    for (final mode in ['headers pending', 'continuous body', 'user cancel']) {
      test(
        'request deadline cancels the transport: native=$native $mode',
        () async {
          final server = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final received = Completer<void>();
          final disconnected = Completer<void>();
          final sockets = <Socket>[];
          final timers = <Timer>[];
          var chunks = 0;
          addTearDown(() async {
            for (final timer in timers) {
              timer.cancel();
            }
            for (final socket in sockets) {
              socket.destroy();
            }
            await server.close();
          });
          server.listen((socket) {
            sockets.add(socket);
            var started = false;
            Timer? ticker;
            void closed() {
              ticker?.cancel();
              if (!disconnected.isCompleted) disconnected.complete();
            }

            unawaited(
              socket.done.then<void>(
                (_) => closed(),
                onError: (Object _, StackTrace stack) => closed(),
              ),
            );

            socket.listen(
              (_) {
                if (started) return;
                started = true;
                received.complete();
                if (mode == 'headers pending') return;
                socket.write(
                  'HTTP/1.1 200 OK\r\n'
                  'Content-Type: application/json\r\n'
                  'Transfer-Encoding: chunked\r\n\r\n',
                );
                ticker = Timer.periodic(const Duration(milliseconds: 10), (_) {
                  chunks++;
                  socket.write('1\r\n \r\n');
                });
                timers.add(ticker!);
              },
              onDone: closed,
              onError: (Object _) => closed(),
            );
          });
          const timeout = Duration(milliseconds: 500);
          final future = _request(
            _config(server.port),
            native: native,
            timeout: timeout,
          );
          final expectation = expectLater(
            future,
            throwsA(
              mode == 'user cancel'
                  ? isNot(isA<RequestTimeoutException>())
                  : isA<RequestTimeoutException>().having(
                      (e) => e.duration,
                      'deadline',
                      timeout,
                    ),
            ),
          );
          await received.future.timeout(const Duration(seconds: 5));
          if (mode == 'user cancel') {
            ChatApiService.cancelRequest('compression');
          }
          await expectation;
          await disconnected.future.timeout(const Duration(seconds: 5));
          if (mode == 'continuous body') expect(chunks, greaterThan(2));
          expect(sockets, hasLength(1));
        },
      );
    }

    test('each request gets a fresh deadline: native=$native', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_response(native)));
        await request.response.close();
      });
      final clock = Stopwatch()..start();
      for (var i = 0; i < 2; i++) {
        await _request(
          _config(server.port),
          native: native,
          timeout: const Duration(milliseconds: 500),
        );
      }
      expect(clock.elapsed, greaterThan(const Duration(milliseconds: 500)));
    });
  }

  test(
    'native default is five minutes and a custom limit replaces it',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_response(true)));
        await request.response.close();
      });
      for (final custom in [false, true]) {
        final deadlines = <Duration>[];
        await runZoned(
          () => custom
              ? _request(
                  _config(server.port),
                  native: true,
                  timeout: const Duration(minutes: 10),
                )
              : ChatApiService.compactHistory(
                  config: _config(server.port),
                  modelId: 'gpt-4o-mini',
                  messages: _messages,
                  requestId: 'compression',
                  conversationId: 'chat',
                ),
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, callback) {
              if (duration == const Duration(minutes: 5) ||
                  duration == const Duration(minutes: 10)) {
                deadlines.add(duration);
              }
              return parent.createTimer(zone, duration, callback);
            },
          ),
        );
        expect(deadlines, [Duration(minutes: custom ? 10 : 5)]);
      }
    },
  );
}
