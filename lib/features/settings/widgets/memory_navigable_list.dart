import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../home/widgets/scroll_nav_buttons.dart';

/// Memory list with the chat's navigation buttons (top / previous / next /
/// bottom), revealed while the list scrolls and hidden shortly after.
class MemoryNavigableList extends StatefulWidget {
  const MemoryNavigableList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.isEntry,
    this.padding,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Whether the item at an index is a memory. Previous / next skip the rest,
  /// such as section headers.
  final bool Function(int index) isEntry;
  final EdgeInsetsGeometry? padding;

  @override
  State<MemoryNavigableList> createState() => _MemoryNavigableListState();
}

class _MemoryNavigableListState extends State<MemoryNavigableList> {
  static const _hideDelay = Duration(seconds: 2);

  final _scroll = ScrollController();
  final _list = ListController();
  Timer? _hideTimer;
  bool _navVisible = false;

  /// Last item targeted by previous / next, so quick repeated taps keep
  /// stepping while the list is still animating. Cleared by manual scrolling
  /// so navigation resumes from what is on screen.
  int? _cursor;

  @override
  void didUpdateWidget(MemoryNavigableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) _cursor = null;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  void _revealNav() {
    if (!_navVisible) setState(() => _navVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) setState(() => _navVisible = false);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification is ScrollUpdateNotification) {
      _revealNav();
    }
    return false;
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _revealNav();
    _cursor = null;
    _scroll.jumpTo(_scroll.position.minScrollExtent);
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients || !_list.isAttached || widget.itemCount == 0) {
      return;
    }
    _revealNav();
    _cursor = null;
    _list.jumpToItem(
      index: widget.itemCount - 1,
      scrollController: _scroll,
      alignment: 1,
    );
    // The jump measures the trailing items; settle on the exact end once laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _jumpToAdjacent({required bool previous}) {
    if (!_scroll.hasClients || !_list.isAttached) return;
    _revealNav();
    final first = _list.visibleRange?.$1;
    if (first == null) return;
    final position = _scroll.position;
    // At the end everything below is already on screen.
    if (!previous && position.pixels >= position.maxScrollExtent - 0.5) return;
    final cursor = _cursor;
    // Items near the end cannot reach the top, so a cursor there may sit below
    // the first visible item; step back from whichever is higher.
    final anchor = cursor == null
        ? first
        : (previous ? math.min(cursor, first) : cursor);
    final step = previous ? -1 : 1;
    var target = anchor + step;
    while (target >= 0 &&
        target < widget.itemCount &&
        !widget.isEntry(target)) {
      target += step;
    }
    if (target < 0 || target >= widget.itemCount) return;
    _cursor = target;
    _list.animateToItem(
      index: target,
      scrollController: _scroll,
      alignment: 0,
      duration: (_) => const Duration(milliseconds: 220),
      curve: (_) => Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (_) => _cursor = null,
          onPointerSignal: (_) => _cursor = null,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: SuperListView.builder(
              controller: _scroll,
              listController: _list,
              padding: widget.padding,
              itemCount: widget.itemCount,
              itemBuilder: widget.itemBuilder,
            ),
          ),
        ),
        ScrollNavButtonsPanel(
          visible: _navVisible,
          bottomOffset: MediaQuery.paddingOf(context).bottom + 16,
          onScrollToTop: _scrollToTop,
          onPreviousMessage: () => _jumpToAdjacent(previous: true),
          onNextMessage: () => _jumpToAdjacent(previous: false),
          onScrollToBottom: _scrollToBottom,
        ),
      ],
    );
  }
}
