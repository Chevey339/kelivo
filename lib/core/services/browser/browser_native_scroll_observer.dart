import 'dart:async';

import 'package:flutter/services.dart';

import 'browser_engine.dart';

/// iOS scroll callbacks come from the WKWebView's UIScrollView, independently
/// of document scripts, frames, navigation handshakes, and DOM touchcancel.
class BrowserNativeScrollObserver {
  BrowserNativeScrollObserver({required this.onUpdate}) {
    _events.setMethodCallHandler(_handle);
  }

  final void Function(BrowserScrollState) onUpdate;
  static const _bridge = MethodChannel('app.browser_scroll');
  static int _nextOwner = 0;
  final String _owner =
      'scroll-${DateTime.now().microsecondsSinceEpoch}-${_nextOwner++}';
  late final _events = MethodChannel('app.browser_scroll/$_owner');
  Future<void>? _attaching;
  Timer? _retry;
  Completer<void>? _retryReady;
  bool _attached = false;
  bool _disposed = false;
  bool _visible = false;
  int _sequence = -1;
  String? _viewId;
  int _configurationRevision = 0;

  Future<void> attach({required String viewId, required bool visible}) {
    assert(viewId.isNotEmpty);
    if (_viewId != viewId || _visible != visible) _configurationRevision++;
    if (_viewId != viewId) {
      _viewId = viewId;
      _cancelRetry();
    }
    _visible = visible;
    if (_disposed) return Future<void>.value();
    // Hidden/headless engines need no UIKit tree scan or attachment retries.
    // An existing lease only receives the cheap visibility update.
    if (!visible) return setVisible(false);
    return _attaching ??= _attach();
  }

  Future<void> _attach() async {
    try {
      // Attachment is asynchronous when a headless host transfers to Flutter.
      // Retry only during that transfer, never on steady-state scroll frames.
      for (var attempt = 0; !_disposed && _visible; attempt++) {
        final viewId = _viewId!;
        final attached = await _bridge.invokeMethod<bool>('attach', {
          'owner': _owner,
          'viewId': viewId,
          'visible': _visible,
        });
        if (_disposed) return;
        if (attached == true) _attached = true;
        if (!_visible) {
          final revision = _configurationRevision;
          await setVisible(false);
          if (revision != _configurationRevision) continue;
          return;
        }
        if (viewId != _viewId) continue;
        if (attached == true) {
          final revision = _configurationRevision;
          await setVisible(_visible);
          // A hide/show or host replacement can join this same attachment
          // while the visibility reply is pending. Reconcile even if the
          // final boolean matches the original request (true -> false -> true).
          if (revision != _configurationRevision) continue;
          return;
        }
        final ready = _retryReady = Completer<void>();
        // A busy host can take longer than a second to enter the view tree.
        // Back off to at most one lookup/second instead of permanently giving
        // up. Hidden/disposed hosts cancel the wait immediately.
        final delay = (50 * (1 << attempt.clamp(0, 5))).clamp(50, 1000);
        _retry = Timer(Duration(milliseconds: delay), ready.complete);
        await ready.future;
        _retry = null;
        _retryReady = null;
      }
    } on MissingPluginException {
      // Tests and a torn-down Flutter engine do not own a native bridge.
    } finally {
      // Clear before completing this future; a new caller must not join an
      // already-finished attempt whose final state it has just superseded.
      _attaching = null;
    }
  }

  Future<void> setVisible(bool visible) async {
    if (_visible != visible) _configurationRevision++;
    _visible = visible;
    if (!visible) _cancelRetry();
    if (_disposed || !_attached) return;
    await _bridge.invokeMethod<void>('visibility', {
      'owner': _owner,
      'visible': visible,
    });
  }

  void reset() {
    if (_disposed) return;
    onUpdate(const BrowserScrollState.reset());
    if (_attached) {
      unawaited(_bridge.invokeMethod<void>('reset', {'owner': _owner}));
    }
  }

  Future<void> _handle(MethodCall call) async {
    if (_disposed || !_visible || call.method != 'scroll') return;
    final data = call.arguments;
    if (data is! Map) return;
    if (data['viewId'] != _viewId) return;
    final sequence = data['sequence'];
    final offset = data['offset'];
    final viewport = data['viewportExtent'];
    final content = data['contentExtent'];
    final interacting = data['isUserInteracting'];
    final delta = data['gestureDelta'];
    final phase = switch (data['phase']) {
      'reset' => BrowserScrollPhase.reset,
      'update' => BrowserScrollPhase.update,
      'metrics' => BrowserScrollPhase.metrics,
      _ => null,
    };
    if (sequence is! int ||
        sequence <= _sequence ||
        phase == null ||
        offset is! num ||
        !offset.isFinite ||
        viewport is! num ||
        !viewport.isFinite ||
        viewport <= 0 ||
        content is! num ||
        !content.isFinite ||
        content < 0 ||
        interacting is! bool ||
        delta is! num ||
        !delta.isFinite ||
        (!interacting && delta != 0)) {
      return;
    }
    _sequence = sequence;
    onUpdate(
      BrowserScrollState(
        offset: offset.toDouble(),
        viewportExtent: viewport.toDouble(),
        contentExtent: content.toDouble(),
        phase: phase,
        supportsScrollEnd: false,
        isUserInteracting: interacting,
        gestureDelta: delta.toDouble(),
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _events.setMethodCallHandler(null);
    _cancelRetry();
    try {
      await _bridge.invokeMethod<void>('detach', {'owner': _owner});
    } on MissingPluginException {
      // The Flutter engine may already have been removed.
    }
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
    if (_retryReady?.isCompleted == false) _retryReady!.complete();
  }
}
