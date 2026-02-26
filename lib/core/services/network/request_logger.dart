import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../utils/app_directories.dart';

class RequestLogger {
  RequestLogger._();

  static bool _enabled = false;
  static bool get enabled => _enabled;
  static bool _writeErrorReported = false;

  static bool saveOutput = true;

  static int _nextRequestId = 0;
  static int nextRequestId() => ++_nextRequestId;

  static Future<void> setEnabled(bool v) async {
    if (_enabled == v) return;
    _enabled = v;
    if (!v) {
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
  }

  static IOSink? _sink;
  static DateTime? _sinkDate;
  static Future<void> _writeQueue = Future<void>.value();

  static String _two(int v) => v.toString().padLeft(2, '0');
  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static String _formatDate(DateTime dt) => '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
  static String _formatTs(DateTime dt) {
    return '${_formatDate(dt)} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}.${dt.millisecond.toString().padLeft(3, '0')}';
  }

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

    final dir = await AppDirectories.getAppDataDirectory();
    final logsDir = Directory('${dir.path}/logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    final active = File('${logsDir.path}/logs.txt');
    if (await active.exists()) {
      try {
        final stat = await active.stat();
        final fileDay = _dayOf(stat.modified.toLocal());
        if (fileDay != today) {
          final suffix = _formatDate(fileDay);
          var rotated = File('${logsDir.path}/logs_$suffix.txt');
          if (await rotated.exists()) {
            int i = 1;
            while (await File('${logsDir.path}/logs_${suffix}_$i.txt').exists()) {
              i++;
            }
            rotated = File('${logsDir.path}/logs_${suffix}_$i.txt');
          }
          await active.rename(rotated.path);
        }
      } catch (_) {}
    }

    _sink = active.openWrite(mode: FileMode.append);
    return _sink!;
  }

  static void logLine(String line) {
    if (!_enabled) return;
    final now = DateTime.now();
    final text = '[${_formatTs(now)}] $line\n';
    _writeQueue = _writeQueue.then((_) async {
      if (!_enabled) return;
      try {
        final sink = await _ensureSink();
        sink.write(text);
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
            stderr.writeln('[RequestLogger] write failed; further write errors will be suppressed.');
          } catch (_) {}
        }
      }
    });
  }

  static String encodeObject(Object? obj) {
    try {
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return obj?.toString() ?? '';
    }
  }

  static String safeDecodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  static String escape(String input) {
    return input
        .replaceAll('\\', r'\\')
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll('\t', r'\t');
  }

  static Future<void> cleanupLogs({
    required int autoDeleteDays,
    required int maxSizeMB,
  }) async {
    try {
      final dir = await AppDirectories.getAppDataDirectory();
      final logsDir = Directory('${dir.path}/logs');
      if (!await logsDir.exists()) return;

      final files = await logsDir
          .list()
          .where((e) => e is File && e.path.toLowerCase().endsWith('.txt'))
          .cast<File>()
          .toList();
      if (files.isEmpty) return;

      // Auto-delete old files
      if (autoDeleteDays > 0) {
        final cutoff = DateTime.now().subtract(Duration(days: autoDeleteDays));
        for (final f in List<File>.from(files)) {
          try {
            final stat = await f.stat();
            if (stat.modified.isBefore(cutoff)) {
              await f.delete();
              files.remove(f);
            }
          } catch (_) {}
        }
      }

      // Enforce max size
      if (maxSizeMB > 0 && files.isNotEmpty) {
        final maxBytes = maxSizeMB * 1024 * 1024;
        final statMap = <File, FileStat>{};
        int totalSize = 0;
        for (final f in files) {
          try {
            final s = await f.stat();
            statMap[f] = s;
            totalSize += s.size;
          } catch (_) {}
        }
        if (totalSize > maxBytes) {
          // Sort oldest first
          final sorted = statMap.entries.toList()
            ..sort((a, b) => a.value.modified.compareTo(b.value.modified));
          for (final entry in sorted) {
            if (totalSize <= maxBytes) break;
            try {
              totalSize -= entry.value.size;
              await entry.key.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
