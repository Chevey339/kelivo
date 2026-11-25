import 'dart:isolate';

import '../services/backup/restore_durability.dart';
import 'schema_migrations.dart';

typedef DatabaseUpgradeWork<T> =
    Future<void> Function(T, RestoreDurability, DatabaseUpgradeStageSink?);

/// Native checkpoints, integrity checks and full disk flushes can block for
/// seconds. Send only the filesystem work to the worker; device free-space
/// checks, application locks and UI progress stay on the calling isolate.
Future<void> runDatabaseUpgradeIo<T>(
  T files,
  DatabaseUpgradeWork<T> work, {
  required RestoreDurability durability,
  DatabaseUpgradeStageSink? onStage,
}) async {
  // Custom durability implementations keep their caller-owned state.
  if (durability is! RestorePlatformDurability) {
    await work(files, durability, onStage);
    return;
  }
  if (onStage == null) {
    await _runOnWorker(files, work, null);
    return;
  }
  final stages = ReceivePort();
  final delivered = stages
      .takeWhile((stage) => stage != null)
      .cast<DatabaseUpgradeStage>()
      .forEach(onStage);
  try {
    await _runOnWorker(files, work, stages.sendPort);
  } finally {
    // Drain already posted stages before the caller opens the app or shows an
    // error. This also completes if the worker could not start.
    stages.sendPort.send(null);
    try {
      await delivered;
    } finally {
      stages.close();
    }
  }
}

Future<void> _runOnWorker<T>(
  T files,
  DatabaseUpgradeWork<T> work,
  SendPort? stages,
) => Isolate.run(
  () => work(files, RestorePlatformDurability(), stages?.send),
  debugName: 'Database upgrade',
);
