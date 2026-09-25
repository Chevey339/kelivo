/// Accumulates deltas without copying the growing prefix until a reader needs it.
/// Repeated reads between appends share the same immutable snapshot.
class StreamTextBuffer {
  StreamTextBuffer([this._snapshot = '']);

  String _snapshot;
  final StringBuffer _pending = StringBuffer();

  int get length => _snapshot.length + _pending.length;
  bool get isEmpty => length == 0;

  void add(String delta) {
    if (delta.isNotEmpty) _pending.write(delta);
  }

  String get value {
    if (_pending.isNotEmpty) {
      _snapshot = _snapshot.isEmpty
          ? _pending.toString()
          : '$_snapshot$_pending';
      _pending.clear();
    }
    return _snapshot;
  }

  set value(String text) {
    _snapshot = text;
    _pending.clear();
  }
}
