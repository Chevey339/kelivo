import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../utils/app_directories.dart';
import 'context_log_models.dart';

class ContextLogger {
  ContextLogger._();

  static const String activeFileName = 'context_logs.txt';
  static const String rotatedFilePrefix = 'context_logs_';

  static bool _enabled = false;
  static bool get enabled => _enabled;
  static bool _writeErrorReported = false;

  static Future<void> setEnabled(bool v) async {
    if (_enabled == v) return;
    if (!v) {
      // Drain writes queued while still enabled before flipping the flag;
      // the write callback no-ops once `_enabled` is false.
      await _writeQueue;
      try {
        await _sink?.flush();
      } catch (_) {}
      try {
        await _sink?.close();
      } catch (_) {}
      _sink = null;
      _sinkDate = null;
    } else {
      _writeErrorReported = false;
    }
    _enabled = v;
  }

  static IOSink? _sink;
  static DateTime? _sinkDate;
  static Future<void> _writeQueue = Future<void>.value();

  static String _two(int v) => v.toString().padLeft(2, '0');
  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static String _formatDate(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

  static Future<IOSink> _ensureSink() async {
    final now = DateTime.now();
    final today = _dayOf(now);
    if (_sink != null && _sinkDate == today) return _sink!;

    try {
      await _sink?.flush();
    } catch (_) {}
    try {
      await _sink?.close();
    } catch (_) {}
    _sink = null;
    _sinkDate = today;

    final dir = await AppDirectories.getContentDirectory();
    final logsDir = Directory('${dir.path}/logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    final active = File('${logsDir.path}/$activeFileName');
    if (await active.exists()) {
      try {
        final stat = await active.stat();
        final fileDay = _dayOf(stat.modified.toLocal());
        if (fileDay != today) {
          final suffix = _formatDate(fileDay);
          var rotated = File('${logsDir.path}/$rotatedFilePrefix$suffix.txt');
          if (await rotated.exists()) {
            int i = 1;
            while (await File(
              '${logsDir.path}/$rotatedFilePrefix${suffix}_$i.txt',
            ).exists()) {
              i++;
            }
            rotated = File(
              '${logsDir.path}/$rotatedFilePrefix${suffix}_$i.txt',
            );
          }
          await active.rename(rotated.path);
        }
      } catch (_) {}
    }

    _sink = active.openWrite(mode: FileMode.append);
    return _sink!;
  }

  static ContextLogSnapshot buildSnapshot({
    required List<Map<String, dynamic>> apiMessages,
    required String conversationId,
    required String assistantName,
    required String provider,
    required String model,
    DateTime? timestamp,
  }) {
    final messages = <ContextLogMessage>[
      for (final message in apiMessages)
        ContextLogMessage(
          role: (message['role'] ?? '').toString(),
          segments: segmentsFromTaggedMessage(message),
        ),
    ];
    return ContextLogSnapshot(
      timestamp: timestamp ?? DateTime.now(),
      conversationId: conversationId,
      assistantName: assistantName,
      provider: provider,
      model: model,
      messages: messages,
      totalTokens: messages.fold(0, (sum, m) => sum + m.tokens),
    );
  }

  static void logSnapshot(ContextLogSnapshot snapshot) {
    if (!_enabled) return;
    final line = '${jsonEncode(snapshot.toJson())}\n';
    _writeQueue = _writeQueue.then((_) async {
      if (!_enabled) return;
      try {
        final sink = await _ensureSink();
        sink.write(line);
        await sink.flush();
      } catch (_) {
        try {
          await _sink?.flush();
        } catch (_) {}
        try {
          await _sink?.close();
        } catch (_) {}
        _sink = null;
        _sinkDate = null;
        if (!_writeErrorReported) {
          _writeErrorReported = true;
          try {
            stderr.writeln(
              '[ContextLogger] write failed; further write errors will be suppressed.',
            );
          } catch (_) {}
        }
      }
    });
  }

  static void logPrepared({
    required List<Map<String, dynamic>> apiMessages,
    required String conversationId,
    required String assistantName,
    required String provider,
    required String model,
  }) {
    if (!_enabled) return;
    logSnapshot(
      buildSnapshot(
        apiMessages: apiMessages,
        conversationId: conversationId,
        assistantName: assistantName,
        provider: provider,
        model: model,
      ),
    );
  }
}
