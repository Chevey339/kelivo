import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Anchors the child's geometric center [center] pixels above the baseline.
/// WidgetSpan applies text scaling to both the box and this baseline once.
class OpticalBaseline extends SingleChildRenderObjectWidget {
  const OpticalBaseline({
    super.key,
    required this.center,
    required super.child,
  });
  final double center;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOpticalBaseline(center);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderOpticalBaseline renderObject,
  ) => renderObject.center = center;
}

class _RenderOpticalBaseline extends RenderProxyBox {
  _RenderOpticalBaseline(this._center);
  double _center;
  set center(double value) {
    if (value == _center) return;
    _center = value;
    markNeedsLayout();
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) =>
      size.height / 2 + _center;

  @override
  double computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => getDryLayout(constraints).height / 2 + _center;
}
