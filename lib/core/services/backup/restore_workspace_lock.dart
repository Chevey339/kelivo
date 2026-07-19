import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'restore_durability.dart';

final class RestoreWorkspaceLock {
  RestoreWorkspaceLock({
    required this.appDataDirectory,
    RestoreDurability? durability,
  }) : _durabilityOverride = durability;

  static const workspaceRootName = '.kelivo_restore';
  static const lockFileName = '.receipt.lock';
  static const activeRunFileName = '.active_run';
  static const publishingRunFileName = '.active_run.publishing';
  static const discardingRunFileName = '.active_run.discarding';
  static const archivingRunFileName = '.active_run.archiving';
  // Reserved only so diagnostics/tests can identify and reject artifacts from
  // the unpublished markerless protocol. Production never creates it.
  static const archivingRunTemporaryFileName = '$archivingRunFileName.tmp';
  static const completedRunsDirectoryName = 'completed';
  static const _markerFileNames = {
    activeRunFileName,
    publishingRunFileName,
    discardingRunFileName,
    archivingRunFileName,
  };
  static const _assetRootNames = {'upload', 'images', 'avatars', 'fonts'};
  static const _previousDirectoryNames = {'previous.pending', 'previous'};
  static final _runIdPattern = RegExp(r'^[a-f0-9]{32}$');
  static final _runDirectoryPattern = RegExp(r'^run_([a-f0-9]{32})$');
  static final _finalReceiptPattern = RegExp(r'^receipt_[0-9]{16}\.json$');
  static final _initialReceiptTempPattern = RegExp(
    r'^receipt_0000000000000001\.json\.[0-9]+_[0-9]+\.tmp$',
  );
  static final _receiptTempPattern = RegExp(
    r'^receipt_[0-9]{16}\.json\.[0-9]+_[0-9]+\.tmp$',
  );
  static final _localTails = <String, Future<void>>{};

  final Directory appDataDirectory;
  final RestoreDurability? _durabilityOverride;

  RestoreDurability get durability =>
      _durabilityOverride ?? RestorePlatformDurability();

  Directory get workspaceRoot =>
      Directory(p.join(appDataDirectory.path, workspaceRootName));

  Directory get completedRunsRoot =>
      Directory(p.join(workspaceRoot.path, completedRunsDirectoryName));

  Future<T> withPublishingRun<T>({
    required String runId,
    required Future<T> Function() action,
  }) {
    return synchronized(() async {
      final claimed = await _claimRun(
        runId: runId,
        claimedFileName: publishingRunFileName,
      );
      try {
        return await action();
      } finally {
        await _restoreClaim(runId: runId, claimed: claimed);
      }
    });
  }

  Future<T> withDiscardingRun<T>({
    required String runId,
    required Future<T> Function() action,
  }) {
    return synchronized(() async {
      final claimed = await _claimRun(
        runId: runId,
        claimedFileName: discardingRunFileName,
      );
      var actionCompleted = false;
      try {
        final result = await action();
        actionCompleted = true;
        await claimed.delete();
        await durability.syncDirectory(workspaceRoot, fullBarrier: true);
        return result;
      } catch (_) {
        if (!actionCompleted) {
          await _restoreClaim(runId: runId, claimed: claimed);
        }
        rethrow;
      }
    });
  }

  Future<T> synchronized<T>(Future<T> Function() action) async {
    final lockKey = p.normalize(p.absolute(workspaceRoot.path));
    final previousTail = _localTails[lockKey] ?? Future<void>.value();
    final release = Completer<void>();
    final currentTail = release.future;
    _localTails[lockKey] = currentTail;

    await previousTail;
    try {
      return await _withFileLock(action);
    } finally {
      release.complete();
      if (identical(_localTails[lockKey], currentTail)) {
        _localTails.remove(lockKey);
      }
    }
  }

