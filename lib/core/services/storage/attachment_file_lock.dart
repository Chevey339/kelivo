import 'dart:async';
import 'dart:isolate';

typedef AttachmentReferenceReader = Map<String, Map<String, String>> Function();

/// Contains only data that can be sent to the worker doing the reference check.
final class TransientAttachmentSnapshot {
  TransientAttachmentSnapshot._(this._readers, this.generationActive);
  final List<AttachmentReferenceReader> _readers;
  final bool generationActive;

  Map<String, Map<String, String>> resolve() {
    final result = <String, Map<String, String>>{};
    for (final read in _readers) {
      for (final entry in read().entries) {
        result.putIfAbsent(entry.key, () => {}).addAll(entry.value);
      }
    }
    return result;
  }
}

/// Coordinates backup readers and attachment deletion on the app isolate.
/// Acquire before taking the database snapshot and keep the lease until the
/// ZIP worker has exited, so its file inventory remains readable throughout.
final class AttachmentFileLock {
  AttachmentFileLock._(this._released);

  static Future<void>? _tail;
  static final _changes = StreamController<void>.broadcast();
  static int _transientRevision = 0;
  static int get transientRevision => _transientRevision;
  static Stream<void> get transientChanges => _changes.stream;

  static void notifyTransientChanged() {
    _transientRevision++;
    if (_changes.hasListener) _changes.add(null);
  }

  static final _transientOwners =
      <
        Object,
        ({
          AttachmentReferenceReader? Function() capture,
          bool Function() active,
        })
      >{};

  /// Memory-only chat mutations use this lock too. Read these callbacks only
  /// after acquiring it so a queued cleanup cannot use an obsolete snapshot.
  static void registerTransientOwner(
    Object owner, {
    required AttachmentReferenceReader? Function() capture,
    required bool Function() active,
  }) {
    _transientOwners[owner] = (capture: capture, active: active);
    notifyTransientChanged();
  }

  static void unregisterTransientOwner(Object owner) {
    if (_transientOwners.remove(owner) != null) notifyTransientChanged();
  }

  static bool get hasActiveTransientGeneration =>
      _transientOwners.values.any((owner) => owner.active());

  static TransientAttachmentSnapshot captureTransient() =>
      TransientAttachmentSnapshot._([
        for (final owner in _transientOwners.values) ?owner.capture(),
      ], hasActiveTransientGeneration);

  static Future<Map<String, Map<String, String>>>
  readTransientReferences() async {
    final snapshot = captureTransient();
    return snapshot._readers.isEmpty ? {} : Isolate.run(snapshot.resolve);
  }

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
