import 'dart:async';

/// The generation owning a tool call, including work after the HTTP response.
class ToolCallCancellation {
  const ToolCallCancellation({
    required this.isCancelled,
    required this.cancelled,
  });

  final bool Function() isCancelled;
  final Future<void> cancelled;
  static final Object _key = Object();
  static ToolCallCancellation? get current =>
      Zone.current[_key] as ToolCallCancellation?;

  Future<T> run<T>(Future<T> Function() action) {
    throwIfCancelled();
    return runZoned(action, zoneValues: {_key: this});
  }

  void throwIfCancelled() {
    if (isCancelled()) throw StateError('tool_call_cancelled');
  }
}
