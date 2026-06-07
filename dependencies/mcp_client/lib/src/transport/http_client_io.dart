/// Native platform HTTP client implementation
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'http_client_stub.dart' as stub;

/// Native platform HTTP client using dart:io
class PlatformHttpClient implements stub.PlatformHttpClient {
  final io.HttpClient _client;

  PlatformHttpClient() : _client = io.HttpClient();

  @override
  Future<stub.PlatformHttpResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = await _client.postUrl(url);

    // Set headers
    headers?.forEach((key, value) {
      request.headers.set(key, value);
    });

    // Set content type if not specified
    if (!request.headers.contentType.toString().contains('application/json')) {
      request.headers.contentType = io.ContentType.json;
    }

    // Write body
    if (body != null) {
      if (body is String) {
        request.write(body);
      } else {
        request.write(jsonEncode(body));
      }
    }

    final response = await request.close();
    return IoHttpResponse(response);
  }

  @override
  Future<stub.PlatformHttpResponse> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final request = await _client.getUrl(url);

    // Set headers
    headers?.forEach((key, value) {
      request.headers.set(key, value);
    });

    final response = await request.close();
    return IoHttpResponse(response);
  }

  @override
  void close() {
    _client.close(force: true);
  }
}

/// Native platform HTTP response wrapper
class IoHttpResponse implements stub.PlatformHttpResponse {
  final io.HttpClientResponse _response;

  IoHttpResponse(this._response);

  @override
  int get statusCode => _response.statusCode;

  @override
  Map<String, String> get headers {
    final map = <String, String>{};
    _response.headers.forEach((name, values) {
      map[name] = values.join(', ');
    });
    return map;
  }

  @override
  Future<String> get body => _response.transform(utf8.decoder).join();

  @override
  Stream<List<int>> get bodyStream => _response;
}
