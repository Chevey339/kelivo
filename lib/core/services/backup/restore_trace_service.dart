import 'dart:io';

import 'package:path/path.dart' as p;

import 'restore_workspace_lock.dart';

final class RestoreTraceSnapshot {
  const RestoreTraceSnapshot({
    required this.visible,
    required this.fileCount,
    required this.bytes,
  });

  static const empty = RestoreTraceSnapshot(
    visible: false,
    fileCount: 0,
    bytes: 0,
  );

  final bool visible;
  final int fileCount;
  final int bytes;
}

/// Inspects and deletes only cold-acknowledged restore archives.
///
/// Active runs and workspace control files are never counted or removed.
final class RestoreTraceService {
  RestoreTraceService(this.appDataDirectory)
    : _workspace = RestoreWorkspaceLock(appDataDirectory: appDataDirectory);

  final Directory appDataDirectory;
  final RestoreWorkspaceLock _workspace;

  Future<RestoreTraceSnapshot> inspect() async {
    final rootType = await FileSystemEntity.type(
      _workspace.workspaceRoot.path,
      followLinks: false,
    );
    if (rootType == FileSystemEntityType.notFound) {
      return RestoreTraceSnapshot.empty;
    }
    if (rootType != FileSystemEntityType.directory) {
      throw StateError('restore_trace_workspace_type');
    }
    return _workspace.synchronized(_inspectWhileLocked);
  }

  Future<void> clear() async {
    final rootType = await FileSystemEntity.type(
      _workspace.workspaceRoot.path,
      followLinks: false,
    );
    if (rootType == FileSystemEntityType.notFound) return;
    if (rootType != FileSystemEntityType.directory) {
      throw StateError('restore_trace_workspace_type');
    }
    await _workspace.synchronized(() async {
      final snapshot = await _inspectWhileLocked();
      if (!snapshot.visible) {
        if (await _hasActiveRunWhileLocked()) {
          throw StateError('restore_trace_active_run');
        }
        return;
      }
      final completed = _workspace.completedRunsRoot;
      final runs = await completed.list(followLinks: false).toList();
      for (final run in runs) {
        await Directory(run.path).delete(recursive: true);
        await _workspace.durability.syncDirectory(completed, fullBarrier: true);
      }
      await completed.delete();
      await _workspace.durability.syncDirectory(
        _workspace.workspaceRoot,
        fullBarrier: true,
      );
    });
  }

  Future<RestoreTraceSnapshot> _inspectWhileLocked() async {
    if (await _hasActiveRunWhileLocked()) return RestoreTraceSnapshot.empty;
    final completed = _workspace.completedRunsRoot;
    final completedType = await FileSystemEntity.type(
      completed.path,
      followLinks: false,
    );
    if (completedType == FileSystemEntityType.notFound) {
      return RestoreTraceSnapshot.empty;
    }
    if (completedType != FileSystemEntityType.directory) {
      throw StateError('restore_trace_completed_type');
    }
    await RestoreWorkspaceLock.validateCompletedRunsDirectory(completed);

    var fileCount = 0;
    var bytes = 0;
    await for (final entity in completed.list(
      recursive: true,
      followLinks: false,
    )) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('restore_trace_archive_topology');
      }
      fileCount++;
      bytes += await File(entity.path).length();
    }
    return RestoreTraceSnapshot(
      visible: fileCount > 0,
      fileCount: fileCount,
      bytes: bytes,
    );
  }

  Future<bool> _hasActiveRunWhileLocked() async {
    await for (final entity in _workspace.workspaceRoot.list(
      followLinks: false,
    )) {
      final name = p.basename(entity.path);
      if (name == RestoreWorkspaceLock.activeRunFileName ||
          name == RestoreWorkspaceLock.publishingRunFileName ||
          name == RestoreWorkspaceLock.discardingRunFileName ||
          name == RestoreWorkspaceLock.archivingRunFileName ||
          name == RestoreWorkspaceLock.archivingRunTemporaryFileName ||
          RegExp(r'^run_[a-f0-9]{32}$').hasMatch(name)) {
        return true;
      }
    }
    return false;
  }
}
