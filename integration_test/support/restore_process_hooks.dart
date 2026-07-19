import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

import 'restore_process_control.dart';

typedef RestoreProcessBoundaryCallback =
    Future<void> Function(RestoreProcessFailpoint failpoint);

/// Observes exact durable DB/assets restore boundaries.
///
/// The process harness callback publishes evidence and then deliberately
/// blocks so the host can SIGKILL the native Runner after the operation is
/// durable but before the next state-machine step starts.
final class RestoreProcessBoundaryDurability implements RestoreDurability {
  RestoreProcessBoundaryDurability({
    required this.appDataDirectory,
    required this.runId,
    required this.failpoint,
    required this.delegate,
    required this.onBoundary,
    this.triggerRollback = false,
  });

  final Directory appDataDirectory;
  final String runId;
  final RestoreProcessFailpoint failpoint;
  final RestoreDurability delegate;
  final RestoreProcessBoundaryCallback onBoundary;
  final bool triggerRollback;

  bool _didReachBoundary = false;
  bool _didTriggerRollback = false;

  Directory get _workspace => Directory(
    p.join(appDataDirectory.path, RestoreWorkspaceLock.workspaceRootName),
  );

  Directory get _run => Directory(p.join(_workspace.path, 'run_$runId'));

  Directory get _candidate => Directory(p.join(_run.path, 'candidate'));

  Directory get _previousPending =>
      Directory(p.join(_run.path, RestorePreviousStore.pendingDirectoryName));

  Directory get _previous =>
      Directory(p.join(_run.path, RestorePreviousStore.previousDirectoryName));

  File get _liveDatabase =>
      File(p.join(appDataDirectory.path, AppDatabase.databaseFileName));

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    final sourcePath = p.normalize(p.absolute(source.path));
    final target = p.normalize(p.absolute(targetPath));
    await delegate.renameAndSync(source: source, targetPath: targetPath);

    if (triggerRollback &&
        !_didTriggerRollback &&
        _isRollbackTrigger(sourcePath, target)) {
      _didTriggerRollback = true;
      throw StateError('restore_harness_trigger_rollback');
    }

