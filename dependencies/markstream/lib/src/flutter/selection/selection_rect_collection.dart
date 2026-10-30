import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keeps rectangle order independent of the direction of the selection edges.
mixin SelectionRectCollection on MultiSelectableSelectionContainerDelegate {
  @override
  SelectionGeometry getSelectionGeometry() {
    final geometry = super.getSelectionGeometry();
    // Flutter collects rectangles only when the start child precedes the end
    // child. Preserve its edge geometry, but also collect a reversed range.
    if (currentSelectionEndIndex < 0 ||
        currentSelectionStartIndex <= currentSelectionEndIndex) {
      return geometry;
    }
    final drawable = hasSize ? Offset.zero & containerSize : null;
    final rects = <Rect>[];
    for (
      var index = currentSelectionEndIndex;
      index <= currentSelectionStartIndex;
      index++
    ) {
      final child = selectables[index];
      final childRects = child.value.selectionRects;
      if (childRects.isEmpty) continue;
      final transform = getTransformFrom(child);
      for (final rect in childRects) {
        final local = MatrixUtils.transformRect(transform, rect);
        final clipped = drawable?.intersect(local) ?? local;
        if (clipped.isFinite && !clipped.isEmpty) rects.add(clipped);
      }
    }
    return SelectionGeometry(
      startSelectionPoint: geometry.startSelectionPoint,
      endSelectionPoint: geometry.endSelectionPoint,
      selectionRects: rects,
      status: geometry.status,
      hasContent: geometry.hasContent,
    );
  }
}
