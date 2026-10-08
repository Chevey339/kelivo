import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Transparent macOS title-bar interaction strip.
///
/// Restores native title-bar behavior under [fullSizeContentView]:
/// drag to move, double-click to zoom (maximize/unmaximize).
class MacOSTitleBarDragArea extends StatelessWidget {
  const MacOSTitleBarDragArea({
    super.key,
    this.height = defaultHeight,
    this.onDoubleTapZoom,
  });

  static const double defaultHeight = 40;

  final double height;
  final Future<void> Function()? onDoubleTapZoom;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(height: height, width: double.infinity);

    if (onDoubleTapZoom != null) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) {
          windowManager.startDragging();
        },
        onDoubleTap: () {
          onDoubleTapZoom!();
        },
        child: child,
      );
    }

    return DragToMoveArea(child: child);
  }
}
