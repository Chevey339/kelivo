import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../database/sqlite_interrupt.dart';
import 'backup_cancel_token.dart';
import 'backup_task_progress.dart';

export '../../database/sqlite_interrupt.dart'
    show debugOnInterruptSqliteHandle, interruptSqliteHandle;

/// Test-only: skip Isolate.kill to simulate a kill-resistant native call.
@visibleForTesting
bool debugSkipBackupIsolateKill = false;

final class BackupIsolateTimeoutException extends TimeoutException {
  BackupIsolateTimeoutException({
    required this.isolateExited,
    this.isolateExit,
    Duration? duration,
  }) : super('backup_isolate_timeout', duration);

  final bool isolateExited;
  final Future<void>? isolateExit;
}

bool backupIsolateStillAlive(Object error) {
  return (error is BackupIsolateTimeoutException && !error.isolateExited) ||
      (error is BackupCancelledException && !error.isolateExited);
}

Future<void>? backupIsolateExitFuture(Object error) {
  return switch (error) {
    BackupIsolateTimeoutException(:final isolateExit) => isolateExit,
    BackupCancelledException(:final isolateExit) => isolateExit,
    _ => null,
  };
}

final class BackupIsolateContext {
  BackupIsolateContext({
    required this.cancelFlag,
    required this._reportProgress,
    this._registerSqliteInterruptHandle,
    this._waitForSqliteCloseAck,
  });

  final IsolateCancelFlag cancelFlag;
  final void Function(BackupProgress progress) _reportProgress;
  final void Function(int handleAddress)? _registerSqliteInterruptHandle;
  final Future<void> Function()? _waitForSqliteCloseAck;

  void throwIfCancelled() => cancelFlag.throwIfCancelled();

  void reportProgress(BackupProgress progress) => _reportProgress(progress);

  void registerSqliteInterruptHandle(int address) {
    _registerSqliteInterruptHandle?.call(address);
  }

  Future<void> waitForSqliteCloseAck() async {
    await _waitForSqliteCloseAck?.call();
  }
}

Future<R> runBackupIsolate<R, P>({
  required FutureOr<R> Function(BackupIsolateContext context, P payload) body,
  required P payload,
  BackupCancelToken? cancelToken,
  BackupProgressSink? onProgress,
  Duration killGrace = const Duration(seconds: 3),
  Duration isolateExitDeadline = const Duration(seconds: 2),
  Duration? timeout,
}) async {
  final progressPort = ReceivePort();
  final controlPort = ReceivePort();
  final exitPort = ReceivePort();
  final isolateExit = Completer<void>();
  var isolateHasExited = false;
  var workerReleased = false;

  void markIsolateExited() {
    isolateHasExited = true;
    if (!isolateExit.isCompleted) {
      isolateExit.complete();
    }
    if (!workerReleased) {
      workerReleased = true;
      cancelToken?.releaseWorker();
    }
  }

  var retained = false;
  late final Isolate isolate;
  try {
    if (cancelToken != null) {
      cancelToken.retainWorker();
      retained = true;
    }
    isolate = await Isolate.spawn(
      _backupIsolateEntry,
      _BackupIsolateSpawnMessage(
        progressPort: progressPort.sendPort,
        controlPort: controlPort.sendPort,
        cancelCellAddress: cancelToken?.cellAddress,
        payload: payload,
        body: body,
      ),
      errorsAreFatal: true,
      onExit: exitPort.sendPort,
    );
  } catch (error) {
    if (retained && !workerReleased) {
      workerReleased = true;
      cancelToken?.releaseWorker();
    }
    progressPort.close();
    controlPort.close();
    exitPort.close();
    rethrow;
  }

  final done = Completer<R>();
  var killScheduled = false;
  var timedOut = false;
  var sqliteHandleAddress = 0;
  SendPort? workerCommandPort;
  Timer? exitFallback;

  void interruptIfOpen() {
    if (sqliteHandleAddress == 0) return;
    interruptSqliteHandle(sqliteHandleAddress);
  }

  final progressSub = progressPort.listen((message) {
    if (message is! BackupProgress) return;
    if (!message.cancellable) {
      cancelToken?.setCancellable(false);
    }
    onProgress?.call(message);
  });
  final controlSub = controlPort.listen((message) {
    if (message is _BackupIsolateReady) {
      workerCommandPort = message.commandPort;
      return;
    }
    if (message is _BackupSqliteOpened) {
      sqliteHandleAddress = message.address;
      if (killScheduled) {
        interruptIfOpen();
      }
      return;
    }
    if (message is _BackupSqliteClosing) {
      sqliteHandleAddress = 0;
      workerCommandPort?.send(const _BackupSqliteCloseAck());
      return;
    }
    if (done.isCompleted || timedOut) return;
    if (message is _BackupIsolateSuccess) {
      done.complete(message.value as R);
    } else if (message is _BackupIsolateFailure) {
      done.completeError(message.error, message.stackTrace);
    }
  });
  final exitSub = exitPort.listen((_) {
    markIsolateExited();
    if (done.isCompleted) return;
    if (timedOut) {
      done.completeError(
        BackupIsolateTimeoutException(
          isolateExited: true,
          isolateExit: isolateExit.future,
          duration: timeout,
        ),
      );
      return;
    }
    if (killScheduled) {
      done.completeError(
        BackupCancelledException(isolateExit: isolateExit.future),
      );
      return;
    }
    exitFallback = Timer(const Duration(milliseconds: 20), () {
      if (!done.isCompleted) {
        done.completeError(StateError('backup_isolate_exited'));
      }
    });
  });

  Timer? killTimer;
  Timer? abandonTimer;
  void scheduleKill() {
    interruptIfOpen();
    killScheduled = true;
    killTimer ??= Timer(killGrace, () {
      if (debugSkipBackupIsolateKill) return;
      isolate.kill(priority: Isolate.immediate);
    });
    abandonTimer ??= Timer(killGrace + isolateExitDeadline, () {
      if (done.isCompleted) return;
      if (timedOut) {
        done.completeError(
          BackupIsolateTimeoutException(
            isolateExited: isolateHasExited,
            isolateExit: isolateExit.future,
            duration: timeout,
          ),
        );
        return;
      }
      done.completeError(
        BackupCancelledException(
          isolateExited: isolateHasExited,
          isolateExit: isolateExit.future,
        ),
      );
    });
  }

  Timer? timeoutTimer;
  if (timeout != null) {
    timeoutTimer = Timer(timeout, () {
      timedOut = true;
      cancelToken?.cancel();
      scheduleKill();
    });
  }

  if (cancelToken != null && cancelToken.isCancelled) {
    scheduleKill();
  }
  final cancelSub = cancelToken?.whenCancelled.asStream().listen((_) {
    scheduleKill();
  });

  try {
    return await done.future;
  } finally {
    timeoutTimer?.cancel();
    killTimer?.cancel();
    abandonTimer?.cancel();
    exitFallback?.cancel();
    await cancelSub?.cancel();
    await progressSub.cancel();
    progressPort.close();
    if (isolateHasExited) {
      await controlSub.cancel();
      controlPort.close();
      await exitSub.cancel();
      exitPort.close();
    } else {
      unawaited(
        isolateExit.future.whenComplete(() async {
          await controlSub.cancel();
          controlPort.close();
          await exitSub.cancel();
          exitPort.close();
        }),
      );
    }
  }
}

