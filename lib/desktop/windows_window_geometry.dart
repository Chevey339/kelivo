import 'package:flutter/services.dart';

const _channel = MethodChannel('app.desktop_window');

/// Exact Win32 monitor and work-area rectangles, in physical pixels.
class WindowsDisplay {
  const WindowsDisplay({
    required this.bounds,
    required this.workArea,
    required this.scale,
    this.isPrimary = false,
  });

  factory WindowsDisplay.fromMap(Map<Object?, Object?> data) => WindowsDisplay(
    bounds: _readRect(data['bounds']),
    workArea: _readRect(data['workArea']),
    scale: (data['scale'] as num).toDouble(),
    isPrimary: data['isPrimary'] as bool,
  );

  final Rect bounds;
  final Rect workArea;
  final double scale;
  final bool isPrimary;

  bool get isValid =>
      bounds.isFinite &&
      !bounds.isEmpty &&
      workArea.isFinite &&
      !workArea.isEmpty &&
      scale.isFinite &&
      scale > 0;
}

Rect _readRect(Object? value) {
  final data = value as Map;
  return Rect.fromLTRB(
    (data['left'] as num).toDouble(),
    (data['top'] as num).toDouble(),
    (data['right'] as num).toDouble(),
    (data['bottom'] as num).toDouble(),
  );
}

Future<List<WindowsDisplay>> getWindowsDisplays() async {
  final data = await _channel.invokeListMethod<Object?>('getDisplays');
  return data?.map((value) => WindowsDisplay.fromMap(value as Map)).toList() ??
      const [];
}

/// Applies physical bounds on the window thread without DPI-driven resizing.
Future<void> restoreWindowsWindowBounds(Rect bounds) =>
    _channel.invokeMethod<void>('restoreBounds', {
      'left': bounds.left.roundToDouble(),
      'top': bounds.top.roundToDouble(),
      'right': bounds.right.roundToDouble(),
      'bottom': bounds.bottom.roundToDouble(),
    });
