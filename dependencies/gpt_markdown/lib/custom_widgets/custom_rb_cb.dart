import 'package:flutter/material.dart';

/// A custom radio button widget that extends StatelessWidget.
class CustomRb extends StatelessWidget {
  const CustomRb({
    super.key,
    this.spacing = 5,
    required this.child,
    this.textDirection = TextDirection.ltr,
    required this.value,
  });
  final Widget child;
  final bool value;
  final double spacing;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textBaseline: TextBaseline.alphabetic,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          Text.rich(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing,
                  end: spacing,
                ),
                child: RadioGroup(
                  groupValue: true,
                  onChanged: (v) {},
                  child: Radio<bool>(
                    value: value,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// A custom checkbox widget that extends StatelessWidget.
class CustomCb extends StatelessWidget {
  const CustomCb({
    super.key,
    this.spacing = 5,
    required this.child,
    this.textDirection = TextDirection.ltr,
    required this.value,
  });
  final Widget child;
  final bool value;
  final double spacing;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textBaseline: TextBaseline.alphabetic,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          Text.rich(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing,
                  end: spacing,
                ),
                child: Checkbox(value: value, onChanged: (value) {}),
              ),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
