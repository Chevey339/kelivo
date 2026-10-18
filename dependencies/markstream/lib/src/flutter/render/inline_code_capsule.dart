import 'package:flutter/widgets.dart';

import '../selection/selectable_span_adapter.dart';

/// An inline code atom that joins its enclosing paragraph's selection chain.
/// Use it in a baseline-aligned WidgetSpan inside buildSelectableText.
class InlineCodeCapsule extends StatelessWidget {
  const InlineCodeCapsule({
    super.key,
    required this.text,
    required this.style,
    required this.backgroundColor,
    required this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.radius = 6,
    this.mouseCursor = SystemMouseCursors.text,
  });

  final String text;
  final TextStyle style;
  final Color backgroundColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final double radius;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) => SelectableSpanAdapter(
    selectedText: text,
    mouseCursor: mouseCursor,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: padding,
        child: Text(text, style: style),
      ),
    ),
  );
}
