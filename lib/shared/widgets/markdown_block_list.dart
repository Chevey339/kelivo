import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'incremental_markdown_document.dart';
import 'export_capture_scope.dart';

/// Retains completed Markdown subtrees. An append rebuilds and lays out only
/// the changed leaf and its ancestors, rather than every previous paragraph.
/// All blocks remain mounted for selection, search and interactive state.
class MarkdownBlockList extends StatefulWidget {
  const MarkdownBlockList({
    super.key,
    required this.blocks,
    required this.signature,
    required this.itemBuilder,
  });

  final List<IncrementalMarkdownBlock> blocks;
  final Object signature;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<MarkdownBlockList> createState() => _MarkdownBlockListState();
}

class _MarkdownBlockListState extends State<MarkdownBlockList> {
  final _root = _BlockForest();
  List<IncrementalMarkdownBlock> _previous = const [];
  Object? _signature;

  @override
  Widget build(BuildContext context) {
    var unchanged = math.min(_previous.length, widget.blocks.length);
    if (_signature != widget.signature) {
      unchanged = 0;
    } else {
      // The document retains only an unchanged prefix: edits reset its scanner,
      // and indentation may reopen a previously completed block at the tail.
      while (unchanged > 0 &&
          !identical(_previous[unchanged - 1], widget.blocks[unchanged - 1])) {
        unchanged--;
      }
    }
    _root.truncate(widget.blocks.length);
    for (var i = unchanged; i < widget.blocks.length; i++) {
      _root.set(i, widget.itemBuilder(context, i));
    }
    _previous = widget.blocks;
    _signature = widget.signature;
    final content = _root.widget;
    final layout = LayoutBuilder(
      builder: (_, constraints) => constraints.hasBoundedHeight
          ? OverflowBox(
              alignment: Alignment.topCenter,
              fit: OverflowBoxFit.deferToChild,
              minHeight: 0,
              maxHeight: double.infinity,
              child: content,
            )
          : content,
    );
    // Rich-text line chunks nest inside Markdown source blocks. Observe once
    // per document/viewport, rather than registering every paragraph.
    Scrollable.maybeOf(context);
    final positions = <ScrollPosition>[];
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (!positions.contains(position)) positions.add(position);
      }
      return true;
    });
    final scope = context
        .dependOnInheritedWidgetOfExactType<_BlockViewportScope>();
    if (scope != null && listEquals(scope.positions, positions)) {
      return layout;
    }
    return _BlockViewportScope(
      positions: positions,
      child: _ViewportPaintObserver(child: layout),
    );
  }
}

class _BlockViewportScope extends InheritedWidget {
  const _BlockViewportScope({required this.positions, required super.child});
  final List<ScrollPosition> positions;

  @override
  bool updateShouldNotify(_BlockViewportScope oldWidget) =>
      !listEquals(positions, oldWidget.positions);
}

// Grow to the right in successively larger, fixed-depth branches. Wrapping the
// old root whenever capacity doubles would deactivate/reactivate the entire
// history, causing a frame spike and selection churn at each capacity boundary.
class _BlockForest {
  final _head = _BlockBranch(0);
  final _branches = <_BlockBranch>[];
  int _length = 0;
  Widget? _widget;

  void set(int index, Widget value) {
    _widget = null;
    _length = math.max(_length, index + 1);
    if (index < _BlockBranch.width) {
      _head.set(index, value);
      return;
    }
    var remaining = index - _BlockBranch.width;
    var i = 0;
    while (true) {
      if (i == _branches.length) _branches.add(_BlockBranch(i + 1));
      final branch = _branches[i];
      if (remaining < branch.capacity) {
        branch.set(remaining, value);
        return;
      }
      remaining -= branch.capacity;
      i++;
    }
  }

  void truncate(int length) {
    if (length >= _length) return;
    _widget = null;
    _length = length;
    _head.truncate(math.min(length, _BlockBranch.width));
    var remaining = math.max(0, length - _BlockBranch.width);
    var keep = 0;
    while (keep < _branches.length && remaining > 0) {
      final branch = _branches[keep++];
      branch.truncate(math.min(remaining, branch.capacity));
      remaining -= branch.capacity;
    }
    _branches.removeRange(keep, _branches.length);
  }

  Widget get widget => _widget ??= _BlockSelectionGroup(
    key: ObjectKey(this),
    child: _BlockColumn(
      children: [
        ..._head.leaves,
        for (final branch in _branches) branch.widget,
      ],
    ),
  );
}

// A small branching factor bounds both Flutter's child diff and Flex layout.
class _BlockBranch {
  _BlockBranch(this.depth);

