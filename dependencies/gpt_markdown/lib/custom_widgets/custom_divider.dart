import 'package:flutter/material.dart';

/// A custom divider widget that extends LeafRenderObjectWidget.
///
/// The [CustomDivider] widget is used to create a horizontal divider line in the UI.
/// It takes an optional [color] parameter to specify the color of the divider,
/// an optional [height] parameter to set the height of the divider,
/// and optional [padding] around the line (default [EdgeInsets.zero]).
///
class CustomDivider extends LeafRenderObjectWidget {
  const CustomDivider({
    super.key,
    this.height,
    this.color,
    this.padding = EdgeInsets.zero,
  });

  /// The color of the divider.
  ///
  /// If not provided, the divider will use the color of the current theme.
  final Color? color;

  /// The height of the divider.
  ///
  /// If not provided, the divider will have a default height of 2.
  final double? height;

  /// Insets around the divider line. The painted line sits inside this padding.
  final EdgeInsets padding;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDivider(
      color ?? Theme.of(context).colorScheme.outline,
      MediaQuery.sizeOf(context).width,
      height ?? 2,
      padding,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderDivider renderObject,
  ) {
    renderObject.color = color ?? Theme.of(context).colorScheme.outline;
    renderObject.height = height ?? 2;
    renderObject.width = MediaQuery.sizeOf(context).width;
    renderObject.padding = padding;
  }
}

/// A custom render object for the [CustomDivider] widget.
///
/// The [RenderDivider] class extends RenderBox and is responsible for
/// painting the divider line. It takes a [color], [width], and [height]
/// and uses them to draw a horizontal line in the UI.
///
class RenderDivider extends RenderBox {
  RenderDivider(Color color, double width, double height, EdgeInsets padding)
    : _color = color,
      _height = height,
      _width = width,
      _padding = padding;
  Color _color;
  double _height;
  double _width;
  EdgeInsets _padding;

  /// The color of the divider.
  set color(Color value) {
    if (value == _color) {
      return;
    }
    _color = value;
    markNeedsPaint();
  }

  /// The height of the divider.
  set height(double value) {
    if (value == _height) {
      return;
    }
    _height = value;
    markNeedsLayout();
  }

  /// The width of the divider.
  set width(double value) {
    if (value == _width) {
      return;
    }
    _width = value;
    markNeedsLayout();
  }

  /// Insets around the divider line.
  set padding(EdgeInsets value) {
    if (value == _padding) {
      return;
    }
    _padding = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final double w = constraints.constrainWidth(
      constraints.hasBoundedWidth ? constraints.maxWidth : _width,
    );
    final double h = constraints.constrainHeight(_padding.vertical + _height);
    return Size(w, h);
  }

  @override
  void performLayout() {
    size = getDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final double lineWidth = size.width - _padding.horizontal;
    if (lineWidth <= 0 || _height <= 0) {
      return;
    }
    final Rect rect = Rect.fromLTWH(
      offset.dx + _padding.left,
      offset.dy + _padding.top,
      lineWidth,
      _height,
    );
    context.canvas.drawRect(rect, Paint()..color = _color);
  }
}
