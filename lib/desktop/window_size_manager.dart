import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages desktop window size/position persistence and defaults.
class WindowSizeManager {
  // Constraints
  static const double minWindowWidth = 960.0;
  static const double minWindowHeight = 640.0;
  static const double maxWindowWidth = 8192.0;
  static const double maxWindowHeight = 8192.0;

  // Default (first launch)
  static const double defaultWindowWidth = 1280.0;
  static const double defaultWindowHeight = 860.0;

  // Keys
  static const String _kWidth = 'window_width_v1';
  static const String _kHeight = 'window_height_v1';
  static const String _kPosX = 'window_pos_x_v1';
  static const String _kPosY = 'window_pos_y_v1';
  static const String _kMaximized = 'window_maximized_v1';

  const WindowSizeManager();

  Size _clamp(Size s) {
    final w = s.width.clamp(minWindowWidth, maxWindowWidth);
    final h = s.height.clamp(minWindowHeight, maxWindowHeight);
    return Size(w.toDouble(), h.toDouble());
  }

  Future<Size> getInitialSize() async {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble(_kWidth) ?? defaultWindowWidth;
    final height = prefs.getDouble(_kHeight) ?? defaultWindowHeight;
    return _clamp(Size(width, height));
  }

  Future<void> setSize(Size size) async {
    final prefs = await SharedPreferences.getInstance();
    final s = _clamp(size);
    await prefs.setDouble(_kWidth, s.width);
    await prefs.setDouble(_kHeight, s.height);
  }

  Future<Offset?> getPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_kPosX);
    final y = prefs.getDouble(_kPosY);
    if (x == null || y == null) return null;
    // Simple sanity: avoid infinities
    if (!x.isFinite || !y.isFinite) return null;
    return Offset(x, y);
  }

  Future<void> setPosition(Offset offset) async {
    final prefs = await SharedPreferences.getInstance();
    final x = offset.dx;
    final y = offset.dy;
    if (x.isFinite && y.isFinite) {
      await prefs.setDouble(_kPosX, x);
      await prefs.setDouble(_kPosY, y);
    }
  }

  Future<bool> getWindowMaximized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kMaximized) ?? false;
  }

  Future<void> setWindowMaximized(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMaximized, value);
  }
}

