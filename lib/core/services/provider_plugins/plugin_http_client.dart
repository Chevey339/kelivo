import 'package:http/http.dart' as http;

import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';
import 'provider_plugin_service.dart';

/// Origin/path confinement applies to API-key plugins as well as OAuth ones.
/// OAuth bearer injection happens at the last transport boundary, so native
/// protocol code cannot accidentally send it as x-api-key or a query parameter.
class PluginHttpClient extends http.BaseClient {
  PluginHttpClient(this._inner, this._original, this._service);

  final http.Client _inner;
  final ProviderConfig _original;
  final ProviderPluginService _service;
  bool _closed = false;

  void _checkOpen() {
    if (_closed) {
      throw const ProviderOAuthException(ProviderOAuthFailure.cancelled);
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _checkOpen();
    final manifest = _original.providerPlugin!;
    if (!manifest.allowsRequest(request.url)) {
      throw const ProviderOAuthException(
        ProviderOAuthFailure.requestRejected,
        code: 'plugin_endpoint_rejected',
      );
    }

    final config = await _service.resolve(_original);
    _checkOpen();
    if (manifest.oauth == null) {
      request.followRedirects = false;
      return _inner.send(request);
    }

    final token = config.providerPluginSession!.credentials.accessToken;
    final originalParams = request.url.queryParametersAll;
    final params = Map<String, List<String>>.from(originalParams);
    // Some Gemini paths add key= before the shared HTTP transport is reached.
    params.removeWhere(
      (key, _) => const {
        'key',
        'api_key',
        'access_token',
        'refresh_token',
        'id_token',
        'token',
      }.contains(key.toLowerCase()),
    );
    final url = params.length == originalParams.length
        ? request.url
        : request.url.replace(queryParameters: params);

    final http.Request? replay;
    if (request is http.Request) {
      // Keep one small request snapshot; streaming/multipart uploads are never
      // buffered or replayed automatically after an authentication error.
      replay = _copy(request, url, token);
    } else {
      replay = null;
      if (url != request.url) {
        throw const ProviderOAuthException(
          ProviderOAuthFailure.requestRejected,
          code: 'plugin_query_credentials',
        );
      }
    }

    final first = replay == null ? request : _copy(replay, url, token);
    _authorize(first, token);
    var response = await _inner.send(first);
    if (response.statusCode != 401 || replay == null) return response;

    // A retry happens before any response bytes are exposed to the caller.
    await response.stream.drain<void>().timeout(const Duration(seconds: 5));
    _checkOpen();
    final refreshed = await _service.resolve(
      config,
      rejectedAccessToken: token,
    );
    _checkOpen();

    response = await _inner.send(
      _copy(
        replay,
        url,
        refreshed.providerPluginSession!.credentials.accessToken,
      ),
    );
    if (response.statusCode == 401) {
      try {
        await _service.markLoginRequired(refreshed);
      } catch (_) {
        // Deletion/logout during the response must not hide the HTTP status.
      }
    }
    return response;
  }

  static void _authorize(http.BaseRequest request, String token) {
    request.followRedirects = false;
    request.headers.removeWhere(
      (name, _) => const {
        'authorization',
        'x-api-key',
        'x-goog-api-key',
        'proxy-authorization',
        'cookie',
      }.contains(name.toLowerCase()),
    );
    request.headers['Authorization'] = 'Bearer $token';
  }

  static http.Request _copy(http.Request source, Uri url, String token) {
    final copy = http.Request(source.method, url)
      ..persistentConnection = source.persistentConnection
      ..headers.addAll(source.headers)
      ..bodyBytes = source.bodyBytes;
    _authorize(copy, token);
    return copy;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _inner.close();
    super.close();
  }
}