  static const width = 16;
  final int depth;
  final leaves = <Widget>[];
  final branches = <_BlockBranch>[];
  Widget? _widget;

  int get capacity => 1 << (4 * (depth + 1));

  void set(int index, Widget value) {
    _widget = null;
    if (depth == 0) {
      if (index == leaves.length) {
        leaves.add(value);
      } else {
        leaves[index] = value;
      }
      return;
    }
    final childCapacity = capacity ~/ width;
    final childIndex = index ~/ childCapacity;
    if (childIndex == branches.length) branches.add(_BlockBranch(depth - 1));
    branches[childIndex].set(index % childCapacity, value);
  }

  void truncate(int length) {
    if (depth == 0) {
      if (length < leaves.length) {
        leaves.removeRange(length, leaves.length);
        _widget = null;
      }
      return;
    }
    final childCapacity = capacity ~/ width;
    final keep = (length + childCapacity - 1) ~/ childCapacity;
    if (keep < branches.length) {
      branches.removeRange(keep, branches.length);
      _widget = null;
    }
    if (keep > 0 && keep <= branches.length && length % childCapacity != 0) {
      final last = branches[keep - 1];
      final oldWidget = last._widget;
      last.truncate(length % childCapacity);
      if (!identical(oldWidget, last._widget)) _widget = null;
    }
  }

  Widget get widget => _widget ??= _BlockSelectionGroup(
    key: ObjectKey(this),
    child: _BlockColumn(
      children: depth == 0
          ? List<Widget>.of(leaves)
          : [for (final branch in branches) branch.widget],
    ),
  );
}

// SelectionArea otherwise sorts every paragraph by its screen transform when
// one new selectable arrives. Mirror the render tree so each registrar sorts
// at most one branch. Selection/copy still traverses all children on demand.
class _BlockSelectionGroup extends StatefulWidget {
  const _BlockSelectionGroup({super.key, required this.child});
  final Widget child;

  @override
  State<_BlockSelectionGroup> createState() => _BlockSelectionGroupState();
}

class _BlockSelectionGroupState extends State<_BlockSelectionGroup> {
  final _delegate = StaticSelectionContainerDelegate();

  @override
  void initState() {
    super.initState();
    // A nested registrar may publish from a microtask after the frame. Ensure
    // its parent gets a frame to finish registration even in a static document.
    _delegate.addListener(WidgetsBinding.instance.ensureVisualUpdate);
  }

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SelectionContainer.maybeOf(context) == null
      ? widget.child
      : SelectionContainer(delegate: _delegate, child: widget.child);
}

class _BlockColumn extends MultiChildRenderObjectWidget {
  const _BlockColumn({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBlockColumn(
    !ExportCaptureScope.of(context),
    Directionality.of(context),
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBlockColumn renderObject,
  ) {
    renderObject.cullToViewport = !ExportCaptureScope.of(context);
    renderObject.textDirection = Directionality.of(context);
  }
}

typedef _ViewportClips = ({Rect? paint, Rect? semantics});

_ViewportClips _viewportClips(RenderBox target) {
  Rect? paint;
  Rect? semantics;
  // Intersect every viewport, including a code area's horizontal viewport
  // inside the vertical transcript. Compare these same clips when a cached
  // layer moves without repainting its contents.
  for (
    var ancestor = target.parent;
    ancestor != null;
    ancestor = ancestor.parent
  ) {
    if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
      final box = ancestor as RenderBox;
      if (!box.hasSize) continue;
      final transform = target.getTransformTo(box);
      if (transform.invert() != 0) {
        final rect = MatrixUtils.transformRect(
          transform,
          Offset.zero & box.size,
        );
        final paintRect = rect.inflate(32);
        final semanticsRect = rect.inflate(box.size.height + 250);
        paint = paint?.intersect(paintRect) ?? paintRect;
        semantics = semantics?.intersect(semanticsRect) ?? semanticsRect;
      }
    }
  }
  return (paint: paint, semantics: semantics);
}

class _RenderBlockColumn extends RenderFlex {
  _RenderBlockColumn(this._cullToViewport, TextDirection textDirection)
    : super(
        direction: Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: textDirection,
      );

