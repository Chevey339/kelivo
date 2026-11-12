import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class BaselineFittedBox extends FittedBox {
  const BaselineFittedBox({required super.child})
    : super(fit: BoxFit.scaleDown);

  @override
  RenderFittedBox createRenderObject(BuildContext context) =>
      _RenderBaselineFittedBox();
}

class _RenderBaselineFittedBox extends RenderFittedBox {
  _RenderBaselineFittedBox() : super(fit: BoxFit.scaleDown);

  // RenderFittedBox forwards the unscaled baseline. Inline placeholders need
  // the painted baseline so a wide, scaled formula keeps the right line height.
  double? _scaledBaseline(Size childSize, Size boxSize, double? baseline) {
    if (baseline == null || childSize.isEmpty) return baseline;
    final fitted = applyBoxFit(BoxFit.scaleDown, childSize, boxSize);
    final scale = fitted.destination.height / childSize.height;
    return (boxSize.height - fitted.destination.height) / 2 + baseline * scale;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child == null
      ? null
      : _scaledBaseline(
          child!.size,
          size,
          child!.getDistanceToActualBaseline(baseline),
        );

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final childBaseline = child?.getDryBaseline(
      const BoxConstraints(),
      baseline,
    );
    if (childBaseline == null) return null;
    return _scaledBaseline(
      child!.getDryLayout(const BoxConstraints()),
      getDryLayout(constraints),
      childBaseline,
    );
  }
}
