import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_adapter.dart';
import 'package:Kelivo/core/services/network/dio_http_client.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _secret = 'private-code-token-state-password';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.error, {required this.statusCode});
  final Object error;
  final int? statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (statusCode == null) throw error;
    return ResponseBody(
      Stream<Uint8List>.error(error),
      statusCode!,
      headers: {
        'x-should-retry': ['false'],
        'set-cookie': [_secret],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<ProviderOAuthException> _failure(Future<Object?> future) async {
  try {
    await future;
    fail('Expected an OAuth failure');
  } on ProviderOAuthException catch (error) {
    return error;
  }
}

void main() {
  final options = RequestOptions(
    path: 'https://user:$_secret@auth.example/token?code=$_secret',
    headers: {'Authorization': 'Bearer $_secret'},
    data: {'refresh_token': _secret, 'code_verifier': _secret},
  );
  final cases = [
    (
      'DNS',
      DioException.connectionError(
        requestOptions: options,
        reason: _secret,
        error: const SocketException('Failed host lookup: $_secret'),
      ),
      ProviderOAuthFailure.network,
      ProviderOAuthTransportFailure.dns,
    ),
    (
      'TLS handshake',
      const HandshakeException(_secret),
      ProviderOAuthFailure.network,
      ProviderOAuthTransportFailure.tls,
    ),
    (
      'TLS certificate',
      DioException.badCertificate(requestOptions: options, error: _secret),
      ProviderOAuthFailure.network,
      ProviderOAuthTransportFailure.tls,
    ),
    (
      'proxy tunnel',
      const HttpException('Proxy failed to establish tunnel: $_secret'),
      ProviderOAuthFailure.network,
      ProviderOAuthTransportFailure.proxy,
    ),
    (
      'connection',
      const SocketException('Connection refused: $_secret'),
      ProviderOAuthFailure.network,
      ProviderOAuthTransportFailure.connection,
    ),
    (
      'connection with an untyped cause',
      DioException.connectionError(
        requestOptions: options,
        reason: _secret,
        error: _secret,
      ),
      ProviderOAuthFailure.network,
      ProviderOAuthTransportFailure.connection,
    ),
    (
      'socket timeout',
      const SocketException('Connection timed out: $_secret'),
      ProviderOAuthFailure.timeout,
      ProviderOAuthTransportFailure.requestTimeout,
    ),
    (
      'connection timeout',
      DioException.connectionTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 1),
        error: _secret,
      ),
      ProviderOAuthFailure.timeout,
      ProviderOAuthTransportFailure.connectionTimeout,
    ),
    (
      'send timeout',
      DioException.sendTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 1),
      ),
      ProviderOAuthFailure.timeout,
      ProviderOAuthTransportFailure.sendTimeout,
    ),
    (
      'receive timeout',
      DioException.receiveTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 1),
      ),
      ProviderOAuthFailure.timeout,
      ProviderOAuthTransportFailure.receiveTimeout,
    ),
    (
      'request timeout',
      TimeoutException(_secret),
      ProviderOAuthFailure.timeout,
      ProviderOAuthTransportFailure.requestTimeout,
    ),
    (
      'unknown transport',
      StateError(_secret),
      ProviderOAuthFailure.network,
      ProviderOAuthTransportFailure.unknown,
    ),
    (
      'cancelled',
      DioException.requestCancelled(requestOptions: options, reason: _secret),
      ProviderOAuthFailure.cancelled,
      null,
    ),
  ];
  for (final (name, cause, kind, transport) in cases) {
    for (final status in [null, 200, 503]) {
      test('$name is classified and sanitized (status: $status)', () async {
        final client = DioHttpClient(
          adapter: _Adapter(cause, statusCode: status),
          logRequests: false,
        );
        addTearDown(client.close);
        final error = await _failure(
          ChatGptOAuthAdapter().login(
            OAuthWire(client),
            OAuthCancellation(),
            (_) async => fail('No device code should be displayed'),
          ),
        );
        expect(error.kind, kind);
        expect(error.transportFailure, transport);
        expect(error.stage, ProviderOAuthStage.requestDeviceCode);
        expect(error.message, isNull);
        expect(error.code, isNull);
        expect(error.toString(), isNot(contains(_secret)));
        expect(error.toString(), isNot(contains('auth.example')));
      });
    }
  }

  for (final (path, stage) in [
    ('/usercode', ProviderOAuthStage.requestDeviceCode),
    ('/deviceauth/token', ProviderOAuthStage.waitDeviceAuthorization),
    ('/oauth/token', ProviderOAuthStage.exchangeToken),
  ]) {
    test(
      'HTTP failures retain their stage at $path and redact credentials',
      () {
        fakeAsync((async) {
          ProviderOAuthException? failure;
          var prompts = 0;
          final client = MockClient((request) async {
            if (request.url.path.endsWith(path)) {
              return http.Response(
                jsonEncode({
                  'error': {
                    'code': 'server_error',
                    'message': 'Request failed: $_secret',
                  },
                  'access_token': _secret,
                }),
                503,
              );
            }
            return http.Response(
              jsonEncode(
                request.url.path.endsWith('/usercode')
                    ? {
                        'device_auth_id': _secret,
                        'user_code': _secret,
                        'interval': '1',
                      }
                    : {'authorization_code': _secret, 'code_verifier': _secret},
              ),
              200,
            );
          });
          _failure(
            ChatGptOAuthAdapter().login(
              OAuthWire(client),
              OAuthCancellation(),
              (_) async => prompts++,
            ),
          ).then((error) => failure = error);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 4));
          expect(failure, isNotNull);
          expect(failure!.kind, ProviderOAuthFailure.requestRejected);
          expect(failure!.stage, stage);
          expect(failure!.statusCode, 503);
          expect(failure!.code, 'server_error');
          expect(failure!.message, 'Request failed: [redacted]');
          expect(failure!.transportFailure, isNull);
          expect(prompts, path == '/usercode' ? 0 : 1);
          expect(async.pendingTimers, isEmpty);
        });
      },
    );
  }

  test(
    'malformed device-code responses retain HTTP status without the body',
    () async {
      final failure = await _failure(
        ChatGptOAuthAdapter().login(
          OAuthWire(MockClient((_) async => http.Response(_secret, 200))),
          OAuthCancellation(),
          (_) async => fail('No device code should be displayed'),
        ),
      );
      expect(failure.kind, ProviderOAuthFailure.invalidResponse);
      expect(failure.stage, ProviderOAuthStage.requestDeviceCode);
      expect(failure.statusCode, 200);
      expect(failure.message, isNull);
      expect(failure.toString(), isNot(contains(_secret)));
    },
  );
}
