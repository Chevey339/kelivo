import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single row of selection actions, bounded by the unobscured viewport.
class AndroidTextSelectionToolbar extends StatelessWidget {
  const AndroidTextSelectionToolbar({
    super.key,
    required this.anchors,
    required this.buttonItems,
    this.trailing,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (buttonItems.isEmpty && trailing == null) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final padding = EdgeInsets.fromLTRB(
      math.max(media.viewPadding.left, media.viewInsets.left) + 8,
      math.max(media.viewPadding.top, media.viewInsets.top) + 8,
      math.max(media.viewPadding.right, media.viewInsets.right) + 8,
      math.max(media.viewPadding.bottom, media.viewInsets.bottom) + 8,
    );
    final origin = Offset(padding.left, padding.top);
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
            return const SizedBox.shrink();
          }
          return CustomSingleChildLayout(
            delegate: _ToolbarLayout(
              anchorAbove: anchors.primaryAnchor - origin - const Offset(0, 8),
              anchorBelow:
                  (anchors.secondaryAnchor ?? anchors.primaryAnchor) -
                  origin +
                  const Offset(
                    0,
                    TextSelectionToolbar.kToolbarContentDistanceBelow,
                  ),
            ),
            child: Material(
              elevation: 1,
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < buttonItems.length; index++)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: TextSelectionToolbarTextButton(
                          padding: TextSelectionToolbarTextButton.getPadding(
                            index,
                            buttonItems.length + (trailing == null ? 0 : 1),
                          ),
                          onPressed: buttonItems[index].onPressed,
                          child: Text(
                            AdaptiveTextSelectionToolbar.getButtonLabel(
                              context,
                              buttonItems[index],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToolbarLayout extends TextSelectionToolbarLayoutDelegate {
  _ToolbarLayout({required super.anchorAbove, required super.anchorBelow});

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final position = super.getPositionForChild(size, childSize);
    return Offset(
      position.dx.clamp(0, math.max(0, size.width - childSize.width)),
      position.dy.clamp(0, math.max(0, size.height - childSize.height)),
    );
  }
}
