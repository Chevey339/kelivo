import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../api/tool_call_cancellation.dart';
import 'workspace_paths.dart';

/// In-process exclusion shared by file tools, web app storage and shells.
/// Directory scopes exclude operations on their descendants as well. External
/// editors and processes started outside these tools do not share this lock.
class WorkspaceFileCoordinator {
  static final _pending = <_FileOperation>[];
  static final _changes = StreamController<String>.broadcast(sync: true);
  static Stream<String> get changes => _changes.stream;
  static void changed(String path) => _changes.add(path);

  static Future<T> run<T>(
    String path,
    Future<T> Function() operation, {
    Duration? waitTimeout,
  }) => runAll([path], operation, waitTimeout: waitTimeout);

  /// Acquires all scopes together so overlapping workspace/session roots cannot
  /// deadlock. Queued operations participate too, preserving their ordering.
  static Future<T> runAll<T>(
    Iterable<String> paths,
    Future<T> Function() operation, {
    Duration? waitTimeout,
  }) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    final keys = await Future.wait(paths.map(WorkspacePaths.resolveHostPath));
    cancellation?.throwIfCancelled();
    final current = _FileOperation(keys.map(_key).toSet());
    final previous = Future.wait([
      for (final pending in _pending)
        if (current.overlaps(pending)) pending.released.future,
    ]);
    _pending.add(current);

    void Function()? unregisterCancellation;
    try {
      final ready = waitTimeout == null
          ? previous
          : previous.timeout(waitTimeout);
      if (cancellation == null) {
        await ready;
      } else {
        final cancelled = Completer<void>();
        unregisterCancellation = cancellation.onCancel(cancelled.complete);
        await Future.any<void>([ready, cancelled.future]);
        cancellation.throwIfCancelled();
      }
      return await operation();
    } finally {
      unregisterCancellation?.call();
      // Cancellation/timeouts must not let a later overlapping operation
      // overtake a holder that is still running (including its after-snapshot).
      unawaited(
        previous.then((_) {
          _pending.remove(current);
          current.released.complete();
        }),
      );
    }
  }

  static String _key(String path) {
    final key = p.normalize(path);
    // Case-insensitive volumes must not get independent locks for aliases.
    if (Platform.isWindows || Platform.isMacOS || Platform.isIOS) {
      return key.toLowerCase();
    }
    return key;
  }
}

class _FileOperation {
  _FileOperation(this.paths);

  final Set<String> paths;
  final released = Completer<void>();

  bool overlaps(_FileOperation other) => paths.any(
    (path) => other.paths.any(
      (candidate) =>
          path == candidate ||
          p.isWithin(path, candidate) ||
          p.isWithin(candidate, path),
    ),
  );
}
