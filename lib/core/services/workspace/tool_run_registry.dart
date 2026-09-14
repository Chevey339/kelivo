import 'dart:async';

import 'package:flutter/foundation.dart';

import 'shell_output_buffer.dart';

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

  late final ShellOutputBuffer _stdout = ShellOutputBuffer(
    onLine: (line) => _updateTail(line, stderr: false, complete: true),
  );
  late final ShellOutputBuffer _stderr = ShellOutputBuffer(
    onLine: (line) => _updateTail(line, stderr: true, complete: true),
  );
  final List<_TailLine> _tailLines = [];
  _TailLine? _stdoutTail;
  _TailLine? _stderrTail;
  Timer? _notifyTimer;

  static const int maxTailLines = 200;
  static const Duration notifyInterval = Duration(milliseconds: 50);

  List<String> get tailLines =>
      List<String>.unmodifiable(_tailLines.map((line) => line.text));

  String get stdoutSoFar => _stdout.text;

  String get stderrSoFar => _stderr.text;

  bool get stdoutTruncated => _stdout.truncated;

  bool get stderrTruncated => _stderr.truncated;

  void appendStdout(Uint8List bytes) {
    final emittedText = _stdout.add(bytes);
    totalBytes += bytes.length;
    if (emittedText) _updatePendingTail(stderr: false);
    _scheduleNotify();
  }

  void appendStderr(Uint8List bytes) {
    final emittedText = _stderr.add(bytes);
    totalBytes += bytes.length;
    if (emittedText) _updatePendingTail(stderr: true);
    _scheduleNotify();
  }

  void complete({required ToolRunStatus status, int? exitCode}) {
    // Only newly decoded text can bring an evicted progress line back.
    if (_stdout.close()) _updatePendingTail(stderr: false);
    if (_stderr.close()) _updatePendingTail(stderr: true);
    _notifyTimer?.cancel();
    _notifyTimer = null;
    this.status = status;
    this.exitCode = exitCode;
    notifyListeners();
  }

  void _updatePendingTail({required bool stderr}) {
    final line = (stderr ? _stderr : _stdout).currentLine;
    if (line.isNotEmpty) _updateTail(line, stderr: stderr, complete: false);
  }

  void _updateTail(
    String text, {
    required bool stderr,
    required bool complete,
  }) {
    var line = stderr ? _stderrTail : _stdoutTail;
    if (line == null) {
      line = _TailLine(text);
      _tailLines.add(line);
      if (_tailLines.length > maxTailLines) {
        final removed = _tailLines.removeAt(0);
        if (identical(removed, _stdoutTail)) _stdoutTail = null;
        if (identical(removed, _stderrTail)) _stderrTail = null;
      }
    } else {
      line.text = text;
    }
    if (stderr) {
      _stderrTail = complete ? null : line;
    } else {
      _stdoutTail = complete ? null : line;
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

class _TailLine {
  _TailLine(this.text);

  String text;
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
