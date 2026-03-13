class MessagePageWindow {
  const MessagePageWindow({required this.start, required this.end});

  const MessagePageWindow.empty() : start = 0, end = 0;

  final int start;
  final int end;

  int get length => end - start;

  bool get isEmpty => length <= 0;

  bool contains(int index) => index >= start && index < end;

  @override
  bool operator ==(Object other) {
    return other is MessagePageWindow &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MessagePageWindow(start: $start, end: $end)';
}

class MessagePageWindowController {
  const MessagePageWindowController({this.pageSize = 20, this.maxPages = 3})
    : assert(pageSize > 0),
      assert(maxPages > 0);

  final int pageSize;
  final int maxPages;

  int get maxVisibleItems => pageSize * maxPages;

  MessagePageWindow resetToLatest(int totalItems) {
    if (totalItems <= 0) return const MessagePageWindow.empty();
    final end = totalItems;
    final start = _clampStart(end - pageSize, totalItems, pageSize);
    return MessagePageWindow(start: start, end: end);
  }

  MessagePageWindow sync({
    required MessagePageWindow current,
    required int previousTotalItems,
    required int nextTotalItems,
    required bool stickToLatest,
  }) {
    if (nextTotalItems <= 0) return const MessagePageWindow.empty();
    if (current.isEmpty) return resetToLatest(nextTotalItems);
    if (stickToLatest) {
      final desiredLength =
          (current.length <= 0
                  ? pageSize
                  : current.length.clamp(1, maxVisibleItems))
              .toInt();
      final end = nextTotalItems;
      final start = _clampStart(
        end - desiredLength,
        nextTotalItems,
        desiredLength,
      );
      return MessagePageWindow(start: start, end: end);
    }

    final desiredLength = current.length.clamp(1, maxVisibleItems).toInt();
    int start = current.start;
    if (start >= nextTotalItems) {
      start = _clampStart(
        nextTotalItems - desiredLength,
        nextTotalItems,
        desiredLength,
      );
    }
    int end = start + desiredLength;
    if (end > nextTotalItems) {
      end = nextTotalItems;
      start = _clampStart(end - desiredLength, nextTotalItems, desiredLength);
    }
    return MessagePageWindow(start: start, end: end);
  }

  MessagePageWindow preloadOlder(MessagePageWindow current, int totalItems) {
    if (!hasOlder(current) || totalItems <= 0) return current;
    final length = _targetLengthForPaging(current);
    final start = _clampStart(current.start - pageSize, totalItems, length);
    final end = (start + length).clamp(0, totalItems).toInt();
    return MessagePageWindow(start: start, end: end);
  }

  MessagePageWindow preloadNewer(MessagePageWindow current, int totalItems) {
    if (!hasNewer(current, totalItems) || totalItems <= 0) return current;
    final end = (current.end + pageSize).clamp(0, totalItems).toInt();
    final length = _targetLengthForPaging(current);
    final start = _clampStart(end - length, totalItems, length);
    return MessagePageWindow(start: start, end: end);
  }

  MessagePageWindow windowForIndex({
    required int totalItems,
    required int targetIndex,
  }) {
    if (totalItems <= 0) return const MessagePageWindow.empty();
    final clampedIndex = targetIndex.clamp(0, totalItems - 1).toInt();
    final targetPageStart = (clampedIndex ~/ pageSize) * pageSize;
    final preferredStart = targetPageStart - pageSize;
    final start = _clampStart(preferredStart, totalItems, maxVisibleItems);
    final end = (start + maxVisibleItems).clamp(0, totalItems).toInt();
    return MessagePageWindow(start: start, end: end);
  }

  bool hasOlder(MessagePageWindow current) => current.start > 0;

  bool hasNewer(MessagePageWindow current, int totalItems) =>
      current.end < totalItems;

  bool isAtLatest(MessagePageWindow current, int totalItems) =>
      current.end >= totalItems;

  int _targetLengthForPaging(MessagePageWindow current) {
    if (current.isEmpty) return pageSize;
    final nextLength = current.length + pageSize;
    return nextLength > maxVisibleItems ? maxVisibleItems : nextLength;
  }

  int _clampStart(int start, int totalItems, int windowLength) {
    if (totalItems <= 0) return 0;
    final safeLength = windowLength.clamp(1, totalItems).toInt();
    final maxStart = totalItems - safeLength;
    if (start < 0) return 0;
    if (start > maxStart) return maxStart;
    return start;
  }
}
