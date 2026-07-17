import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_settings_cold_ack.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

/// Rebinds the durable ack to a synthetic native process for in-process tests.
///
/// Production code must observe a real process exit. Tests cannot replace the
/// Dart VM, so this helper explicitly models an ack written by a different PID.
Future<void> simulateRestoreColdProcessBoundary(
  Directory appDataDirectory,
) async {
  final pending = await RestoreStartupGate.inspect(
    appDataDirectory: appDataDirectory,
  );
  if (pending == null) {
    throw StateError('restore_test_missing_pending_run');
  }
  final store = RestoreSettingsColdAckStore(
    runDirectory: Directory(
      p.join(
        appDataDirectory.path,
        RestoreWorkspaceLock.workspaceRootName,
        'run_${pending.runId}',
      ),
    ),
  );
  final ack = await store.read();
  if (ack == null) throw StateError('restore_test_missing_cold_ack');
  final otherProcessId = pid == 1 ? 2 : pid - 1;
  await store.writeOrReplace(
    terminalReceiptChecksum: ack.terminalReceiptChecksum,
    expected: ack.expected,
    leaseInstanceId: ack.leaseInstanceId,
    processId: otherProcessId,
  );
}
