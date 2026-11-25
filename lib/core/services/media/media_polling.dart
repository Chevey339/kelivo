import 'dart:async';
import 'dart:math' as math;

import 'media_adapter.dart';
import 'media_request.dart';

Stream<MediaEvent> pollMediaTask(
  MediaContext context, {
  required Future<Map<String, dynamic>> Function() poll,
  required FutureOr<List<MediaResult>?> Function(Map<String, dynamic>) result,
  MediaTaskAccepted accepted = const MediaTaskAccepted(),
  MediaOutput Function(List<MediaResult>) outputEvent = MediaOutput.new,
  MediaEvent? Function(Map<String, dynamic>)? beforeResult,
  double? Function(Map<String, dynamic>)? progress,
  Map<String, dynamic>? initial,
}) async* {
  yield accepted;
  var response = initial;
  var waitBeforeRequest = initial == null;
  var interval = 2;
  var failures = 0;
  var resultAnnounced = false;
  Duration? retryDelay;
  final elapsed = Stopwatch()..start();
  const timeout = Duration(minutes: 15);

  Future<T> withinDeadline<T>(Future<T> Function() request) => Future.any<T>([
    request(),
    context.cancelToken.whenCancel.then((error) => throw error),
  ]).timeout(timeout - elapsed.elapsed);

  while (elapsed.elapsed < timeout) {
    if (context.cancelToken.cancelError case final error?) throw error;
    if (waitBeforeRequest) {
      final backoff = retryDelay ?? Duration(seconds: interval);
      final untilDeadline = timeout - elapsed.elapsed;
      if (untilDeadline.inMicroseconds <= 0) break;
      await _wait(context, backoff < untilDeadline ? backoff : untilDeadline);
      if (elapsed.elapsed >= timeout) break;
    }
    try {
      if (response == null) {
        response = await withinDeadline(poll);
        interval = math.min(interval + 1, 8);
        failures = 0;
      }
      final current = response!;
      // Keep the last status while retrieving the completed result. A transient
      // result fetch must never submit another generation.
      if (!resultAnnounced && beforeResult != null) {
        final event = beforeResult(current);
        if (event != null) {
          resultAnnounced = true;
          yield event;
        }
      }
      final output = await withinDeadline(() async => result(current));
      if (output != null) {
        yield outputEvent(output);
        return;
      }
      final fraction = progress?.call(current);
      if (fraction != null) yield MediaProgress(fraction);
      response = null;
      failures = 0;
      retryDelay = null;
    } catch (error) {
      if (context.cancelToken.cancelError case final cancelled?) {
        throw cancelled;
      }
      final failure = classifyMediaFailure(error);
      if (!failure.retryable || failures >= 3) throw failure;
      final retry = failure.retryAfter;
      final exponential = Duration(seconds: 1 << failures++);
      retryDelay = retry != null && retry > exponential ? retry : exponential;
      final remaining = timeout - elapsed.elapsed;
      if (remaining > Duration.zero) {
        context.log?.retry(
          failure,
          retryDelay < remaining ? retryDelay : remaining,
        );
      }
    }
    waitBeforeRequest = true;
  }
  throw const MediaFailure(MediaFailureKind.network, 'Generation timed out');
}

Future<void> _wait(MediaContext context, Duration duration) => Future.any([
  context.delay(duration),
  context.cancelToken.whenCancel.then<void>((error) => throw error),
]);

String requireMediaTaskId(Object? id) {
  if (id is String && id.trim().isNotEmpty) return id;
  throw const MediaFailure(MediaFailureKind.invalidResponse, 'Missing task ID');
}

Uri? mediaResultUri(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          const {'http', 'https'}.contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

double? mediaPercent(Object? value) {
  final numeric = value is num
      ? value
      : value is String
      ? double.tryParse(value.replaceAll('%', ''))
      : null;
  if (numeric == null || !numeric.isFinite) return null;
  return numeric.clamp(0, 100) / 100;
}

int? videoDurationMs(Object? seconds) {
  final value = seconds is num ? seconds : num.tryParse('$seconds');
  if (value == null || !value.isFinite || value <= 0) return null;
  return (value * 1000).round();
}

Never failedMediaTask(Object? details) {
  final failure = mediaResponseFailure(details);
  throw MediaFailure(
    failure.kind,
    failure.message.isEmpty
        ? 'Provider could not generate media'
        : failure.message,
  );
}
