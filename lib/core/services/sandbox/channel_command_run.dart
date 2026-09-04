import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

/// Maps workspace channel exec events for [request.runId] into [CommandEvent]s.
///
/// [before] / [after] wrap the exec lifetime (iOS background task). The stream
/// closes after the matching `exit` event. If [WorkspaceChannel.exec] throws,
/// the stream errors.
Stream<CommandEvent> runChannelCommand({
  required WorkspaceChannel channel,
  required CommandRequest request,
  required ExecArgs args,
  Future<void> Function()? before,
  Future<void> Function()? after,
}) {
  final controller = StreamController<CommandEvent>();
  late final StreamSubscription<Map<String, Object?>> subscription;
  var began = false;
  var finished = false;
  var closing = false;

  Future<void> finish() async {
    finished = true;
    if (closing) return;
    closing = true;
    await subscription.cancel();
    if (began && after != null) {
      try {
        await after();
      } catch (_) {}
    }
    if (!controller.isClosed) {
      await controller.close();
    }
  }

  subscription = channel.events.listen(
    (event) {
      if (event['runId']?.toString() != request.runId) return;
      switch (event['type']) {
        case 'stdout':
          if (!finished && !controller.isClosed) {
            controller.add(
              CommandOutput(
                OutputStreamKind.stdout,
                _eventBytes(event['data']),
              ),
            );
          }
        case 'stderr':
          if (!finished && !controller.isClosed) {
            controller.add(
              CommandOutput(
                OutputStreamKind.stderr,
                _eventBytes(event['data']),
              ),
            );
          }
        case 'exit':
          if (finished) return;
          if (!controller.isClosed) {
            controller.add(_exitFrom(event));
          }
          unawaited(finish());
      }
    },
    onError: (Object error, StackTrace stack) {
      if (!controller.isClosed) {
        controller.addError(error, stack);
      }
      unawaited(finish());
    },
  );

  controller.onCancel = finish;

  unawaited(() async {
    try {
      if (before != null) {
        await before();
        began = true;
      }
      await channel.exec(args);
    } catch (error, stack) {
      if (!controller.isClosed) {
        controller.addError(error, stack);
      }
      await finish();
    }
  }());

  return controller.stream;
}

CommandExited _exitFrom(Map<String, Object?> event) {
  return CommandExited(
    exitCode: _eventInt(event['exitCode']) ?? -1,
    timedOut: _eventFlag(event['timedOut']),
    cancelled: _eventFlag(event['cancelled']),
    interrupted: _eventFlag(event['interrupted']),
    duration: Duration(milliseconds: _eventInt(event['durationMs']) ?? 0),
  );
}

/// Treats `true` and `1` as set. iOS `NSNumber` bools can decode as ints.
bool _eventFlag(Object? value) {
  if (value == true || value == 1) return true;
  if (value is String) {
    return value == 'true' || value == '1';
  }
  return false;
}

int? _eventInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Uint8List _eventBytes(Object? data) {
  if (data is Uint8List) return data;
  if (data is List<int>) return Uint8List.fromList(data);
  return Uint8List(0);
}
