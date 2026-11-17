import 'package:flutter/widgets.dart';

enum MarkdownSurfaceKind { frosted, solid, tinted }

/// Describes the existing message surface without adding a render object.
class MarkdownSurfaceScope extends InheritedWidget {
  const MarkdownSurfaceScope({
    super.key,
    required this.kind,
    this.backgroundColor,
    this.hasCustomBackground = false,
    required super.child,
  }) : assert(!hasCustomBackground || backgroundColor != null);
  final MarkdownSurfaceKind kind;

  /// The tint painted behind the Markdown, including bubble opacity.
  final Color? backgroundColor;
  final bool hasCustomBackground;

  static MarkdownSurfaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarkdownSurfaceScope>();

  @override
  bool updateShouldNotify(MarkdownSurfaceScope oldWidget) =>
      kind != oldWidget.kind ||
      backgroundColor != oldWidget.backgroundColor ||
      hasCustomBackground != oldWidget.hasCustomBackground;
}
