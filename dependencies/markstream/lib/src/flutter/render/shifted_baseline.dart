import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Changes the inline anchor without moving content inside its selection box.
/// A positive shift raises the glyph relative to the surrounding text baseline.
class ShiftedBaseline extends SingleChildRenderObjectWidget {
  const ShiftedBaseline({super.key, required this.shift, required super.child});
  final double shift;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ShiftedBaseline(shift);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ShiftedBaseline renderObject,
  ) {
    renderObject.shift = shift;
  }
}

class _ShiftedBaseline extends RenderProxyBox {
  _ShiftedBaseline(this._shift);
  double _shift;
  set shift(double value) {
    if (_shift == value) return;
    _shift = value;
    markNeedsLayout();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final result = child?.getDistanceToActualBaseline(baseline);
    return result == null ? null : result + _shift;
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final result = child?.getDryBaseline(constraints, baseline);
    return result == null ? null : result + _shift;
  }
}
