import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../models/auto_retry_options.dart';
import '../retry_policy.dart';

/// Replays [attempt] with exponential backoff while the inner stream has
/// not yielded any element.
///
/// [onRetry] runs after a failed empty attempt that will be retried, before
/// the backoff sleep. [retryEvent] if non-null is yielded on the outer stream
/// at that same moment (used for in-bubble "retrying in N s" UI).
/// [attemptStartEvent] if non-null is yielded after the wait, before the
/// next attempt (used to clear that countdown).
Stream<T> retryingStream<T>({
  required Stream<T> Function(int attempt) attempt,
  required AutoRetryOptions options,
  required bool Function() isCancelled,
  required bool Function(Object error) shouldRetry,
  Future<void> Function(int attempt, Duration delay, Object error)? onRetry,
  T Function(int attempt, Duration delay, Object error)? retryEvent,
  T Function()? attemptStartEvent,
  Future<void>? cancelled,
}) async* {
  final maxRetries = options.enabled ? options.maxRetries : 0;
  Object? lastError;

  for (var i = 0; i <= maxRetries; i++) {
    if (isCancelled()) {
      throw http.ClientException('cancelled');
    }
    var yielded = false;
    try {
      await for (final item in attempt(i)) {
        yielded = true;
        yield item;
      }
      return;
    } catch (e) {
      lastError = e;
      if (isCancelled()) {
        throw http.ClientException('cancelled');
      }
      if (yielded) rethrow;
      if (i >= maxRetries || !shouldRetry(e)) rethrow;
      final delay = backoffDelay(i, options);
      await onRetry?.call(i, delay, e);
      // retryEvent is built here, at backoff start, so RetryPending.retryAt
      // is an absolute deadline rather than "now + delay" after persistence.
      final event = retryEvent?.call(i, delay, e);
      if (event != null) yield event;
      await interruptibleDelay(
        delay,
        isCancelled: isCancelled,
        cancelled: cancelled,
      );
      if (isCancelled()) {
        throw http.ClientException('cancelled');
      }
      final start = attemptStartEvent?.call();
      if (start != null) yield start;
    }
  }

  throw lastError!;
}

Future<void> interruptibleDelay(
  Duration delay, {
  required bool Function() isCancelled,
  Future<void>? cancelled,
}) async {
  if (delay <= Duration.zero || isCancelled()) return;
  if (cancelled != null) {
    await Future.any<void>([Future<void>.delayed(delay), cancelled]);
    return;
  }
  const slice = Duration(milliseconds: 20);
  var remaining = delay;
  while (remaining > Duration.zero) {
    if (isCancelled()) return;
    final step = remaining < slice ? remaining : slice;
    await Future<void>.delayed(step);
    remaining -= step;
  }
}
