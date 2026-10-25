import 'dart:async';

import 'package:flutter/widgets.dart';

/// Document-owned history with Flutter UndoHistory's 500 ms coalescing and
/// Android composing policy. Unlike a widget's history, it survives renderer
/// removal until accepted input has drained.
class MessageUndoHistory extends ChangeNotifier {
  MessageUndoHistory(this.document, {required this.onTriggered}) {
    document.addListener(_record);
    _record();
  }

  final TextEditingController document;
  final VoidCallback onTriggered;
  final _values = <TextEditingValue>[];
  int _index = -1;
  TextEditingValue? _lastValue;
  TextEditingValue? _pendingValue;
  Timer? _timer;
  bool _triggering = false;

  bool get canUndo => _index > 0;
  bool get canRedo => _index >= 0 && _index < _values.length - 1;

  void _record() {
    final value = document.value;
    if (_triggering || !value.selection.isValid) return;
    final previous = _lastValue;
    if (previous != null &&
        previous.text == value.text &&
        previous.composing == value.composing) {
      return;
    }
    final next = value.copyWith(composing: TextRange.empty);
    if (next == previous) return;
    _lastValue = next;
    _pendingValue = next;
    if (_timer?.isActive ?? false) return;
    _timer = Timer(const Duration(milliseconds: 500), () {
      final latest = _pendingValue!;
      if (_index >= 0 && latest == _values[_index]) return;
      _values.removeRange(_index + 1, _values.length);
      _values.add(latest);
      _index = _values.length - 1;
      notifyListeners();
    });
  }

  void undo() {
    if (_index < 0) return;
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
    } else if (canUndo) {
      _index--;
    }
    _restore();
  }

  void redo() {
    if (!canRedo) return;
    _index++;
    _restore();
  }

  void _restore() {
    final next = _values[_index];
    if (_lastValue != next) {
      _lastValue = next;
      _triggering = true;
      final changed = document.text != next.text;
      try {
        document.value = next;
        if (changed) onTriggered();
      } finally {
        _triggering = false;
      }
    }
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _values.clear();
    _index = -1;
    _lastValue = null;
    _pendingValue = null;
    _record();
    notifyListeners();
  }

  @override
  void dispose() {
    document.removeListener(_record);
    _timer?.cancel();
    _values.clear();
    super.dispose();
  }
}
