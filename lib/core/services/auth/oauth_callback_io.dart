import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'oauth_callback_types.dart';

const _mobileOAuthChannel = MethodChannel('app.oauth');

Future<OAuthCallback> openOAuthCallback(
  Uri authorizationServer, {
  Uri? loopbackRedirect,
}) async {
  if (loopbackRedirect != null) {
    if (loopbackRedirect.scheme != "http" ||
        !{"localhost", "127.0.0.1"}.contains(loopbackRedirect.host)) {
      throw ArgumentError.value(loopbackRedirect, "loopbackRedirect");
    }
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      loopbackRedirect.port,
    );
    return _IoOAuthCallback(server, redirectUri: loopbackRedirect);
  }
  if (Platform.isAndroid) {
    return _AndroidOAuthCallback(authorizationServer);
  }
  if (Platform.isIOS) {
    return _IosOAuthCallback(authorizationServer);
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  return _IoOAuthCallback(server);
}

@visibleForTesting
OAuthCallback createAndroidOAuthCallbackForTesting(Uri authorizationServer) =>
    _AndroidOAuthCallback(authorizationServer);

String _authorizationServerHash(Uri authorizationServer) => base64UrlEncode(
  sha256.convert(utf8.encode(authorizationServer.toString())).bytes,
).replaceAll('=', '');

final class _AndroidOAuthCallback implements OAuthCallback {
  _AndroidOAuthCallback(Uri authorizationServer)
    : redirectUri = Uri(
        scheme: 'psyche.kelivo',
        // This URI is registered with authorization servers; sharing the
        // callback implementation must not rename the registered redirect.
        host: 'mcp-oauth-callback',
        path: '/${_authorizationServerHash(authorizationServer)}',
      );

  @override
  final Uri redirectUri;

  @override
  Future<Uri> authorize(
    Uri authorizationUrl,
    Duration timeout,
    OAuthUrlLauncher launchAuthorizationUrl,
  ) async {
    try {
      final value = await _mobileOAuthChannel
          .invokeMethod<String>('authenticate', {
            'url': authorizationUrl.toString(),
            'redirectUri': redirectUri.toString(),
          })
          .timeout(timeout);
      if (value == null) {
        throw const OAuthCallbackException(
          'authorization session returned no callback URL',
        );
      }
      return Uri.parse(value);
    } on TimeoutException {
      await _mobileOAuthChannel.invokeMethod<void>('cancel');
      rethrow;
    } on PlatformException catch (error) {
      throw OAuthCallbackException(
        error.message ?? 'authorization session failed',
        cancelled: error.code == 'authorization_cancelled',
      );
    }
  }

  @override
  Future<Uri> waitForCallback(Duration timeout) {
    throw UnsupportedError('Android OAuth callbacks are handled by the app');
  }

  @override
  Future<void> close() => _mobileOAuthChannel.invokeMethod<void>('cancel');
}

final class _IosOAuthCallback implements OAuthCallback {
  _IosOAuthCallback(Uri authorizationServer)
    : redirectUri = Uri(
        scheme: 'psyche.kelivo',
        path:
            '/oauth/callback/${_authorizationServerHash(authorizationServer)}',
      );

  @override
  final Uri redirectUri;

  @override
  Future<Uri> authorize(
    Uri authorizationUrl,
    Duration timeout,
    OAuthUrlLauncher launchAuthorizationUrl,
  ) async {
    try {
      final value = await _mobileOAuthChannel
          .invokeMethod<String>('authenticate', {
            'url': authorizationUrl.toString(),
            'callbackScheme': redirectUri.scheme,
          })
          .timeout(timeout);
      if (value == null) {
        throw const OAuthCallbackException(
          'authorization session returned no callback URL',
        );
      }
      return Uri.parse(value);
    } on TimeoutException {
      await _mobileOAuthChannel.invokeMethod<void>('cancel');
      rethrow;
    } on PlatformException catch (error) {
      throw OAuthCallbackException(
        error.message ?? 'authorization session failed',
        cancelled: error.code == 'authorization_cancelled',
      );
    }
  }

  @override
  Future<Uri> waitForCallback(Duration timeout) {
    throw UnsupportedError('iOS OAuth callbacks are handled by the system');
  }

  @override
  Future<void> close() => _mobileOAuthChannel.invokeMethod<void>('cancel');
}

final class _IoOAuthCallback implements OAuthCallback {
  _IoOAuthCallback(HttpServer server, {Uri? redirectUri})
    : _server = server,
      _redirectUri =
          redirectUri ??
          Uri(
            scheme: 'http',
            host: InternetAddress.loopbackIPv4.address,
            port: server.port,
            path: '/oauth/callback',
          ) {
    _callback.future.ignore();
    _subscription = _server.listen(_handleRequest);
  }

  final HttpServer _server;
  final Uri _redirectUri;
  final Completer<Uri> _callback = Completer<Uri>();
  late final StreamSubscription<HttpRequest> _subscription;
  bool _closed = false;

  @override
  Uri get redirectUri => _redirectUri;

  @override
  Future<Uri> authorize(
    Uri authorizationUrl,
    Duration timeout,
    OAuthUrlLauncher launchAuthorizationUrl,
  ) async {
    if (!await launchAuthorizationUrl(authorizationUrl)) {
      throw const OAuthCallbackException(
        'could not open the authorization URL',
      );
    }
    return waitForCallback(timeout);
  }

  @override
  Future<Uri> waitForCallback(Duration timeout) =>
      _callback.future.timeout(timeout);

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != redirectUri.path) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found');
      await request.response.close();
      return;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..write(_callbackPage());
    await request.response.close();
    if (!_callback.isCompleted) {
      _callback.complete(redirectUri.replace(query: request.uri.query));
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_callback.isCompleted) {
      _callback.completeError(
        const OAuthCallbackException(
          'authorization cancelled',
          cancelled: true,
        ),
      );
    }
    await _subscription.cancel();
    await _server.close(force: true);
  }
}

String _callbackPage() => '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Kelivo</title></head>
<body><p>Authorization received. You may close this window and return to Kelivo.</p>
</body></html>''';
