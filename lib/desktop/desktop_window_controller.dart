import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'window_size_manager.dart';
import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// Handles desktop window initialization and persistence (size/position/maximized).
class DesktopWindowController with WindowListener {
  DesktopWindowController._();
  static final DesktopWindowController instance = DesktopWindowController._();

  final WindowSizeManager _sizeMgr = const WindowSizeManager();
  bool _attached = false;
  // Debounce timers to avoid frequent disk writes during drag/resize
  Timer? _moveDebounce;
  Timer? _resizeDebounce;
  static const _debounceDuration = Duration(milliseconds: 400);

  Future<void> initializeAndShow({String? title}) async {
    if (kIsWeb) return;
    if (!(defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux)) {
      return;
    }

    await windowManager.ensureInitialized();
    _attachListeners();
    // Windows custom title bar is handled in main (TitleBarStyle.hidden)

    final initialSize = await _sizeMgr.getInitialSize();
    const minSize = Size(
      WindowSizeManager.minWindowWidth,
      WindowSizeManager.minWindowHeight,
    );
    const maxSize = Size(
      WindowSizeManager.maxWindowWidth,
      WindowSizeManager.maxWindowHeight,
    );

    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final options = WindowOptions(
      // On macOS, let Cocoa autosave restore the last frame to avoid jumps.
      size: isMac ? null : initialSize,
      // Avoid imposing min/max on macOS to prevent subtle size corrections.
      minimumSize: isMac ? null : minSize,
      maximumSize: isMac ? null : maxSize,
      title: title,
    );

    final savedPos = await _sizeMgr.getPosition();
    final wasMax = await _sizeMgr.getWindowMaximized();

    if (defaultTargetPlatform == TargetPlatform.windows){
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      doWhenWindowReady(() async {
        appWindow.minSize = options.minimumSize;
        appWindow.maxSize = options.maximumSize;
        appWindow.size = initialSize;

        if (savedPos != null) {
          appWindow.position = savedPos;
        }

        /// on Windows we maximize the window if it was previously closed
        /// from a maximized state.
        if (wasMax) {
          appWindow.maximize();
        }
      });
    } else {
      await windowManager.waitUntilReadyToShow(options, () async {
        // Show first, then restore position to avoid macOS jump/flicker.
        await windowManager.show();
        await windowManager.focus();
        // On macOS rely on native autosave. Do not set position from Dart.
        final shouldRestorePos = savedPos != null && !isMac;
        if (shouldRestorePos) {
          try {
            await windowManager.setPosition(savedPos);
          } catch (_) {}
        }
      });      
    }


    
  }

  void _attachListeners() {
    if (_attached) return;
    windowManager.addListener(this);
    _attached = true;
  }

  @override
  void onWindowResize() async {
    // Throttle saves while resizing to reduce jank
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(_debounceDuration, () async {
      try {
        final isMax = await windowManager.isMaximized();
        if (!isMax) {
          final s = await windowManager.getSize();
          await _sizeMgr.setSize(s);
        }
      } catch (_) {}
    });
  }

  @override
  void onWindowMove() async {
    // Debounce position persistence during drag to avoid main-isolate IO on every move
    _moveDebounce?.cancel();
    _moveDebounce = Timer(_debounceDuration, () async {
      try {
        final offset = await windowManager.getPosition();
        await _sizeMgr.setPosition(offset);
      } catch (_) {}
    });
  }

  @override
  void onWindowMaximize() async {
    try {
      await _sizeMgr.setWindowMaximized(true);
      // Mark position as origin placeholder to avoid stale restore when maximized.
      await _sizeMgr.setPosition(const Offset(0, 0));
    } catch (_) {}
  }

  @override
  void onWindowUnmaximize() async {
    try {
      await _sizeMgr.setWindowMaximized(false);
      // Capture current position on restore from maximized.
      final offset = await windowManager.getPosition();
      await _sizeMgr.setPosition(offset);
    } catch (_) {}
  }

  // Persist fullscreen transitions similarly to maximize/unmaximize to
  // keep state consistent across platforms and avoid position jumps.
  @override
  void onWindowEnterFullScreen() async {
    try {
      await _sizeMgr.setWindowMaximized(true);
      await _sizeMgr.setPosition(const Offset(0, 0));
    } catch (_) {}
  }

  @override
  void onWindowLeaveFullScreen() async {
    try {
      await _sizeMgr.setWindowMaximized(false);
      final offset = await windowManager.getPosition();
      await _sizeMgr.setPosition(offset);
    } catch (_) {}
  }
}
