import 'dart:async';

/// Coordinates backup readers and attachment deletion on the app isolate.
/// Acquire before taking the database snapshot and keep the lease until the
/// ZIP worker has exited, so its file inventory remains readable throughout.
final class AttachmentFileLock {
  AttachmentFileLock._(this._released);

  static Future<void>? _tail;
  final Completer<void> _released;

  static Future<AttachmentFileLock> acquire() async {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    if (previous != null) await previous;
    return AttachmentFileLock._(released);
  }

  static Future<T> synchronized<T>(Future<T> Function() action) async {
    final lease = await acquire();
    try {
      return await action();
    } finally {
      lease.release();
    }
  }

  void release() {
    if (_released.isCompleted) return;
    // A completed Future retains its originating Zone. Drop the idle queue
    // tail so a finished generation (or a disposed test scheduler) is not kept
    // alive by a process-global lock. A queued waiter already owns a new tail.
    if (identical(_tail, _released.future)) _tail = null;
    _released.complete();
  }
}
