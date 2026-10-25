import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/network/dio_http_client.dart';
import 'package:Kelivo/core/services/network/request_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _RealHttpOverrides extends HttpOverrides {}

class _StreamingAdapter implements HttpClientAdapter {
  _StreamingAdapter(this.stream);

  final Stream<Uint8List> stream;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(stream, 200);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_dio_error_logs_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    RequestLogger.saveOutput = false;
    await RequestLogger.setEnabled(true);
  });

  tearDown(() async {
    await RequestLogger.setEnabled(false);
    RequestLogger.saveOutput = false;
    PathProviderPlatform.instance = previousPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> waitForLog(List<String> expected) async {
    final file = File('${tempDir.path}/logs/logs.txt');
    for (var attempt = 0; attempt < 50; attempt++) {
      if (await file.exists()) {
        final content = await file.readAsString();
        if (expected.every(content.contains)) return content;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  Future<http.StreamedResponse> openLoggedStream(
    Stream<Uint8List> stream, {
    CancelToken? cancelToken,
  }) {
    RequestLogger.saveOutput = true;
    final client = DioHttpClient(
      adapter: _StreamingAdapter(stream),
      cancelToken: cancelToken,
    );
    addTearDown(client.close);
    return client.send(
      http.Request('GET', Uri.parse('https://test.invalid/stream')),
    );
  }

  Map<String, String> loggedChunks(String log) {
    final chunks = <String, String>{};
    for (final match in RegExp(r'\[RES (\d+)\] chunk=(.*)').allMatches(log)) {
      chunks.update(
        match[1]!,
        (text) => '$text${match[2]}',
        ifAbsent: () => match[2]!,
      );
    }
    return chunks;
  }

  test(
    'stream logs preserve Chinese and emoji across byte boundaries',
    () async {
      const text = 'data: 你好，流式😀输出\n\n';
      final bytes = utf8.encode(text);
      final response = await openLoggedStream(
        Stream.fromIterable(bytes.map((byte) => Uint8List.fromList([byte]))),
      );

      expect(await response.stream.toBytes(), bytes);
      final log = await waitForLog(const ['done']);
      expect(loggedChunks(log).values.single, RequestLogger.escape(text));
      expect(log, isNot(contains('\uFFFD')));
    },
  );

  test('stream logging stays incremental and preserves backpressure', () async {
    final source = StreamController<Uint8List>(sync: true);
    final response = await openLoggedStream(source.stream);
    expect(source.hasListener, isFalse);
    final received = <int>[];
    final resumed = Completer<void>();
    final done = Completer<void>();
    final subscription = response.stream.listen((bytes) {
      received.addAll(bytes);
      if (received.length == utf8.encode('prefix中').length) {
        resumed.complete();
      }
    }, onDone: done.complete);
    source.add(Uint8List.fromList([...utf8.encode('prefix'), 0xE4]));
    final partialLog = await waitForLog(const ['chunk=prefix']);
    expect(loggedChunks(partialLog).values.single, 'prefix');
    expect(partialLog, isNot(contains('\uFFFD')));

    subscription.pause();
    expect(source.isPaused, isTrue);
    source.add(Uint8List.fromList([0xB8, 0xAD]));
    expect(received, [...utf8.encode('prefix'), 0xE4]);
    subscription.resume();
    await resumed.future.timeout(const Duration(seconds: 1));
    await source.close();
    await done.future;

    expect(received, utf8.encode('prefix中'));
    final log = await waitForLog(const ['done']);
    expect(loggedChunks(log).values.single, 'prefix中');
  });

  test('interleaved responses keep independent UTF-8 log state', () async {
    final first = StreamController<Uint8List>(sync: true);
    final second = StreamController<Uint8List>(sync: true);
    final firstResponse = await openLoggedStream(first.stream);
    final secondResponse = await openLoggedStream(second.stream);
    final firstBytes = firstResponse.stream.toBytes();
    final secondBytes = secondResponse.stream.toBytes();
    final chinese = utf8.encode('中');
    final emoji = utf8.encode('😀');

    first.add(Uint8List.fromList(chinese.sublist(0, 1)));
    second.add(Uint8List.fromList(emoji.sublist(0, 2)));
    first.add(Uint8List.fromList(chinese.sublist(1)));
    second.add(Uint8List.fromList(emoji.sublist(2)));
    await first.close();
    await second.close();
    expect(await firstBytes, chinese);
    expect(await secondBytes, emoji);

    final log = await waitForLog(const ['chunk=中', 'chunk=😀']);
    final chunks = loggedChunks(log);
    expect(chunks.values, ['中', '😀']);
    final completed = await waitForLog([
      for (final id in chunks.keys) '[RES $id] done',
    ]);
    for (final id in chunks.keys) {
      expect(completed, contains('[RES $id] done'));
    }
  });

  test(
    'malformed bytes and an incomplete tail remain visible in logs',
    () async {
      final bytes = Uint8List.fromList([0x61, 0xFF, 0xE4, 0xB8]);
      final response = await openLoggedStream(Stream.value(bytes));

      expect(await response.stream.toBytes(), bytes);
      final log = await waitForLog(const ['done']);
      expect(loggedChunks(log).values.single, 'a\uFFFD\uFFFD');
      expect(log.lastIndexOf('chunk='), lessThan(log.indexOf('done')));
    },
  );

  test('a transport error flushes the incomplete log character once', () async {
    final source = StreamController<Uint8List>(sync: true);
    final response = await openLoggedStream(source.stream);
    final received = <int>[];
    final errors = <Object>[];
    final done = Completer<void>();
    response.stream.listen(
      received.addAll,
      onError: errors.add,
      onDone: done.complete,
    );
    final error = StateError('stream-broken');
    source.add(Uint8List.fromList([0xE4, 0xB8]));
    source.addError(error);
    await done.future.timeout(const Duration(seconds: 1));
    await source.close();

    expect(received, [0xE4, 0xB8]);
    expect(errors, [same(error)]);
    final log = await waitForLog(const ['error=Bad state: stream-broken']);
    expect(loggedChunks(log).values.single, '\uFFFD');
    expect(log.lastIndexOf('chunk='), lessThan(log.indexOf('error=')));
  });

  test('synchronous cancellation logs the last delivered bytes once', () async {
    var cancellations = 0;
    final source = StreamController<Uint8List>(
      sync: true,
      onCancel: () => cancellations++,
    );
    final response = await openLoggedStream(source.stream);
    final received = <int>[];
    late Future<void> cancellation;
    late StreamSubscription<List<int>> subscription;
    subscription = response.stream.listen((bytes) {
      received.addAll(bytes);
      cancellation = subscription.cancel();
    });
    source.add(Uint8List.fromList([...utf8.encode('prefix'), 0xE4, 0xB8]));
    await cancellation;
    await source.close();

    expect(cancellations, 1);
    expect(received, [...utf8.encode('prefix'), 0xE4, 0xB8]);
    final log = await waitForLog(const ['chunk=\uFFFD']);
    expect(loggedChunks(log).values.single, 'prefix\uFFFD');
  });

  test(
    'token cancellation flushes log state without changing the error',
    () async {
      var cancellations = 0;
      final source = StreamController<Uint8List>(
        sync: true,
        onCancel: () => cancellations++,
      );
      final token = CancelToken();
      final response = await openLoggedStream(
        source.stream,
        cancelToken: token,
      );
      final received = <int>[];
      final errors = <Object>[];
      final done = Completer<void>();
      response.stream.listen(
        received.addAll,
        onError: errors.add,
        onDone: done.complete,
      );
      source.add(Uint8List.fromList([0xE4, 0xB8]));
      token.cancel('stop logging');
      await done.future.timeout(const Duration(seconds: 1));
      await source.close();

      expect(cancellations, 1);
      expect(received, [0xE4, 0xB8]);
      expect(errors, [same(token.cancelError)]);
      final log = await waitForLog(const ['chunk=\uFFFD']);
      expect(loggedChunks(log).values.single, '\uFFFD');
    },
  );

  test('HTTP error body is logged when saveOutput is off', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await utf8.decoder.bind(request).drain<void>();
      request.response.statusCode = 401;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error': {'message': 'invalid api key'},
        }),
      );
      await request.response.close();
    });

    await HttpOverrides.runZoned(
      () async {
        final client = DioHttpClient();
        addTearDown(client.close);
        final uri = Uri.parse('http://127.0.0.1:${server.port}/chat');
        final response = await client.send(http.Request('POST', uri));
        await response.stream.bytesToString();
      },
      createHttpClient: (context) =>
          _RealHttpOverrides().createHttpClient(context),
    );

    final log = await waitForLog(const ['status=401', 'invalid api key']);
    expect(log, contains('status=401'));
    expect(log, contains('invalid api key'));
    expect(log, isNot(contains('chunk=')));
  });

  test('successful stream body is not logged when saveOutput is off', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await utf8.decoder.bind(request).drain<void>();
      request.response.statusCode = 200;
      request.response.write('data: unique-success-chunk-xyz\n\n');
      await request.response.close();
    });

    await HttpOverrides.runZoned(
      () async {
        final client = DioHttpClient();
        addTearDown(client.close);
        final uri = Uri.parse('http://127.0.0.1:${server.port}/chat');
        final response = await client.send(http.Request('POST', uri));
        await response.stream.bytesToString();
      },
      createHttpClient: (context) =>
          _RealHttpOverrides().createHttpClient(context),
    );

    final log = await waitForLog(const ['status=200', 'done']);
    expect(log, contains('status=200'));
    expect(log, isNot(contains('unique-success-chunk-xyz')));
    expect(log, isNot(contains('chunk=')));
  });

  test('Authorization and query keys are redacted before write', () async {
    const rawKey = 'sk-test-redact-unique-key-zzzz';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await utf8.decoder.bind(request).drain<void>();
      request.response.statusCode = 401;
      request.response.headers.set('set-cookie', 'sid=$rawKey; Path=/');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'error': {'message': 'invalid api key'},
        }),
      );
      await request.response.close();
    });

    await HttpOverrides.runZoned(
      () async {
        final client = DioHttpClient();
        addTearDown(client.close);
        final uri = Uri.parse(
          'http://127.0.0.1:${server.port}/chat?key=$rawKey',
        );
        final request = http.Request('POST', uri);
        request.headers['Authorization'] = 'Bearer $rawKey';
        request.headers['x-goog-api-key'] = rawKey;
        request.body = jsonEncode({'api_key': rawKey, 'prompt': 'hi'});
        final response = await client.send(request);
        await response.stream.bytesToString();
      },
      createHttpClient: (context) =>
          _RealHttpOverrides().createHttpClient(context),
    );

    final log = await waitForLog(const ['status=401', 'headers=']);
    expect(log, contains('status=401'));
    expect(log, isNot(contains(rawKey)));
    expect(log, contains('***'));
  });

  test('a body the size of a file upload is logged by size only', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = 200;
      request.response.write('ok');
      await request.response.close();
    });

    // Past the limit by one byte; a marker inside shows whether the bytes
    // were decoded into the log.
    final size = 4 * 1024 * 1024 + 1;
    final body = List<int>.filled(size, 0x61)
      ..setRange(0, 24, 'unique-upload-marker-xyz'.codeUnits);
    await HttpOverrides.runZoned(
      () async {
        final client = DioHttpClient();
        addTearDown(client.close);
        final uri = Uri.parse('http://127.0.0.1:${server.port}/files');
        final response = await client.send(
          http.Request('POST', uri)..bodyBytes = body,
        );
        await response.stream.bytesToString();
      },
      createHttpClient: (context) =>
          _RealHttpOverrides().createHttpClient(context),
    );

    final log = await waitForLog(const ['status=200']);
    expect(log, contains('body=<$size bytes, not logged>'));
    expect(log, isNot(contains('unique-upload-marker-xyz')));
  });

  test('a body that cannot be read fails the request as such', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var reached = 0;
    server.listen((request) async {
      reached++;
      await request.drain<void>();
      request.response.statusCode = 400;
      await request.response.close();
    });

    // A multipart upload whose file went away between the size check and
    // the read: the failure must reach the caller, not go out as an empty
    // body and come back as the server's 400.
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('http://127.0.0.1:${server.port}/files'),
          )
          ..files.add(
            http.MultipartFile(
              'file',
              Stream<List<int>>.error(
                const FileSystemException('Cannot open file'),
              ),
              3,
              filename: 'gone.csv',
            ),
          );
    await HttpOverrides.runZoned(
      () async {
        final client = DioHttpClient();
        addTearDown(client.close);
        await expectLater(
          client.send(request),
          throwsA(isA<FileSystemException>()),
        );
      },
      createHttpClient: (context) =>
          _RealHttpOverrides().createHttpClient(context),
    );
    expect(reached, 0);
  });
}
