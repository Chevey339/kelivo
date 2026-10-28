import 'package:flutter/material.dart';

/// Gives Flutter controls a continuous cursor region above native WebViews.
/// MouseRegion alone cannot cover the gaps between glyphs in AppKit's
/// foreground paint regions. Keep this paint above, not around, the WebView.
class DesktopPointerSurface extends StatelessWidget {
  const DesktopPointerSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionContainer.disabled(
    child: MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: ColoredBox(color: const Color(0x01000000), child: child),
    ),
  );
}
