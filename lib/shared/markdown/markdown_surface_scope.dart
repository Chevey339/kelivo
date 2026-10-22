import 'package:flutter/widgets.dart';

enum MarkdownSurfaceKind { frosted, solid, tinted }

/// Describes the existing message surface without adding a render object.
class MarkdownSurfaceScope extends InheritedWidget {
  const MarkdownSurfaceScope({
    super.key,
    required this.kind,
    required super.child,
  });
  final MarkdownSurfaceKind kind;

  static MarkdownSurfaceKind? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarkdownSurfaceScope>()?.kind;

  @override
  bool updateShouldNotify(MarkdownSurfaceScope oldWidget) =>
      kind != oldWidget.kind;
}
