import 'dart:async';

/// The generation owning a tool call, including work after the HTTP response.
class ToolCallCancellation {
  ToolCallCancellation({required this.isCancelled, required this.cancelled}) {
    // One Future continuation per generation, not one per completed tool.
    cancelled.then((_) {
      _didCancel = true;
      final listeners = List<void Function()>.of(_listeners);
      _listeners.clear();
      for (final listener in listeners) {
        listener();
      }
    });
  }

  final bool Function() isCancelled;
  final Future<void> cancelled;
  final Set<void Function()> _listeners = {};
  bool _didCancel = false;

  int get listenerCount => _listeners.length;

  /// Returns an idempotent unregister function. Registration after cancellation
  /// invokes the callback immediately, so a tool cannot miss the cancellation.
  void Function() onCancel(void Function() listener) {
    final guarded = Zone.current.bindCallbackGuarded(listener);
    if (_didCancel || isCancelled()) {
      guarded();
      return () {};
    }
    _listeners.add(guarded);
    return () => _listeners.remove(guarded);
  }

  static final Object _key = Object();
  static ToolCallCancellation? get current =>
      Zone.current[_key] as ToolCallCancellation?;

  Future<T> run<T>(Future<T> Function() action) {
    throwIfCancelled();
    return runZoned(action, zoneValues: {_key: this});
  }

  /// Include request preparation and provider continuations, which may perform
  /// I/O before or after the tool handler itself (for example image replay).
  Stream<T> runStream<T>(Stream<T> Function() action) {
    return Stream<T>.multi((controller) {
      final subscription = runZoned(
        () => action().listen(
          controller.addSync,
          onError: controller.addErrorSync,
          onDone: controller.closeSync,
        ),
        zoneValues: {_key: this},
      );
      controller.onPause = subscription.pause;
      controller.onResume = subscription.resume;
      controller.onCancel = subscription.cancel;
    });
  }

  void throwIfCancelled() {
    if (isCancelled()) throw StateError('tool_call_cancelled');
  }
}
