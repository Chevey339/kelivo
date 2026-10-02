import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/provider_oauth.dart';
import '../../models/provider_plugin.dart';
import '../auth/oauth_callback.dart';
import '../auth/oauth_cancellation.dart';
import '../auth/oauth_pkce.dart';

typedef PluginCallbackFactory =
    Future<OAuthCallback> Function(
      Uri authorizationServer, {
      Uri? loopbackRedirect,
      String? expectedState,
    });

/// Public-client OAuth: external browser + authorization code + S256 PKCE.
/// Never accepts a client secret, implicit grant, pasted token or ID-token JWT
/// as proof of identity. Endpoint URLs are fixed by the approved manifest.
class PluginOAuthClient {
  PluginOAuthClient({
    required this.client,
    PluginCallbackFactory? callbackFactory,
    OAuthUrlLauncher? launcher,
    DateTime Function()? clock,
  }) : _callbackFactory = callbackFactory ?? openOAuthCallback,
       _launcher = launcher ?? _launch,
       _clock = clock ?? DateTime.now;

  final http.Client client;
  final PluginCallbackFactory _callbackFactory;
  final OAuthUrlLauncher _launcher;
  final DateTime Function() _clock;

  static const maxResponseBytes = 64 * 1024;
  static const requestTimeout = Duration(seconds: 30);
  static const loginTimeout = Duration(minutes: 5);

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<ProviderOAuthCredentials> login(
    ProviderPluginOAuth oauth,
    OAuthCancellation cancellation, {
    void Function(Uri)? onAuthorization,
  }) async {
    cancellation.check();
    final state = oauthRandomString(32);
    final verifier = oauthRandomString(32);
    OAuthCallback? callback;
    try {
      callback = await _callbackFactory(
        oauth.issuer ?? oauth.authorizationEndpoint,
        loopbackRedirect: oauth.loopbackRedirect,
        expectedState: state,
      );
      cancellation.check();
      final activeCallback = callback;
      unawaited(
        cancellation.whenCancelled.then((_) async {
          await _closeCallback(activeCallback);
        }),
      );

      final authorization = oauth.authorizationEndpoint.replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': oauth.clientId,
          'redirect_uri': callback.redirectUri.toString(),
          if (oauth.scopes.isNotEmpty) 'scope': oauth.scopes.join(' '),
          'state': state,
          'code_challenge': oauthPkceChallenge(verifier),
          'code_challenge_method': 'S256',
        },
      );
      onAuthorization?.call(authorization);

      final result = await _cancelWith(
        callback.authorize(authorization, loginTimeout, _launcher),
        cancellation,
      );
      final code = validateCallback(
        result,
        callback.redirectUri,
        state,
        issuer: oauth.issuer,
      );
      cancellation.check();

