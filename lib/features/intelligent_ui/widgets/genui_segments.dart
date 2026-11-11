import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'genui_theme.dart';

/// Compact painted segments with independent, full-sized touch targets.
/// Focus/keyboard traversal belongs to the enclosing field or view selector.
class GenUiSegments extends StatelessWidget {
  const GenUiSegments({
    super.key,
    required this.labels,
    required this.index,
    required this.enabled,
    required this.onChanged,
    this.expand = false,
    this.radioGroup = false,
    this.focused = false,
    this.visualEnabled = true,
  });
  final List<String> labels;
  final int index;
  final bool enabled, expand, radioGroup, focused, visualEnabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final style = radioGroup ? theme.fieldLabel : theme.label;
    final visualHeight = math.max(
      radioGroup ? 36.0 : 28.0,
      MediaQuery.textScalerOf(context).scale(style.fontSize!) *
              (style.height ?? 1.3) +
          10,
    );
    final touchHeight = math.max(
      ResponsiveHelper.isDesktop(context) ? 32.0 : 44.0,
      visualHeight,
    );
    final inset = (touchHeight - visualHeight) / 2;
    final radius = BorderRadius.circular(theme.controlRadius);
    Widget segment(int i) => Semantics(
      label: labels[i],
      button: !radioGroup,
      selected: radioGroup ? null : i == index,
      checked: radioGroup ? i == index : null,
      inMutuallyExclusiveGroup: radioGroup,
      enabled: enabled,
      onTap: enabled ? () => onChanged(i) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(i) : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: EdgeInsets.symmetric(vertical: inset + 3),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(
                horizontal: radioGroup ? theme.sm : theme.xs,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == index ? theme.card : theme.transparent,
                borderRadius: BorderRadius.circular(theme.controlRadius - 3),
                border: Border.all(
                  color: i == index ? theme.hairline : theme.transparent,
                ),
              ),
              child: Text(
                labels[i],
                style: style.copyWith(
                  color: !visualEnabled
                      ? theme.disabledInk
                      : i == index
                      ? theme.primary
                      : theme.secondaryInk,
                  fontWeight: i == index ? theme.header.fontWeight : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          top: inset,
          bottom: inset,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.fill,
              borderRadius: radius,
              border: Border.all(
                color: focused ? theme.primary : theme.transparent,
                width: 2,
              ),
            ),
          ),
        ),
        SizedBox(
          height: touchHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                for (var i = 0; i < labels.length; i++)
                  if (expand) Expanded(child: segment(i)) else segment(i),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
