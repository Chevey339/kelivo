import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChatVisibleRange {
  const ChatVisibleRange({
    required this.firstIndex,
    required this.lastIndex,
    required this.isAtTop,
    required this.isAtBottom,
  });

  final int firstIndex;
  final int lastIndex;
  final bool isAtTop;
  final bool isAtBottom;

  static const empty = ChatVisibleRange(
    firstIndex: -1,
    lastIndex: -1,
    isAtTop: true,
    isAtBottom: true,
  );
}

class ChatIndexedScrollControllers {
  ChatIndexedScrollControllers({
    ItemScrollController? itemScrollController,
    ItemPositionsListener? itemPositionsListener,
    ScrollOffsetListener? scrollOffsetListener,
  }) : itemScrollController = itemScrollController ?? ItemScrollController(),
       itemPositionsListener =
           itemPositionsListener ?? ItemPositionsListener.create(),
       scrollOffsetListener =
           scrollOffsetListener ??
           ScrollOffsetListener.create(recordProgrammaticScrolls: false);

  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final ScrollOffsetListener scrollOffsetListener;
}

enum ChatUserScrollIntentDirection { unknown, towardTop, towardBottom }

class ChatScrollPositionTracker {
  ChatScrollPositionTracker({
    required ChatIndexedScrollControllers controllers,
    required int Function() itemCount,
    required VoidCallback onChanged,
    Duration scrollIdleDelay = const Duration(milliseconds: 180),
  }) : _controllers = controllers,
       _itemCount = itemCount,
       _onChanged = onChanged,
       _scrollIdleDelay = scrollIdleDelay {
    _controllers.itemPositionsListener.itemPositions.addListener(
      _onPositionsChanged,
    );
    _offsetSubscription = _controllers.scrollOffsetListener.changes.listen(
      _onOffsetChanged,
    );
  }

  final ChatIndexedScrollControllers _controllers;
  final int Function() _itemCount;
  final VoidCallback _onChanged;
  final Duration _scrollIdleDelay;

  StreamSubscription<double>? _offsetSubscription;
  Timer? _scrollIdleTimer;
  ChatVisibleRange _visibleRange = ChatVisibleRange.empty;
  int? _visibleRangeItemCount;
  bool _isUserScrolling = false;
  bool _isProgrammaticScroll = false;
  double _lastUserScrollDelta = 0;
  int _jumpGeneration = 0;

  ChatVisibleRange get visibleRange => _visibleRange;
  bool get hasCurrentVisibleRange =>
      _visibleRangeItemCount == _itemCount() &&
      _visibleRange.firstIndex >= 0 &&
      _visibleRange.lastIndex >= 0;
  bool get isUserScrolling => _isUserScrolling;
  bool get isAttached => _controllers.itemScrollController.isAttached;
  int get firstVisibleIndex => _visibleRange.firstIndex;
  int get lastVisibleIndex => _visibleRange.lastIndex;
  bool get isAtTop => _visibleRange.isAtTop;
  bool get isAtBottom => _visibleRange.isAtBottom;
  bool get lastUserScrollWasTowardBottom => _lastUserScrollDelta > 0;

  double? leadingEdgeForIndex(int index) {
    for (final position
        in _controllers.itemPositionsListener.itemPositions.value) {
      if (position.index == index) return position.itemLeadingEdge;
    }
    return null;
  }

  ItemPosition? readingAnchorPosition() {
    final count = _itemCount();
    if (count <= 0) return null;
    final positions =
        _controllers.itemPositionsListener.itemPositions.value
            .where(
              (position) =>
                  position.index >= 0 &&
                  position.index < count &&
                  position.itemTrailingEdge > 0 &&
                  position.itemLeadingEdge < 1,
            )
            .toList(growable: false)
          ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (positions.isEmpty) return null;
    return positions.firstWhere(
      (position) => position.itemTrailingEdge > 0.04,
      orElse: () => positions.first,
    );
  }

  bool visibleContentFitsInViewport() {
    final count = _itemCount();
    if (count <= 0) return true;
    if (!hasCurrentVisibleRange) return false;

    ItemPosition? firstMessage;
    ItemPosition? bottomAnchor;
    for (final position
        in _controllers.itemPositionsListener.itemPositions.value) {
      if (position.index == 0) {
        firstMessage = position;
      } else if (position.index == count) {
        bottomAnchor = position;
      }
    }
    return firstMessage != null &&
        bottomAnchor != null &&
        bottomAnchor.itemTrailingEdge - firstMessage.itemLeadingEdge <= 1.02;
  }

