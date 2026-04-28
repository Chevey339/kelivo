import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/services/network/dio_http_client.dart';
import 'package:Kelivo/core/services/network/request_logger.dart';

void main() {
  group('RequestLogger secret redaction', () {
    test('keeps normal headers readable while redacting sensitive headers', () {
      final encoded = RequestLogger.encodeObject(const <String, String>{
        'Content-Type': 'application/json',
        'X-Request-Id': 'request-123',
        'Authorization': 'Bearer bearer-header-secret',
        'x-api-key': 'api-key-secret',
        'xi-api-key': 'elevenlabs-secret',
      }, redactSecrets: true);

      expect(encoded, contains('Content-Type'));
      expect(encoded, contains('application/json'));
      expect(encoded, contains('X-Request-Id'));
      expect(encoded, contains('request-123'));
      expect(encoded, contains('Bearer <redacted>'));
      expect(encoded, isNot(contains('bearer-header-secret')));
      expect(encoded, isNot(contains('api-key-secret')));
      expect(encoded, isNot(contains('elevenlabs-secret')));
    });

    test('redacts mixed-case sensitive header names', () {
      final encoded = RequestLogger.encodeObject(const <String, String>{
        'AUTHORIZATION': 'Bearer mixed-case-secret',
        'X-GoOg-Api-Key': 'google-secret',
      }, redactSecrets: true);

      expect(encoded, contains('Bearer <redacted>'));
      expect(encoded, isNot(contains('mixed-case-secret')));
      expect(encoded, isNot(contains('google-secret')));
    });

    test('redacts sensitive JSON request body fields recursively', () {
      final body = jsonEncode(<String, Object?>{
        'model': 'test-model',
        'max_tokens': 128,
        'api_key': 'body-api-key-secret',
        'apiKey': 'body-camel-secret',
        'nested': <String, Object?>{
          'access_token': 'access-secret',
          'Authorization': 'Bearer body-bearer-secret',
        },
        'items': <Object?>[
          <String, Object?>{'refresh_token': 'refresh-secret'},
        ],
      });

      final sanitized = RequestLogger.sanitizeBodyForLogging(body);
      final decoded = jsonDecode(sanitized) as Map<String, dynamic>;

      expect(decoded['model'], 'test-model');
      expect(decoded['max_tokens'], 128);
      expect(decoded['api_key'], '<redacted>');
      expect(decoded['apiKey'], '<redacted>');
      expect(
        (decoded['nested'] as Map<String, dynamic>)['access_token'],
        '<redacted>',
      );
      expect(
        (decoded['nested'] as Map<String, dynamic>)['Authorization'],
        'Bearer <redacted>',
      );
      expect(
        ((decoded['items'] as List<dynamic>).single
            as Map<String, dynamic>)['refresh_token'],
        '<redacted>',
      );
      expect(sanitized, isNot(contains('body-api-key-secret')));
      expect(sanitized, isNot(contains('body-camel-secret')));
      expect(sanitized, isNot(contains('access-secret')));
      expect(sanitized, isNot(contains('body-bearer-secret')));
      expect(sanitized, isNot(contains('refresh-secret')));
    });

    test('redacts bearer tokens in malformed or non-JSON bodies', () {
      final sanitized = RequestLogger.sanitizeBodyForLogging(
        'raw body with Authorization: Bearer non-json-secret and standalone Bearer standalone-bearer-secret',
      );

      expect(sanitized, contains('Bearer <redacted>'));
      expect(sanitized, isNot(contains('non-json-secret')));
      expect(sanitized, isNot(contains('standalone-bearer-secret')));
      expect(sanitized, contains('standalone'));
    });

    test('redacts non-bearer authorization values in text fragments', () {
      final sanitized = RequestLogger.sanitizeBodyForLogging(
        'Authorization: Basic basic-auth-secret and Proxy-Authorization: Token proxy-token-secret',
      );

      expect(sanitized, contains('Authorization: Basic <redacted>'));
      expect(sanitized, contains('Proxy-Authorization: Token <redacted>'));
      expect(sanitized, isNot(contains('basic-auth-secret')));
      expect(sanitized, isNot(contains('proxy-token-secret')));
    });

    test('redacts URL query credentials and user info', () {
      final sanitized = RequestLogger.sanitizeUrlForLogging(
        Uri.parse(
          'https://user:password@example.com/v1/models?api_key=url-api-secret&key=url-key-secret&access_token=url-access-secret&model=visible-model',
        ),
      );

      expect(sanitized, contains('model=visible-model'));
      expect(sanitized, contains('api_key=%3Credacted%3E'));
      expect(sanitized, contains('key=%3Credacted%3E'));
      expect(sanitized, contains('access_token=%3Credacted%3E'));
      expect(sanitized, isNot(contains('user:password')));
      expect(sanitized, isNot(contains('url-api-secret')));
      expect(sanitized, isNot(contains('url-key-secret')));
      expect(sanitized, isNot(contains('url-access-secret')));
    });

    test('redacts URL secrets inside plain text fragments', () {
      final sanitized = RequestLogger.sanitizeBodyForLogging(
        'DioException for https://user:password@example.com/v1/models?api_key=text-api-secret&key=text-key-secret&model=visible-model',
      );

      expect(sanitized, contains('model=visible-model'));
      expect(sanitized, contains('api_key=%3Credacted%3E'));
      expect(sanitized, contains('key=%3Credacted%3E'));
      expect(sanitized, isNot(contains('user:password')));
      expect(sanitized, isNot(contains('text-api-secret')));
      expect(sanitized, isNot(contains('text-key-secret')));
    });

    test('redacts quoted sensitive keys in non-JSON fragments', () {
      final sanitized = RequestLogger.sanitizeBodyForLogging(
        'data: {"access_token":"fragment-access-secret","api_key":"fragment-api-secret"}',
      );

      expect(sanitized, contains('"access_token":"<redacted>"'));
      expect(sanitized, contains('"api_key":"<redacted>"'));
      expect(sanitized, isNot(contains('fragment-access-secret')));
      expect(sanitized, isNot(contains('fragment-api-secret')));
    });

    test('redacts malformed sensitive values without closing quotes', () {
      final sanitized = RequestLogger.sanitizeBodyForLogging(
        '{"access_token":"malformed-access-secret, "Authorization":"Bearer malformed-bearer-secret',
      );

      expect(sanitized, contains('"access_token":"<redacted>"'));
      expect(sanitized, contains('"Authorization":"Bearer <redacted>"'));
      expect(sanitized, isNot(contains('malformed-access-secret')));
      expect(sanitized, isNot(contains('malformed-bearer-secret')));
    });

    test('redacts response log secrets split across stream chunks', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'kelivo_request_logger_test_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(
        server.first.then((request) async {
          request.response.headers.contentType = ContentType.text;
          request.response.write('data: {"access_');
          await request.response.flush();
          request.response.write('token":"stream-access-secret"}\n');
          await request.response.flush();
          request.response.write('Authorization: Bearer ');
          await request.response.flush();
          request.response.write('stream-bearer-secret\n');
          await request.response.close();
        }),
      );

      RequestLogger.saveOutput = true;
      await RequestLogger.setEnabled(true);

      try {
        final client = DioHttpClient();
        try {
          final request = http.Request(
            'GET',
            Uri.parse('http://${server.address.host}:${server.port}/stream'),
          );
          final response = await client.send(request);
          await response.stream.toBytes();
        } finally {
          client.close();
        }

        final logText = await _readLogUntil(
          tempDir,
          (content) => content.contains('[RES') && content.contains('done'),
        );

        expect(logText, contains('"access_token":"<redacted>"'));
        expect(logText, contains('Bearer <redacted>'));
        expect(logText, isNot(contains('stream-access-secret')));
        expect(logText, isNot(contains('stream-bearer-secret')));
      } finally {
        await RequestLogger.setEnabled(false);
        RequestLogger.saveOutput = true;
        await server.close(force: true);
        PathProviderPlatform.instance = previousPathProvider;
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'writes response logs incrementally without waiting for done',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'kelivo_request_logger_incremental_test_',
        );
        final previousPathProvider = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

        final allowFinish = Completer<void>();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        unawaited(
          server.first.then((request) async {
            request.response.bufferOutput = false;
            request.response.headers.contentType = ContentType.text;
            request.response.write('data: {"message":"first-visible"}\n');
            await request.response.flush();
            await allowFinish.future;
            request.response.write(
              'data: {"access_token":"incremental-access-secret"}\n',
            );
            await request.response.close();
          }),
        );

        RequestLogger.saveOutput = true;
        await RequestLogger.setEnabled(true);

        try {
          final client = DioHttpClient();
          try {
            final request = http.Request(
              'GET',
              Uri.parse('http://${server.address.host}:${server.port}/stream'),
            );
            final response = await client.send(request);
            final drainFuture = response.stream.drain<void>();

            final partialLogText = await _readLogUntil(
              tempDir,
              (content) =>
                  content.contains('first-visible') &&
                  !content.contains('done'),
            );

            expect(partialLogText, contains('first-visible'));
            expect(partialLogText, isNot(contains('done')));

            allowFinish.complete();
            await drainFuture;
          } finally {
            client.close();
          }

          final logText = await _readLogUntil(
            tempDir,
            (content) => content.contains('[RES') && content.contains('done'),
          );

          expect(logText, contains('"access_token":"<redacted>"'));
          expect(logText, isNot(contains('incremental-access-secret')));
        } finally {
          if (!allowFinish.isCompleted) allowFinish.complete();
          await RequestLogger.setEnabled(false);
          RequestLogger.saveOutput = true;
          await server.close(force: true);
          PathProviderPlatform.instance = previousPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('redacts URL secrets in actual request log lines', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'kelivo_request_logger_url_test_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(
        server.first.then((request) async {
          request.response.statusCode = 204;
          await request.response.close();
        }),
      );

      await RequestLogger.setEnabled(true);

      try {
        final client = DioHttpClient();
        try {
          final request = http.Request(
            'GET',
            Uri.parse(
              'http://${server.address.host}:${server.port}/models?api_key=request-url-api-secret&key=request-url-key-secret&model=visible-model',
            ),
          );
          final response = await client.send(request);
          await response.stream.toBytes();
        } finally {
          client.close();
        }

        final logText = await _readLogUntil(
          tempDir,
          (content) => content.contains('[RES') && content.contains('done'),
        );

        expect(logText, contains('model=visible-model'));
        expect(logText, contains('api_key=%3Credacted%3E'));
        expect(logText, contains('key=%3Credacted%3E'));
        expect(logText, isNot(contains('request-url-api-secret')));
        expect(logText, isNot(contains('request-url-key-secret')));
      } finally {
        await RequestLogger.setEnabled(false);
        await server.close(force: true);
        PathProviderPlatform.instance = previousPathProvider;
        await tempDir.delete(recursive: true);
      }
    });
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

Future<String> _readLogUntil(
  Directory root,
  bool Function(String content) predicate,
) async {
  final file = File('${root.path}/logs/logs.txt');
  for (var i = 0; i < 50; i++) {
    if (await file.exists()) {
      final content = await file.readAsString();
      if (predicate(content)) return content;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return await file.exists() ? file.readAsString() : '';
}
