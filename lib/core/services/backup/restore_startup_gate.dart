import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'restore_bundle_staging.dart';
import 'restore_business_lease.dart';
import 'restore_cutover_executor.dart';
import 'restore_durability.dart';
import 'restore_previous_store.dart';
import 'restore_receipt.dart';
import 'restore_settings_cold_ack.dart';
import 'restore_settings_store.dart';
import 'restore_workspace_lock.dart';

/// A terminal restore is active but its settings still need proof from a new
/// process. Business persistence must remain unopened when this is thrown.
final class RestoreColdRestartRequired implements Exception {
  const RestoreColdRestartRequired(this.state);

  final RestoreReceiptState state;
}

final class PendingRestoreRun {
  const PendingRestoreRun({
    required this.runId,
    required this.markerFileName,
    required this.receipt,
    required this.runInCompletedDirectory,
  });

  final String runId;
  final String markerFileName;
  final RestoreReceipt receipt;
  final bool runInCompletedDirectory;
}

/// Recovers restore state before any business persistence is opened.
///
/// Nonterminal runs converge under one workspace lock to committed or
/// rolledBack. Terminal evidence is then archived outside active admission;
/// malformed or ambiguous state remains fail-closed.
final class RestoreStartupGate {
  RestoreStartupGate._();

  static const _runPattern = r'^run_([a-f0-9]{32})$';
  static const _markerFileNames = {
    RestoreWorkspaceLock.activeRunFileName,
    RestoreWorkspaceLock.publishingRunFileName,
    RestoreWorkspaceLock.discardingRunFileName,
    RestoreWorkspaceLock.archivingRunFileName,
  };
  static final _coldAckTemporaryPattern = RegExp(
    r'^settings_cold_ack\.json\.[0-9]+_[0-9]+_[0-9]+\.tmp$',
  );

  static Future<PendingRestoreRun?> inspect({
    required Directory appDataDirectory,
  }) async {
    final workspaceLock = RestoreWorkspaceLock(
      appDataDirectory: appDataDirectory,
    );
    final workspaceType = await FileSystemEntity.type(
      workspaceLock.workspaceRoot.path,
      followLinks: false,
    );
    if (workspaceType == FileSystemEntityType.notFound) return null;
    if (workspaceType != FileSystemEntityType.directory) {
      throw StateError('restore_startup_workspace_root');
    }
    return workspaceLock.synchronized(
      () => _inspectLocked(
        appDataDirectory: appDataDirectory,
        workspaceLock: workspaceLock,
      ),
    );
  }

