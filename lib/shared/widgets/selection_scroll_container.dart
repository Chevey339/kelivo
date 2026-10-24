import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:markstream/markstream.dart';

/// Selection handles express user scroll intent even when their overlay is
/// outside the message list's pointer listener.
class SelectionAutoScrollNotification extends Notification {}

/// Connects a message-local SelectionArea to its enclosing vertical viewport.
/// Scrollables inside the selection area continue using Flutter's own handler.
class SelectionScrollContainer extends StatefulWidget {
  const SelectionScrollContainer({super.key, required this.child});
  final Widget child;

  @override
  State<SelectionScrollContainer> createState() =>
      SelectionScrollContainerState();
}

class SelectionScrollContainerState extends State<SelectionScrollContainer> {
  late final _delegate = _ScrollSelectionDelegate(_edgeUpdated, _stop);
  String? get selectedText => _delegate.getSelectedContent()?.plainText;
  ScrollableState? _scrollable;
  ScrollPosition? _position;
  EdgeDraggingAutoScroller? _autoScroller;
  ValueListenable<SelectableRegionSelectionStatus>? _status;
  SelectionEdgeUpdateEvent? _edge;
  bool _layoutScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    if (_scrollable != scrollable || _position != scrollable?.position) {
      _stop();
      _position?.removeListener(_scrolled);
      _scrollable = scrollable;
      _delegate.scrollable = scrollable;
      _position = scrollable?.position;
      _position?.addListener(_scrolled);
      _autoScroller = scrollable == null
          ? null
          : EdgeDraggingAutoScroller(scrollable, velocityScalar: 30);
    }
    final status = SelectableRegionSelectionStatusScope.maybeOf(context);
    if (_status != status) {
      _status?.removeListener(_statusChanged);
      _status = status;
      _status?.addListener(_statusChanged);
    }
  }

  void _statusChanged() {
    if (_status?.value == SelectableRegionSelectionStatus.changing) {
      _updateAutoScroll();
    } else {
      _stop();
    }
  }

  void _edgeUpdated(SelectionEdgeUpdateEvent event, SelectionResult result) {
    // A nested code/table scroller gets to finish before the outer page moves.
    if (result == SelectionResult.pending) {
      _stop();
      return;
    }
    _edge = event;
    if (_status?.value == SelectableRegionSelectionStatus.changing) {
      _updateAutoScroll();
    }
  }

  void _updateAutoScroll() {
    final edge = _edge;
    final scrollable = _scrollable;
    final scroller = _autoScroller;
    if (edge == null || scrollable == null || scroller == null) return;
    final wasScrolling = scroller.scrolling;
    scroller.startAutoScrollIfNecessary(
      Rect.fromCenter(
        center: edge.globalPosition,
        width: 0,
        height: math.min(96, scrollable.position.viewportDimension),
      ),
    );
    if (!wasScrolling && scroller.scrolling) {
      SelectionAutoScrollNotification().dispatch(context);
    }
  }

  void _scrolled() {
    if (_layoutScheduled || !_delegate.value.hasSelection) return;
    _layoutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutScheduled = false;
      if (!mounted) return;
      final edge = _edge;
      if (edge != null &&
          _status?.value == SelectableRegionSelectionStatus.changing) {
        // The finger can remain stationary at the edge. Extend into the newly
        // visible text after layout, while retaining the opposite text anchor.
        _delegate.dispatchSelectionEvent(edge);
      } else {
        _delegate.layoutDidChange();
      }
    });
  }

  void _stop() {
    _autoScroller?.stopAutoScroll();
    _edge = null;
  }

  @override
  Widget build(BuildContext context) =>
      SelectionContainer(delegate: _delegate, child: widget.child);

  @override
  void dispose() {
    _stop();
    _position?.removeListener(_scrolled);
    _status?.removeListener(_statusChanged);
    _delegate.dispose();
    super.dispose();
  }
}

class _ScrollSelectionDelegate extends StableSelectionDelegate {
  _ScrollSelectionDelegate(this.onEdge, this.onReset);
  final void Function(SelectionEdgeUpdateEvent, SelectionResult) onEdge;
  final VoidCallback onReset;
  ScrollableState? scrollable;

  @override
  SelectionGeometry getSelectionGeometry() {
    final geometry = super.getSelectionGeometry();
    final viewport = scrollable?.context.findRenderObject();
    if (viewport is! RenderBox ||
        !viewport.hasSize ||
        geometry.selectionRects.isEmpty) {
      return geometry;
    }
    final toLocal = getTransformTo(viewport);
    if (toLocal.invert() == 0) return geometry;
    final visible = MatrixUtils.transformRect(
      toLocal,
      Offset.zero & viewport.size,
    );
    // Match Flutter's scrollable selection container: only visible highlight
    // rectangles reach the region/magnifier. Text ranges and both anchors stay
    // complete, including selected text above and below the viewport.
    return SelectionGeometry(
      startSelectionPoint: geometry.startSelectionPoint,
      endSelectionPoint: geometry.endSelectionPoint,
      status: geometry.status,
      hasContent: geometry.hasContent,
      selectionRects: [
        for (final rect in geometry.selectionRects)
          if (rect.intersect(visible) case final clipped
              when !clipped.isEmpty && clipped.isFinite)
            clipped,
      ],
    );
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    if (event is SelectionEdgeUpdateEvent) {
      final movingEnd = event.type == SelectionEventType.endEdgeUpdate;
      final stationary = movingEnd
          ? value.startSelectionPoint
          : value.endSelectionPoint;
      if (stationary != null) {
        // Static delegates otherwise replay the old *screen* coordinate when
        // the moving edge reaches another paragraph after the page scrolls.
        updateLastSelectionEdgeLocation(
          globalSelectionEdgeLocation: MatrixUtils.transformPoint(
            getTransformTo(null),
            stationary.localPosition - Offset(0, stationary.lineHeight / 2),
          ),
          forEnd: !movingEnd,
        );
      }
      final result = super.dispatchSelectionEvent(event);
      onEdge(event, result);
      return result;
    }
    onReset();
    return super.dispatchSelectionEvent(event);
  }
}
