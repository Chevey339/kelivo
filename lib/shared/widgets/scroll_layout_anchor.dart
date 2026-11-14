import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

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
      SliverMultiBoxAdaptorElement? indexedList;
      context.visitAncestorElements((element) {
        if (element.widget is SuperSliverList) {
          final list =
              element.findRenderObject() as RenderSliverMultiBoxAdaptor;
          if (RenderAbstractViewport.maybeOf(list) == node) {
            indexedList = element as SliverMultiBoxAdaptorElement;
            return false;
          }
        }
        return true;
      });
      position.preserveViewportAnchor(node, indexedList: indexedList);
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

  void preserveViewportAnchor(
    RenderViewport viewport, {
    SliverMultiBoxAdaptorElement? indexedList,
  }) {
    if (_readingAnchor != null ||
        _laidOutPixels == null ||
        !hasContentDimensions ||
        outOfRange ||
        axisDirection != AxisDirection.down ||
        !viewport.attached ||
        !viewport.hasSize) {
      return;
    }
    // Prefer the leading visible text. Sparse points can all fall in paragraph
    // gaps, choosing text below the loading image and pulling earlier text out
    // of view. Probe line-sized intervals only for this asynchronous update.
    _ReadingAnchor? imageAnchor;
    for (var y = 8.0; y < viewport.size.height; y += 16) {
      for (final x in [.5, .25, .75, .1, .9]) {
        final hit = BoxHitTestResult();
        viewport.hitTest(hit, position: Offset(viewport.size.width * x, y));
        for (final entry in hit.path) {
          final target = entry.target;
          if (entry is! BoxHitTestEntry ||
              (target is! RenderParagraph && target is! RenderImage)) {
            continue;
          }
          if (target is RenderImage && imageAnchor != null) continue;
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
            row: _ReadingRow.capture(box, point, indexedList),
          );
          if (box is RenderImage) {
            imageAnchor ??= anchor;
            continue;
          }
          _setReadingAnchor(anchor);
          return;
        }
      }
    }
    if (imageAnchor != null) _setReadingAnchor(imageAnchor);
  }

  void _setReadingAnchor(_ReadingAnchor anchor) {
    _readingAnchor = anchor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_readingAnchor, anchor)) _readingAnchor = null;
    });
  }

  /// Returns false when the viewport must lay out again before painting.
  bool applyScrollLayoutAnchor() {
    final anchor = _readingAnchor;
    if (anchor != null && !outOfRange) {
      // Wheel/drag input still moves the reader. Existing sliver and nested
      // block corrections must not be mistaken for additional user movement.
      final userDelta =
          pixels - anchor.pixels - (_layoutCorrection - anchor.correction);
      final expected = anchor.offset - userDelta;
      // A small downward wheel movement may take the leading reading point
      // just above the viewport. Still compensate its layout shift; only
      // navigation or a movement exceeding a viewport abandons this anchor.
      if (userDelta.abs() <= anchor.viewport.size.height) {
        final offset = anchor.scrollOffset(pixels);
        if (offset != null) {
          final target = (offset - expected).clamp(
            minScrollExtent,
            maxScrollExtent,
          );
          if (target.isFinite && (target - pixels).abs() >= .5) {
            correctBy(target - pixels);
            return false;
          }
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
    required this.row,
  });

  final RenderViewport viewport;
  final RenderBox box;
  final Offset point;
  final TextPosition? textPosition;
  final double offset, pixels, correction;
  final _ReadingRow? row;

  double? scrollOffset(double pixels) {
    final row = this.row;
    if (row != null) {
      if (!row.parent.attached ||
          !row.element.mounted ||
          row.element.childCount != row.childCount ||
          !viewport.attached ||
          !row.updateIndex()) {
        return null;
      }
      // Use the extent index even if this layout recycled the reading row.
      // Querying with a size snapshot is safe during viewport layout; asking
      // getOffsetToReveal for a live descendant would read its size outside
      // the parent's layout contract.
      final point = isAttached
          ? box.localToGlobal(currentPoint, ancestor: row.box)
          : row.point;
      return viewport
          .getOffsetToRevealExt(
            row,
            0,
            rect: point & Size.zero,
            esimationOnly: true,
          )
          .offset;
    }
    if (!isAttached) return null;
    return pixels + box.localToGlobal(currentPoint, ancestor: viewport).dy;
  }

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

/// A layout-only target for SuperSliverList's indexed offset query, including
/// rows removed from its cache area by the image's new height.
class _ReadingRow extends RenderBox {
  _ReadingRow({
    required this.parent,
    required this.element,
    required this.box,
    required this.point,
    required this.size,
    required this.childCount,
    required this.childKey,
    required this.delegate,
    required int index,
  }) {
    parentData = SliverMultiBoxAdaptorParentData()..index = index;
  }

  @override
  final RenderSliverMultiBoxAdaptor parent;
  final SliverMultiBoxAdaptorElement element;
  final RenderBox box;
  final Offset point;
  final int childCount;
  final Key? childKey;
  final SliverChildDelegate delegate;
  @override
  final Size size;

  bool updateIndex() {
    final current = (element.widget as SliverMultiBoxAdaptorWidget).delegate;
    final key = childKey;
    final index = key == null ? null : current.findIndexByKey(key);
    if (index == null) {
      // Without a key mapping, only the original delegate can vouch for the
      // captured index. Equal-length history windows can still change rows.
      return identical(current, delegate);
    }
    if (index < 0 || index >= element.childCount) return false;
    (parentData as SliverMultiBoxAdaptorParentData).index = index;
    return true;
  }

  static _ReadingRow? capture(
    RenderBox box,
    Offset point,
    SliverMultiBoxAdaptorElement? element,
  ) {
    if (element == null) return null;
    final list = element.renderObject;
    RenderObject? node = box;
    while (node != null && node.parent != list) {
      node = node.parent;
    }
    if (node is! RenderBox) return null;
    final data = node.parentData as SliverMultiBoxAdaptorParentData;
    Key? childKey;
    element.visitChildren((child) {
      if (identical(child.findRenderObject(), node)) {
        childKey = child.widget.key;
      }
    });
    return _ReadingRow(
      parent: list,
      element: element,
      box: node,
      point: box.localToGlobal(point, ancestor: node),
      size: node.size,
      childCount: element.childCount,
      childKey: childKey,
      delegate: (element.widget as SliverMultiBoxAdaptorWidget).delegate,
      index: data.index!,
    );
  }

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) => Matrix4.identity();
}
