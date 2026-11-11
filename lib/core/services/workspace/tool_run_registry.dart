import 'dart:async';

import 'package:flutter/foundation.dart';

import 'shell_output_buffer.dart';
import 'output_buffer.dart' show utf16SafeCut;

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
    this.onSettled,
  }) : runtimeRunId = runtimeRunId ?? toolCallId,
       startedAt = startedAt ?? DateTime.now();

  final String toolCallId;
  final String runtimeRunId;
  final String toolName;
  final DateTime startedAt;
  final String? command;
  final VoidCallback? onSettled;
  bool awaitingHandoff = false;

  ToolRunStatus status = ToolRunStatus.running;
  int? exitCode;
  int totalBytes = 0;

  late ShellOutputBuffer? _stdout = ShellOutputBuffer(
    onLine: (line) => _updateTail(line, stderr: false, complete: true),
  );
  late ShellOutputBuffer? _stderr = ShellOutputBuffer(
    onLine: (line) => _updateTail(line, stderr: true, complete: true),
  );
  final List<_TailLine> _tailLines = [];
  _TailLine? _stdoutTail;
  _TailLine? _stderrTail;
  Timer? _notifyTimer;

  static const int maxTailLines = 200;
  static const int maxTailBytes = 32 * 1024;
  int _tailBytes = 0;
  String _finishedStdout = '';
  String _finishedStderr = '';
  bool _stdoutTruncated = false;
  bool _stderrTruncated = false;

  int get retainedBytes =>
      _tailBytes +
      (_stdout?.retainedBytes ?? _finishedStdout.length * 2) +
      (_stderr?.retainedBytes ?? _finishedStderr.length * 2);
  int get tailBytes => _tailBytes;
  bool get hasOutputBuffers => _stdout != null || _stderr != null;
  static const Duration notifyInterval = Duration(milliseconds: 50);

  List<String> get tailLines =>
      List<String>.unmodifiable(_tailLines.map((line) => line.text));

  String get stdoutSoFar => _stdout?.text ?? _finishedStdout;

  String get stderrSoFar => _stderr?.text ?? _finishedStderr;

  bool get stdoutTruncated => _stdout?.truncated ?? _stdoutTruncated;

  bool get stderrTruncated => _stderr?.truncated ?? _stderrTruncated;

  void appendStdout(Uint8List bytes) {
    final emittedText = _stdout!.add(bytes);
    totalBytes += bytes.length;
    if (emittedText) _updatePendingTail(stderr: false);
    _scheduleNotify();
  }

  void appendStderr(Uint8List bytes) {
    final emittedText = _stderr!.add(bytes);
    totalBytes += bytes.length;
    if (emittedText) _updatePendingTail(stderr: true);
    _scheduleNotify();
  }

  void complete({
    required ToolRunStatus status,
    int? exitCode,
    bool retainUntilHandoff = false,
  }) {
    if (this.status != ToolRunStatus.running) return;
    awaitingHandoff = retainUntilHandoff;
    // Only newly decoded text can bring an evicted progress line back.
    if (_stdout!.close()) _updatePendingTail(stderr: false);
    if (_stderr!.close()) _updatePendingTail(stderr: true);
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _finishedStdout = _stdout!.text;
    _finishedStderr = _stderr!.text;
    _stdoutTruncated = _stdout!.truncated;
    _stderrTruncated = _stderr!.truncated;
    for (final line in _tailLines) {
      line.freeze();
    }
    _stdoutTail = null;
    _stderrTail = null;
    _stdout = null;
    _stderr = null;
    this.status = status;
    this.exitCode = exitCode;
    notifyListeners();
    onSettled?.call();
  }

  void _updatePendingTail({required bool stderr}) {
    final output = stderr ? _stderr : _stdout;
    if (output!.hasCurrentLine) {
      _updateTail(null, stderr: stderr, complete: false);
    }
  }

  void _updateTail(
    String? text, {
    required bool stderr,
    required bool complete,
  }) {
    var line = stderr ? _stderrTail : _stdoutTail;
    if (line == null) {
      line = _TailLine(stderr ? _stderr! : _stdout!);
      _tailLines.add(line);
    } else {
      _tailBytes -= line.retainedBytes;
    }
    line.update(text);
    _tailBytes += line.retainedBytes;
    if (stderr) {
      _stderrTail = complete ? null : line;
    } else {
      _stdoutTail = complete ? null : line;
    }
    while (_tailLines.length > maxTailLines || _tailBytes > maxTailBytes) {
      final removed = _tailLines.removeAt(0);
      _tailBytes -= removed.retainedBytes;
      if (identical(removed, _stdoutTail)) _stdoutTail = null;
      if (identical(removed, _stderrTail)) _stderrTail = null;
    }
  }

  void finishHandoff() {
    awaitingHandoff = false;
    onSettled?.call();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) onSettled?.call();
  }

  void _scheduleNotify() {
    if (!hasListeners) return;
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
  _TailLine(this.output);

  String? completedText;
  ShellOutputBuffer? output;
  int retainedBytes = 0;

  void update(String? value) {
    completedText = value == null
        ? null
        : utf16SafeCut(value, ToolRun.maxTailBytes ~/ 2, keepTail: true);
    retainedBytes = completedText != null
        ? completedText!.length * 2
        : (output!.currentLineRetainedBytes * 2).clamp(0, ToolRun.maxTailBytes);
    if (value != null) output = null;
  }

  String get text =>
      completedText ??
      utf16SafeCut(
        output!.currentLine,
        ToolRun.maxTailBytes ~/ 2,
        keepTail: true,
      );

  void freeze() {
    completedText = text;
    output = null;
  }
}

/// Process-lifetime registry of tool runs. Finished runs are kept until the
/// cap of 200 entries; least-recently-used finished runs are evicted first.
typedef _RunKey = (String?, String);

class ToolRunRegistry extends ChangeNotifier {
  static const int maxEntries = 200;
  static const int maxRetainedBytes = 8 * 1024 * 1024;
  int get retainedBytes =>
      _runs.values.fold(0, (sum, run) => sum + run.retainedBytes);

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
      onSettled: _evictOverflow,
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

  @override
  void dispose() {
    for (final run in _runs.values) {
      run.dispose();
    }
    _runs.clear();
    _lru.clear();
    super.dispose();
  }

  void _touch(_RunKey id) {
    _lru.remove(id);
    _lru.add(id);
  }

  void _evictOverflow() {
    while (_runs.length > maxEntries || retainedBytes > maxRetainedBytes) {
      _RunKey? victim;
      for (final id in _lru) {
        final run = _runs[id];
        if (run != null &&
            run.status != ToolRunStatus.running &&
            !run.awaitingHandoff &&
            !run.hasListeners) {
          victim = id;
          break;
        }
      }
      if (victim == null) break;
      final run = _runs.remove(victim);
      _lru.remove(victim);
      run?.dispose();
    }
  }
}
