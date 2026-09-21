import 'dart:math' as math;
import 'dart:ui';

import 'window_size_manager.dart';
import 'windows_window_geometry.dart';

bool _canDragTitleBar(Rect window, double scale, List<WindowsDisplay> screens) {
  // WindowTitleBar is 40 logical pixels high. Exclude its left controls and
  // three caption buttons, so exposing only buttons does not count as usable.
  final dragArea = Rect.fromLTWH(
    window.left + 64 * scale,
    window.top,
    math.max(0, window.width - (64 + 144) * scale),
    40 * scale,
  );
  return dragArea.width > 0 &&
      screens.any((screen) {
        final visible = dragArea.intersect(screen.workArea);
        return visible.height >= dragArea.height &&
            visible.width >= math.min(120 * scale, dragArea.width);
      });
}

double _overlapArea(Rect window, Rect screen) {
  final overlap = window.intersect(screen);
  return overlap.isEmpty ? 0 : overlap.width * overlap.height;
}

/// Resolves a saved physical position against the current Windows work areas.
/// [size] is logical pixels; the returned bounds are physical pixels.
Rect? resolveWindowsWindowBounds({
  required Size size,
  required Offset? savedPosition,
  required List<WindowsDisplay> displays,
}) {
  final screens = displays.where((screen) => screen.isValid).toList();
  if (screens.isEmpty) return null;
  final primary = screens.where((screen) => screen.isPrimary).firstOrNull;

  WindowsDisplay? overlapping;
  var nearestDistance = double.infinity;
  if (savedPosition != null &&
      savedPosition.dx.isFinite &&
      savedPosition.dy.isFinite) {
    for (final screen in screens) {
      final candidate = savedPosition & (size * screen.scale);
      if (!candidate.overlaps(screen.bounds)) continue;
      // Select by the saved physical origin, including origins just outside a
      // monitor. Comparing differently scaled candidate areas would favour
      // high-DPI neighbours even when the saved title bar is still reachable.
      final nearestPoint = Offset(
        savedPosition.dx.clamp(screen.bounds.left, screen.bounds.right),
        savedPosition.dy.clamp(screen.bounds.top, screen.bounds.bottom),
      );
      final distance = (savedPosition - nearestPoint).distanceSquared;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        overlapping = screen;
      }
    }
  }

  final target = overlapping ?? primary ?? screens.first;
  final work = target.workArea;
  final desiredSize = size * target.scale;
  // The desktop UI itself requires at least 960 x 640 logical pixels. On a
  // smaller work area, anchor that minimum-sized window at the top left rather
  // than shrinking its viewport and clipping its custom title bar.
  final fittedSize = Size(
    math.max(
      WindowSizeManager.minWindowWidth * target.scale,
      math.min(desiredSize.width, work.width),
    ),
    math.max(
      WindowSizeManager.minWindowHeight * target.scale,
      math.min(desiredSize.height, work.height),
    ),
  );
  final savedBounds = savedPosition == null ? null : savedPosition & fittedSize;
  // MonitorFromWindow uses full monitor rectangles, including taskbars. If
  // another DPI can own this spanning window, move it into the sizing monitor.
  final hasConflictingDpi =
      savedBounds != null &&
      screens.any(
        (screen) =>
            screen.scale != target.scale &&
            _overlapArea(savedBounds, screen.bounds) >=
                _overlapArea(savedBounds, target.bounds),
      );
  Offset position;
  if (overlapping == null) {
    position =
        work.topLeft +
        Offset(
          math.max(0, (work.width - fittedSize.width) / 2),
          math.max(0, (work.height - fittedSize.height) / 2),
        );
  } else if (fittedSize != desiredSize ||
      !_canDragTitleBar(savedBounds!, target.scale, screens) ||
      hasConflictingDpi ||
      fittedSize.width > work.width ||
      fittedSize.height > work.height) {
    position = Offset(
      savedPosition!.dx.clamp(
        work.left,
        math.max(work.left, work.right - fittedSize.width),
      ),
      savedPosition.dy.clamp(
        work.top,
        math.max(work.top, work.bottom - fittedSize.height),
      ),
    );
  } else {
    position = savedPosition!;
  }

  return position & fittedSize;
}
