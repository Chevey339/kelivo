import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// Document-owned history with Flutter UndoHistory's 500 ms coalescing and
/// Android composing policy. Unlike a widget's history, it survives renderer
/// removal until accepted input has drained.
class MessageUndoHistory extends ChangeNotifier {
  MessageUndoHistory(
    this.document, {
    required this.onTriggered,
    this.captureValue,
  }) {
    document.addListener(_record);
    _record();
  }

  final TextEditingController document;
  final VoidCallback onTriggered;
  final TextEditingValue Function(TextEditingValue)? captureValue;
  final _values = <TextEditingValue>[];
  int _index = -1;
  TextEditingValue? _lastValue;
  TextEditingValue? _pendingValue;
  Timer? _timer;
  bool _triggering = false;

  bool get isRestoring => _triggering;

  bool get canUndo => _index > 0;
  bool get canRedo => _index >= 0 && _index < _values.length - 1;

  void _record() {
    final value = document.value;
    if (_triggering || !value.selection.isValid) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        !value.composing.isCollapsed) {
      return;
    }
    final previous = _lastValue;
    final plain = value.copyWith(composing: TextRange.empty);
    final next = captureValue?.call(plain) ?? plain;
    // Ignore caret movement, but include the captured semantic metadata.
    final comparable = next.copyWith(selection: previous?.selection);
    if (comparable == previous) return;
    _lastValue = next;
    _pendingValue = next;
    if (_timer?.isActive ?? false) return;
    _timer = Timer(const Duration(milliseconds: 500), () {
      _commitPending();
    });
  }

  void _commitPending() {
    final latest = _pendingValue;
    if (latest == null || (_index >= 0 && latest == _values[_index])) return;
    _values.removeRange(_index + 1, _values.length);
    _values.add(latest);
    _index = _values.length - 1;
    notifyListeners();
  }

  /// Finish a typing group before and after an explicit semantic operation.
  void checkpoint() {
    _timer?.cancel();
    _record();
    _timer?.cancel();
    _commitPending();
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
        if (changed || next != _pendingValue) onTriggered();
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
