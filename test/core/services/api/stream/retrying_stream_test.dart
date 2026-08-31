import 'dart:async';

import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:Kelivo/core/services/api/retry_policy.dart';
import 'package:Kelivo/core/services/api/stream/retrying_stream.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

AutoRetryOptions _fastRetry({int maxRetries = 3}) {
  return AutoRetryOptions(
    enabled: true,
    maxRetries: maxRetries,
    initialDelayMs: 0,
    multiplier: 2,
    maxDelayMs: 0,
    jitter: false,
    retryOnNetworkError: true,
    retryStatusCodes: AutoRetryOptions.defaultRetryStatusCodes,
    retryKeywords: AutoRetryOptions.defaultRetryKeywords,
    stopKeywords: AutoRetryOptions.defaultStopKeywords,
  );
}

void main() {
  test('fails then succeeds on the next attempt', () async {
    var attempts = 0;
    final values = await retryingStream<int>(
      options: _fastRetry(),
      isCancelled: () => false,
      shouldRetry: (e) => shouldRetryError(e, _fastRetry()),
      attempt: (i) async* {
        attempts++;
        if (i == 0) throw Exception('HTTP 429: 访问量过大');
        yield 7;
      },
    ).toList();
    expect(values, [7]);
    expect(attempts, 2);
  });

  test('does not retry after the attempt has yielded an element', () async {
    var attempts = 0;
    final stream = retryingStream<int>(
      options: _fastRetry(),
      isCancelled: () => false,
      shouldRetry: (_) => true,
      attempt: (i) async* {
        attempts++;
        yield 1;
        throw Exception('HTTP 429: busy');
      },
    );
    await expectLater(stream, emitsInOrder([1, emitsError(isA<Exception>())]));
    expect(attempts, 1);
  });

  test('cancel interrupts immediately and does not retry', () async {
    var attempts = 0;
    var cancelled = false;
    final stream = retryingStream<int>(
      options: _fastRetry(),
      isCancelled: () => cancelled,
      shouldRetry: (_) => true,
      attempt: (i) async* {
        attempts++;
        cancelled = true;
        throw Exception('HTTP 429: busy');
      },
    );
    await expectLater(stream, emitsError(isA<http.ClientException>()));
    expect(attempts, 1);
  });

  test('cancel during backoff throws cancelled without waiting', () async {
    var attempts = 0;
    var cancelled = false;
    final gate = Completer<void>();
    final options = AutoRetryOptions(
      enabled: true,
      maxRetries: 3,
      initialDelayMs: 8000,
      multiplier: 2,
      maxDelayMs: 8000,
      jitter: false,
      retryOnNetworkError: true,
      retryStatusCodes: AutoRetryOptions.defaultRetryStatusCodes,
      retryKeywords: AutoRetryOptions.defaultRetryKeywords,
      stopKeywords: AutoRetryOptions.defaultStopKeywords,
    );
    final sw = Stopwatch()..start();
    final stream = retryingStream<int>(
      options: options,
      isCancelled: () => cancelled,
      cancelled: gate.future,
      shouldRetry: (_) => true,
      attempt: (i) async* {
        attempts++;
        throw Exception('HTTP 429: busy');
      },
    );
    final done = stream.toList();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    cancelled = true;
    gate.complete();
    await expectLater(done, throwsA(isA<http.ClientException>()));
    expect(sw.elapsedMilliseconds, lessThan(1500));
    expect(attempts, 1);
  });

  test('emits attempt-start after backoff so countdown can clear', () async {
    var attempts = 0;
    final values = await retryingStream<String>(
      options: _fastRetry(maxRetries: 1),
      isCancelled: () => false,
      shouldRetry: (_) => true,
      retryEvent: (attempt, delay, error) => 'pending',
      attemptStartEvent: () => 'start',
      attempt: (i) async* {
        attempts++;
        if (i == 0) throw Exception('HTTP 429: busy');
        yield 'ok';
      },
    ).toList();
    expect(values, ['pending', 'start', 'ok']);
    expect(attempts, 2);
  });

  test('exceeding maxRetries throws the last error unchanged', () async {
    final errors = <Object>[];
    var attempts = 0;
    try {
      await retryingStream<int>(
        options: _fastRetry(maxRetries: 2),
        isCancelled: () => false,
        shouldRetry: (_) => true,
        attempt: (i) async* {
          attempts++;
          final error = Exception('HTTP 429: busy $i');
          errors.add(error);
          throw error;
        },
      ).toList();
      fail('expected error');
    } catch (e) {
      expect(attempts, 3);
      expect(identical(e, errors.last), isTrue);
      expect(e.toString(), 'Exception: HTTP 429: busy 2');
    }
  });

  test('disabled options never retry', () async {
    var attempts = 0;
    final stream = retryingStream<int>(
      options: const AutoRetryOptions.defaults(),
      isCancelled: () => false,
      shouldRetry: (_) => true,
      attempt: (i) async* {
        attempts++;
        throw Exception('HTTP 429: busy');
      },
    );
    await expectLater(stream, emitsError(isA<Exception>()));
    expect(attempts, 1);
  });

  test('maxRetries of 0 still runs the first attempt', () async {
    var attempts = 0;
    final stream = retryingStream<int>(
      options: _fastRetry(maxRetries: 0),
      isCancelled: () => false,
      shouldRetry: (_) => true,
      attempt: (i) async* {
        attempts++;
        throw Exception('HTTP 429: busy');
      },
    );
    await expectLater(stream, emitsError(isA<Exception>()));
    expect(attempts, 1);
  });
}
