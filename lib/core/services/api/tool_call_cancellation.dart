import 'dart:async';

import 'request_tool_declarations.dart';

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
      late Zone requestZone;
      final subscription = runZoned(
        () {
          requestZone = Zone.current;
          return action().listen(
            controller.addSync,
            onError: controller.addErrorSync,
            onDone: controller.closeSync,
          );
        },
        zoneValues: {
          _key: this,
          RequestToolDeclarations: RequestToolDeclarations(),
        },
      );
      // A tool often executes after the consumer resumes from its start event.
      controller.onPause = () => requestZone.run(subscription.pause);
      controller.onResume = () => requestZone.run(subscription.resume);
      controller.onCancel = () => requestZone.run(subscription.cancel);
    });
  }

  void throwIfCancelled() {
    if (isCancelled()) throw StateError('tool_call_cancelled');
  }
}
