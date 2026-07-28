import 'dart:io';

import 'package:path/path.dart' as p;

import 'restore_trace_service.dart';
import 'restore_workspace_lock.dart';

/// Trims `.kelivo_restore/completed/` archives after a few successful cold
/// starts so each overwrite restore does not strand a full copy of the old
/// database and assets forever.
///
/// The cold-start counter lives in the caller-provided store (main.dart backs
/// it with the app preference store). The counter resets only after a
/// successful clear, so a failed cleanup retries on the next cold start;
/// pruning never throws into startup.
final class RestoreArchivePruner {
  RestoreArchivePruner({
    required this.appDataDirectory,
    required Future<int> Function() readColdStarts,
    required Future<void> Function(int count) writeColdStarts,
    this.coldStartsThreshold = 3,
    Future<void> Function()? clearArchive,
    // ignore: prefer_initializing_formals
  }) : _readColdStarts = readColdStarts,
       // ignore: prefer_initializing_formals
       _writeColdStarts = writeColdStarts,
       _clearArchive =
           clearArchive ??
           (() => RestoreTraceService(appDataDirectory).clear());

  static const coldStartsKey = 'restore_archive_prune_cold_starts_v1';

  final Directory appDataDirectory;
  final int coldStartsThreshold;
  final Future<int> Function() _readColdStarts;
  final Future<void> Function(int count) _writeColdStarts;
  final Future<void> Function() _clearArchive;

  Future<void> pruneAfterSuccessfulColdStart() async {
    try {
      if (!await _hasArchivedRuns()) {
        if (await _readColdStarts() != 0) await _writeColdStarts(0);
        return;
      }
      final coldStarts = await _readColdStarts() + 1;
      if (coldStarts < coldStartsThreshold) {
        await _writeColdStarts(coldStarts);
        return;
      }
      await _clearArchive();
      await _writeColdStarts(0);
    } catch (_) {
      // Pruning is best-effort and must never affect startup.
    }
  }

  Future<bool> _hasArchivedRuns() async {
    final completed = Directory(
      p.join(
        appDataDirectory.path,
        RestoreWorkspaceLock.workspaceRootName,
        RestoreWorkspaceLock.completedRunsDirectoryName,
      ),
    );
    if (await FileSystemEntity.type(completed.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return false;
    }
    await for (final _ in completed.list(followLinks: false)) {
      return true;
    }
    return false;
  }
}
