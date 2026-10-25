import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Starts a new edge at its opposite edge, visiting every intervening child.
/// An initialized edge can still lack visible geometry, so its index must be
/// used directly rather than relying on the framework's geometry-based search.
mixin SelectionEdgeInitialization on MultiSelectableSelectionContainerDelegate {
  @protected
  void prepareInitialSelectionEdge(SelectionEdgeUpdateEvent event) {}

  @override
  SelectionResult handleSelectionEdgeUpdate(SelectionEdgeUpdateEvent event) {
    final isEnd = event.type == SelectionEventType.endEdgeUpdate;
    if ((isEnd ? currentSelectionEndIndex : currentSelectionStartIndex) >= 0) {
      return super.handleSelectionEdgeUpdate(event);
    }
    prepareInitialSelectionEdge(event);
    if (selectables.isEmpty) return SelectionResult.none;
    var index = math.max(
      isEnd ? currentSelectionStartIndex : currentSelectionEndIndex,
      0,
    );
    var edge = index;
    bool? forward;
    SelectionResult? result;
    while (index >= 0 && index < selectables.length) {
      final childResult = dispatchSelectionEventToChild(
        selectables[index],
        event,
      );
      if (childResult == SelectionResult.end ||
          childResult == SelectionResult.pending) {
        edge = index;
        result = childResult;
        break;
      }
      if (childResult == SelectionResult.next ||
          childResult == SelectionResult.previous) {
        final nextForward = childResult == SelectionResult.next;
        if (forward != null && forward != nextForward) {
          result = SelectionResult.end;
          break;
        }
        forward = nextForward;
        edge = index;
        if ((!nextForward && index == 0) ||
            (nextForward && index == selectables.length - 1)) {
          result = childResult;
          break;
        }
      } else {
        edge = index;
      }
      index += (forward ?? true) ? 1 : -1;
    }
    if (isEnd) {
      currentSelectionEndIndex = edge;
    } else {
      currentSelectionStartIndex = edge;
    }
    final start = currentSelectionStartIndex < 0
        ? edge
        : currentSelectionStartIndex;
    final end = currentSelectionEndIndex < 0 ? edge : currentSelectionEndIndex;
    final first = math.min(start, end), last = math.max(start, end);
    for (var i = 0; i < selectables.length; i++) {
      if (i < first || i > last) {
        dispatchSelectionEventToChild(
          selectables[i],
          const ClearSelectionEvent(),
        );
      }
    }
    return result ?? SelectionResult.next;
  }
}
