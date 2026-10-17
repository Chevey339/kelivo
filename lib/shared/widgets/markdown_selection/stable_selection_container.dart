import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Publishes incoming selectables before replaying selection edge events.
class StableSelectionDelegate extends StaticSelectionContainerDelegate {
  StableSelectionDelegate() {
    addListener(WidgetsBinding.instance.ensureVisualUpdate);
  }

  final _pending = <Selectable>{};

  @override
  void add(Selectable selectable) {
    _pending.add(selectable);
    super.add(selectable);
  }

  @override
  void remove(Selectable selectable) {
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
    super.didChangeSelectables();
  }

  @override
  void dispose() {
    _pending.clear();
    super.dispose();
  }
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
