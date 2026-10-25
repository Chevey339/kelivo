import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// AppKit keeps this resize gesture attached to its initiating window while
/// the pointer crosses Flutter overlays and native WebViews.
class SidebarResizeCapture {
  SidebarResizeCapture({required this.onEnd});

  static const _channel = MethodChannel('app.sidebar_resize');
  static int _nextSession = 0;
  static int _nextCursorOwner = 0;
  final _cursorOwner = ++_nextCursorOwner;
  static SidebarResizeCapture? _owner;
  final VoidCallback onEnd;
  int? _session;

  Future<bool> begin(Duration timestamp) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return false;
    final previous = _owner;
    previous?.cancel();
    previous?.onEnd();
    final session = ++_nextSession;
    _session = session;
    _owner = this;
    _channel.setMethodCallHandler(_handleEvent);
    try {
      final captured = await _channel.invokeMethod<bool>('begin', {
        'session': session,
        'timestampMicros': timestamp.inMicroseconds,
      });
      return _session == session && captured == true;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> _handleEvent(MethodCall call) async {
    final args = call.arguments;
    final owner = _owner;
    if (owner == null || args is! Map || args['session'] != owner._session) {
      return;
    }
    if (call.method == 'end') {
      owner.cancel();
      owner.onEnd();
    }
  }

  void updateCursor(Rect? bounds) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    unawaited(() async {
      try {
        await _channel.invokeMethod<void>('cursor', {
          'owner': _cursorOwner,
          'bounds': bounds == null
              ? null
              : [bounds.left, bounds.top, bounds.width, bounds.height],
        });
      } on MissingPluginException {
        // Non-native previews keep Flutter's standard resize cursor.
      }
    }());
  }

  void dispose() {
    cancel();
    updateCursor(null);
  }

  void cancel() {
    final session = _session;
    _session = null;
    if (identical(_owner, this)) _owner = null;
    if (session == null) return;
    unawaited(_release(session));
  }

  static Future<void> _release(int session) async {
    try {
      await _channel.invokeMethod<void>('end', session);
    } on MissingPluginException {
      // Widget tests and non-macOS hosts do not install the AppKit bridge.
    }
  }
}
