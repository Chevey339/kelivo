import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'window_size_manager.dart';
import '../utils/platform_utils.dart';

/// Handles desktop window initialization and persistence (size/position/maximized).
class DesktopWindowController with WindowListener {
  DesktopWindowController._();
  static final DesktopWindowController instance = DesktopWindowController._();

  final WindowSizeManager _sizeMgr = const WindowSizeManager();
  bool _attached = false;

  Future<void> initializeAndShow({String? title}) async {
    if (kIsWeb || !PlatformUtils.isDesktop) return;

    try {
      await windowManager.ensureInitialized();
    } catch (e) {
      debugPrint('Window manager initialization failed: $e');
      return;
    }

    // Windows custom title bar is handled in main (TitleBarStyle.hidden)

    final initialSize = await _sizeMgr.getInitialSize();
    const minSize = Size(WindowSizeManager.minWindowWidth, WindowSizeManager.minWindowHeight);
    const maxSize = Size(WindowSizeManager.maxWindowWidth, WindowSizeManager.maxWindowHeight);

    final options = WindowOptions(
      size: initialSize,
      minimumSize: minSize,
      maximumSize: maxSize,
      title: title,
    );

    final savedPos = await _sizeMgr.getPosition();
    final wasMax = await _sizeMgr.getWindowMaximized();

    await windowManager.waitUntilReadyToShow(options, () async {
      if (savedPos != null) {
        try { await windowManager.setPosition(savedPos); } catch (_) {}
      }
      await windowManager.show();
      await windowManager.focus();
      if (wasMax) {
        try { await windowManager.maximize(); } catch (_) {}
      }
    });

    _attachListeners();
  }

  void _attachListeners() {
    if (_attached) return;
    windowManager.addListener(this);
    _attached = true;
  }

  @override
  void onWindowResize() async {
    try {
      final isMax = await windowManager.isMaximized();
      // Avoid saving full-screen/maximized size; keep last restored size.
      if (!isMax) {
        final s = await windowManager.getSize();
        await _sizeMgr.setSize(s);
      }
    } catch (_) {}
  }

  @override
  void onWindowMove() async {
    try {
      final offset = await windowManager.getPosition();
      await _sizeMgr.setPosition(offset);
    } catch (_) {}
  }

  @override
  void onWindowMaximize() async {
    try { await _sizeMgr.setWindowMaximized(true); } catch (_) {}
  }

  @override
  void onWindowUnmaximize() async {
    try { await _sizeMgr.setWindowMaximized(false); } catch (_) {}
  }
}