  /// Converts the exact marker observed by a lock-held startup inspector into
  /// the durable cutover claim, or resumes an interrupted publishing claim.
  ///
  /// The caller must invoke this from one [synchronized] action after it has
  /// validated the run and receipt chain under that same lock.
  Future<void> claimCutoverRunWhileWorkspaceLocked({
    required String runId,
    required String observedMarkerFileName,
  }) async {
    _validateRunId(runId);
    if (observedMarkerFileName == publishingRunFileName) {
      await _requireRunFile(
        File(p.join(workspaceRoot.path, publishingRunFileName)),
        runId,
      );
      await _requireOtherMarkersMissing(except: publishingRunFileName);
      return;
    }
    if (observedMarkerFileName != activeRunFileName &&
        observedMarkerFileName != discardingRunFileName) {
      throw StateError('restore_workspace_cutover_marker');
    }
    await _requireOtherMarkersMissing(except: observedMarkerFileName);
    final observed = File(p.join(workspaceRoot.path, observedMarkerFileName));
    await _requireRunFile(observed, runId);
    final publishing = File(p.join(workspaceRoot.path, publishingRunFileName));
    await durability.renameAndSync(
      source: observed,
      targetPath: publishing.path,
    );
    await _requireRunFile(publishing, runId);
  }

  /// Moves a terminal run out of the single-active-run admission area while
  /// retaining its receipt, candidate, and previous evidence.
  ///
  /// The caller must hold this workspace lock and must already have verified a
  /// terminal committed/rolledBack receipt for [runId]. The archiving marker
  /// remains operation-ahead evidence until the run-directory rename and both
  /// parent-directory barriers are complete.
  Future<Directory> archiveTerminalRunWhileWorkspaceLocked({
    required String runId,
    required String observedMarkerFileName,
  }) async {
    _validateRunId(runId);
    final source = Directory(p.join(workspaceRoot.path, 'run_$runId'));
    final target = Directory(p.join(completedRunsRoot.path, 'run_$runId'));
    final sourceType = await FileSystemEntity.type(
      source.path,
      followLinks: false,
    );
    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    final sourceActive = sourceType == FileSystemEntityType.directory;
    final targetArchived = targetType == FileSystemEntityType.directory;
    if (sourceActive == targetArchived ||
        (!sourceActive && sourceType != FileSystemEntityType.notFound) ||
        (!targetArchived && targetType != FileSystemEntityType.notFound)) {
      throw StateError('restore_workspace_terminal_archive_topology');
    }
    if ((sourceActive &&
            observedMarkerFileName != publishingRunFileName &&
            observedMarkerFileName != archivingRunFileName) ||
        (targetArchived && observedMarkerFileName != archivingRunFileName)) {
      throw StateError('restore_workspace_terminal_marker');
    }
    final observedMarker = File(
      p.join(workspaceRoot.path, observedMarkerFileName),
    );
    await _requireOtherMarkersMissing(except: observedMarkerFileName);
    await _requireRunFile(observedMarker, runId);
    await _ensureCompletedRunsRoot();

    if (observedMarkerFileName == publishingRunFileName) {
      await durability.renameAndSync(
        source: observedMarker,
        targetPath: p.join(workspaceRoot.path, archivingRunFileName),
      );
    }
    final archiving = File(p.join(workspaceRoot.path, archivingRunFileName));
    await _requireRunFile(archiving, runId);

    if (sourceActive) {
      await durability.renameAndSync(source: source, targetPath: target.path);
    } else {
      if (observedMarkerFileName != archivingRunFileName) {
        throw StateError('restore_workspace_terminal_marker');
      }
      await durability.syncDirectory(completedRunsRoot, fullBarrier: true);
      await durability.syncDirectory(workspaceRoot, fullBarrier: true);
    }
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type(target.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw StateError('restore_workspace_terminal_archive_result');
    }
    await validateCompletedRunsDirectory(completedRunsRoot);
    await _requireRunFile(archiving, runId);
    await archiving.delete();
    await durability.syncDirectory(workspaceRoot, fullBarrier: true);
    return target;
  }

