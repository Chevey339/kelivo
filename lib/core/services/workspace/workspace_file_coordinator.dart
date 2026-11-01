import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// In-process read/modify/write exclusion, shared by web apps and AI tools.
/// Callers pass a resolved path. Shells/external editors do not share this lock.
class WorkspaceFileCoordinator {
  static final _tails = <String, Future<void>>{};
  static final _changes = StreamController<String>.broadcast(sync: true);
  static Stream<String> get changes => _changes.stream;
  static void changed(String path) => _changes.add(path);

  static Future<T> run<T>(String path, Future<T> Function() operation) async {
    var key = p.normalize(path);
    // Case-insensitive volumes must not get two independent locks. This may
    // serialize distinct case-sensitive files too, which is harmless.
    if (Platform.isWindows || Platform.isMacOS || Platform.isIOS) {
      key = key.toLowerCase();
    }
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
}
