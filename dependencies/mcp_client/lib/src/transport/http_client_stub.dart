/// Stub implementation for HTTP client abstraction
/// This file is used for conditional imports to provide platform-specific implementations
library;

import 'dart:async';

/// Abstract HTTP client interface
abstract class PlatformHttpClient {
  /// Create a platform-specific HTTP client instance
  factory PlatformHttpClient() {
    throw UnsupportedError(
      'Cannot create HTTP client - platform implementation not available',
    );
  }

  /// Send a POST request
  Future<PlatformHttpResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  });

  /// Send a GET request
  Future<PlatformHttpResponse> get(Uri url, {Map<String, String>? headers});

  /// Close the client
  void close();
}

/// Abstract HTTP response interface
abstract class PlatformHttpResponse {
  /// Response status code
  int get statusCode;

  /// Response headers
  Map<String, String> get headers;

  /// Response body as string
  Future<String> get body;

  /// Response body as stream
  Stream<List<int>> get bodyStream;
}
