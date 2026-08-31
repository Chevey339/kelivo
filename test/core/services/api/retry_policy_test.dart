import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:Kelivo/core/services/api/retry_policy.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const options = AutoRetryOptions.defaults();

  group('httpStatusFromError', () {
    test('parses HTTP code from provider HttpException text', () {
      expect(
        httpStatusFromError(
          const HttpException(
            'HTTP 429: {"error":{"code":"1305","message":"访问量过大"}}',
          ),
        ),
        429,
      );
      expect(httpStatusFromError(Exception('HTTP 503: overloaded')), 503);
      expect(httpStatusFromError(Exception('connection reset')), isNull);
    });
  });

  group('shouldRetryError', () {
    test('retries 429 and 5xx status codes', () {
      expect(
        shouldRetryError(const HttpException('HTTP 429: busy'), options),
        isTrue,
      );
      expect(
        shouldRetryError(const HttpException('HTTP 500: oops'), options),
        isTrue,
      );
      expect(
        shouldRetryError(const HttpException('HTTP 529: overloaded'), options),
        isTrue,
      );
      expect(
        shouldRetryError(const HttpException('HTTP 404: missing'), options),
        isFalse,
      );
    });

    test('retries on retry keywords even without a status code', () {
      expect(shouldRetryError(Exception('该模型当前访问量过大，请您稍后再试'), options), isTrue);
      expect(
        shouldRetryError(Exception('Rate Limit exceeded'), options),
        isTrue,
      );
    });

    test('stop keywords beat retry keywords and status codes', () {
      expect(
        shouldRetryError(const HttpException('HTTP 429: 余额不足，请充值'), options),
        isFalse,
      );
      expect(
        shouldRetryError(Exception('访问量过大 but quota exceeded'), options),
        isFalse,
      );
      expect(
        shouldRetryError(
          const HttpException('HTTP 503: insufficient_quota'),
          options,
        ),
        isFalse,
      );
    });

    test('retries network errors when retryOnNetworkError is true', () {
      expect(
        shouldRetryError(const SocketException('Failed host lookup'), options),
        isTrue,
      );
      expect(shouldRetryError(TimeoutException('timed out'), options), isTrue);
      expect(
        shouldRetryError(
          http.ClientException('Connection closed', Uri.parse('https://x')),
          options,
        ),
        isTrue,
      );
    });

    test('does not treat status-bearing ClientException as a network miss', () {
      expect(
        shouldRetryError(http.ClientException('HTTP 404: not found'), options),
        isFalse,
      );
    });

    test('skips network errors when retryOnNetworkError is false', () {
      final off = options.copyWith(retryOnNetworkError: false);
      expect(
        shouldRetryError(const SocketException('Failed host lookup'), off),
        isFalse,
      );
      expect(shouldRetryError(TimeoutException('timed out'), off), isFalse);
      expect(
        shouldRetryError(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.receiveTimeout,
            message: 'timeout',
          ),
          off,
        ),
        isFalse,
      );
    });

    test('retries mid-stream disconnect HttpException', () {
      expect(
        shouldRetryError(
          const HttpException('Connection closed while receiving data'),
          options,
        ),
        isTrue,
      );
      expect(
        shouldRetryError(
          const HttpException('Connection closed while receiving data'),
          options.copyWith(retryOnNetworkError: false),
        ),
        isFalse,
      );
    });

    test('does not retry user cancel', () {
      expect(
        shouldRetryError(http.ClientException('cancelled'), options),
        isFalse,
      );
      expect(
        shouldRetryError(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.cancel,
            message: 'The request was cancelled',
          ),
          options,
        ),
        isFalse,
      );
    });

    test('retries Dio connection-abort errors when network retry is on', () {
      expect(
        shouldRetryError(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError,
            error: const HttpException(
              'Connection closed while receiving data',
            ),
          ),
          options,
        ),
        isTrue,
      );
    });

    test('can disable network retry per call without changing options', () {
      expect(
        shouldRetryError(
          http.ClientException('Connection closed'),
          options,
          retryOnNetworkError: false,
        ),
        isFalse,
      );
      expect(
        shouldRetryError(
          const HttpException('HTTP 429: busy'),
          options,
          retryOnNetworkError: false,
        ),
        isTrue,
      );
    });

    test(
      'TimeoutException is a transport error, not a timeout-keyword hit',
      () {
        final imageOpts = options.copyWith(retryOnNetworkError: false);
        expect(
          shouldRetryError(TimeoutException('timeout'), imageOpts),
          isFalse,
        );
        expect(
          shouldRetryError(
            TimeoutException('TimeoutException after 0:00:30.000000: 超时'),
            imageOpts,
          ),
          isFalse,
        );
        expect(
          shouldRetryError(
            DioException(
              requestOptions: RequestOptions(path: '/images'),
              type: DioExceptionType.connectionTimeout,
              message: 'The request connection timed out',
            ),
            imageOpts,
          ),
          isFalse,
        );
        expect(shouldRetryError(TimeoutException('timeout'), options), isTrue);
        expect(
          shouldRetryError(
            DioException(
              requestOptions: RequestOptions(path: '/chat'),
              type: DioExceptionType.receiveTimeout,
            ),
            options,
          ),
          isTrue,
        );
        expect(
          shouldRetryError(
            const HttpException(
              'HTTP 429: {"error":{"message":"gateway timeout"}}',
            ),
            imageOpts,
          ),
          isTrue,
        );
      },
    );
  });

  group('isCancelledGenerationError', () {
    test('treats user stop as cancellation even when last error is 429', () {
      expect(
        isCancelledGenerationError(
          Exception('HTTP 429: busy'),
          requestCancelled: true,
        ),
        isTrue,
      );
      expect(
        isCancelledGenerationError(
          http.ClientException('cancelled'),
          requestCancelled: false,
        ),
        isTrue,
      );
      expect(
        isCancelledGenerationError(
          Exception('HTTP 429: busy'),
          requestCancelled: false,
        ),
        isFalse,
      );
    });
  });

  group('prepareErrorAction', () {
    test('user stop skips the prepare failed write', () {
      expect(
        prepareErrorAction(Exception('HTTP 429: busy'), requestCancelled: true),
        PrepareErrorAction.skip,
      );
      expect(
        prepareErrorAction(
          http.ClientException('cancelled'),
          requestCancelled: true,
        ),
        PrepareErrorAction.skip,
      );
    });

    test('cancel without stop persists cancelled, not failed', () {
      expect(
        prepareErrorAction(
          http.ClientException('cancelled'),
          requestCancelled: false,
        ),
        PrepareErrorAction.cancelled,
      );
    });

    test('other prepare errors persist failed', () {
      expect(
        prepareErrorAction(Exception('ocr failed'), requestCancelled: false),
        PrepareErrorAction.failed,
      );
    });
  });

  group('backoffDelay', () {
    final steady = AutoRetryOptions(
      enabled: true,
      maxRetries: 5,
      initialDelayMs: 1000,
      multiplier: 2,
      maxDelayMs: 8000,
      jitter: false,
      retryOnNetworkError: true,
      retryStatusCodes: AutoRetryOptions.defaultRetryStatusCodes,
      retryKeywords: AutoRetryOptions.defaultRetryKeywords,
      stopKeywords: AutoRetryOptions.defaultStopKeywords,
    );

    test('grows exponentially and caps at maxDelay', () {
      expect(backoffDelay(0, steady), const Duration(milliseconds: 1000));
      expect(backoffDelay(1, steady), const Duration(milliseconds: 2000));
      expect(backoffDelay(2, steady), const Duration(milliseconds: 4000));
      expect(backoffDelay(3, steady), const Duration(milliseconds: 8000));
      expect(backoffDelay(4, steady), const Duration(milliseconds: 8000));
    });

    test('jitter stays within ±20% and never exceeds maxDelay', () {
      final jittered = steady.copyWith(jitter: true);
      for (var seed = 0; seed < 40; seed++) {
        final delay = backoffDelay(0, jittered, random: Random(seed));
        expect(delay.inMilliseconds, inInclusiveRange(800, 1200));
      }
      for (var seed = 0; seed < 40; seed++) {
        final delay = backoffDelay(3, jittered, random: Random(seed));
        expect(delay.inMilliseconds, inInclusiveRange(6400, 8000));
        expect(delay.inMilliseconds, lessThanOrEqualTo(jittered.maxDelayMs));
      }
    });

    test('huge finite multiplier does not produce NaN delays', () {
      final wild = AutoRetryOptions(
        enabled: true,
        maxRetries: 5,
        initialDelayMs: 0,
        multiplier: 1e308,
        maxDelayMs: 8000,
        jitter: false,
        retryOnNetworkError: true,
        retryStatusCodes: AutoRetryOptions.defaultRetryStatusCodes,
        retryKeywords: AutoRetryOptions.defaultRetryKeywords,
        stopKeywords: AutoRetryOptions.defaultStopKeywords,
      );
      expect(wild.multiplier, AutoRetryOptions.maxMultiplier);
      expect(backoffDelay(0, wild), Duration.zero);
      expect(backoffDelay(1, wild), Duration.zero);
      expect(backoffDelay(2, wild), Duration.zero);
    });
  });
}
