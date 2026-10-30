import 'dart:async';

/// Coordinates backup readers and attachment deletion on the app isolate.
/// Acquire before taking the database snapshot and keep the lease until the
/// ZIP worker has exited, so its file inventory remains readable throughout.
final class AttachmentFileLock {
  AttachmentFileLock._(this._released);

  static Future<void> _tail = Future<void>.value();
  final Completer<void> _released;

  static Future<AttachmentFileLock> acquire() async {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    await previous;
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
    if (!_released.isCompleted) _released.complete();
  }
}
