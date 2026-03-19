import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Thin wrapper over a macOS-only MethodChannel that gets/sets
/// the NSWindow frame origin (Cocoa coordinates; origin at bottom-left).
class MacOSWindowPosition {
  static const MethodChannel _chan = MethodChannel('app.windowPosition');

  static bool get isSupported => !kIsWeb && Platform.isMacOS;

  /// Returns the window origin (frame.origin.x/y) in Cocoa coordinates.
  static Future<Offset> getOrigin() async {
    if (!isSupported) {
      throw StateError('MacOSWindowPosition used on unsupported platform');
    }
    final List<dynamic> res = await _chan.invokeMethod('getWindowOrigin');
    final dx = (res[0] as num).toDouble();
    final dy = (res[1] as num).toDouble();
    return Offset(dx, dy);
  }

  /// Sets the window origin (frame.origin.x/y) with clamping to visible frame.
  static Future<bool> setOrigin(Offset origin) async {
    if (!isSupported) return false;
    final ok = await _chan.invokeMethod('setWindowOrigin', <double>[
      origin.dx,
      origin.dy,
    ]);
    return ok == true;
  }

  /// Visible frame for current screen (x,y,width,height) in Cocoa coordinates.
  static Future<Rect?> getCurrentVisibleFrame() async {
    if (!isSupported) return null;
    final List<dynamic> res = await _chan.invokeMethod(
      'getVisibleFrameForCurrentScreen',
    );
    final x = (res[0] as num).toDouble();
    final y = (res[1] as num).toDouble();
    final w = (res[2] as num).toDouble();
    final h = (res[3] as num).toDouble();
    return Rect.fromLTWH(x, y, w, h);
  }
}
