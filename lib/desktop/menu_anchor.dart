import 'package:flutter/material.dart';

class DesktopMenuAnchor {
  static Offset? _last;

  static void setPosition(Offset globalPosition) {
    _last = globalPosition;
  }

  static Offset positionOrCenter(BuildContext context) {
    if (_last != null) return _last!;
    final overlay = Overlay.of(context)?.context.findRenderObject() as RenderBox?;
    if (overlay != null) {
      final size = overlay.size;
      return Offset(size.width / 2, size.height / 2);
    }
    return const Offset(300, 300);
  }
}

