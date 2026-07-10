import 'dart:io';

import 'package:path/path.dart' as p;

import 'restore_bundle_staging.dart';
import 'restore_receipt.dart';
import 'restore_workspace_lock.dart';

final class PendingRestoreRun {
  const PendingRestoreRun({
    required this.runId,
    required this.markerFileName,
    required this.receipt,
  });

  final String runId;
  final String markerFileName;
  final RestoreReceipt receipt;
}

/// Inspects restore state before any business persistence is opened.
///
/// This admission slice deliberately blocks every published run. The cutover
/// coordinator will replace that pending branch with deterministic recovery;
/// until then no caller may mistake a staged bundle for a completed restore.
final class RestoreStartupGate {
  RestoreStartupGate._();

  static const _runPattern = r'^run_([a-f0-9]{32})$';
  static const _markerFileNames = {
    RestoreWorkspaceLock.activeRunFileName,
    RestoreWorkspaceLock.publishingRunFileName,
    RestoreWorkspaceLock.discardingRunFileName,
  };

  static Future<PendingRestoreRun?> inspect({
    required Directory appDataDirectory,
  }) {
    final workspaceLock = RestoreWorkspaceLock(
      appDataDirectory: appDataDirectory,
    );
    return workspaceLock.synchronized(
      () => _inspectLocked(
        appDataDirectory: appDataDirectory,
        workspaceRoot: workspaceLock.workspaceRoot,
      ),
    );
  }

  static Future<PendingRestoreRun?> _inspectLocked({
    required Directory appDataDirectory,
    required Directory workspaceRoot,
  }) async {
    final rootType = await FileSystemEntity.type(
      workspaceRoot.path,
      followLinks: false,
    );
    if (rootType == FileSystemEntityType.notFound) return null;
    if (rootType != FileSystemEntityType.directory) {
      throw StateError('restore_startup_workspace_root');
    }

    File? markerFile;
    String? markerFileName;
    Directory? runDirectory;
    String? directoryRunId;
    await for (final entity in workspaceRoot.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == RestoreWorkspaceLock.lockFileName &&
          type == FileSystemEntityType.file) {
        continue;
      }
      if (_markerFileNames.contains(name) &&
          type == FileSystemEntityType.file &&
          markerFile == null) {
        markerFile = File(entity.path);
        markerFileName = name;
        continue;
      }
      final match = RegExp(_runPattern).firstMatch(name);
      if (match != null &&
          type == FileSystemEntityType.directory &&
          runDirectory == null) {
        runDirectory = Directory(entity.path);
        directoryRunId = match[1];
        continue;
      }
      throw StateError('restore_startup_workspace_entry');
    }

    if (markerFile == null && runDirectory == null) return null;
    if (markerFile == null ||
        markerFileName == null ||
        runDirectory == null ||
        directoryRunId == null) {
      throw StateError('restore_startup_run_topology');
    }
    final runId = await _readRunId(markerFile);
    if (runId != directoryRunId) {
      throw StateError('restore_startup_run_identity');
    }

    final store = RestoreReceiptStore(
      appDataDirectory: appDataDirectory,
      runId: runId,
    );
    final receipt = await store.readLatestWhileWorkspaceLocked();
    if (receipt == null) throw StateError('restore_startup_receipt');
    if (receipt.state == RestoreReceiptState.prepared) {
      await _validatePreparedRun(runDirectory: runDirectory, receipt: receipt);
    }
    return PendingRestoreRun(
      runId: runId,
      markerFileName: markerFileName,
      receipt: receipt,
    );
  }

  static Future<void> requireBusinessReady({
    required Directory appDataDirectory,
  }) async {
    final pending = await inspect(appDataDirectory: appDataDirectory);
    if (pending != null) {
      throw StateError('restore_startup_pending:${pending.receipt.state.name}');
    }
  }

  static Future<String> _readRunId(File markerFile) async {
    if (await markerFile.length() != 32) {
      throw StateError('restore_startup_marker');
    }
    final runId = await markerFile.readAsString();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(runId)) {
      throw StateError('restore_startup_marker');
    }
    return runId;
  }

  static Future<void> _validatePreparedRun({
    required Directory runDirectory,
    required RestoreReceipt receipt,
  }) async {
    var foundCandidate = false;
    var foundReceipts = false;
    await for (final entity in runDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == 'candidate' &&
          type == FileSystemEntityType.directory &&
          !foundCandidate) {
        foundCandidate = true;
        continue;
      }
      if (name == 'receipts' &&
          type == FileSystemEntityType.directory &&
          !foundReceipts) {
        foundReceipts = true;
        continue;
      }
      throw StateError('restore_startup_prepared_topology');
    }
    if (!foundCandidate || !foundReceipts) {
      throw StateError('restore_startup_prepared_topology');
    }

    final candidate = await RestoreBundleStaging.validateExistingCandidate(
      candidateDirectory: Directory(p.join(runDirectory.path, 'candidate')),
      expectedManifestSha256: receipt.candidateManifestSha256,
    );
    if ((receipt.selectedComponents.contains(RestoreComponent.database) &&
            !candidate.includeChats) ||
        (receipt.selectedComponents.contains(RestoreComponent.assets) &&
            !candidate.includeFiles)) {
      throw StateError('restore_startup_candidate_selection');
    }
  }
}
