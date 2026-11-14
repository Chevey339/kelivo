import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;

/// A total request deadline, distinct from an idle timeout or user cancellation.
class RequestTimeoutException implements Exception {
  const RequestTimeoutException(this.duration);
  final Duration duration;

  @override
  String toString() => 'request_timeout:${duration.inMicroseconds}';
}

Timer? cancelOnRequestTimeout(CancelToken token, Duration? timeout) =>
    timeout == null
    ? null
    : Timer(timeout, () {
        // Preserve whichever cancellation happened first.
        if (!token.isCancelled) {
          token.cancel(RequestTimeoutException(timeout));
        }
      });

/// Transport/provider layers may replace a cancellation error with their own.
/// Recover the deadline reason from the owning token before reporting failure.
void checkRequestTimeout(CancelToken token) {
  final reason = token.cancelError?.error;
  if (reason is RequestTimeoutException) throw reason;
}
