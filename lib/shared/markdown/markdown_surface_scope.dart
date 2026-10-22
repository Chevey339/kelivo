import 'package:flutter/widgets.dart';

enum MarkdownSurfaceKind { frosted, solid, tinted }

/// Describes the existing message surface without adding a render object.
class MarkdownSurfaceScope extends InheritedWidget {
  const MarkdownSurfaceScope({
    super.key,
    required this.kind,
    this.customBackground,
    required super.child,
  });
  final MarkdownSurfaceKind kind;
  // Opaque RGB of an explicit bubble background override. Actual opacity is
  // accounted for by kind; export fills must never inherit that opacity.
  final Color? customBackground;

  static MarkdownSurfaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarkdownSurfaceScope>();

  @override
  bool updateShouldNotify(MarkdownSurfaceScope oldWidget) =>
      kind != oldWidget.kind || customBackground != oldWidget.customBackground;
}