  static Future<PendingRestoreRun?> _inspectLocked({
    required Directory appDataDirectory,
    required RestoreWorkspaceLock workspaceLock,
  }) async {
    final workspaceRoot = workspaceLock.workspaceRoot;
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
    Directory? completedRunsRoot;
    await for (final entity in workspaceRoot.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == RestoreWorkspaceLock.lockFileName &&
          type == FileSystemEntityType.file) {
        continue;
      }
      if (name == RestoreWorkspaceLock.completedRunsDirectoryName &&
          type == FileSystemEntityType.directory) {
        if (completedRunsRoot != null) {
          throw StateError('restore_startup_workspace_entry');
        }
        completedRunsRoot = Directory(entity.path);
        await RestoreWorkspaceLock.validateCompletedRunsDirectory(
          completedRunsRoot,
        );
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

    if (markerFile == null && runDirectory == null) {
      return null;
    }
    if (markerFile == null || markerFileName == null) {
      throw StateError('restore_startup_run_topology');
    }
    final markerRunId = await _readRunId(markerFile);
    if (runDirectory == null || directoryRunId == null) {
      if (markerFileName != RestoreWorkspaceLock.archivingRunFileName ||
          completedRunsRoot == null) {
        throw StateError('restore_startup_run_topology');
      }
      final archivedRunDirectory = Directory(
        p.join(completedRunsRoot.path, 'run_$markerRunId'),
      );
      if (await FileSystemEntity.type(
            archivedRunDirectory.path,
            followLinks: false,
          ) !=
          FileSystemEntityType.directory) {
        throw StateError('restore_startup_run_topology');
      }
      final store = RestoreReceiptStore(
        appDataDirectory: appDataDirectory,
        runId: markerRunId,
        archived: true,
      );
      final receipt = await store.readLatestWhileWorkspaceLocked();
      if (receipt == null ||
          (receipt.state != RestoreReceiptState.committed &&
              receipt.state != RestoreReceiptState.rolledBack)) {
        throw StateError('restore_startup_receipt');
      }
      await _validateRunTopLevelTopology(
        runDirectory: archivedRunDirectory,
        receipt: receipt,
      );
      return PendingRestoreRun(
        runId: markerRunId,
        markerFileName: markerFileName,
        receipt: receipt,
        runInCompletedDirectory: true,
      );
    }

    final runId = markerRunId;
    if (markerRunId != directoryRunId) {
      throw StateError('restore_startup_run_identity');
    }
    if (completedRunsRoot != null &&
        await FileSystemEntity.type(
              p.join(completedRunsRoot.path, 'run_$runId'),
              followLinks: false,
            ) !=
            FileSystemEntityType.notFound) {
      throw StateError('restore_startup_run_topology');
    }

    final store = RestoreReceiptStore(
      appDataDirectory: appDataDirectory,
      runId: runId,
    );
    final receipt = await store.readLatestWhileWorkspaceLocked();
    if (receipt == null) throw StateError('restore_startup_receipt');
    final terminal =
        receipt.state == RestoreReceiptState.committed ||
        receipt.state == RestoreReceiptState.rolledBack;
    if (terminal) {
      if (markerFileName != RestoreWorkspaceLock.publishingRunFileName &&
          markerFileName != RestoreWorkspaceLock.archivingRunFileName) {
        throw StateError('restore_startup_terminal_marker');
      }
    } else if (receipt.state == RestoreReceiptState.prepared) {
      if (markerFileName == RestoreWorkspaceLock.archivingRunFileName) {
        throw StateError('restore_startup_cutover_marker');
      }
    } else if (markerFileName != RestoreWorkspaceLock.publishingRunFileName) {
      throw StateError('restore_startup_cutover_marker');
    }
    await _validateRunTopLevelTopology(
      runDirectory: runDirectory,
      receipt: receipt,
    );
    if (receipt.state == RestoreReceiptState.prepared) {
      await _validatePreparedCandidate(
        runDirectory: runDirectory,
        receipt: receipt,
      );
    }
    return PendingRestoreRun(
      runId: runId,
      markerFileName: markerFileName,
      receipt: receipt,
      runInCompletedDirectory: false,
    );
  }

  static Future<RestoreReceipt?> recoverAndRequireBusinessReady({
    required Directory appDataDirectory,
    SharedPreferences? preferences,
    RestoreBusinessLease? businessLease,
    RestoreDurability? durability,
  }) async {
    final resolvedDurability = durability ?? RestorePlatformDurability();
    final ownedBusinessLease = businessLease == null
        ? await RestoreBusinessLease.acquire(
            appDataDirectory: appDataDirectory,
            durability: resolvedDurability,
          )
        : null;
    final effectiveBusinessLease = businessLease ?? ownedBusinessLease!;
    final expectedLeasePath = p.normalize(
      p.absolute(
        p.join(
          appDataDirectory.path,
          RestoreBusinessLease.leaseDirectoryName,
          RestoreBusinessLease.lockFileName,
        ),
      ),
    );
    if (effectiveBusinessLease.isClosed ||
        !p.equals(effectiveBusinessLease.lockFile.path, expectedLeasePath)) {
      await ownedBusinessLease?.close();
      throw StateError('restore_startup_business_lease');
    }
    final workspaceLock = RestoreWorkspaceLock(
      appDataDirectory: appDataDirectory,
      durability: resolvedDurability,
    );
    try {
      final workspaceType = await FileSystemEntity.type(
        workspaceLock.workspaceRoot.path,
        followLinks: false,
      );
      if (workspaceType == FileSystemEntityType.notFound) return null;
      if (workspaceType != FileSystemEntityType.directory) {
        throw StateError('restore_startup_workspace_root');
      }
      return await workspaceLock.synchronized(() async {
        final discardedUnpublished = await workspaceLock
            .discardStrictlyUnpublishedRunWhileWorkspaceLocked();
        if (discardedUnpublished) {
          final remaining = await _inspectLocked(
            appDataDirectory: appDataDirectory,
            workspaceLock: workspaceLock,
          );
          if (remaining != null) {
            throw StateError('restore_startup_unpublished_discard');
          }
          return null;
        }
        final pending = await _inspectLocked(
          appDataDirectory: appDataDirectory,
          workspaceLock: workspaceLock,
        );
        if (pending == null) return null;
        final executor = RestoreCutoverExecutor(
          appDataDirectory: appDataDirectory,
          runId: pending.runId,
          preferences: preferences ?? await SharedPreferences.getInstance(),
          workspaceLock: workspaceLock,
          durability: resolvedDurability,
          archived: pending.runInCompletedDirectory,
        );
        final coldAckStore = RestoreSettingsColdAckStore(
          runDirectory: executor.receiptStore.runDirectory,
          durability: resolvedDurability,
        );
        if (pending.receipt.state == RestoreReceiptState.committed ||
            pending.receipt.state == RestoreReceiptState.rolledBack) {
          final expected = _coldAckExpected(pending.receipt);
          final coldAck = await coldAckStore.read();
          if (coldAck == null) {
            final terminal = await executor
                .revalidateTerminalWhileWorkspaceLocked(pending.receipt);
            await coldAckStore.writeOrReplace(
              terminalReceiptChecksum: terminal.checksum,
              expected: expected,
              leaseInstanceId: effectiveBusinessLease.instanceId,
              processId: effectiveBusinessLease.processId,
            );
            throw RestoreColdRestartRequired(terminal.state);
          }
          if (coldAck.terminalReceiptChecksum != pending.receipt.checksum ||
              coldAck.expected != expected) {
            throw StateError('restore_startup_cold_ack_binding');
          }
          if (coldAck.processId == effectiveBusinessLease.processId ||
              coldAck.leaseInstanceId == effectiveBusinessLease.instanceId) {
            throw RestoreColdRestartRequired(pending.receipt.state);
          }
          final settingsReadback = await executor
              .inspectTerminalSettingsWhileWorkspaceLocked(pending.receipt);
          if (settingsReadback ==
              RestoreSettingsReadback.recoverableNeedsWrite) {
            final terminal = await executor
                .revalidateTerminalWhileWorkspaceLocked(pending.receipt);
            await coldAckStore.writeOrReplace(
              terminalReceiptChecksum: terminal.checksum,
              expected: expected,
              leaseInstanceId: effectiveBusinessLease.instanceId,
              processId: effectiveBusinessLease.processId,
            );
            throw RestoreColdRestartRequired(terminal.state);
          }
          final terminal = await executor
              .revalidateTerminalWhileWorkspaceLocked(
                pending.receipt,
                repairSettings: false,
              );
          await workspaceLock.archiveTerminalRunWhileWorkspaceLocked(
            runId: pending.runId,
            observedMarkerFileName: pending.markerFileName,
          );
          return terminal;
        }
        final result = await executor.executeWhileWorkspaceLocked(
          observedMarkerFileName: pending.markerFileName,
        );
        if (result.state != RestoreReceiptState.committed &&
            result.state != RestoreReceiptState.rolledBack) {
          throw StateError('restore_startup_not_terminal');
        }
        final terminal = await executor.revalidateTerminalWhileWorkspaceLocked(
          result,
        );
        await coldAckStore.writeOrReplace(
          terminalReceiptChecksum: terminal.checksum,
          expected: _coldAckExpected(terminal),
          leaseInstanceId: effectiveBusinessLease.instanceId,
          processId: effectiveBusinessLease.processId,
        );
        throw RestoreColdRestartRequired(terminal.state);
      });
    } finally {
      await ownedBusinessLease?.close();
    }
  }

  static RestoreSettingsColdAckExpected _coldAckExpected(
    RestoreReceipt receipt,
  ) {
    return switch (receipt.state) {
      RestoreReceiptState.committed => RestoreSettingsColdAckExpected.target,
      RestoreReceiptState.rolledBack => RestoreSettingsColdAckExpected.before,
      RestoreReceiptState.prepared ||
      RestoreReceiptState.oldRenamed ||
      RestoreReceiptState.newInstalled ||
      RestoreReceiptState.verified ||
      RestoreReceiptState.rollingBack => throw StateError(
        'restore_startup_cold_ack_state',
      ),
    };
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

  static Future<void> _validateRunTopLevelTopology({
    required Directory runDirectory,
    required RestoreReceipt receipt,
  }) async {
    var foundCandidate = false;
    var foundReceipts = false;
    var foundPreviousPending = false;
    var foundPrevious = false;
    final terminal =
        receipt.state == RestoreReceiptState.committed ||
        receipt.state == RestoreReceiptState.rolledBack;
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
      if (name == RestorePreviousStore.pendingDirectoryName &&
          type == FileSystemEntityType.directory &&
          !foundPreviousPending) {
        foundPreviousPending = true;
        continue;
      }
      if (name == RestorePreviousStore.previousDirectoryName &&
          type == FileSystemEntityType.directory &&
          !foundPrevious) {
        foundPrevious = true;
        continue;
      }
      if (terminal &&
          type == FileSystemEntityType.file &&
          (name == RestoreSettingsColdAckStore.fileName ||
              _coldAckTemporaryPattern.hasMatch(name))) {
        continue;
      }
      throw StateError('restore_startup_run_entry');
    }
    if (!foundCandidate || !foundReceipts) {
      throw StateError('restore_startup_run_topology');
    }
    if (receipt.state == RestoreReceiptState.prepared) {
      if (foundPreviousPending && foundPrevious) {
        throw StateError('restore_startup_run_topology');
      }
      return;
    }
    if (foundPreviousPending || !foundPrevious) {
      throw StateError('restore_startup_run_topology');
    }
  }

  static Future<void> _validatePreparedCandidate({
    required Directory runDirectory,
    required RestoreReceipt receipt,
  }) async {
    final candidate = await RestoreBundleStaging.validateExistingCandidate(
      candidateDirectory: Directory(p.join(runDirectory.path, 'candidate')),
      expectedManifestSha256: receipt.candidateManifestSha256,
    );
    if (receipt.selectedComponents.contains(RestoreComponent.database) !=
            candidate.includeChats ||
        receipt.selectedComponents.contains(RestoreComponent.assets) !=
            candidate.includeFiles) {
      throw StateError('restore_startup_candidate_selection');
    }
  }
}