  void _onPositionsChanged() {
    final count = _itemCount();
    final bottomAnchorIndex = count;
    final positions = _controllers.itemPositionsListener.itemPositions.value;
    final visible = positions
        .where(
          (position) =>
              position.index >= 0 &&
              position.index <= bottomAnchorIndex &&
              position.itemTrailingEdge > 0 &&
              position.itemLeadingEdge < 1,
        )
        .toList(growable: false);

    final next = visible.isEmpty
        ? ChatVisibleRange(
            firstIndex: _visibleRange.firstIndex.clamp(0, bottomAnchorIndex),
            lastIndex: _visibleRange.lastIndex.clamp(0, bottomAnchorIndex),
            isAtTop: _visibleRange.isAtTop,
            isAtBottom: _visibleRange.isAtBottom,
          )
        : _rangeFromPositions(visible, count, bottomAnchorIndex);

    if (_visibleRangeItemCount == count &&
        _visibleRange.firstIndex == next.firstIndex &&
        _visibleRange.lastIndex == next.lastIndex &&
        _visibleRange.isAtTop == next.isAtTop &&
        _visibleRange.isAtBottom == next.isAtBottom) {
      return;
    }

    _visibleRange = next;
    _visibleRangeItemCount = count;
    _onChanged();
  }

  ChatVisibleRange _rangeFromPositions(
    List<ItemPosition> positions,
    int count,
    int bottomAnchorIndex,
  ) {
    var first = positions.first.index;
    var last = positions.first.index;
    var topVisible = false;
    var bottomVisible = false;

    for (final position in positions) {
      if (position.index < first) first = position.index;
      if (position.index > last) last = position.index;
      if (position.index == 0 && position.itemLeadingEdge >= -0.02) {
        topVisible = true;
      }
      if (position.index == bottomAnchorIndex &&
          position.itemTrailingEdge <= 1.02) {
        bottomVisible = true;
      }
    }

    return ChatVisibleRange(
      firstIndex: first,
      lastIndex: last,
      isAtTop: topVisible,
      isAtBottom: bottomVisible,
    );
  }

  void _onOffsetChanged(double delta) {
    if (delta.abs() < 0.5) return;
    if (_isProgrammaticScroll) return;
    _lastUserScrollDelta = delta;
    if (!_isUserScrolling) {
      _isUserScrolling = true;
    }
    _onChanged();
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(_scrollIdleDelay, () {
      if (!_isUserScrolling) return;
      _isUserScrolling = false;
      _onChanged();
    });
  }

  bool shouldAnimateToIndex(int targetIndex, {int maxAnimatedDistance = 80}) {
    if (_visibleRange.firstIndex < 0 || _visibleRange.lastIndex < 0) {
      return false;
    }
    if (targetIndex >= _visibleRange.firstIndex &&
        targetIndex <= _visibleRange.lastIndex) {
      return true;
    }
    final distance = targetIndex < _visibleRange.firstIndex
        ? _visibleRange.firstIndex - targetIndex
        : targetIndex - _visibleRange.lastIndex;
    return distance <= maxAnimatedDistance;
  }

  Future<void> scrollToIndex({
    required int index,
    double alignment = 0,
    bool animate = true,
    Duration duration = const Duration(milliseconds: 250),
  }) async {
    final count = _itemCount();
    if (!_controllers.itemScrollController.isAttached) return;
    final target = index.clamp(0, count);
    final generation = ++_jumpGeneration;
    _isUserScrolling = false;
    _lastUserScrollDelta = 0;
    _isProgrammaticScroll = true;
    _scrollIdleTimer?.cancel();

    try {
      if (!animate || duration == Duration.zero) {
        _controllers.itemScrollController.jumpTo(
          index: target,
          alignment: alignment,
        );
        return;
      }

      await _controllers.itemScrollController.scrollTo(
        index: target,
        alignment: alignment,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (generation != _jumpGeneration) return;
        _isProgrammaticScroll = false;
      });
    }
  }

  void resetUserScrolling() {
    _isUserScrolling = false;
    _lastUserScrollDelta = 0;
    _scrollIdleTimer?.cancel();
    _onChanged();
  }

  void dispose() {
    _controllers.itemPositionsListener.itemPositions.removeListener(
      _onPositionsChanged,
    );
    _offsetSubscription?.cancel();
    _scrollIdleTimer?.cancel();
  }
}