@pragma('vm:entry-point')
void _backupIsolateEntry(_BackupIsolateSpawnMessage message) async {
  final commandPort = ReceivePort();
  message.controlPort.send(_BackupIsolateReady(commandPort.sendPort));
  Completer<void>? closingAck;
  final commandSub = commandPort.listen((incoming) {
    if (incoming is _BackupSqliteCloseAck) {
      closingAck?.complete();
    }
  });
  final cancelFlag = message.cancelCellAddress == null
      ? IsolateCancelFlag.disabled()
      : IsolateCancelFlag.fromAddress(message.cancelCellAddress!);
  final reporter = _ThrottledProgressReporter(message.progressPort);
  final context = BackupIsolateContext(
    cancelFlag: cancelFlag,
    reportProgress: reporter.report,
    registerSqliteInterruptHandle: (address) {
      message.controlPort.send(_BackupSqliteOpened(address));
    },
    waitForSqliteCloseAck: () async {
      final ack = Completer<void>();
      closingAck = ack;
      message.controlPort.send(const _BackupSqliteClosing());
      await ack.future;
    },
  );
  try {
    final value = await (message.body as dynamic)(context, message.payload);
    reporter.flush();
    message.controlPort.send(_BackupIsolateSuccess(value));
  } catch (error, stackTrace) {
    reporter.flush();
    message.controlPort.send(_BackupIsolateFailure(error, stackTrace));
  } finally {
    await commandSub.cancel();
    commandPort.close();
  }
}

final class _BackupIsolateSpawnMessage {
  const _BackupIsolateSpawnMessage({
    required this.progressPort,
    required this.controlPort,
    required this.cancelCellAddress,
    required this.payload,
    required this.body,
  });

  final SendPort progressPort;
  final SendPort controlPort;
  final int? cancelCellAddress;
  final Object? payload;
  final Function body;
}

final class _BackupIsolateSuccess {
  const _BackupIsolateSuccess(this.value);

  final Object? value;
}

final class _BackupIsolateFailure {
  const _BackupIsolateFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

final class _BackupIsolateReady {
  const _BackupIsolateReady(this.commandPort);

  final SendPort commandPort;
}

final class _BackupSqliteOpened {
  const _BackupSqliteOpened(this.address);

  final int address;
}

final class _BackupSqliteClosing {
  const _BackupSqliteClosing();
}

final class _BackupSqliteCloseAck {
  const _BackupSqliteCloseAck();
}

final class _ThrottledProgressReporter {
  _ThrottledProgressReporter(this._port) {
    _elapsed.start();
  }

  static const _minIntervalMs = 100;

  final SendPort _port;
  final Stopwatch _elapsed = Stopwatch();
  int? _lastEmitMs;
  BackupPhase? _lastPhase;
  int? _lastTotal;
  BackupProgress? _pending;
  var _emittedPhaseFinal = false;

  void report(BackupProgress progress) {
    final nowMs = _elapsed.elapsedMilliseconds;
    final phaseChanged = progress.phase != _lastPhase;
    if (phaseChanged) {
      _emittedPhaseFinal = false;
    }
    final becameIndeterminate = progress.total == null && _lastTotal != null;
    final reachedEnd =
        progress.total != null && progress.processed >= progress.total!;
    final isFinal = reachedEnd && !_emittedPhaseFinal;
    final due = _lastEmitMs == null || nowMs - _lastEmitMs! >= _minIntervalMs;
    if (phaseChanged || isFinal || due || becameIndeterminate) {
      if (reachedEnd) {
        _emittedPhaseFinal = true;
      }
      _emit(progress, nowMs);
    } else {
      _pending = progress;
    }
  }

  void flush() {
    final pending = _pending;
    if (pending != null) {
      _emit(pending, _elapsed.elapsedMilliseconds);
    }
  }

  void _emit(BackupProgress progress, int nowMs) {
    _pending = null;
    _lastEmitMs = nowMs;
    _lastPhase = progress.phase;
    _lastTotal = progress.total;
    _port.send(progress);
  }
}