    final matched = switch (failpoint) {
      RestoreProcessFailpoint.cutoverClaimPublished =>
        _same(
              sourcePath,
              p.join(_workspace.path, RestoreWorkspaceLock.activeRunFileName),
            ) &&
            _same(
              target,
              p.join(
                _workspace.path,
                RestoreWorkspaceLock.publishingRunFileName,
              ),
            ),
      RestoreProcessFailpoint.previousManifestPublished => _same(
        target,
        p.join(_previousPending.path, RestorePreviousStore.manifestFileName),
      ),
      RestoreProcessFailpoint.previousAssetsMoved => _isAssetRootTarget(
        target,
        _previousPending,
      ),
      RestoreProcessFailpoint.previousDatabaseMoved => _same(
        target,
        p.join(_previousPending.path, 'database', AppDatabase.databaseFileName),
      ),
      RestoreProcessFailpoint.previousPromoted =>
        _same(sourcePath, _previousPending.path) &&
            _same(target, _previous.path),
      RestoreProcessFailpoint.oldRenamedReceiptPublished =>
        await _isReceiptState(target, RestoreReceiptState.oldRenamed),
      RestoreProcessFailpoint.candidateDatabaseMoved =>
        _isCandidateDatabaseInstall(sourcePath, target),
      RestoreProcessFailpoint.candidateAssetsMoved =>
        _isAssetRootSource(sourcePath, _candidate) &&
            _isAssetRootTarget(target, appDataDirectory),
      RestoreProcessFailpoint.newInstalledReceiptPublished =>
        await _isReceiptState(target, RestoreReceiptState.newInstalled),
      RestoreProcessFailpoint.verifiedReceiptPublished => await _isReceiptState(
        target,
        RestoreReceiptState.verified,
      ),
      RestoreProcessFailpoint.committedReceiptPublished =>
        await _isReceiptState(target, RestoreReceiptState.committed),
      RestoreProcessFailpoint.rollingBackReceiptPublished =>
        await _isReceiptState(target, RestoreReceiptState.rollingBack),
      RestoreProcessFailpoint.newDatabaseReturnedToCandidate =>
        _same(sourcePath, _liveDatabase.path) &&
            _same(
              target,
              p.join(_candidate.path, 'database', AppDatabase.databaseFileName),
            ),
      RestoreProcessFailpoint.previousDatabaseRestoredToLive =>
        _same(
              sourcePath,
              p.join(_previous.path, 'database', AppDatabase.databaseFileName),
            ) &&
            _same(target, _liveDatabase.path),
      RestoreProcessFailpoint.newAssetsReturnedToCandidate =>
        _isAssetRootSource(sourcePath, appDataDirectory) &&
            _isAssetRootTarget(target, _candidate),
      RestoreProcessFailpoint.previousAssetsRestoredToLive =>
        _isAssetRootSource(sourcePath, _previous) &&
            _isAssetRootTarget(target, appDataDirectory),
      RestoreProcessFailpoint.rolledBackReceiptPublished =>
        await _isReceiptState(target, RestoreReceiptState.rolledBack),
      RestoreProcessFailpoint.terminalRunArchived =>
        _same(sourcePath, _run.path) &&
            _same(
              target,
              p.join(
                _workspace.path,
                RestoreWorkspaceLock.completedRunsDirectoryName,
                'run_$runId',
              ),
            ),
      RestoreProcessFailpoint.liveDatabaseNormalized ||
      RestoreProcessFailpoint.archivingMarkerRemovedDurable ||
      RestoreProcessFailpoint.publishingMarkerWithoutRun => false,
    };
    if (matched) await _reach();
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    await delegate.syncFile(file, fullBarrier: fullBarrier);
    if (failpoint == RestoreProcessFailpoint.liveDatabaseNormalized &&
        fullBarrier &&
        _same(file.path, _liveDatabase.path)) {
      await _reach();
    }
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
    if (failpoint == RestoreProcessFailpoint.archivingMarkerRemovedDurable &&
        fullBarrier &&
        _same(directory.path, _workspace.path) &&
        await FileSystemEntity.type(
              p.join(
                _workspace.path,
                RestoreWorkspaceLock.completedRunsDirectoryName,
                'run_$runId',
              ),
              followLinks: false,
            ) ==
            FileSystemEntityType.directory &&
        await FileSystemEntity.type(
              p.join(
                _workspace.path,
                RestoreWorkspaceLock.archivingRunFileName,
              ),
              followLinks: false,
            ) ==
            FileSystemEntityType.notFound) {
      await _reach();
    }
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  Future<void> _reach() async {
    if (_didReachBoundary) return;
    _didReachBoundary = true;
    await onBoundary(failpoint);
  }

  bool _isCandidateDatabaseInstall(String source, String target) =>
      _same(
        source,
        p.join(_candidate.path, 'database', AppDatabase.databaseFileName),
      ) &&
      _same(target, _liveDatabase.path);

  bool _isRollbackTrigger(String source, String target) {
    if (failpoint == RestoreProcessFailpoint.newAssetsReturnedToCandidate) {
      return _isAssetRootSource(source, _candidate) &&
          _isAssetRootTarget(target, appDataDirectory);
    }
    return _isCandidateDatabaseInstall(source, target);
  }

  static const _assetRoots = {'upload', 'images', 'avatars', 'fonts'};

  static bool _isAssetRootSource(String path, Directory container) =>
      _isAssetRootTarget(path, container);

  static bool _isAssetRootTarget(String path, Directory container) {
    final normalized = p.normalize(p.absolute(path));
    final parent = p.normalize(p.absolute(p.dirname(normalized)));
    return _same(parent, container.path) &&
        _assetRoots.contains(p.basename(normalized));
  }

  static bool _same(String left, String right) =>
      p.equals(p.normalize(p.absolute(left)), p.normalize(p.absolute(right)));

  static Future<bool> _isReceiptState(
    String target,
    RestoreReceiptState state,
  ) async {
    if (!RegExp(r'^receipt_[0-9]{16}\.json$').hasMatch(p.basename(target))) {
      return false;
    }
    final file = File(target);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return false;
    }
    final decoded = jsonDecode(await file.readAsString());
    return decoded is Map && decoded['state'] == state.name;
  }
}