  List<RenderBox>? _semanticChildren;
  Rect? _paintedClip;
  bool _hasPainted = false;
  bool _cullToViewport;
  set cullToViewport(bool value) {
    if (_cullToViewport == value) return;
    _cullToViewport = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  _ViewportClips get _clips =>
      _cullToViewport ? _viewportClips(this) : (paint: null, semantics: null);

  List<RenderBox> _childrenNearViewport(Rect? visible) {
    return [
      for (
        var child = firstChild;
        child != null;
        child = (child.parentData! as FlexParentData).nextSibling
      )
        if (visible == null ||
            visible.overlaps(
              child.paintBounds.shift(
                (child.parentData! as FlexParentData).offset,
              ),
            ))
          child,
    ];
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    // Like a sliver cache, retain neighbouring content for accessibility's
    // implicit scroll, without recomputing geometry for the entire transcript.
    // Membership is a snapshot, updated before the semantics pass. Changing it
    // while Flutter validates parent data can expose a newly visible node whose
    // semantics have not been adopted yet (e.g. a sliver offset correction).
    (_semanticChildren ??= _childrenNearViewport(
      _clips.semantics,
    )).forEach(visitor);
  }

  void viewportChanged() {
    final clips = _clips;
    // A descendant can sit behind another RepaintBoundary. Dirty its own
    // cached paint when its viewport changes, even if the document's outer
    // observer did not move (for example, a details block above it collapsed).
    if (_hasPainted && _paintedClip != clips.paint) markNeedsPaint();
    final next = _childrenNearViewport(clips.semantics);
    final previous = _semanticChildren ?? const <RenderBox>[];
    if (next.length != previous.length ||
        Iterable<int>.generate(
          next.length,
        ).any((i) => next[i] != previous[i])) {
      _semanticChildren = next;
      markNeedsSemanticsUpdate();
    }
    void visit(RenderObject node) {
      if (!node.attached) return;
      if (node is _RenderBlockColumn) {
        if (node.hasSize) node.viewportChanged();
      } else {
        node.visitChildren(visit);
      }
    }

    for (final child in {...previous, ...next}) {
      visit(child);
    }
  }

  @override
  void insert(RenderBox child, {RenderBox? after}) {
    _semanticChildren = null;
    super.insert(child, after: after);
  }

  @override
  void remove(RenderBox child) {
    _semanticChildren = null;
    super.remove(child);
  }

  @override
  void move(RenderBox child, {RenderBox? after}) {
    _semanticChildren = null;
    super.move(child, after: after);
  }

  @override
  void defaultPaint(PaintingContext context, Offset offset) {
    _hasPainted = true;
    final visible = _paintedClip = _clips.paint;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      if (visible == null ||
          visible.overlaps(child.paintBounds.shift(data.offset))) {
        context.paintChild(child, offset + data.offset);
      }
      child = data.nextSibling;
    }
  }
}

class _ViewportPaintObserver extends SingleChildRenderObjectWidget {
  const _ViewportPaintObserver({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderViewportPaintObserver();
}

// A child pipeline's layout phase runs after its parent's entire render tree
// has finished layout, and before that tree paints. Checking here includes
// ancestor movement and viewport resizing even behind retained layers, with
// no stale frame. Composition/post-frame callbacks are already too late.
// This pipeline owns no render nodes: it only invalidates paint and semantics,
// never layout, and never flushes its parent's pipeline or requests idle frames.
final class _ViewportPaintPipeline extends PipelineOwner {
  _ViewportPaintPipeline()
    : super(onSemanticsUpdate: (update) => update.dispose());

  static final _pipelines = Expando<_ViewportPaintPipeline>();
  final _observers = <_RenderViewportPaintObserver>{};

  static void register(_RenderViewportPaintObserver observer) {
    final owner = observer.owner!;
    var pipeline = _pipelines[owner];
    if (pipeline == null) {
      pipeline = _ViewportPaintPipeline();
      _pipelines[owner] = pipeline;
      owner.adoptChild(pipeline);
    }
    pipeline._observers.add(observer);
  }

  static void unregister(_RenderViewportPaintObserver observer) {
    final owner = observer.owner!;
    final pipeline = _pipelines[owner]!;
    pipeline._observers.remove(observer);
    if (pipeline._observers.isEmpty) {
      owner.dropChild(pipeline);
      _pipelines[owner] = null;
      pipeline.dispose();
    }
  }

  @override
  void flushLayout() {
    super.flushLayout();
    for (final observer in _observers) {
      observer._refreshBlocks();
    }
  }
}

class _RenderViewportPaintObserver extends RenderProxyBox {
  void _refreshBlocks() {
    if (!attached || !hasSize) return;
    void visit(RenderObject node) {
      if (node is _RenderBlockColumn) {
        if (node.hasSize) node.viewportChanged();
      } else {
        node.visitChildren(visit);
      }
    }

    child?.visitChildren(visit);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _ViewportPaintPipeline.register(this);
  }

  @override
  void detach() {
    _ViewportPaintPipeline.unregister(this);
    super.detach();
  }
}
