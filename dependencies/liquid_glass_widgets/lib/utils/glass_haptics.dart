import 'package:flutter/services.dart';

/// Host hooks for applications with a central haptics preference. Null hooks
/// retain Flutter's default behavior for standalone package consumers.
class GlassHaptics {
  GlassHaptics._();
  static void Function()? onSelection, onLight, onMedium, onHeavy, onVibrate;
  static Future<void> _play(
      void Function()? hook, Future<void> Function() fallback) async {
    if (hook != null) {
      hook();
    } else {
      await fallback();
    }
  }

  static Future<void> selectionClick() =>
      _play(onSelection, HapticFeedback.selectionClick);
  static Future<void> lightImpact() =>
      _play(onLight, HapticFeedback.lightImpact);
  static Future<void> mediumImpact() =>
      _play(onMedium, HapticFeedback.mediumImpact);
  static Future<void> heavyImpact() =>
      _play(onHeavy, HapticFeedback.heavyImpact);
  static Future<void> vibrate() => _play(onVibrate, HapticFeedback.vibrate);
}
