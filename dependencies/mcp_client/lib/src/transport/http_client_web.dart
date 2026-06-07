/// Web platform HTTP client implementation
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client_stub.dart' as stub;

/// Web platform HTTP client using package:http
class PlatformHttpClient implements stub.PlatformHttpClient {
  final http.Client _client;

  PlatformHttpClient() : _client = http.Client();

  @override
  Future<stub.PlatformHttpResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final Map<String, String> requestHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };

    String? bodyString;
    if (body != null) {
      bodyString = body is String ? body : jsonEncode(body);
    }

    final response = await _client.post(
      url,
      headers: requestHeaders,
      body: bodyString,
    );

    return WebHttpResponse(response);
  }

  @override
  Future<stub.PlatformHttpResponse> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.get(url, headers: headers);

    return WebHttpResponse(response);
  }

  @override
  void close() {
    _client.close();
  }
}

/// Web platform HTTP response wrapper
class WebHttpResponse implements stub.PlatformHttpResponse {
  final http.Response _response;
  late final Stream<List<int>> _bodyStream;

  WebHttpResponse(this._response) {
    // Create a single-subscription stream from the response body
    final controller = StreamController<List<int>>();
    controller.add(utf8.encode(_response.body));
    controller.close();
    _bodyStream = controller.stream;
  }

  @override
  int get statusCode => _response.statusCode;

  @override
  Map<String, String> get headers => _response.headers;

  @override
  Future<String> get body => Future.value(_response.body);

  @override
  Stream<List<int>> get bodyStream => _bodyStream;
}
