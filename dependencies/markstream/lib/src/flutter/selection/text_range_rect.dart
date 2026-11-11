import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keeps an inline atom's logical length available without a SelectionArea.
class TextRangeAtom extends SingleChildRenderObjectWidget {
  const TextRangeAtom({super.key, required this.length, required super.child});
  final int length;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTextRangeAtom(length);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderTextRangeAtom object,
  ) => object.length = length;
}

class _RenderTextRangeAtom extends RenderProxyBox {
  _RenderTextRangeAtom(this.length);
  int length;
}

/// Reveal an inner code/table viewport before its enclosing document scrolls.
bool revealRectInScrollables(
  Rect rect, {
  required BuildContext context,
  required BuildContext boundary,
}) {
  var ready = true;
  context.visitAncestorElements((element) {
    if (element == boundary) return false;
    if (element is! StatefulElement || element.state is! ScrollableState)
      return true;
    final scrollable = element.state as ScrollableState;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return true;
    final position = scrollable.position;
    final viewport = box.localToGlobal(Offset.zero) & box.size;
    final delta = position.axis == Axis.vertical
        ? rect.center.dy - viewport.center.dy
        : rect.center.dx - viewport.center.dx;
    final reversed =
        position.axisDirection == AxisDirection.up ||
        position.axisDirection == AxisDirection.left;
    final target = (position.pixels + (reversed ? -delta : delta)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() > .5) {
      position.jumpTo(target);
      ready = false;
    }
    return true;
  });
  return ready;
}

/// Geometry of the first visible glyph in a logical selectable-text range.
/// Inline widgets contribute their selectable text, rather than U+FFFC, and
/// native paragraph batches and long-text chunks retain their reading order.
Rect? textRangeRect(RenderObject root, TextRange range) {
  if (!root.attached || range.isCollapsed || !range.isValid) return null;
  var offset = 0;
  Rect? result;

  void visit(RenderObject object) {
    if (result != null || !object.attached) return;
    if (object is RenderBox && !object.hasSize) return;
    if (object is RenderBox &&
        (object is Selectable || object is _RenderTextRangeAtom)) {
      final length = object is _RenderTextRangeAtom
          ? object.length
          : (object as Selectable).contentLength;
      if (range.start < offset + length && range.end > offset) {
        result = MatrixUtils.transformRect(
          object.getTransformTo(null),
          object.paintBounds,
        );
      }
      offset += length;
      return;
    }
    if (object is RenderParagraph) {
      final children = <RenderObject>[];
      object.visitChildren(children.add);
      var childIndex = 0;
      var glyphOffset = 0;
      void span(InlineSpan value) {
        if (result != null) return;
        if (value is TextSpan) {
          final length = value.text?.length ?? 0;
          if (range.start < offset + length && range.end > offset) {
            final start = (range.start - offset).clamp(0, length);
            final end = (range.end - offset).clamp(start, length);
            final boxes = object.getBoxesForSelection(
              TextSelection(
                baseOffset: glyphOffset + start,
                extentOffset: glyphOffset + end,
              ),
            );
            if (boxes.isNotEmpty) {
              result = MatrixUtils.transformRect(
                object.getTransformTo(null),
                boxes.first.toRect(),
              );
            }
          }
          offset += length;
          glyphOffset += length;
          for (final child in value.children ?? const <InlineSpan>[]) {
            span(child);
          }
        } else if (value is PlaceholderSpan) {
          if (childIndex < children.length) visit(children[childIndex++]);
          glyphOffset++;
        }
      }

      span(object.text);
      return;
    }
    object.visitChildren(visit);
  }

  visit(root);
  return result;
}
