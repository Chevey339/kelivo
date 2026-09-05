import 'dart:collection';

/// A cursor over a queue of string chunks that yields one code point at a time
/// and can be rewound.
///
/// Chunks are indexed in place rather than expanded into a `List<int>` of runes
/// up front, which copied every chunk before the parser had looked at it - the
/// hottest allocation in the write path.
///
/// Offsets and counts are in UTF-16 code units, so a surrogate pair advances
/// the cursor by two. Callers only rewind by a difference of two
/// [totalConsumed] readings, so the distinction doesn't leak out.
class ByteConsumer {
  final _queue = ListQueue<String>();

  final _consumed = ListQueue<String>();

  var _currentOffset = 0;

  var _length = 0;

  var _totalConsumed = 0;

  void add(String data) {
    if (data.isEmpty) return;
    _queue.addLast(data);
    _length += data.length;
  }

  int peek() {
    final before = _totalConsumed;
    final result = consume();
    rollback(_totalConsumed - before);
    return result;
  }

  int consume() {
    var data = _queue.first;

    while (_currentOffset >= data.length) {
      _consumed.add(_queue.removeFirst());
      _currentOffset -= data.length;
      data = _queue.first;
    }

    final unit = data.codeUnitAt(_currentOffset);

    // Pairs never straddle a chunk boundary: chunks come from a UTF-8 decoder,
    // which only emits whole code points.
    if (unit >= 0xd800 && unit < 0xdc00 && _currentOffset + 1 < data.length) {
      final low = data.codeUnitAt(_currentOffset + 1);
      if (low >= 0xdc00 && low < 0xe000) {
        _currentOffset += 2;
        _length -= 2;
        _totalConsumed += 2;
        return 0x10000 + ((unit - 0xd800) << 10) + (low - 0xdc00);
      }
    }

    _currentOffset++;
    _length--;
    _totalConsumed++;
    return unit;
  }

  /// Rolls back the last [n] code units.
  void rollback([int n = 1]) {
    _currentOffset -= n;
    _totalConsumed -= n;
    _length += n;
    while (_currentOffset < 0) {
      final rollback = _consumed.removeLast();
      _queue.addFirst(rollback);
      _currentOffset += rollback.length;
    }
  }

  /// Rolls back to the state when this consumer had [length] code units.
  void rollbackTo(int length) {
    rollback(length - _length);
  }

  int get length => _length;

  int get totalConsumed => _totalConsumed;

  bool get isEmpty => _length == 0;

  bool get isNotEmpty => _length != 0;

  /// Unreferences data blocks that have been consumed. After calling this
  /// method, the consumer will not be able to roll back to consumed blocks.
  void unrefConsumedBlocks() {
    _consumed.clear();
  }

  /// Resets the consumer to its initial state.
  void reset() {
    _queue.clear();
    _consumed.clear();
    _currentOffset = 0;
    _totalConsumed = 0;
    _length = 0;
  }
}
