import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'code_selection.dart';
import 'stable_selection_container.dart';

// Logical offsets include source that is outside the virtualized viewport.
// Each mounted fragment reports its source offset; copying a range slices the
// original text, including the newline between adjacent chunks.
class SourceTextSelectionDelegate extends StableSelectionDelegate
    with Selectable, SelectionRegistrant {
  String source = '';
  bool _selectionEnabled = true;

  /// Set before attaching or removing this delegate's selection host. Empty
  /// virtualized slivers remain enabled even when no fragments are painted.
  bool get selectionEnabled => _selectionEnabled;
  set selectionEnabled(bool value) {
    if (_selectionEnabled == value) return;
    _selectionEnabled = value;
    if (!value) _anchorFragments.clear();
    for (final fragment in _fragments) {
      fragment.selectionModeChanged();
    }
  }

  @override
  bool get hasSize => selectionEnabled && super.hasSize;
  (TextStyle, TextScaler, TextDirection, double)? _textLayout;

  /// End the current selection before glyphs are reflowed. Native text owns
  /// screen-coordinate anchors which cannot survive an offscreen relayout.
  /// Scrolling and paint-only style updates leave those anchors unchanged.
  void updateTextLayout(
    BuildContext context,
    TextStyle style,
    double width, {
    TextDirection? textDirection,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = textDirection ?? Directionality.of(context);
    final previous = _textLayout;
    _textLayout = (style, scaler, direction, width);
    if (previous == null ||
        (previous.$1.compareTo(style) != RenderComparison.layout &&
            previous.$2 == scaler &&
            previous.$3 == direction &&
            previous.$4 == width)) {
      return;
    }
    if (value.hasSelection) {
      dispatchSelectionEvent(const ClearSelectionEvent());
      // Also discard ancestor ScrollableSelectionContainer screen edges so it
      // cannot replay the old selection into the newly laid-out paragraphs.
      // Finish native registration batches first: clearing an old container
      // while its replacement registers can mutate Flutter's selectable list.
      // Public onSelectionChanged callbacks may also call ancestor setState,
      // which is only safe after the LayoutBuilder build scope has completed.
      final region = context.findAncestorStateOfType<SelectableRegionState>();
      if (region != null) {
        unawaited(
          WidgetsBinding.instance.endOfFrame.then((_) {
            if (region.mounted) region.clearSelection();
          }),
        );
      }
    }
    _transforms.clear();
  }

  final _transforms =
      Map<Selectable, (Matrix4, ScrollPosition?, double)>.identity();
  Map<Selectable, Matrix4>? _geometryTransforms;

  Matrix4 _globalTransform(Selectable child) => _readGlobalTransform(child);

  Matrix4 _readGlobalTransform(Selectable child) {
    final transform = child.getTransformTo(null);
    if (transform.determinant() != 0) {
      final position = child is State<StatefulWidget>
          ? Scrollable.maybeOf(
              (child as State<StatefulWidget>).context,
              axis: Axis.vertical,
            )?.position
          : null;
      _transforms[child] = (transform, position, position?.pixels ?? 0);
      return transform;
    }
    // Flutter uses a singular paint transform for kept-alive sliver children.
    // Their text selection still exists. Move the last painted geometry by the
    // actual scroll delta instead of interpreting a stale screen coordinate.
    final previous = _transforms[child];
    if (previous == null) return transform;
    final delta = (previous.$2?.pixels ?? previous.$3) - previous.$3;
    return Matrix4.translationValues(0, -delta, 0)..multiply(previous.$1);
  }

  @override
  Matrix4 getTransformFrom(Selectable child) =>
      _geometryTransforms?.putIfAbsent(
        child,
        () => _relativeTransform(child),
      ) ??
      _relativeTransform(child);

  Matrix4 _relativeTransform(Selectable child) =>
      Matrix4.inverted(getTransformTo(null))..multiply(_globalTransform(child));

  Rect _globalBounds(Selectable child) => MatrixUtils.transformRect(
    _globalTransform(child),
    child.boundingBoxes.fold<Rect?>(
          null,
          (bounds, rect) => bounds?.expandToInclude(rect) ?? rect,
        ) ??
        Rect.zero,
  );

  @override
  Comparator<Selectable> get compareOrder => (a, b) {
    final first = _globalBounds(a), second = _globalBounds(b);
    final vertical = first.top.compareTo(second.top);
    return vertical != 0 ? vertical : first.left.compareTo(second.left);
  };

  @override
  void remove(Selectable child) {
    super.remove(child);
    _transforms.remove(child);
  }

  @override
  SelectionResult dispatchSelectionEventToChild(
    Selectable child,
    SelectionEvent event,
  ) {
    if (event is SelectionEdgeUpdateEvent &&
        child.getTransformTo(null).determinant() == 0) {
      // Native text cannot convert coordinates through the singular transform.
      // Preserve its source anchor; route the moving edge toward visible text.
      return SelectionUtils.getResultBasedOnRect(
        _globalBounds(child),
        event.globalPosition,
      );
    }
    return super.dispatchSelectionEventToChild(child, event);
  }

  @override
  void dispose() {
    _transforms.clear();
    super.dispose();
  }

  @override
  Size get size => containerSize;
  @override
  List<Rect> get boundingBoxes => [Offset.zero & size];
  final _fragments = <_SourceTextSelectionFragmentState>{};
  final _anchorFragments = <_SourceTextSelectionFragmentState>{};
  bool _all = false;
  int? _startBoundary, _endBoundary;
  @override
  int get contentLength => source.length;
  @override
  SelectionGeometry getSelectionGeometry() {
    if (!selectionEnabled) {
      return const SelectionGeometry(
        status: SelectionStatus.none,
        hasContent: false,
      );
    }
    final previousTransforms = _geometryTransforms;
    _geometryTransforms = Map.identity();
    final SelectionGeometry geometry;
    try {
      geometry = super.getSelectionGeometry();
    } finally {
      _geometryTransforms = previousTransforms;
    }
    return SelectionGeometry(
      startSelectionPoint: geometry.startSelectionPoint,
      endSelectionPoint: geometry.endSelectionPoint,
      selectionRects: geometry.selectionRects,
      status: _all && source.isNotEmpty
          ? SelectionStatus.uncollapsed
          : geometry.status,
      hasContent: source.isNotEmpty,
    );
  }

  @override
  void didChangeSelectables() {
    if (selectables.isEmpty) {
      // Detachment can queue this callback after SelectionContainer's context
      // or the sliver render object has gone away. Clear native screen edges
      // before the base class can replay them. A still-mounted virtualized
      // section keeps its full-source Select All state without keeping rows.
      if (!selectionEnabled) _all = false;
      _startBoundary = null;
      _endBoundary = null;
      super.handleClearSelection(const ClearSelectionEvent());
      super.didChangeSelectables();
      return;
    }
    if (!_all && hasSize) {
      // A sliver's origin moves while its logical text offsets stay fixed.
      // Rebase the saved screen positions before replaying edges into newly
      // mounted fragments, retaining the existing text anchors while scrolling.
      void rebase(SelectionPoint? point, bool forEnd) {
        if (point == null) return;
        updateLastSelectionEdgeLocation(
          globalSelectionEdgeLocation: MatrixUtils.transformPoint(
            getTransformTo(null),
            point.localPosition - Offset(0, point.lineHeight / 2),
          ),
          forEnd: forEnd,
        );
      }

      rebase(value.startSelectionPoint, false);
      rebase(value.endSelectionPoint, true);
    }
    super.didChangeSelectables();
    if (_all) super.handleSelectAll(const SelectAllSelectionEvent());
    _updateAnchorFragments();
  }

  void _updateAnchorFragments() {
    _SourceTextSelectionFragmentState? first, last;
    var start = source.length + 1;
    var end = -1;
    if (selectionEnabled && !_all) {
      for (final fragment in _fragments) {
        final range = fragment._selection.getSelection();
        if (range == null) continue;
        final from =
            fragment.widget.offset +
            (range.startOffset < range.endOffset
                ? range.startOffset
                : range.endOffset);
        final to =
            fragment.widget.offset +
            (range.startOffset > range.endOffset
                ? range.startOffset
                : range.endOffset);
        if (from < start) {
          start = from;
          first = fragment;
        }
        if (to > end) {
          end = to;
          last = fragment;
        }
      }
    }
    final previous = Set.of(_anchorFragments);
    _anchorFragments
      ..clear()
      ..addAll([if (first != null) first, if (last != null) last]);
    for (final fragment in {...previous, ..._anchorFragments}) {
      fragment.selectionModeChanged();
    }
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    _all = event is SelectAllSelectionEvent;
    if (event is! SelectionEdgeUpdateEvent) {
      _startBoundary = null;
      _endBoundary = null;
    }
    final result = super.dispatchSelectionEvent(event);
    // Only the two source anchors need native selection state. Middle chunks
    // can unmount because copying slices the full logical source between them.
    _updateAnchorFragments();
    return result;
  }

  @override
  SelectionResult handleSelectionEdgeUpdate(SelectionEdgeUpdateEvent event) {
    final local = MatrixUtils.transformPoint(
      Matrix4.inverted(getTransformTo(null)),
      event.globalPosition,
    );
    final boundary = local.dy < 0
        ? -1
        : local.dy > containerSize.height
        ? 1
        : null;
    if (event.type == SelectionEventType.startEdgeUpdate) {
      _startBoundary = boundary;
    } else {
      _endBoundary = boundary;
    }
    final result = super.handleSelectionEdgeUpdate(event);
    return boundary == null
        ? result
        : boundary < 0
        ? SelectionResult.previous
        : SelectionResult.next;
  }

  @override
  SelectedContentRange? getSelection() {
    if (_all && source.isNotEmpty)
      return SelectedContentRange(startOffset: 0, endOffset: source.length);
    final ranges = <(int, int)>[];
    for (final fragment in _fragments) {
      final range = fragment._selection.getSelection();
      if (range != null)
        ranges.add((
          fragment.widget.offset + range.startOffset,
          fragment.widget.offset + range.endOffset,
        ));
    }
    if (_startBoundary != null && _endBoundary != null)
      return SelectedContentRange(
        startOffset: _startBoundary! < 0 ? 0 : source.length,
        endOffset: _endBoundary! < 0 ? 0 : source.length,
      );
    if (ranges.isEmpty) return null;
    final start = ranges
        .map((r) => math.min(r.$1, r.$2))
        .reduce(math.min)
        .clamp(0, source.length);
    final end = ranges
        .map((r) => math.max(r.$1, r.$2))
        .reduce(math.max)
        .clamp(start, source.length);
    final reverse =
        currentSelectionEndIndex < currentSelectionStartIndex ||
        (currentSelectionEndIndex == currentSelectionStartIndex &&
            ranges.first.$1 > ranges.first.$2);
    return SelectedContentRange(
      startOffset: _startBoundary == null
          ? (reverse ? end : start)
          : _startBoundary! < 0
          ? 0
          : source.length,
      endOffset: _endBoundary == null
          ? (reverse ? start : end)
          : _endBoundary! < 0
          ? 0
          : source.length,
    );
  }

  @override
  SelectedContent? getSelectedContent() {
    final range = getSelection();
    if (range == null || range.startOffset == range.endOffset) return null;
    return SelectedContent(
      plainText: source.substring(
        math.min(range.startOffset, range.endOffset),
        math.max(range.startOffset, range.endOffset),
      ),
    );
  }
}

/// Associates a mounted text fragment with its offset in the full source.
/// The child must render [source] exactly; separators may remain in the owner
/// source without being laid out twice at adjacent fragment boundaries.
class SourceTextSelectionFragment extends StatefulWidget {
  const SourceTextSelectionFragment({
    super.key,
    required this.source,
    required this.offset,
    required this.owner,
    required this.child,
  });
  final String source;
  final int offset;
  final SourceTextSelectionDelegate owner;
  final Widget child;

  @override
  State<SourceTextSelectionFragment> createState() =>
      _SourceTextSelectionFragmentState();
}

class _SourceTextSelectionFragmentState
    extends State<SourceTextSelectionFragment>
    with AutomaticKeepAliveClientMixin {
  late final _selection = CodeSelectionDelegate(widget.source)
    ..addListener(updateKeepAlive);

  @override
  bool get wantKeepAlive =>
      widget.owner.selectionEnabled &&
      widget.owner._anchorFragments.contains(this);

  void selectionModeChanged() => updateKeepAlive();

  @override
  void initState() {
    super.initState();
    widget.owner._fragments.add(this);
  }

  @override
  void didUpdateWidget(SourceTextSelectionFragment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner) {
      oldWidget.owner._fragments.remove(this);
      oldWidget.owner._anchorFragments.remove(this);
      widget.owner._fragments.add(this);
      updateKeepAlive();
    }
    _selection.source = widget.source;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SelectionContainer.maybeOf(context) == null
        ? widget.child
        : SelectionContainer(delegate: _selection, child: widget.child);
  }

  @override
  void dispose() {
    widget.owner._fragments.remove(this);
    widget.owner._anchorFragments.remove(this);
    _selection.dispose();
    super.dispose();
  }
}
