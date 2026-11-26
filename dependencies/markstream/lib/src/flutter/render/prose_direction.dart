import 'package:flutter/widgets.dart';

/// A loose, start-aligned Markdown column would otherwise place a short RTL
/// block on the left even if its glyphs were shaped in the correct direction.
Widget directionalBlock(
  BuildContext context,
  TextDirection? direction,
  Widget child, {
  bool align = true,
}) {
  final ambient = Directionality.of(context);
  final resolved = direction ?? ambient;
  if (align && (resolved == TextDirection.rtl || resolved != ambient)) {
    final content = child;
    child = Builder(
      builder: (context) {
        final alignment = switch (DefaultTextStyle.of(context).textAlign) {
          TextAlign.center => Alignment.topCenter,
          TextAlign.right => Alignment.topRight,
          TextAlign.left => Alignment.topLeft,
          TextAlign.end => AlignmentDirectional.topEnd,
          _ => AlignmentDirectional.topStart,
        };
        return Align(alignment: alignment, widthFactor: 1, child: content);
      },
    );
  }
  return resolved == ambient
      ? child
      : Directionality(textDirection: resolved, child: child);
}

/// Directional columns stretch their children once the document has a known
/// width. During measurement every child reports its content width.
class ProseWidthScope extends InheritedWidget {
  const ProseWidthScope({required this.enabled, required super.child});
  final bool enabled;
  static bool isDirectional(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProseWidthScope>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(ProseWidthScope oldWidget) =>
      enabled != oldWidget.enabled;
}

Widget proseColumn({required List<Widget> children, double spacing = 0}) {
  Widget column(CrossAxisAlignment alignment) => Column(
    spacing: spacing,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: alignment,
    children: children,
  );
  return LayoutBuilder(
    builder: (context, constraints) => column(
      constraints.hasTightWidth && ProseWidthScope.isDirectional(context)
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
    ),
  );
}
