import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'selection_edge_initialization.dart';

/// Publishes incoming selectables before replaying selection edge events.
class StableSelectionDelegate extends StaticSelectionContainerDelegate
    with SelectionEdgeInitialization {
  StableSelectionDelegate() {
    addListener(WidgetsBinding.instance.ensureVisualUpdate);
  }

  final _pending = <Selectable>{};
  final _orderingGeometry = Map<Selectable, _OrderingGeometry>.identity();
  Map<Selectable, Matrix4>? _selectionTransforms;
  bool _dispatching = false;

  @override
  void prepareInitialSelectionEdge(SelectionEdgeUpdateEvent event) {
    updateLastSelectionEdgeLocation(
      globalSelectionEdgeLocation: event.globalPosition,
      forEnd: event.type == SelectionEventType.endEdgeUpdate,
    );
  }

  @override
  Comparator<Selectable> get compareOrder => _compareOrder;

  int _compareOrder(Selectable a, Selectable b) {
    final compare = super.compareOrder;
    if (_pending.isEmpty && !_dispatching) return compare(a, b);
    // Reuse geometry only during this registration batch or synchronous input
    // event, retaining Flutter's reading order without stale scroll coordinates.
    return compare(
      _orderingGeometry.putIfAbsent(a, () => _OrderingGeometry(a)),
      _orderingGeometry.putIfAbsent(b, () => _OrderingGeometry(b)),
    );
  }

  @override
  void add(Selectable selectable) {
    _orderingGeometry.clear();
    _pending.add(selectable);
    super.add(selectable);
  }

  @override
  void remove(Selectable selectable) {
    _orderingGeometry.clear();
    _pending.remove(selectable);
    super.remove(selectable);
  }

  @override
  void ensureChildUpdated(Selectable selectable) {
    // Flutter calls this while merging additions, before rebasing the edge
    // indices. Replaying an edge there can index the partially merged list.
    // didChangeSelectables replays both edges after the complete merge.
    if (_pending.contains(selectable)) return;
    super.ensureChildUpdated(selectable);
  }

  @override
  void didChangeSelectables() {
    _pending.clear();
    _orderingGeometry.clear();
    super.didChangeSelectables();
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    _orderingGeometry.clear();
    final wasDispatching = _dispatching;
    _dispatching = true;
    try {
      return super.dispatchSelectionEvent(event);
    } finally {
      _dispatching = wasDispatching;
      _orderingGeometry.clear();
    }
  }

  @override
  SelectedContentRange? getSelection() {
    // Flutter collects every descendant range before checking these indices.
    // An unselected group cannot contribute a range, including during copy.
    if (currentSelectionStartIndex == -1 || currentSelectionEndIndex == -1) {
      return null;
    }
    return super.getSelection();
  }

  @override
  SelectionGeometry getSelectionGeometry() {
    if (currentSelectionStartIndex == -1 || currentSelectionEndIndex == -1) {
      return super.getSelectionGeometry();
    }
    final previous = _selectionTransforms;
    // Flutter asks for the same child transform for every selected line.
    // Share it within one geometry calculation, never across layout or input.
    _selectionTransforms = Map.identity();
    try {
      return super.getSelectionGeometry();
    } finally {
      _selectionTransforms = previous;
    }
  }

  @override
  Matrix4 getTransformFrom(Selectable child) =>
      _selectionTransforms?.putIfAbsent(
        child,
        () => super.getTransformFrom(child),
      ) ??
      super.getTransformFrom(child);

  @override
  void dispose() {
    _pending.clear();
    _orderingGeometry.clear();
    super.dispose();
  }
}

// Only used as a geometry argument to Flutter's comparator. The original
// selectable remains registered and owns all selection state and resources.
class _OrderingGeometry implements Selectable {
  _OrderingGeometry(this.selectable);
  final Selectable selectable;
  late final _transform = selectable.getTransformTo(null);
  late final _bounds = List<Rect>.of(selectable.boundingBoxes);
  @override
  Matrix4 getTransformTo(RenderObject? ancestor) =>
      ancestor == null ? _transform : selectable.getTransformTo(ancestor);
  @override
  List<Rect> get boundingBoxes => _bounds;
  @override
  Size get size => selectable.size;
  @override
  int get contentLength => selectable.contentLength;
  @override
  SelectionGeometry get value => selectable.value;
  @override
  SelectedContent? getSelectedContent() => selectable.getSelectedContent();
  @override
  SelectedContentRange? getSelection() => selectable.getSelection();
  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) =>
      selectable.dispatchSelectionEvent(event);
  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) =>
      selectable.pushHandleLayers(startHandle, endHandle);
  @override
  void addListener(VoidCallback listener) => selectable.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      selectable.removeListener(listener);
  @override
  void dispose() {}
}

/// Keeps one participant in the ancestor selection while descendants change.
class StableSelectionContainer extends StatefulWidget {
  const StableSelectionContainer({super.key, required this.child});
  final Widget child;

  @override
  State<StableSelectionContainer> createState() =>
      _StableSelectionContainerState();
}

class _StableSelectionContainerState extends State<StableSelectionContainer> {
  final _delegate = StableSelectionDelegate();

  @override
  Widget build(BuildContext context) =>
      SelectionContainer.maybeOf(context) == null
      ? widget.child
      : SelectionContainer(delegate: _delegate, child: widget.child);

  @override
  void dispose() {
    _delegate.dispose();
    super.dispose();
  }
}
