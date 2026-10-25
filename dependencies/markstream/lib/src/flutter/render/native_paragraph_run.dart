import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import 'block_list.dart' show BlockList, ViewportClipParticipant, viewportClips;

/// Native RenderParagraphs share one element. This removes per-paragraph
/// widget mounting while retaining Flutter's layout, hit testing and selection.
class NativeParagraphRun extends LeafRenderObjectWidget {
  const NativeParagraphRun({
    super.key,
    required this.paragraphs,
    required this.spacing,
  });
  final List<RichText> paragraphs;
  final double spacing;
  double _devicePixelRatio(BuildContext context) =>
      MediaQuery.maybeDevicePixelRatioOf(context) ??
      View.maybeOf(context)?.devicePixelRatio ??
      1.0;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderParagraphRun(
    context,
    paragraphs,
    spacing,
    _devicePixelRatio(context),
    BlockList.cullingEnabled(context),
  );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderParagraphRun renderObject,
  ) => renderObject.update(
    context,
    paragraphs,
    spacing,
    _devicePixelRatio(context),
    BlockList.cullingEnabled(context),
  );
}

class _ParagraphParentData extends ContainerBoxParentData<RenderParagraph> {}

class _RenderParagraphRun extends RenderBox
    with
        ContainerRenderObjectMixin<RenderParagraph, _ParagraphParentData>,
        RenderBoxContainerDefaultsMixin<RenderParagraph, _ParagraphParentData>
    implements ViewportClipParticipant {
  _RenderParagraphRun(
    BuildContext context,
    List<RichText> paragraphs,
    double spacing,
    double ratio,
    bool cull,
  ) {
    update(context, paragraphs, spacing, ratio, cull);
  }
  List<RichText> _paragraphs = const [];
  double _spacing = 0, _ratio = 1;
  bool _cull = true, _painted = false;
  List<RenderParagraph> _paintedChildren = const [];
  List<RenderParagraph>? _semanticChildren;
  ({Rect? paint, Rect? semantics}) get _clips =>
      _cull ? viewportClips(this) : (paint: null, semantics: null);
  List<RenderParagraph> _near(Rect? clip) {
    final result = <RenderParagraph>[];
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (clip == null ||
          clip.overlaps(
            child.paintBounds.shift(
              (child.parentData! as _ParagraphParentData).offset,
            ),
          ))
        result.add(child);
    }
    return result;
  }

  @override
  void viewportChanged() {
    final clips = _clips;
    if (_painted && !listEquals(_paintedChildren, _near(clips.paint)))
      markNeedsPaint();
    final next = _near(clips.semantics);
    if (!listEquals(_semanticChildren, next)) {
      _semanticChildren = next;
      markNeedsSemanticsUpdate();
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      (_semanticChildren ??= _near(_clips.semantics)).forEach(visitor);
  void update(
    BuildContext context,
    List<RichText> paragraphs,
    double spacing,
    double ratio,
    bool cull,
  ) {
    if (_cull != cull) {
      _cull = cull;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
    var child = firstChild;
    for (var i = 0; i < paragraphs.length; i++) {
      final text = paragraphs[i];
      if (child == null) {
        _semanticChildren = null;
        // Let the host Flutter version supply all paragraph properties,
        // including device-pixel-ratio support where its renderer provides it.
        child = text.createRenderObject(context);
        add(child);
      } else if (i >= _paragraphs.length ||
          !identical(_paragraphs[i], text) ||
          _ratio != ratio) {
        text.updateRenderObject(context, child);
      }
      child = childAfter(child);
    }
    while (child != null) {
      _semanticChildren = null;
      final next = childAfter(child);
      remove(child);
      child.dispose();
      child = next;
    }
    if (_spacing != spacing) {
      _spacing = spacing;
      markNeedsLayout();
    }
    _paragraphs = paragraphs;
    _ratio = ratio;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ParagraphParentData)
      child.parentData = _ParagraphParentData();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.loosen().copyWith(maxHeight: double.infinity);
  @override
  void performLayout() {
    var width = 0.0, height = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(_childConstraints(constraints), parentUsesSize: true);
      (child.parentData! as _ParagraphParentData).offset = Offset(0, height);
      width = math.max(width, child.size.width);
      height += child.size.height;
      child = childAfter(child);
      if (child != null) height += _spacing;
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    var width = 0.0, height = 0.0;
    var child = firstChild;
    while (child != null) {
      final size = child.getDryLayout(_childConstraints(constraints));
      width = math.max(width, size.width);
      height += size.height;
      child = childAfter(child);
      if (child != null) height += _spacing;
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => firstChild?.getDryBaseline(_childConstraints(constraints), baseline);
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      firstChild?.getDistanceToActualBaseline(baseline);
  @override
  void paint(PaintingContext context, Offset offset) {
    _painted = true;
    _paintedChildren = _near(_clips.paint);
    for (final child in _paintedChildren)
      context.paintChild(
        child,
        offset + (child.parentData! as _ParagraphParentData).offset,
      );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
  @override
  void dispose() {
    while (firstChild != null) {
      final child = firstChild!;
      remove(child);
      child.dispose();
    }
    super.dispose();
  }
}