  /// Durably removes a run that provably never published its first receipt.
  ///
  /// The caller must hold this workspace lock. Only the exact staging and
  /// initial-receipt publication topology is accepted. Any final receipt,
  /// previous bundle, link, special filesystem entry, or unknown path leaves
  /// the workspace untouched and fail-closed.
  Future<bool> discardStrictlyUnpublishedRunWhileWorkspaceLocked() async {
    final observation = await _inspectWorkspaceForUnpublishedRun();
    final marker = observation.marker;
    final markerFileName = observation.markerFileName;
    if (marker == null || markerFileName == null) return false;

    if (markerFileName == archivingRunFileName) return false;
    final runDirectory = observation.runDirectory;
    String? runId;
    if (runDirectory == null) {
      if (markerFileName != activeRunFileName &&
          markerFileName != discardingRunFileName) {
        throw StateError('restore_workspace_unpublished_topology');
      }
    } else {
      runId = await _readRunFile(marker);
      if (observation.directoryRunId != runId) {
        throw StateError('restore_workspace_unpublished_identity');
      }
      final hasFinalReceipt = await _validateUnpublishedRunTopology(
        runDirectory,
      );
      if (hasFinalReceipt) return false;
    }

    await _requireOtherMarkersMissing(except: markerFileName);
    final discarding = File(p.join(workspaceRoot.path, discardingRunFileName));
    if (markerFileName == discardingRunFileName) {
      if (runId != null) await _requireRunFile(discarding, runId);
    } else {
      await durability.renameAndSync(
        source: marker,
        targetPath: discarding.path,
      );
      if (runId != null) await _requireRunFile(discarding, runId);
    }

    if (runDirectory != null) {
      await _deleteRegularDirectoryTree(runDirectory);
      await durability.syncDirectory(workspaceRoot, fullBarrier: true);
      if (await FileSystemEntity.type(runDirectory.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('restore_workspace_unpublished_delete');
      }
    }

    if (runId != null) {
      await _requireRunFile(discarding, runId);
    } else if (await FileSystemEntity.type(
          discarding.path,
          followLinks: false,
        ) !=
        FileSystemEntityType.file) {
      throw StateError('restore_workspace_unpublished_marker');
    }
    await discarding.delete();
    await durability.syncDirectory(workspaceRoot, fullBarrier: true);
    if (await FileSystemEntity.type(discarding.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_workspace_unpublished_marker');
    }
    return true;
  }

  Future<
    ({
      File? marker,
      String? markerFileName,
      Directory? runDirectory,
      String? directoryRunId,
    })
  >
  _inspectWorkspaceForUnpublishedRun() async {
    File? marker;
    String? markerFileName;
    Directory? runDirectory;
    String? directoryRunId;
    await for (final entity in workspaceRoot.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == lockFileName && type == FileSystemEntityType.file) {
        continue;
      }
      if (name == completedRunsDirectoryName &&
          type == FileSystemEntityType.directory) {
        await validateCompletedRunsDirectory(Directory(entity.path));
        continue;
      }
      if (_markerFileNames.contains(name) &&
          type == FileSystemEntityType.file &&
          marker == null) {
        marker = File(entity.path);
        markerFileName = name;
        continue;
      }
      final match = _runDirectoryPattern.firstMatch(name);
      if (match != null &&
          type == FileSystemEntityType.directory &&
          runDirectory == null) {
        runDirectory = Directory(entity.path);
        directoryRunId = match[1];
        continue;
      }
      throw StateError('restore_workspace_unpublished_entry');
    }
    return (
      marker: marker,
      markerFileName: markerFileName,
      runDirectory: runDirectory,
      directoryRunId: directoryRunId,
    );
  }

  Future<bool> _validateUnpublishedRunTopology(Directory runDirectory) async {
    Directory? candidateDirectory;
    Directory? receiptDirectory;
    final previousDirectories = <String>{};
    await for (final entity in runDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == 'candidate' &&
          type == FileSystemEntityType.directory &&
          candidateDirectory == null) {
        candidateDirectory = Directory(entity.path);
        continue;
      }
      if (name == 'receipts' &&
          type == FileSystemEntityType.directory &&
          receiptDirectory == null) {
        receiptDirectory = Directory(entity.path);
        continue;
      }
      if (_previousDirectoryNames.contains(name) &&
          type == FileSystemEntityType.directory &&
          previousDirectories.add(name)) {
        continue;
      }
      throw StateError('restore_workspace_unpublished_run_entry');
    }

    final hasFinalReceipt =
        receiptDirectory != null &&
        await _containsFinalReceiptOrValidInitialTemps(receiptDirectory);
    if (hasFinalReceipt) return true;
    if (previousDirectories.isNotEmpty) {
      throw StateError('restore_workspace_unpublished_previous');
    }
    if (candidateDirectory != null) {
      await _validateUnpublishedCandidate(candidateDirectory);
    }
    return false;
  }

