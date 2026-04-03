import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'window_size_manager.dart';
import 'dart:async';

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

    // Validate saved position against current screen bounds to prevent
    // the window from restoring off-screen (e.g. after an RDP session
    // changes the display layout). See issue #432.
    final validatedPos =
        savedPos != null ? await _validatePosition(savedPos, initialSize) : null;

    await windowManager.waitUntilReadyToShow(options, () async {
      // Show first, then restore position to avoid macOS jump/flicker.
      await windowManager.show();
      await windowManager.focus();
      // On macOS rely on native autosave. Do not set position from Dart.
      final shouldRestorePos = validatedPos != null && !isMac;
      if (shouldRestorePos) {
        try {
          final logicPos = await _physicalToLogical(validatedPos);
          await windowManager.setPosition(logicPos);
        } catch (_) {}
      }
      // Only auto-restore maximize on Windows; macOS restore may cause jump.
      try {
        if (defaultTargetPlatform == TargetPlatform.windows && wasMax) {
          await windowManager.maximize();
        }
      } catch (_) {}
    });

    _attachListeners();
  }
    /// 将物理像素坐标转换为逻辑坐标
    /// Windows上 window_manager 返回物理像素，需除以所在屏幕的 devicePixelRatio
    Future<Offset> _physicalToLogical(Offset physicalPos) async {
      try {
        final displays = await ScreenRetriever.instance.getAllDisplays();
        for (final display in displays) {
          if (display.visiblePosition == null || display.visibleSize == null) continue;
          final scale = display.scaleFactor ?? 1.0; // scaleFactor 即 devicePixelRatio
        
          // display 的 visiblePosition/visibleSize 是逻辑像素
          // 把 physicalPos 先转成该屏幕下的逻辑坐标再判断归属
          final logicalPos = Offset(physicalPos.dx / scale, physicalPos.dy / scale);
        
          // 但这样不对，因为多屏时物理坐标的原点是混合的
          // 更可靠：直接比较物理坐标范围
          final physLeft = display.visiblePosition!.dx * scale;
          final physTop = display.visiblePosition!.dy * scale;
          final physRight = physLeft + display.visibleSize!.width * scale;
          final physBottom = physTop + display.visibleSize!.height * scale;
        
          if (physicalPos.dx >= physLeft && physicalPos.dx < physRight &&
              physicalPos.dy >= physTop && physicalPos.dy < physBottom) {
            // 属于这个屏幕，转为逻辑坐标
            return Offset(physicalPos.dx / scale, physicalPos.dy / scale);
          }
        }
      } catch (_) {}
      return physicalPos; // fallback
    }
    
  /// Returns [position] if at least a portion of the window (defined by
  /// [windowSize]) would be visible on any connected display; otherwise
  /// returns `null` so the OS can place the window at a default location.
  ///
  /// This guards against the window restoring off-screen when the display
  /// layout has changed (e.g. after an RDP session or monitor disconnect).
  Future<Offset?> _validatePosition(Offset position, Size windowSize) async {
    try {
      final displays = await ScreenRetriever.instance.getAllDisplays();
      if (displays.isEmpty) return position; // fallback: trust the value

      // Require at least this many pixels of the window to be visible
      // on some display so the user can grab and move it.
      const minVisible = 100.0;

      final winLeft = position.dx;
      final winTop = position.dy;
      final winRight = winLeft + windowSize.width;
      final winBottom = winTop + windowSize.height;

      for (final display in displays) {
        final visibleRect = display.visiblePosition != null &&
                display.visibleSize != null
            ? Rect.fromLTWH(
                display.visiblePosition!.dx,
                display.visiblePosition!.dy,
                display.visibleSize!.width,
                display.visibleSize!.height,
              )
            : Rect.fromLTWH(
                display.size.width * 0, // origin fallback
                display.size.height * 0,
                display.size.width,
                display.size.height,
              );

        // Compute overlap between window rect and display rect.
        final overlapLeft =
            winLeft > visibleRect.left ? winLeft : visibleRect.left;
        final overlapTop =
            winTop > visibleRect.top ? winTop : visibleRect.top;
        final overlapRight =
            winRight < visibleRect.right ? winRight : visibleRect.right;
        final overlapBottom =
            winBottom < visibleRect.bottom ? winBottom : visibleRect.bottom;

        final overlapW = overlapRight - overlapLeft;
        final overlapH = overlapBottom - overlapTop;

        if (overlapW >= minVisible && overlapH >= minVisible) {
          return position; // enough of the window is visible
        }
      }

      // Window would be off-screen on all displays → discard position.
      return null;
    } catch (_) {
      // If screen query fails, fall back to the saved position rather
      // than risk discarding a valid one.
      return position;
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
