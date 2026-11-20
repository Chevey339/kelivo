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
  /// Shared scopes only conflict with overlapping exclusive scopes.
  static Future<T> runAll<T>(
    Iterable<String> exclusivePaths,
    Future<T> Function() operation, {
    Iterable<String> sharedPaths = const [],
    Duration? waitTimeout,
  }) async {
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    final [exclusiveKeys, sharedKeys] = await Future.wait([
      _resolveKeys(exclusivePaths),
      _resolveKeys(sharedPaths),
    ]);
    cancellation?.throwIfCancelled();
    final current = _FileOperation(exclusiveKeys, sharedKeys);
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

  static Future<Set<String>> _resolveKeys(Iterable<String> paths) async {
    final resolved = await Future.wait(
      paths.map(WorkspacePaths.resolveHostPath),
    );
    return resolved.map(_key).toSet();
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
  _FileOperation(this.exclusivePaths, this.sharedPaths);

  final Set<String> exclusivePaths;
  final Set<String> sharedPaths;
  final released = Completer<void>();

  bool overlaps(_FileOperation other) =>
      _pathsOverlap(exclusivePaths, other.exclusivePaths) ||
      _pathsOverlap(exclusivePaths, other.sharedPaths) ||
      _pathsOverlap(sharedPaths, other.exclusivePaths);

  static bool _pathsOverlap(Set<String> first, Set<String> second) => first.any(
    (path) => second.any(
      (candidate) =>
          path == candidate ||
          p.isWithin(path, candidate) ||
          p.isWithin(candidate, path),
    ),
  );
}
