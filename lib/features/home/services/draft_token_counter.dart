import 'dart:async';
import 'dart:isolate';

import '../../../core/utils/token_estimator.dart';

// Keep the isolate closure separate from the counter and its UI callback.
Future<int> _estimateDraftTokens(String text) =>
    Isolate.run(() => estimateTokens(text));

/// Coalesces edits into one running estimate and one pending latest draft.
class DraftTokenCounter {
  DraftTokenCounter({
    required this._onCountChanged,
    Future<int> Function(String)? estimate,
    this._debounce = const Duration(milliseconds: 200),
  }) : _estimate = estimate ?? _estimateDraftTokens;

  final void Function(int) _onCountChanged;
  final Future<int> Function(String) _estimate;
  final Duration _debounce;
  Timer? _timer;
  String? _pendingText;
  Future<void>? _running;
  int? _runningVersion;
  int _version = 0;
  int _tokens = 0;
  bool _disposed = false;
  AsyncError? _error;

  int get tokens => _tokens;

  void update(String text) {
    if (_disposed) return;
    _version++;
    _error = null;
    _timer?.cancel();
    _timer = null;
    _pendingText = null;
    if (text.isEmpty) {
      _publish(0);
      return;
    }
    _pendingText = text;
    _timer = Timer(_debounce, () {
      _timer = null;
      _start();
    });
  }

  /// Explicit refreshes can await the latest count without blocking the UI.
  Future<void> flush() async {
    while (!_disposed) {
      _timer?.cancel();
      _timer = null;
      _start();
      final running = _running;
      if (running == null ||
          (_pendingText == null && _runningVersion != _version)) {
        break;
      }
      await running;
    }
    final error = _error;
    if (!_disposed && error != null) {
      Error.throwWithStackTrace(error.error, error.stackTrace);
    }
  }

  void _start() {
    final text = _pendingText;
    if (_disposed || _running != null || text == null) return;
    final version = _version;
    _pendingText = null;
    _runningVersion = version;
    _running = _run(text, version);
  }

  Future<void> _run(String text, int version) async {
    try {
      final count = await Future<int>.sync(() => _estimate(text));
      if (!_disposed && version == _version) _publish(count);
    } catch (error, stack) {
      // Preserve the last valid count; a refresh observes the failure and a
      // subsequent edit retries. Timer-launched tasks must not leak errors.
      if (!_disposed && version == _version) {
        _error = AsyncError(error, stack);
      }
    } finally {
      _running = null;
      _runningVersion = null;
      if (!_disposed && _timer == null) _start();
    }
  }

  void _publish(int count) {
    if (_tokens == count) return;
    _tokens = count;
    _onCountChanged(count);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pendingText = null;
  }
}
