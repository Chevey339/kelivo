import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Retain the content being read when an asynchronous image changes size.
/// This is deliberately requested before the update, while hit testing still
/// describes the painted frame. No render-tree scanning runs during scrolling.
void preserveScrollLayoutAnchor(BuildContext context) {
  final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
  if (position is! ScrollLayoutAnchor) return;
  // Table cells can contain a horizontal scrollable. Resolve the viewport
  // owned by the vertical history position, rather than the nearest viewport.
  RenderObject? node = context.findRenderObject();
  while (node != null) {
    if (node is RenderViewport && identical(node.offset, position)) {
      position.preserveViewportAnchor(node);
      return;
    }
    node = node.parent;
  }
}

/// Layout-time anchoring for a scroll position. The owner calls
/// [applyScrollLayoutAnchor] after applying dimensions, unless an explicit
/// navigation or bottom-follow request owns that layout.
mixin ScrollLayoutAnchor on ScrollPosition {
  _ReadingAnchor? _readingAnchor;
  double _layoutCorrection = 0;
  double? _laidOutPixels;
  double _laidOutCorrection = 0;

  @override
  void correctBy(double correction) {
    _layoutCorrection += correction;
    super.correctBy(correction);
  }

  @override
  void correctPixels(double value) {
    if (hasPixels) _layoutCorrection += value - pixels;
    super.correctPixels(value);
  }

  void clearScrollLayoutAnchor() => _readingAnchor = null;

  void preserveViewportAnchor(RenderViewport viewport) {
    if (_readingAnchor != null ||
        _laidOutPixels == null ||
        !hasContentDimensions ||
        outOfRange ||
        axisDirection != AxisDirection.down ||
        !viewport.attached ||
        !viewport.hasSize) {
      return;
    }
    // Try the center first; nearby points also cover paragraph margins and
    // spaces between blocks. Hit testing excludes clipped and kept-alive rows.
    for (final y in [.5, .35, .65]) {
      for (final x in [.5, .25, .75]) {
        final hit = BoxHitTestResult();
        viewport.hitTest(
          hit,
          position: Offset(viewport.size.width * x, viewport.size.height * y),
        );
        for (final entry in hit.path) {
          final target = entry.target;
          if (entry is! BoxHitTestEntry ||
              (target is! RenderParagraph && target is! RenderImage)) {
            continue;
          }
          final box = target as RenderBox;
          final textPosition = box is RenderParagraph
              ? box.getPositionForOffset(entry.localPosition)
              : null;
          final point = textPosition != null
              ? (box as RenderParagraph).getOffsetForCaret(
                  textPosition,
                  Rect.zero,
                )
              : entry.localPosition;
          final offset = box.localToGlobal(point, ancestor: viewport).dy;
          if (!offset.isFinite || offset < 0 || offset > viewport.size.height) {
            continue;
          }
          final anchor = _ReadingAnchor(
            viewport: viewport,
            box: box,
            point: point,
            textPosition: textPosition,
            offset: offset,
            pixels: _laidOutPixels!,
            correction: _laidOutCorrection,
          );
          _readingAnchor = anchor;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (identical(_readingAnchor, anchor)) _readingAnchor = null;
          });
          return;
        }
      }
    }
  }

  /// Returns false when the viewport must lay out again before painting.
  bool applyScrollLayoutAnchor() {
    final anchor = _readingAnchor;
    if (anchor != null && anchor.isAttached && !outOfRange) {
      // Wheel/drag input still moves the reader. Existing sliver and nested
      // block corrections must not be mistaken for additional user movement.
      final userDelta =
          pixels - anchor.pixels - (_layoutCorrection - anchor.correction);
      final expected = anchor.offset - userDelta;
      if (expected >= 0 && expected <= anchor.viewport.size.height) {
        final actual = anchor.box
            .localToGlobal(anchor.currentPoint, ancestor: anchor.viewport)
            .dy;
        final target = (pixels + actual - expected).clamp(
          minScrollExtent,
          maxScrollExtent,
        );
        if (target.isFinite && (target - pixels).abs() >= .5) {
          correctBy(target - pixels);
          return false;
        }
      } else {
        // A navigation or large wheel movement left the captured content.
        clearScrollLayoutAnchor();
      }
    }
    _laidOutPixels = pixels;
    _laidOutCorrection = _layoutCorrection;
    return true;
  }
}

class _ReadingAnchor {
  const _ReadingAnchor({
    required this.viewport,
    required this.box,
    required this.point,
    required this.textPosition,
    required this.offset,
    required this.pixels,
    required this.correction,
  });

  final RenderBox viewport, box;
  final Offset point;
  final TextPosition? textPosition;
  final double offset, pixels, correction;

  bool get isAttached {
    if (!box.attached || !viewport.attached) return false;
    RenderObject? node = box;
    while (node != null && node != viewport) {
      if (node is RenderOffstage && node.offstage) return false;
      final data = node.parentData;
      if (data is SliverMultiBoxAdaptorParentData && data.keptAlive) {
        return false;
      }
      node = node.parent;
    }
    return node == viewport;
  }

  Offset get currentPoint => textPosition != null
      ? (box as RenderParagraph).getOffsetForCaret(textPosition!, Rect.zero)
      : point;
}
