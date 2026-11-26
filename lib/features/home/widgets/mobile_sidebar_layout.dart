import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/sidebar_layout.dart';

class MobileSidebarLayout extends StatelessWidget {
  const MobileSidebarLayout({
    super.key,
    required this.layout,
    required this.blocks,
    required this.conversations,
    this.header,
    this.footer,
    this.fade,
  });

  final SidebarLayout layout;
  final Map<SidebarBlock, Widget> blocks;
  final Widget conversations;
  final Widget? header;
  final Widget? footer;
  final Widget? fade;

  @override
  Widget build(BuildContext context) {
    final top = <Widget>[if (header != null) header!];
    final bottom = <Widget>[];
    var hasTopBlocks = false;
    for (final block in layout.visibleOrder) {
      final child = blocks[block];
      if (child == null) continue;
      if (layout.isBelowConversations(block)) {
        bottom.add(child);
      } else {
        hasTopBlocks = true;
        top.add(child);
      }
    }
    if (footer != null) bottom.add(footer!);

    return CustomMultiChildLayout(
      delegate: _SidebarRegions(hasTopBlocks),
      children: [
        LayoutId(
          id: _Region.top,
          child: _FixedBlocks(children: top),
        ),
        LayoutId(
          id: _Region.list,
          child: Stack(
            fit: StackFit.expand,
            children: [
              conversations,
              if (fade != null && bottom.isNotEmpty)
                Positioned(left: 0, right: 0, bottom: 0, child: fade!),
            ],
          ),
        ),
        LayoutId(
          id: _Region.bottom,
          child: _FixedBlocks(reverse: true, children: bottom),
        ),
      ],
    );
  }
}

class _FixedBlocks extends StatelessWidget {
  const _FixedBlocks({required this.children, this.reverse = false});

  final List<Widget> children;
  final bool reverse;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    primary: false,
    reverse: reverse,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

enum _Region { top, list, bottom }

class _SidebarRegions extends MultiChildLayoutDelegate {
  _SidebarRegions(this.hasTopBlocks);

  final bool hasTopBlocks;

  @override
  void performLayout(Size size) {
    final fixedHeight = size.height - math.min(100.0, size.height / 3);
    final topReserve = hasTopBlocks ? math.min(100.0, fixedHeight / 2) : 0.0;
    final fixed = BoxConstraints.tightFor(width: size.width);
    final bottom = layoutChild(
      _Region.bottom,
      fixed.copyWith(maxHeight: fixedHeight - topReserve),
    );
    final top = layoutChild(
      _Region.top,
      fixed.copyWith(maxHeight: fixedHeight - bottom.height),
    );
    final listHeight = math.max(0.0, size.height - top.height - bottom.height);
    layoutChild(
      _Region.list,
      BoxConstraints.tightFor(width: size.width, height: listHeight),
    );
    positionChild(_Region.top, Offset.zero);
    positionChild(_Region.list, Offset(0, top.height));
    positionChild(_Region.bottom, Offset(0, size.height - bottom.height));
  }

  @override
  bool shouldRelayout(covariant _SidebarRegions oldDelegate) =>
      hasTopBlocks != oldDelegate.hasTopBlocks;
}
