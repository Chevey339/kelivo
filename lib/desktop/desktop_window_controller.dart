import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'window_size_manager.dart';
import 'windows_window_geometry.dart';
import 'windows_window_placement.dart';
import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// Handles desktop window initialization and persistence (size/position/maximized).
class DesktopWindowController with WindowListener {
  DesktopWindowController._() : _whenWindowReady = _whenWindowsReady;

  @visibleForTesting
  DesktopWindowController.forTesting(this._whenWindowReady);

  static final DesktopWindowController instance = DesktopWindowController._();

  static void _whenWindowsReady(AsyncCallback callback) {
    doWhenWindowReady(() {
      // Bitsdojo consumes WM_GETMINMAXINFO, so its constraints must remain set
      // even though restoration uses awaited window_manager calls.
      appWindow.minSize = const Size(
        WindowSizeManager.minWindowWidth,
        WindowSizeManager.minWindowHeight,
      );
      appWindow.maxSize = const Size(
        WindowSizeManager.maxWindowWidth,
        WindowSizeManager.maxWindowHeight,
      );
      unawaited(callback());
    });
  }

  final void Function(AsyncCallback) _whenWindowReady;
  final WindowSizeManager _sizeMgr = const WindowSizeManager();
  bool _attached = false;
  bool _restoring = false;
  int _geometryRevision = 0;
  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;
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
    if (!_isWindows) _attachListeners();
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

    if (_isWindows) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      final placement = await _windowsPlacement(initialSize, savedPos);
      _whenWindowReady(() async {
        _restoring = true;
        try {
          if (placement == null) {
            // If display discovery fails, retain the runner's initial position.
            await windowManager.setSize(initialSize);
          } else {
            await restoreWindowsWindowBounds(placement);
          }
          if (wasMax) await windowManager.maximize();
        } catch (_) {
          // A window-manager failure must not prevent the app from opening.
        } finally {
          _restoring = false;
          _attachListeners();
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

  Future<Rect?> _windowsPlacement(Size size, Offset? position) async {
    try {
      return resolveWindowsWindowBounds(
        size: size,
        savedPosition: position,
        displays: await getWindowsDisplays(),
      );
    } catch (_) {
      return null;
    }
  }

  void _cancelWindowsSave() {
    _geometryRevision++;
    _moveDebounce?.cancel();
  }

  void _scheduleWindowsSave() {
    _cancelWindowsSave();
    if (_restoring) return;
    _moveDebounce = Timer(_debounceDuration, _saveWindowsNormalBounds);
  }

  Future<void> _saveWindowsNormalBounds() async {
    final revision = _geometryRevision;
    try {
      if (_restoring ||
          await windowManager.isMaximized() ||
          await windowManager.isMinimized() ||
          await windowManager.isFullScreen()) {
        return;
      }
      // Capture the same scale that getBounds passes to its native call.
      final scale = windowManager.getDevicePixelRatio();
      final bounds = await windowManager.getBounds();
      if (_restoring || revision != _geometryRevision) return;
      await _sizeMgr.setSize(bounds.size);
      await _sizeMgr.setPosition(bounds.topLeft * scale);
    } catch (_) {}
  }

  void _attachListeners() {
    if (_attached) return;
    windowManager.addListener(this);
    _attached = true;
  }

  @override
  void onWindowResize() async {
    if (_isWindows) {
      _scheduleWindowsSave();
      return;
    }
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
    if (_isWindows) {
      _scheduleWindowsSave();
      return;
    }
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
    if (_isWindows) _cancelWindowsSave();
    if (_restoring) return;
    try {
      await _sizeMgr.setWindowMaximized(true);
      if (!_isWindows) await _sizeMgr.setPosition(const Offset(0, 0));
    } catch (_) {}
  }

  @override
  void onWindowUnmaximize() async {
    if (_restoring) return;
    try {
      await _sizeMgr.setWindowMaximized(false);
      if (_isWindows) {
        _scheduleWindowsSave();
        return;
      }
      // Capture current position on restore from maximized.
      final offset = await windowManager.getPosition();
      await _sizeMgr.setPosition(offset);
    } catch (_) {}
  }

  // Persist fullscreen transitions similarly to maximize/unmaximize to
  // keep state consistent across platforms and avoid position jumps.
  @override
  void onWindowEnterFullScreen() async {
    if (_isWindows) _cancelWindowsSave();
    if (_restoring) return;
    try {
      await _sizeMgr.setWindowMaximized(true);
      if (!_isWindows) await _sizeMgr.setPosition(const Offset(0, 0));
    } catch (_) {}
  }

  @override
  void onWindowLeaveFullScreen() async {
    if (_restoring) return;
    try {
      await _sizeMgr.setWindowMaximized(false);
      if (_isWindows) {
        _scheduleWindowsSave();
        return;
      }
      final offset = await windowManager.getPosition();
      await _sizeMgr.setPosition(offset);
    } catch (_) {}
  }

  @override
  void onWindowMinimize() {
    if (_isWindows) _cancelWindowsSave();
  }

  @override
  void onWindowRestore() {
    if (_isWindows) _scheduleWindowsSave();
  }
}
