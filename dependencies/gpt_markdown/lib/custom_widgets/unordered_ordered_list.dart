import 'package:flutter/material.dart';

/// A custom widget that displays an unordered list of items.
///
/// The [UnorderedListView] widget is used to create a list of items with bullet points.
/// It takes a [child] parameter which is the content of the list item,
/// a [spacing] parameter to set the spacing between items,
/// a [padding] parameter to set the padding of the list item,
class UnorderedListView extends StatelessWidget {
  const UnorderedListView({
    super.key,
    this.spacing = 8,
    this.padding = 12,
    this.bulletColor,
    this.bulletSize = 4,
    this.textDirection = TextDirection.ltr,
    required this.child,
  });

  /// The size of the bullet point.
  final double bulletSize;

  /// The spacing between items.
  final double spacing;

  /// The padding of the list item.
  final double padding;
  final TextDirection textDirection;

  /// The color of the bullet point.
  final Color? bulletColor;

  /// The child widget to be displayed in the list item.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textBaseline: TextBaseline.alphabetic,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          if (bulletSize == 0)
            SizedBox(width: spacing + padding)
          else
            Text.rich(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: padding,
                    end: spacing,
                  ),
                  child: Container(
                    width: bulletSize,
                    height: bulletSize,
                    decoration: BoxDecoration(
                      color: bulletColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// A custom widget that displays an ordered list of items.
///
/// The [OrderedListView] widget is used to create a list of items with numbered points.
/// It takes a [child] parameter which is the content of the list item,
/// a [spacing] parameter to set the spacing between items,
/// a [padding] parameter to set the padding of the list item,
class OrderedListView extends StatelessWidget {
  final String no;
  final double spacing;
  final double padding;
  const OrderedListView({
    super.key,
    this.spacing = 6,
    this.padding = 6,
    TextStyle? style,
    required this.child,
    this.textDirection = TextDirection.ltr,
    required this.no,
  }) : _style = style;

  /// The style of the text.
  final TextStyle? _style;

  /// The direction of the text.
  final TextDirection textDirection;

  /// The child widget to be displayed in the list item.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textBaseline: TextBaseline.alphabetic,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(start: padding, end: spacing),
            child: Text.rich(TextSpan(text: no), style: _style),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