  Future<bool> _containsFinalReceiptOrValidInitialTemps(
    Directory receiptDirectory,
  ) async {
    var hasFinalReceipt = false;
    var hasLaterReceiptTemp = false;
    await for (final entity in receiptDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw StateError('restore_workspace_unpublished_receipt_entry');
      }
      if (_finalReceiptPattern.hasMatch(name)) {
        hasFinalReceipt = true;
        continue;
      }
      if (_initialReceiptTempPattern.hasMatch(name)) continue;
      if (_receiptTempPattern.hasMatch(name)) {
        hasLaterReceiptTemp = true;
        continue;
      }
      throw StateError('restore_workspace_unpublished_receipt_entry');
    }
    if (!hasFinalReceipt && hasLaterReceiptTemp) {
      throw StateError('restore_workspace_unpublished_receipt_entry');
    }
    return hasFinalReceipt;
  }

  Future<void> _validateUnpublishedCandidate(Directory candidate) async {
    await for (final entity in candidate.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == 'manifest.json' && type == FileSystemEntityType.file) {
        continue;
      }
      if (name == 'database' && type == FileSystemEntityType.directory) {
        await for (final databaseEntry in Directory(
          entity.path,
        ).list(followLinks: false)) {
          if (p.basename(databaseEntry.path) != 'kelivo.db' ||
              await FileSystemEntity.type(
                    databaseEntry.path,
                    followLinks: false,
                  ) !=
                  FileSystemEntityType.file) {
            throw StateError('restore_workspace_unpublished_database_entry');
          }
        }
        continue;
      }
      if (_assetRootNames.contains(name) &&
          type == FileSystemEntityType.directory) {
        await _validateRegularDirectoryTree(Directory(entity.path));
        continue;
      }
      throw StateError('restore_workspace_unpublished_candidate_entry');
    }
  }

  static Future<void> _validateRegularDirectoryTree(Directory root) async {
    final pending = <Directory>[root];
    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      await for (final entity in directory.list(followLinks: false)) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.directory) {
          pending.add(Directory(entity.path));
        } else if (type != FileSystemEntityType.file) {
          throw StateError('restore_workspace_unpublished_tree_entry');
        }
      }
    }
  }

  static Future<void> _deleteRegularDirectoryTree(Directory directory) async {
    await for (final entity in directory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await _deleteRegularDirectoryTree(Directory(entity.path));
      } else if (type == FileSystemEntityType.file) {
        await File(entity.path).delete();
      } else {
        throw StateError('restore_workspace_unpublished_delete_entry');
      }
    }
    await directory.delete();
  }

  Future<File> _claimRun({
    required String runId,
    required String claimedFileName,
  }) async {
    _validateRunId(runId);
    final active = File(p.join(workspaceRoot.path, activeRunFileName));
    final claimed = File(p.join(workspaceRoot.path, claimedFileName));
    await _requireRunFile(active, runId);
    if (await FileSystemEntity.type(claimed.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_workspace_claim');
    }
    await durability.renameAndSync(source: active, targetPath: claimed.path);
    await _requireRunFile(claimed, runId);
    return claimed;
  }

  Future<void> _restoreClaim({
    required String runId,
    required File claimed,
  }) async {
    final active = File(p.join(workspaceRoot.path, activeRunFileName));
    await _requireRunFile(claimed, runId);
    if (await FileSystemEntity.type(active.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('restore_workspace_claim_release');
    }
    await durability.renameAndSync(source: claimed, targetPath: active.path);
    await _requireRunFile(active, runId);
  }

  static Future<void> _requireRunFile(File file, String runId) async {
    if (await _readRunFile(file) != runId) {
      throw StateError('restore_workspace_active_run');
    }
  }

  static Future<String> _readRunFile(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() != 32) {
      throw StateError('restore_workspace_active_run');
    }
    final runId = await file.readAsString();
    if (!_runIdPattern.hasMatch(runId)) {
      throw StateError('restore_workspace_active_run');
    }
    return runId;
  }

  Future<void> _requireOtherMarkersMissing({required String except}) async {
    for (final name in const {
      activeRunFileName,
      publishingRunFileName,
      discardingRunFileName,
      archivingRunFileName,
    }) {
      if (name == except) continue;
      if (await FileSystemEntity.type(
            p.join(workspaceRoot.path, name),
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        throw StateError('restore_workspace_cutover_markers');
      }
    }
  }

  Future<void> _ensureCompletedRunsRoot() async {
    final type = await FileSystemEntity.type(
      completedRunsRoot.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      await completedRunsRoot.create();
      await durability.restrictDirectory(completedRunsRoot);
      await durability.syncDirectory(workspaceRoot, fullBarrier: true);
    } else if (type != FileSystemEntityType.directory) {
      throw StateError('restore_workspace_completed_runs');
    } else {
      await durability.restrictDirectory(completedRunsRoot);
    }
    await validateCompletedRunsDirectory(completedRunsRoot);
  }

  static Future<void> validateCompletedRunsDirectory(
    Directory directory,
  ) async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_workspace_completed_runs');
    }
    await for (final entity in directory.list(followLinks: false)) {
      if (!RegExp(r'^run_[a-f0-9]{32}$').hasMatch(p.basename(entity.path)) ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.directory) {
        throw StateError('restore_workspace_completed_entry');
      }
    }
  }

  static void _validateRunId(String runId) {
    if (!_runIdPattern.hasMatch(runId)) {
      throw ArgumentError.value(runId, 'runId');
    }
  }

  Future<T> _withFileLock<T>(Future<T> Function() action) async {
    await _ensureWorkspaceRoot();
    final lockFile = File(p.join(workspaceRoot.path, lockFileName));
    await _requireSafeLockPath(lockFile, allowMissing: true);

    final handle = await lockFile.open(mode: FileMode.append);
    var locked = false;
    try {
      await _requireSafeLockPath(lockFile);
      await durability.restrictFile(lockFile);
      await handle.lock(FileLock.blockingExclusive);
      locked = true;
      await _requireWorkspaceRoot();
      await _requireSafeLockPath(lockFile);
      return await action();
    } finally {
      try {
        if (locked) await handle.unlock();
      } finally {
        await handle.close();
      }
    }
  }

  Future<void> _ensureWorkspaceRoot() async {
    final type = await FileSystemEntity.type(
      workspaceRoot.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link ||
        (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.directory)) {
      throw StateError('restore_workspace_root');
    }
    if (type == FileSystemEntityType.notFound) {
      await workspaceRoot.create(recursive: true);
      await durability.restrictDirectory(workspaceRoot);
      if (await FileSystemEntity.type(
            appDataDirectory.path,
            followLinks: false,
          ) ==
          FileSystemEntityType.directory) {
        await durability.syncDirectory(appDataDirectory, fullBarrier: true);
      }
    } else {
      await durability.restrictDirectory(workspaceRoot);
    }
    await _requireWorkspaceRoot();
  }

  Future<void> _requireWorkspaceRoot() async {
    if (await FileSystemEntity.type(workspaceRoot.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_workspace_root');
    }
  }

  static Future<void> _requireSafeLockPath(
    File lockFile, {
    bool allowMissing = false,
  }) async {
    final type = await FileSystemEntity.type(lockFile.path, followLinks: false);
    if ((allowMissing && type == FileSystemEntityType.notFound) ||
        type == FileSystemEntityType.file) {
      return;
    }
    throw StateError('restore_workspace_lock');
  }
}