      final response = await _cancelWith(
        _token(oauth, {
          'grant_type': 'authorization_code',
          'client_id': oauth.clientId,
          'redirect_uri': callback.redirectUri.toString(),
          'code': code,
          'code_verifier': verifier,
        }),
        cancellation,
      );
      cancellation.check();
      return _credentials(response);
    } on OAuthCallbackException catch (error) {
      throw ProviderOAuthException(
        error.cancelled
            ? ProviderOAuthFailure.cancelled
            : ProviderOAuthFailure.invalidResponse,
      );
    } on TimeoutException {
      throw const ProviderOAuthException(ProviderOAuthFailure.timeout);
    } finally {
      if (callback != null) await _closeCallback(callback);
    }
  }

  static Future<void> _closeCallback(OAuthCallback callback) async {
    try {
      await callback.close();
    } catch (_) {
      // Cleanup must not mask the original error or leak into an unawaited task.
    }
  }

  static Future<T> _cancelWith<T>(
    Future<T> operation,
    OAuthCancellation cancellation,
  ) => Future.any([
    operation,
    cancellation.whenCancelled.then<T>(
      (_) => throw const ProviderOAuthException(ProviderOAuthFailure.cancelled),
    ),
  ]);

  static String validateCallback(
    Uri actual,
    Uri expected,
    String state, {
    Uri? issuer,
  }) {
    final query = actual.queryParametersAll;

    String? single(String key) {
      final values = query[key];
      return values?.length == 1 && values!.single.isNotEmpty
          ? values.single
          : null;
    }

    if (actual.scheme != expected.scheme ||
        actual.host != expected.host ||
        actual.port != expected.port ||
        actual.path != expected.path ||
        actual.userInfo.isNotEmpty ||
        actual.hasFragment ||
        single('state') != state ||
        (issuer != null && single('iss') != issuer.toString()) ||
        (query.containsKey('iss') && single('iss') == null)) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }

    // Exactly one result, even for denied authorization responses.
    if (query.containsKey('error')) {
      if (single('error') == null || query.containsKey('code')) {
        throw const ProviderOAuthException(
          ProviderOAuthFailure.invalidResponse,
        );
      }
      throw const ProviderOAuthException(ProviderOAuthFailure.denied);
    }

    final code = single('code');
    if (code == null ||
        code.length > 8192 ||
        RegExp(r'[\x00-\x20\x7f]').hasMatch(code)) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }
    return code;
  }

  Future<ProviderOAuthCredentials> refresh(
    ProviderPluginOAuth oauth,
    ProviderOAuthCredentials previous,
  ) async {
    if (previous.refreshToken.isEmpty || previous.requiresLogin) {
      throw const ProviderOAuthException(ProviderOAuthFailure.loginRequired);
    }
    return _credentials(
      await _token(oauth, {
        'grant_type': 'refresh_token',
        'client_id': oauth.clientId,
        'refresh_token': previous.refreshToken,
      }),
      previous: previous,
    );
  }

  Future<Map<String, dynamic>> _token(
    ProviderPluginOAuth oauth,
    Map<String, String> form,
  ) async {
    try {
      return await (() async {
        final request = http.Request('POST', oauth.tokenEndpoint)
          ..followRedirects = false
          ..headers['Accept'] = 'application/json'
          ..bodyFields = form;
        final response = await client.send(request);

        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxResponseBytes) {
            throw const ProviderOAuthException(
              ProviderOAuthFailure.invalidResponse,
            );
          }
          bytes.add(chunk);
        }

        Map<String, dynamic> data = const {};
        try {
          final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
          if (decoded is Map<String, dynamic>) data = decoded;
        } on FormatException {
          // Neither the token payload nor a server error body is logged.
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final invalid =
              response.statusCode == 401 ||
              const {'invalid_grant', 'invalid_token'}.contains(data['error']);
          throw ProviderOAuthException(
            invalid
                ? ProviderOAuthFailure.loginRequired
                : ProviderOAuthFailure.requestRejected,
            statusCode: response.statusCode,
          );
        }
        return data;
      })().timeout(requestTimeout);
    } on ProviderOAuthException {
      rethrow;
    } on TimeoutException {
      throw const ProviderOAuthException(ProviderOAuthFailure.timeout);
    } catch (_) {
      throw const ProviderOAuthException(ProviderOAuthFailure.network);
    }
  }

  ProviderOAuthCredentials _credentials(
    Map<String, dynamic> data, {
    ProviderOAuthCredentials? previous,
  }) {
    final access = data['access_token'];
    final type = data['token_type'];
    final seconds = switch (data['expires_in']) {
      num value => value.toDouble(),
      String value => double.tryParse(value),
      _ => null,
    };
    final refresh = data.containsKey('refresh_token')
        ? data['refresh_token']
        : previous?.refreshToken ?? '';

    bool validToken(Object? value, {bool allowEmpty = false}) =>
        value is String &&
        (allowEmpty || value.isNotEmpty) &&
        value.length <= 16384 &&
        !RegExp(r'[\x00-\x20\x7f]').hasMatch(value);

    if (!validToken(access) ||
        !validToken(refresh, allowEmpty: true) ||
        type is! String ||
        type.toLowerCase() != 'bearer' ||
        seconds == null ||
        !seconds.isFinite ||
        seconds < 1 ||
        seconds > 31536000) {
      throw const ProviderOAuthException(ProviderOAuthFailure.invalidResponse);
    }

    return ProviderOAuthCredentials(
      accessToken: access as String,
      refreshToken: refresh as String,
      expiresAt: _clock().toUtc().add(Duration(seconds: seconds.floor())),
      sessionId: previous?.sessionId ?? oauthRandomString(32),
    );
  }
}
