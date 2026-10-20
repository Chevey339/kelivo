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
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    this.border,
    this.radius = 6,
    this.mouseCursor = SystemMouseCursors.text,
  });

  final String text;
  final TextStyle style;
  final Color backgroundColor;
  final Color borderColor;
  final Border? border;
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
        border:
            border ??
            (borderColor.a == 0 ? null : Border.all(color: borderColor)),
        borderRadius: switch (radius) {
          6 => const BorderRadius.all(Radius.circular(6)),
          4 => const BorderRadius.all(Radius.circular(4)),
          _ => BorderRadius.circular(radius),
        },
      ),
      child: Padding(
        padding: padding,
        child: Text(
          text,
          style: style,
          textHeightBehavior: const TextHeightBehavior(
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    ),
  );
}
