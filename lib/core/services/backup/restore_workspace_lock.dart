import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

final class RestoreWorkspaceLock {
  RestoreWorkspaceLock({required this.appDataDirectory});

  static const workspaceRootName = '.kelivo_restore';
  static const lockFileName = '.receipt.lock';
  static const activeRunFileName = '.active_run';
  static const publishingRunFileName = '.active_run.publishing';
  static const discardingRunFileName = '.active_run.discarding';
  static final _localTails = <String, Future<void>>{};

  final Directory appDataDirectory;

  Directory get workspaceRoot =>
      Directory(p.join(appDataDirectory.path, workspaceRootName));

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
    await active.rename(claimed.path);
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
    await claimed.rename(active.path);
    await _requireRunFile(active, runId);
  }

  static Future<void> _requireRunFile(File file, String runId) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() != 32 ||
        await file.readAsString() != runId) {
      throw StateError('restore_workspace_active_run');
    }
  }

  static void _validateRunId(String runId) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(runId)) {
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
