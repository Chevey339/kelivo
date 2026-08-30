import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_isolate_runner.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';

void main() {
  group('BackupProgress', () {
    test('fraction is null when total is missing or zero', () {
      expect(
        const BackupProgress(
          phase: BackupPhase.preparing,
          processed: 1,
        ).fraction,
        isNull,
      );
      expect(
        const BackupProgress(
          phase: BackupPhase.preparing,
          processed: 1,
          total: 0,
        ).fraction,
        isNull,
      );
    });

    test('fraction is clamped to 0..1', () {
      expect(
        const BackupProgress(
          phase: BackupPhase.packing,
          processed: 5,
          total: 10,
          unit: BackupProgressUnit.bytes,
        ).fraction,
        0.5,
      );
      expect(
        const BackupProgress(
          phase: BackupPhase.packing,
          processed: 15,
          total: 10,
          unit: BackupProgressUnit.bytes,
        ).fraction,
        1.0,
      );
    });
  });

  group('BackupCancelToken', () {
    test('cancel is idempotent and dispose frees the ffi cell', () {
      final token = BackupCancelToken();
      token.cancel();
      token.cancel();
      expect(token.isCancelled, isTrue);
      token.dispose();
      token.dispose();
      token.cancel();
      expect(() => token.cellAddress, throwsStateError);
    });

    test('cancel is a no-op after cancellable is set to false', () {
      final token = BackupCancelToken();
      token.setCancellable(false);
      token.cancel();
      expect(token.isCancelled, isFalse);
      token.dispose();
    });

    test('dispose while a worker is outstanding defers freeing the cell', () {
      final token = BackupCancelToken();
      token.retainWorker();
      final address = token.cellAddress;
      token.cancel();
      token.dispose();

      expect(token.isCellAllocated, isTrue);
      expect(() => token.cellAddress, throwsStateError);
      expect(IsolateCancelFlag.fromAddress(address).isCancelled, isTrue);

      token.releaseWorker();
      expect(token.isCellAllocated, isFalse);
    });
  });

  group('runBackupIsolate', () {
    test('debug native sleep restores the caller signal mask', () {
      if (Platform.isWindows) return;

      final before = _currentSignalMask();
      debugNativeSleepIgnoringKill(0);

      expect(_currentSignalMask(), before);
    });

    test('processed is monotonic within a phase', () async {
      final events = <BackupProgress>[];
      await runBackupIsolate<int, int>(
        body: _monotonicWork,
        payload: 8,
        onProgress: events.add,
      );
      final packing = events
          .where((event) => event.phase == BackupPhase.packing)
          .toList();
      expect(packing, isNotEmpty);
      for (var i = 1; i < packing.length; i++) {
        expect(
          packing[i].processed,
          greaterThanOrEqualTo(packing[i - 1].processed),
        );
      }
    });

    test('phase changes arrive in order', () async {
      final phases = <BackupPhase>[];
      await runBackupIsolate<void, int>(
        body: _phaseOrderWork,
        payload: 0,
        onProgress: (event) => phases.add(event.phase),
      );
      expect(phases, [
        BackupPhase.preparing,
        BackupPhase.packing,
        BackupPhase.verifying,
        BackupPhase.finalizing,
      ]);
    });

    test('cancel during a sync loop throws within the kill grace', () async {
      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final future = runBackupIsolate<void, int>(
        body: _cancellableSyncLoop,
        payload: 0,
        cancelToken: token,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();
      await expectLater(future, throwsA(isA<BackupCancelledException>()));
    });

    test('cancel is a no-op after a non-cancellable progress event', () async {
      final token = BackupCancelToken();
      addTearDown(token.dispose);
      final started = DateTime.now();
      final future = runBackupIsolate<String, int>(
        body: _nonCancellableThenCancelRace,
        payload: 0,
        cancelToken: token,
        onProgress: (event) {
          if (!event.cancellable) {
            token.cancel();
          }
        },
      );
      expect(await future, 'committed');
      expect(token.isCancelled, isFalse);
      expect(
        DateTime.now().difference(started) < const Duration(seconds: 2),
        isTrue,
      );
    });

    test(
      'parent dispose after isolateExited false does not free the cancel cell',
      () async {
        final token = BackupCancelToken();
        final address = token.cellAddress;

        await expectLater(
          runBackupIsolate<void, int>(
            body: _nativeSleepIgnoringKill,
            payload: 120,
            cancelToken: token,
            timeout: const Duration(milliseconds: 150),
            killGrace: const Duration(milliseconds: 40),
            isolateExitDeadline: const Duration(milliseconds: 80),
          ),
          throwsA(
            isA<BackupIsolateTimeoutException>().having(
              (error) => error.isolateExited,
              'isolateExited',
              isFalse,
            ),
          ),
        );
        token.dispose();
        expect(token.isCellAllocated, isTrue);
        expect(IsolateCancelFlag.fromAddress(address).isCancelled, isTrue);
      },
    );

    test(
      'timeout completes even if the isolate ignores kill and never exits',
      () async {
        final token = BackupCancelToken();
        addTearDown(token.dispose);
        final started = DateTime.now();

        await expectLater(
          runBackupIsolate<void, int>(
            body: _nativeSleepIgnoringKill,
            payload: 120,
            cancelToken: token,
            timeout: const Duration(milliseconds: 150),
            killGrace: const Duration(milliseconds: 40),
            isolateExitDeadline: const Duration(milliseconds: 200),
          ),
          throwsA(
            isA<BackupIsolateTimeoutException>().having(
              (error) => error.isolateExited,
              'isolateExited',
              isFalse,
            ),
          ),
        );
        expect(token.isCancelled, isTrue);
        expect(
          DateTime.now().difference(started) < const Duration(seconds: 3),
          isTrue,
        );
      },
    );

    test(
      'timeout cancels the token and kills a stuck isolate before returning',
      () async {
        final token = BackupCancelToken();
        addTearDown(token.dispose);
        final heartbeat = File(
          '${Directory.systemTemp.path}/kelivo_backup_timeout_${identityHashCode(token)}.hb',
        );
        addTearDown(() async {
          if (await heartbeat.exists()) await heartbeat.delete();
        });

        await expectLater(
          runBackupIsolate<void, String>(
            body: _stuckHeartbeatLoop,
            payload: heartbeat.path,
            cancelToken: token,
            timeout: const Duration(milliseconds: 180),
            killGrace: const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
        expect(token.isCancelled, isTrue);
        expect(heartbeat.existsSync(), isTrue);
        final stamp = heartbeat.readAsStringSync();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(heartbeat.readAsStringSync(), stamp);
      },
    );

    test(
      'throttles same-phase updates but always emits phase changes and finals',
      () async {
        final events = <BackupProgress>[];
        final rawReports = await runBackupIsolate<int, int>(
          body: _throttledSpamWork,
          payload: 0,
          onProgress: events.add,
        );
        final samePhase = events
            .where((event) => event.phase == BackupPhase.packing)
            .toList();
        expect(rawReports, greaterThan(samePhase.length));
        expect(samePhase.length, lessThanOrEqualTo(12));
        expect(samePhase, isNotEmpty);
        expect(samePhase.first.processed, 0);
        expect(samePhase.last.processed, samePhase.last.total);
        expect(
          events.map((event) => event.phase),
          containsAllInOrder([BackupPhase.packing, BackupPhase.verifying]),
        );
      },
    );

    test('cancel interrupts a registered sqlite handle before kill', () async {
      final interrupted = <int>[];
      debugOnInterruptSqliteHandle = interrupted.add;
      addTearDown(() => debugOnInterruptSqliteHandle = null);

      final token = BackupCancelToken();
      addTearDown(token.dispose);
      const handle = 0x1234abcd;
      final future = runBackupIsolate<void, int>(
        body: _registerThenHang,
        payload: handle,
        cancelToken: token,
        killGrace: const Duration(milliseconds: 40),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      token.cancel();

      await expectLater(future, throwsA(isA<BackupCancelledException>()));
      expect(interrupted, [handle]);
    });

    test(
      'cancel before handle registration still interrupts when it arrives',
      () async {
        final interrupted = <int>[];
        debugOnInterruptSqliteHandle = (address) {
          expect(address, isNot(0));
          interrupted.add(address);
        };
        addTearDown(() => debugOnInterruptSqliteHandle = null);

        final token = BackupCancelToken();
        addTearDown(token.dispose);
        const handle = 0x1111aaaa;
        final future = runBackupIsolate<void, int>(
          body: _delayThenRegisterThenHang,
          payload: handle,
          cancelToken: token,
          onProgress: (event) {
            if (event.phase == BackupPhase.preparing) {
              token.cancel();
            }
          },
          killGrace: const Duration(milliseconds: 400),
        );

        await expectLater(future, throwsA(isA<BackupCancelledException>()));
        expect(interrupted, [handle]);
      },
    );

    test('cancel during VACUUM interrupts the open handle', () async {
      final interrupted = <int>[];
      debugOnInterruptSqliteHandle = interrupted.add;
      addTearDown(() => debugOnInterruptSqliteHandle = null);

      final token = BackupCancelToken();
      addTearDown(token.dispose);
      const handle = 0x2222bbbb;
      final future = runBackupIsolate<void, int>(
        body: _registerThenHang,
        payload: handle,
        cancelToken: token,
        killGrace: const Duration(milliseconds: 40),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      token.cancel();

      await expectLater(future, throwsA(isA<BackupCancelledException>()));
      expect(interrupted, [handle]);
    });

    test(
      'acks sqlite close after timeout returns with isolate still alive',
      () async {
        final closedMarker = File(
          '${Directory.systemTemp.path}/kelivo_sqlite_close_after_timeout_${DateTime.now().microsecondsSinceEpoch}.marker',
        );
        if (closedMarker.existsSync()) closedMarker.deleteSync();
        final resumedMarker = File('${closedMarker.path}.resumed');
        addTearDown(() {
          if (closedMarker.existsSync()) closedMarker.deleteSync();
          if (resumedMarker.existsSync()) resumedMarker.deleteSync();
        });

        debugOnInterruptSqliteHandle = (_) {};
        debugSkipBackupIsolateKill = true;
        addTearDown(() {
          debugOnInterruptSqliteHandle = null;
          debugSkipBackupIsolateKill = false;
        });

        final token = BackupCancelToken();
        addTearDown(token.dispose);
        const handle = 0x4444dddd;

        await expectLater(
          runBackupIsolate<void, _SqliteCloseRaceArgs>(
            body: _nativeSleepThenCloseHandshake,
            payload: _SqliteCloseRaceArgs(
              handle: handle,
              closedMarkerPath: closedMarker.path,
            ),
            cancelToken: token,
            timeout: const Duration(milliseconds: 150),
            killGrace: const Duration(milliseconds: 40),
            isolateExitDeadline: const Duration(milliseconds: 80),
          ),
          throwsA(
            isA<BackupIsolateTimeoutException>().having(
              (error) => error.isolateExited,
              'isolateExited',
              isFalse,
            ),
          ),
        );

        expect(
          closedMarker.existsSync(),
          isFalse,
          reason: 'native work should still be blocked when timeout returns',
        );

        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (!closedMarker.existsSync() &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(resumedMarker.existsSync(), isTrue);
        expect(
          closedMarker.existsSync(),
          isTrue,
          reason:
              'parent must keep the control port open and ACK closing so '
              'source.close() can run after timeout',
        );
      },
    );

    test(
      'cancel after VACUUM before close never interrupts a closed handle',
      () async {
        final closedMarker = File(
          '${Directory.systemTemp.path}/kelivo_sqlite_closed_${DateTime.now().microsecondsSinceEpoch}.marker',
        );
        if (closedMarker.existsSync()) closedMarker.deleteSync();
        addTearDown(() {
          if (closedMarker.existsSync()) closedMarker.deleteSync();
        });

        final interrupted = <int>[];
        debugOnInterruptSqliteHandle = (address) {
          expect(
            closedMarker.existsSync(),
            isFalse,
            reason: 'interrupt after the worker closed the handle',
          );
          interrupted.add(address);
        };
        addTearDown(() => debugOnInterruptSqliteHandle = null);

        final token = BackupCancelToken();
        addTearDown(token.dispose);
        const handle = 0x3333cccc;
        final future = runBackupIsolate<void, _SqliteCloseRaceArgs>(
          body: _registerVacuumThenCloseHandshake,
          payload: _SqliteCloseRaceArgs(
            handle: handle,
            closedMarkerPath: closedMarker.path,
          ),
          cancelToken: token,
          killGrace: const Duration(milliseconds: 80),
        );

        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (!closedMarker.existsSync() &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(closedMarker.existsSync(), isTrue);
        token.cancel();

        await expectLater(future, throwsA(isA<BackupCancelledException>()));
        expect(interrupted, isEmpty);
      },
    );
  });
}

List<int> _currentSignalMask() {
  const signalSetSize = 256;
  final current = calloc<Uint8>(signalSetSize);
  try {
    final pthreadSigmask = DynamicLibrary.process()
        .lookupFunction<
          Int32 Function(Int32, Pointer<Void>, Pointer<Void>),
          int Function(int, Pointer<Void>, Pointer<Void>)
        >('pthread_sigmask');
    final sigBlock = Platform.isMacOS || Platform.isIOS ? 1 : 0;
    expect(pthreadSigmask(sigBlock, nullptr, current.cast()), 0);
    return List<int>.of(current.asTypedList(signalSetSize));
  } finally {
    calloc.free(current);
  }
}

Future<void> _registerThenHang(BackupIsolateContext context, int handle) async {
  context.registerSqliteInterruptHandle(handle);
  context.reportProgress(
    const BackupProgress(
      phase: BackupPhase.snapshottingDatabase,
      processed: 0,
      cancellable: true,
    ),
  );
  await Future<void>.delayed(const Duration(hours: 1));
}

Future<void> _delayThenRegisterThenHang(
  BackupIsolateContext context,
  int handle,
) async {
  context.reportProgress(
    const BackupProgress(
      phase: BackupPhase.preparing,
      processed: 0,
      cancellable: true,
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 80));
  context.registerSqliteInterruptHandle(handle);
  context.reportProgress(
    const BackupProgress(
      phase: BackupPhase.snapshottingDatabase,
      processed: 0,
      cancellable: true,
    ),
  );
  await Future<void>.delayed(const Duration(hours: 1));
}

class _SqliteCloseRaceArgs {
  const _SqliteCloseRaceArgs({
    required this.handle,
    required this.closedMarkerPath,
  });

  final int handle;
  final String closedMarkerPath;
}

Future<void> _nativeSleepThenCloseHandshake(
  BackupIsolateContext context,
  _SqliteCloseRaceArgs args,
) async {
  context.registerSqliteInterruptHandle(args.handle);
  try {
    _nativeSleepIgnoringKill(context, 2);
  } finally {
    File(
      '${args.closedMarkerPath}.resumed',
    ).writeAsStringSync('resumed', flush: true);
    await context.waitForSqliteCloseAck();
    File(args.closedMarkerPath).writeAsStringSync('closed', flush: true);
  }
}

Future<void> _registerVacuumThenCloseHandshake(
  BackupIsolateContext context,
  _SqliteCloseRaceArgs args,
) async {
  context.registerSqliteInterruptHandle(args.handle);
  context.reportProgress(
    const BackupProgress(
      phase: BackupPhase.snapshottingDatabase,
      processed: 1,
      total: 1,
      cancellable: true,
    ),
  );
  await context.waitForSqliteCloseAck();
  File(args.closedMarkerPath).writeAsStringSync('closed', flush: true);
  await Future<void>.delayed(const Duration(hours: 1));
}

int _monotonicWork(BackupIsolateContext context, int payload) {
  for (var i = 0; i <= payload; i++) {
    context.reportProgress(
      BackupProgress(
        phase: BackupPhase.packing,
        processed: i,
        total: payload,
        unit: BackupProgressUnit.bytes,
      ),
    );
  }
  return payload;
}

void _phaseOrderWork(BackupIsolateContext context, int payload) {
  for (final phase in [
    BackupPhase.preparing,
    BackupPhase.packing,
    BackupPhase.verifying,
    BackupPhase.finalizing,
  ]) {
    context.reportProgress(
      BackupProgress(phase: phase, processed: 0, unit: BackupProgressUnit.none),
    );
  }
}

void _cancellableSyncLoop(BackupIsolateContext context, int payload) {
  var processed = 0;
  while (true) {
    context.throwIfCancelled();
    processed++;
    context.reportProgress(
      BackupProgress(
        phase: BackupPhase.packing,
        processed: processed,
        unit: BackupProgressUnit.bytes,
      ),
    );
  }
}

String _nonCancellableThenCancelRace(
  BackupIsolateContext context,
  int payload,
) {
  context.reportProgress(
    const BackupProgress(
      phase: BackupPhase.committing,
      processed: 0,
      cancellable: false,
    ),
  );
  // Give the parent time to observe the event and attempt cancel.
  final until = DateTime.now().add(const Duration(milliseconds: 80));
  while (DateTime.now().isBefore(until)) {
    context.throwIfCancelled();
  }
  return 'committed';
}

void _nativeSleepIgnoringKill(BackupIsolateContext context, int seconds) =>
    debugNativeSleepIgnoringKill(seconds);

void _stuckHeartbeatLoop(BackupIsolateContext context, String path) {
  final file = File(path);
  while (true) {
    file.writeAsStringSync(
      DateTime.now().microsecondsSinceEpoch.toString(),
      flush: true,
    );
  }
}

int _throttledSpamWork(BackupIsolateContext context, int payload) {
  const total = 100000;
  final sw = Stopwatch()..start();
  var processed = 0;
  while (sw.elapsedMilliseconds < 450) {
    context.reportProgress(
      BackupProgress(
        phase: BackupPhase.packing,
        processed: processed < total ? processed : total - 1,
        total: total,
        unit: BackupProgressUnit.bytes,
      ),
    );
    processed++;
  }
  context.reportProgress(
    BackupProgress(
      phase: BackupPhase.packing,
      processed: total,
      total: total,
      unit: BackupProgressUnit.bytes,
    ),
  );
  context.reportProgress(
    const BackupProgress(
      phase: BackupPhase.verifying,
      processed: 0,
      total: 1,
      unit: BackupProgressUnit.bytes,
    ),
  );
  return processed + 2;
}
