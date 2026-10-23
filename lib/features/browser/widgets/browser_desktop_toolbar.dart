import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact address row below the tabs. Window controls belong to the tab row,
/// so an embedded browser uses exactly the same horizontal address geometry.
class BrowserDesktopToolbar extends StatelessWidget {
  const BrowserDesktopToolbar({
    super.key,
    required this.navigation,
    required this.addressBar,
    required this.actions,
    this.compactNavigation,
    this.compactActions,
  });

  final Widget navigation;
  final Widget addressBar;
  final Widget actions;
  final Widget? compactNavigation;
  final Widget? compactActions;

  static const double height = 40;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 650;
      return SizedBox(
        key: const ValueKey('browserDesktopToolbar'),
        height: height,
        child: CustomMultiChildLayout(
          delegate: _ToolbarLayout(),
          children: [
            LayoutId(
              id: _ToolbarSlot.navigation,
              child: compact ? compactNavigation ?? navigation : navigation,
            ),
            LayoutId(id: _ToolbarSlot.address, child: addressBar),
            LayoutId(
              id: _ToolbarSlot.actions,
              child: compact ? compactActions ?? actions : actions,
            ),
          ],
        ),
      );
    },
  );
}

/// Commands share the header's material rather than each adding another native
/// backdrop surface. Individual controls keep their own hover/focus feedback.
class BrowserDesktopControlGroup extends StatelessWidget {
  const BrowserDesktopControlGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: children);
}

enum _ToolbarSlot { navigation, address, actions }

class _ToolbarLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    const edge = 10.0;
    const gap = 8.0;
    final groupSpace = math.max(0.0, (size.width - edge * 2 - gap * 2) / 2);
    final groupConstraints = BoxConstraints(
      maxWidth: groupSpace,
      maxHeight: 36,
    );
    final navigation = layoutChild(_ToolbarSlot.navigation, groupConstraints);
    final actions = layoutChild(_ToolbarSlot.actions, groupConstraints);
    positionChild(
      _ToolbarSlot.navigation,
      Offset(edge, (size.height - navigation.height) / 2),
    );
    positionChild(
      _ToolbarSlot.actions,
      Offset(
        size.width - edge - actions.width,
        (size.height - actions.height) / 2,
      ),
    );
    final available = math.max(
      0.0,
      size.width - edge * 2 - gap * 2 - navigation.width - actions.width,
    );
    final width = math.min(640.0, available);
    final address = layoutChild(
      _ToolbarSlot.address,
      BoxConstraints.tightFor(width: width, height: 32),
    );
    positionChild(
      _ToolbarSlot.address,
      Offset(
        edge + navigation.width + gap + (available - width) / 2,
        (size.height - address.height) / 2,
      ),
    );
  }

  @override
  bool shouldRelayout(_ToolbarLayout oldDelegate) => false;
}
