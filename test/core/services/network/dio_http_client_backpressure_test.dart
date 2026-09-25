import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:Kelivo/core/services/network/dio_http_client.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.open);
  final FutureOr<Stream<Uint8List>> Function() open;
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(
      requestStream == null
          ? const []
          : await requestStream.expand((bytes) => bytes).toList(),
    );
    return ResponseBody(await open(), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final fails in [false, true]) {
    test(
      fails
          ? 'a cancelled connection handles a late adapter error'
          : 'a cancelled connection releases a late response',
      () async {
        final opened = Completer<void>();
        final body = Completer<Stream<Uint8List>>();
        final token = CancelToken();
        final client = DioHttpClient(
          adapter: _Adapter(() {
            opened.complete();
            return body.future;
          }),
          cancelToken: token,
          logRequests: false,
        );
        addTearDown(client.close);
        addTearDown(() {
          if (!body.isCompleted) body.complete(const Stream.empty());
        });
        final response = client.send(
          http.Request('GET', Uri.parse('https://test.invalid')),
        );
        await opened.future;
        token.cancel('stop before headers');
        await expectLater(
          response.timeout(const Duration(seconds: 1)),
          throwsA(isA<http.ClientException>()),
        );
        if (fails) {
          body.completeError(StateError('late connection failure'));
          await Future<void>.delayed(Duration.zero);
        } else {
          final cancelled = Completer<void>();
          final source = StreamController<Uint8List>(
            onCancel: cancelled.complete,
          );
          body.complete(source.stream);
          await cancelled.future.timeout(const Duration(seconds: 1));
          expect(source.hasListener, false);
          await source.close();
        }
      },
    );
  }

  test('cancellation before a body listener releases the transport', () async {
    final source = StreamController<Uint8List>();
    var cancellations = 0;
    source.onCancel = () => cancellations++;
    final token = CancelToken();
    final client = DioHttpClient(
      adapter: _Adapter(() => source.stream),
      cancelToken: token,
      logRequests: false,
    );
    addTearDown(client.close);
    final response = await client.send(
      http.Request('GET', Uri.parse('https://test.invalid')),
    );
    token.cancel('before listen');
    await Future<void>.delayed(Duration.zero);
    expect(cancellations, 1);
    await expectLater(response.stream.toList(), throwsA(isA<DioException>()));
    await source.close();
  });

  test(
    'response demand propagates to the transport without an eager buffer',
    () async {
      final source = StreamController<Uint8List>(sync: true);
      var cancellations = 0;
      source.onCancel = () => cancellations++;
      final adapter = _Adapter(() => source.stream);
      final client = DioHttpClient(adapter: adapter, logRequests: false);
      addTearDown(client.close);
      final response = await client.send(
        http.Request('GET', Uri.parse('https://test.invalid')),
      );
      expect(source.hasListener, false);
      final seen = <int>[];
      final subscription = response.stream.listen(seen.addAll);
      source.add(Uint8List.fromList([1]));
      subscription.pause();
      expect(source.isPaused, true);
      source.add(Uint8List.fromList([2]));
      expect(seen, [1]);
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(source.isPaused, false);
      expect(seen, [1, 2]);
      await subscription.cancel();
      expect(cancellations, 1);
      await source.close();
    },
  );

  test(
    'cancelling one response preserves the token and next tool round',
    () async {
      final first = StreamController<Uint8List>();
      var calls = 0;
      final adapter = _Adapter(
        () => ++calls == 1
            ? first.stream
            : Stream.value(Uint8List.fromList([3, 4])),
      );
      final token = CancelToken();
      final client = DioHttpClient(
        adapter: adapter,
        cancelToken: token,
        logRequests: false,
      );
      addTearDown(client.close);
      final response = await client.send(
        http.Request('GET', Uri.parse('https://test.invalid')),
      );
      final subscription = response.stream.listen((_) {});
      await subscription.cancel();
      expect(token.isCancelled, false);
      final request = http.Request('POST', Uri.parse('https://test.invalid'))
        ..headers['content-type'] = 'application/json'
        ..body = '{"tool":"result"}';
      final next = await client.send(request);
      expect(await next.stream.toBytes(), [3, 4]);
      expect(adapter.bodies.last, request.bodyBytes);
      expect(adapter.requests.last.headers['content-type'], 'application/json');
      await first.close();
    },
  );

  test(
    'receive timeout is suspended during backpressure and resumes afterwards',
    () async {
      final source = StreamController<Uint8List>();
      final client = DioHttpClient(
        adapter: _Adapter(() => source.stream),
        timeout: const Duration(milliseconds: 50),
        logRequests: false,
      );
      addTearDown(client.close);
      final response = await client.send(
        http.Request('GET', Uri.parse('https://test.invalid')),
      );
      final errors = <Object>[];
      final done = Completer<void>();
      final subscription = response.stream.listen(
        (_) {},
        onError: errors.add,
        onDone: done.complete,
      );
      subscription.pause();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(errors, isEmpty);
      subscription.resume();
      await done.future.timeout(const Duration(seconds: 2));
      expect(errors.single, isA<DioException>());
      expect(
        (errors.single as DioException).type,
        DioExceptionType.receiveTimeout,
      );
      await source.close();
    },
  );

  test('the conversation cancel token terminates a paused transport', () async {
    final source = StreamController<Uint8List>();
    var cancelled = false;
    source.onCancel = () => cancelled = true;
    final token = CancelToken();
    final client = DioHttpClient(
      adapter: _Adapter(() => source.stream),
      cancelToken: token,
      logRequests: false,
    );
    addTearDown(client.close);
    final response = await client.send(
      http.Request('GET', Uri.parse('https://test.invalid')),
    );
    final errors = <Object>[];
    final subscription = response.stream.listen((_) {}, onError: errors.add);
    subscription.pause();
    token.cancel('stop');
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, true);
    subscription.resume();
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<DioException>());
    await subscription.cancel();
    await source.close();
  });
}
