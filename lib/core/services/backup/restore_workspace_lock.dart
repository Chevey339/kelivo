import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

final class RestoreWorkspaceLock {
  RestoreWorkspaceLock({required this.appDataDirectory});

  static const workspaceRootName = '.kelivo_restore';
  static const lockFileName = '.receipt.lock';
  static const activeRunFileName = '.active_run';
  static final _localTails = <String, Future<void>>{};

  final Directory appDataDirectory;

  Directory get workspaceRoot =>
      Directory(p.join(appDataDirectory.path, workspaceRootName));

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
