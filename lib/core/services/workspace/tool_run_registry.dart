import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'output_buffer.dart';

enum ToolRunStatus { running, succeeded, failed, cancelled, timedOut }

/// Live state of one tool invocation. Listeners are notified at most once
/// per 50 ms while running, and immediately on [complete].
class ToolRun extends ChangeNotifier {
  ToolRun({
    required this.toolCallId,
    required this.toolName,
    this.command,
    String? runtimeRunId,
    DateTime? startedAt,
  }) : runtimeRunId = runtimeRunId ?? toolCallId,
       startedAt = startedAt ?? DateTime.now();

  final String toolCallId;
  final String runtimeRunId;
  final String toolName;
  final DateTime startedAt;
  final String? command;

  ToolRunStatus status = ToolRunStatus.running;
  int? exitCode;
  int totalBytes = 0;

  final BoundedStreamBuffer _stdout = BoundedStreamBuffer();
  final BoundedStreamBuffer _stderr = BoundedStreamBuffer();
  final List<String> _tailLines = <String>[];
  String _lineCarry = '';
  Timer? _notifyTimer;

  static const int maxTailLines = 200;
  static const Duration notifyInterval = Duration(milliseconds: 50);

  List<String> get tailLines => List<String>.unmodifiable(_tailLines);

  String get stdoutSoFar => _stdout.text;

  String get stderrSoFar => _stderr.text;

  bool get stdoutTruncated => _stdout.truncated;

  bool get stderrTruncated => _stderr.truncated;

  void appendStdout(Uint8List bytes) {
    _stdout.add(bytes);
    totalBytes += bytes.length;
    _feedTail(bytes);
    _scheduleNotify();
  }

  void appendStderr(Uint8List bytes) {
    _stderr.add(bytes);
    totalBytes += bytes.length;
    _feedTail(bytes);
    _scheduleNotify();
  }

  void complete({required ToolRunStatus status, int? exitCode}) {
    _flushCarry();
    _notifyTimer?.cancel();
    _notifyTimer = null;
    this.status = status;
    this.exitCode = exitCode;
    notifyListeners();
  }

  void _feedTail(List<int> bytes) {
    final chunk = utf8.decode(bytes, allowMalformed: true);
    final data = '$_lineCarry$chunk';
    final parts = const LineSplitter().convert(data);
    final endedWithNewline = data.endsWith('\n');
    if (!endedWithNewline && parts.isNotEmpty) {
      _lineCarry = parts.removeLast();
    } else {
      _lineCarry = '';
    }
    for (final line in parts) {
      _pushTail(line);
    }
  }

  void _flushCarry() {
    if (_lineCarry.isEmpty) return;
    _pushTail(_lineCarry);
    _lineCarry = '';
  }

  void _pushTail(String line) {
    _tailLines.add(line);
    if (_tailLines.length > maxTailLines) {
      _tailLines.removeAt(0);
    }
  }

  void _scheduleNotify() {
    _notifyTimer ??= Timer(notifyInterval, () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    super.dispose();
  }
}

/// Process-lifetime registry of tool runs. Finished runs are kept until the
/// cap of 200 entries; least-recently-used finished runs are evicted first.
typedef _RunKey = (String?, String);

class ToolRunRegistry extends ChangeNotifier {
  static const int maxEntries = 200;

  final Map<_RunKey, ToolRun> _runs = {};
  final List<_RunKey> _lru = [];

  ToolRun start(
    String toolCallId,
    String toolName, {
    String? command,
    String? conversationId,
    String? runtimeRunId,
  }) {
    final key = (conversationId, toolCallId);
    final existing = _runs.remove(key);
    existing?.dispose();
    _lru.remove(key);
    final run = ToolRun(
      toolCallId: toolCallId,
      toolName: toolName,
      runtimeRunId: runtimeRunId,
      command: command,
    );
    _runs[key] = run;
    _lru.add(key);
    _evictOverflow();
    notifyListeners();
    return run;
  }

  ToolRun? of(String toolCallId, {String? conversationId}) {
    final key = (conversationId, toolCallId);
    final run = _runs[key];
    if (run != null) _touch(key);
    return run;
  }

  void evict(String toolCallId, {String? conversationId}) {
    final key = (conversationId, toolCallId);
    final run = _runs.remove(key);
    _lru.remove(key);
    run?.dispose();
    notifyListeners();
  }

  Iterable<ToolRun> get running =>
      _runs.values.where((run) => run.status == ToolRunStatus.running);

  Iterable<ToolRun> get all => _runs.values;

  void _touch(_RunKey id) {
    _lru.remove(id);
    _lru.add(id);
  }

  void _evictOverflow() {
    while (_runs.length > maxEntries) {
      _RunKey? victim;
      for (final id in _lru) {
        final run = _runs[id];
        if (run != null && run.status != ToolRunStatus.running) {
          victim = id;
          break;
        }
      }
      victim ??= _lru.first;
      final run = _runs.remove(victim);
      _lru.remove(victim);
      run?.dispose();
    }
  }
}
