import 'package:flutter/material.dart';

/// A settings label and control that stack without replacing the focused
/// control's element when the window is resized.
class DesktopLabeledControl extends StatelessWidget {
  const DesktopLabeledControl({
    super.key,
    required this.label,
    required this.control,
    this.controlWidth = 280,
  });

  final Widget label;
  final Widget control;
  final double controlWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < controlWidth + 180;
      return Flex(
        direction: compact ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Flexible(fit: compact ? FlexFit.loose : FlexFit.tight, child: label),
          SizedBox(width: compact ? 0 : 12, height: compact ? 8 : 0),
          Flexible(
            flex: compact ? 1 : 0,
            fit: FlexFit.loose,
            child: SizedBox(
              width: compact ? constraints.maxWidth : controlWidth,
              child: Align(alignment: Alignment.centerRight, child: control),
            ),
          ),
        ],
      );
    },
  );
}
