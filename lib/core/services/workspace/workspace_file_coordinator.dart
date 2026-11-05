import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// In-process file coordination shared by web apps and AI tools.
/// Callers pass a resolved path. Shell transactions use a workspace-root lock;
/// external editors do not participate in either lock.
class WorkspaceFileCoordinator {
  static final _tails = <String, Future<void>>{};
  static final _workspaceTails = <String, Future<void>>{};
  static final _changes = StreamController<String>.broadcast(sync: true);
  static Stream<String> get changes => _changes.stream;
  static void changed(String path) => _changes.add(path);

  /// Queues shell snapshot transactions for one shared workspace root.
  ///
  /// The lock covers the caller's before-snapshot, command, and after-snapshot
  /// work. A shell from another conversation therefore cannot be mistaken for
  /// the current call's file change while its snapshots are in flight.
  static Future<WorkspaceFileLock> acquireWorkspace(
    String root, {
    void Function()? checkCancelled,
    Future<void>? cancelled,
  }) async {
    final key = _key(root);
    final previous = _workspaceTails[key] ?? Future<void>.value();
    final released = Completer<void>();
    _workspaceTails[key] = released.future;

    try {
      if (cancelled == null) {
        await previous;
      } else {
        final cancelledFirst = await Future.any<bool>([
          previous.then((_) => false),
          cancelled.then((_) => true),
        ]);
        if (cancelledFirst) {
          throw StateError('tool_call_cancelled');
        }
      }
      checkCancelled?.call();
      return WorkspaceFileLock._(key, released);
    } catch (_) {
      // Keep this ticket in the queue until the preceding holder releases it.
      // Otherwise a new shell could start while that holder is still taking
      // its after-snapshot.
      unawaited(
        previous.whenComplete(() {
          if (!released.isCompleted) released.complete();
          if (identical(_workspaceTails[key], released.future)) {
            _workspaceTails.remove(key);
          }
        }),
      );
      rethrow;
    }
  }

  static Future<T> run<T>(String path, Future<T> Function() operation) async {
    final key = _key(path);
    final previous = _tails[key] ?? Future<void>.value();
    final released = Completer<void>();
    _tails[key] = released.future;
    await previous;
    try {
      return await operation();
    } finally {
      released.complete();
      if (identical(_tails[key], released.future)) _tails.remove(key);
    }
  }

  static String _key(String path) {
    var key = p.normalize(path);
    // Case-insensitive volumes must not get two independent locks. This may
    // serialize distinct case-sensitive files too, which is harmless.
    if (Platform.isWindows || Platform.isMacOS || Platform.isIOS) {
      key = key.toLowerCase();
    }
    return key;
  }
}

class WorkspaceFileLock {
  WorkspaceFileLock._(this._key, this._released);

  final String _key;
  final Completer<void> _released;
  bool _didRelease = false;

  void release() {
    if (_didRelease) return;
    _didRelease = true;
    if (!_released.isCompleted) _released.complete();
    if (identical(
      WorkspaceFileCoordinator._workspaceTails[_key],
      _released.future,
    )) {
      WorkspaceFileCoordinator._workspaceTails.remove(_key);
    }
  }
}
