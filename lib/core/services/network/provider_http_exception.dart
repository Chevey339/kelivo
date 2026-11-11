import 'dart:io';

import 'package:http/http.dart' as http;

/// Keep the provider's retry verdict when converting an HTTP error response.
class ProviderHttpException extends HttpException {
  ProviderHttpException(http.BaseResponse response, String body)
    : statusCode = response.statusCode,
      headers = Map.unmodifiable(response.headers),
      bodyReadError = null,
      super('HTTP ${response.statusCode}: $body');

  ProviderHttpException.bodyReadFailure(
    this.statusCode,
    Map<String, String> headers,
    Object error,
  ) : headers = Map.unmodifiable(headers),
      bodyReadError = error,
      super('HTTP $statusCode: $error');

  final int statusCode;
  final Map<String, String> headers;

  /// Preserve network retry/cancellation policy when the error body itself
  /// failed, while retaining the HTTP response's explicit no-retry verdict.
  final Object? bodyReadError;

  bool get prohibitsRetry => headers.entries.any(
    (entry) =>
        entry.key.toLowerCase() == 'x-should-retry' &&
        entry.value.trim().toLowerCase() == 'false',
  );
}
