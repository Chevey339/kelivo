import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../../models/auto_retry_options.dart';

/// Process-wide auto-retry config, synced from [SettingsProvider].
///
/// Call sites read this instead of threading options through every API
/// helper. Tests assign it directly.
class AutoRetryConfig {
  static AutoRetryOptions current = const AutoRetryOptions.defaults();
}

final RegExp _httpStatusPattern = RegExp(
  r'HTTP\s+(\d{3})',
  caseSensitive: false,
);

int? httpStatusFromError(Object error) {
  final match = _httpStatusPattern.firstMatch(error.toString());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

bool shouldRetryError(
  Object error,
  AutoRetryOptions o, {
  bool? retryOnNetworkError,
}) {
  if (isUserCancelError(error)) return false;
  final text = error.toString();
  if (_containsKeyword(text, o.stopKeywords)) return false;
  final status = httpStatusFromError(error);
  // Transport failures (timeout, disconnect) must honor [retryOnNetworkError]
  // and must not match the "timeout" retry keyword first.
  if (_isRetryableNetworkError(error, status)) {
    return retryOnNetworkError ?? o.retryOnNetworkError;
  }
  if (_containsKeyword(text, o.retryKeywords)) return true;
  if (status != null && o.retryStatusCodes.contains(status)) return true;
  return false;
}

/// True when a retrying request ended because it was cancelled, not because
/// the last provider error should be shown as a generation failure.
bool isCancelledGenerationError(
  Object error, {
  required bool requestCancelled,
}) {
  if (requestCancelled) return true;
  return isUserCancelError(error);
}

/// How a prepare-phase error should be persisted.
///
/// User Stop ([requestCancelled]) lets the cancel flow own the terminal
/// write. Other cancel errors persist as [cancelled]. Everything else is a
/// preparation failure.
enum PrepareErrorAction { skip, cancelled, failed }

PrepareErrorAction prepareErrorAction(
  Object error, {
  required bool requestCancelled,
}) {
  if (!isCancelledGenerationError(error, requestCancelled: requestCancelled)) {
    return PrepareErrorAction.failed;
  }
  return requestCancelled
      ? PrepareErrorAction.skip
      : PrepareErrorAction.cancelled;
}

/// Delay before retrying after [attemptIndex] (0 = first retry).
Duration backoffDelay(int attemptIndex, AutoRetryOptions o, {Random? random}) {
  final initial = o.initialDelayMs < 0 ? 0 : o.initialDelayMs;
  final maxDelay = o.maxDelayMs < 0 ? 0 : o.maxDelayMs;
  final multiplier = AutoRetryOptions.clampMultiplier(o.multiplier);
  final factor = attemptIndex <= 0 ? 1.0 : pow(multiplier, attemptIndex);
  var ms = initial * factor;
  if (!ms.isFinite || ms > maxDelay) ms = maxDelay.toDouble();
  if (ms < 0) ms = 0;
  if (o.jitter) {
    final rng = random ?? Random();
    // ±20%
    final jittered = ms * (0.8 + rng.nextDouble() * 0.4);
    ms = jittered < 0 ? 0 : jittered;
  }
  if (!ms.isFinite || ms > maxDelay) ms = maxDelay.toDouble();
  return Duration(milliseconds: ms.round());
}

bool _isRetryableNetworkError(Object error, int? status) {
  if (isUserCancelError(error)) return false;
  if (error is SocketException || error is TimeoutException) return true;
  if (error is DioException) return _isRetryableDioError(error);
  if (error is HttpException && _isConnectionAbortMessage(error.message)) {
    return true;
  }
  if (error is http.ClientException && status == null) return true;
  return false;
}

bool _isRetryableDioError(DioException error) {
  if (error.type == DioExceptionType.cancel) return false;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    case DioExceptionType.unknown:
      final inner = error.error;
      if (inner != null) {
        return _isRetryableNetworkError(inner, httpStatusFromError(inner));
      }
      return _isConnectionAbortMessage(error.message ?? error.toString());
    case DioExceptionType.badResponse:
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
      return false;
  }
}

bool isUserCancelError(Object error) {
  if (error is DioException && error.type == DioExceptionType.cancel) {
    return true;
  }
  if (error is http.ClientException &&
      error.message.trim().toLowerCase() == 'cancelled') {
    return true;
  }
  final text = error.toString().toLowerCase();
  return text.contains('dioexceptiontype.cancel') ||
      text.contains('dioexception [cancel]');
}

bool _isConnectionAbortMessage(String message) {
  final text = message.toLowerCase();
  return text.contains('connection closed') ||
      text.contains('while receiving data') ||
      text.contains('connection reset') ||
      text.contains('broken pipe');
}

bool _containsKeyword(String text, List<String> keywords) {
  if (keywords.isEmpty || text.isEmpty) return false;
  final haystack = text.toLowerCase();
  for (final raw in keywords) {
    final keyword = raw.trim().toLowerCase();
    if (keyword.isEmpty) continue;
    if (haystack.contains(keyword)) return true;
  }
  return false;
}
