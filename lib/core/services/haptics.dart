import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as System;
import 'package:haptic_feedback/haptic_feedback.dart' as HFP;

/// Centralized gentle haptics using the `haptic_feedback` plugin.
///
/// These helpers intentionally keep calls fire-and-forget (no await) and
/// are safe on platforms without plugin support (errors are swallowed).
class Haptics {
  Haptics._();
  // Global master switch controlled by settings. When false, all haptics are disabled.
  static bool _enabled = true;
  static bool get enabled => _enabled;
  static void setEnabled(bool v) { _enabled = v; }

  /// Very light tap feedback (e.g., small UI taps or success tick).
  static void light() {
    if (!enabled) return;
    if (_isIOS) {
      _safe(() => HFP.Haptics.vibrate(HFP.HapticsType.light));
    } else if (_isAndroid) {
      _safe(() => System.HapticFeedback.lightImpact());
    }
  }

  /// Medium tap feedback (e.g., opening/closing drawer, toggles).
  static void medium() {
    if (!enabled) return;
    if (_isIOS) {
      _safe(() => HFP.Haptics.vibrate(HFP.HapticsType.medium));
    } else if (_isAndroid) {
      _safe(() => System.HapticFeedback.mediumImpact());
    }
  }

  static void soft() {
    if (!enabled) return;
    if (_isIOS) {
      _safe(() => HFP.Haptics.vibrate(HFP.HapticsType.soft));
    } else if (_isAndroid) {
      // Closest built-in equivalent to a very gentle tap
      _safe(() => System.HapticFeedback.selectionClick());
    }
  }

  /// Drawer-specific pulse; tuned to feel present but not harsh.
  static void drawerPulse() {
    if (!enabled) return;
    if (_isIOS) {
      _safe(() => HFP.Haptics.vibrate(HFP.HapticsType.soft));
    } else if (_isAndroid) {
      _safe(() => System.HapticFeedback.selectionClick());
    }
  }

  /// Cancel any ongoing vibration (rarely needed in our use cases).
  static void cancel() { /* no-op */ }

  // Fire-and-forget wrapper to avoid exceptions on unsupported platforms.
  static void _safe(Future<void> Function() action) {
    if (kIsWeb) return; // Skip on web targets
    try {
      // Don't await; haptic should not block UI.
      // ignore: discarded_futures
      action();
    } catch (_) {
      // Swallow any MissingPluginException or platform channel errors.
    }
  }

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
