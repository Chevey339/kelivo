import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../utils/app_directories.dart';

class RequestLogger {
  RequestLogger._();

  static const String _redactedValue = '<redacted>';

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
  static String _formatDate(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
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
            while (await File(
              '${logsDir.path}/logs_${suffix}_$i.txt',
            ).exists()) {
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
            stderr.writeln(
              '[RequestLogger] write failed; further write errors will be suppressed.',
            );
          } catch (_) {}
        }
      }
    });
  }

  static String encodeObject(Object? obj, {bool redactSecrets = false}) {
    final value = redactSecrets ? _redactSecrets(obj) : obj;
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      final text = value?.toString() ?? '';
      return redactSecrets ? _redactTextSecrets(text) : text;
    }
  }

  static String sanitizeBodyForLogging(String bodyText) {
    try {
      final decoded = jsonDecode(bodyText);
      return jsonEncode(_redactSecrets(decoded));
    } catch (_) {
      return _redactTextSecrets(bodyText);
    }
  }

  static String sanitizeUrlForLogging(Uri uri) {
    final redactedUserInfo = _redactUrlUserInfo(uri.toString());
    return _redactUrlQuerySecrets(redactedUserInfo);
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

  static Object? _redactSecrets(Object? value, {String? key}) {
    final normalizedKey = key == null ? null : _normalizeKey(key);
    if (normalizedKey != null && _isSensitiveKey(normalizedKey)) {
      return _redactValueForKey(normalizedKey, value);
    }

    if (value is Map) {
      return value.map<String, Object?>(
        (k, v) => MapEntry(k.toString(), _redactSecrets(v, key: k.toString())),
      );
    }
    if (value is Iterable) {
      return value.map((v) => _redactSecrets(v)).toList();
    }
    if (value is String) {
      return _redactTextSecrets(value);
    }
    return value;
  }

  static String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool _isSensitiveKey(String normalizedKey) {
    if (_sensitiveExactKeys.contains(normalizedKey)) return true;
    if (normalizedKey.contains('apikey')) return true;
    if (normalizedKey.endsWith('token')) return true;
    if (normalizedKey.endsWith('secret')) return true;
    return false;
  }

  static Object _redactValueForKey(String normalizedKey, Object? value) {
    if ((normalizedKey == 'authorization' ||
            normalizedKey == 'proxyauthorization') &&
        value is String) {
      return _redactAuthorizationValue(value);
    }
    return _redactedValue;
  }

  static String _redactTextSecrets(String text) {
    return _redactUrlQuerySecrets(
      _redactUrlUserInfo(
        _redactInlineSecretPairs(
          _redactBearerTokens(_redactAuthorizationPairs(text)),
        ),
      ),
    );
  }

  static String _redactAuthorizationValue(String text) {
    final match = _authorizationValueRe.firstMatch(text.trim());
    if (match == null) return _redactedValue;
    return '${match.group(1)} $_redactedValue';
  }

  static String _redactAuthorizationPairs(String text) {
    return text.replaceAllMapped(_authorizationPairRe, (m) {
      final prefix = m.group(1) ?? '';
      final keyQuote = m.group(2) ?? '';
      final key = m.group(3) ?? '';
      final separator = m.group(4) ?? '';
      final valueQuote = m.group(5) ?? '';
      final scheme = m.group(6) ?? m.group(8);
      final value = scheme == null ? _redactedValue : '$scheme $_redactedValue';
      return '$prefix$keyQuote$key$keyQuote$separator$valueQuote$value$valueQuote';
    });
  }

  static String _redactBearerTokens(String text) {
    return text.replaceAllMapped(_bearerTokenRe, (m) {
      return '${m.group(1)} $_redactedValue';
    });
  }

  static String _redactInlineSecretPairs(String text) {
    return text.replaceAllMapped(_inlineSecretPairRe, (m) {
      final prefix = m.group(1) ?? '';
      final keyQuote = m.group(2) ?? '';
      final key = m.group(3) ?? '';
      final separator = m.group(4) ?? '';
      final valueQuote = m.group(5) ?? '';
      return '$prefix$keyQuote$key$keyQuote$separator$valueQuote$_redactedValue$valueQuote';
    });
  }

  static String _redactUrlUserInfo(String text) {
    return text.replaceAllMapped(_urlUserInfoRe, (m) {
      return '${m.group(1)}${Uri.encodeComponent(_redactedValue)}@';
    });
  }

  static String _redactUrlQuerySecrets(String text) {
    return text.replaceAllMapped(_urlQueryParamRe, (m) {
      final prefix = m.group(1) ?? '';
      final rawKey = m.group(2) ?? '';
      final normalizedKey = _normalizeKey(Uri.decodeQueryComponent(rawKey));
      if (!_isSensitiveQueryKey(normalizedKey)) return m.group(0) ?? '';
      return '$prefix$rawKey=${Uri.encodeQueryComponent(_redactedValue)}';
    });
  }

  static bool _isSensitiveQueryKey(String normalizedKey) {
    return _isSensitiveKey(normalizedKey) ||
        _sensitiveQueryExactKeys.contains(normalizedKey) ||
        normalizedKey.endsWith('signature') ||
        normalizedKey.endsWith('credential');
  }

  static const Set<String> _sensitiveExactKeys = <String>{
    'authorization',
    'proxyauthorization',
    'apikey',
    'accesstoken',
    'refreshtoken',
    'idtoken',
    'authtoken',
    'token',
    'clientsecret',
    'secret',
    'cookie',
    'setcookie',
  };

  static const Set<String> _sensitiveQueryExactKeys = <String>{
    'key',
    'sig',
    'signature',
    'xamzsignature',
    'xamzcredential',
    'xamzsecuritytoken',
  };

  static final RegExp _authorizationValueRe = RegExp(
    r'''^([A-Za-z]+)\s+(.+)$''',
    caseSensitive: false,
  );

  static final RegExp _authorizationPairRe = RegExp(
    r'''(^|[\s,{])(["']?)(authorization|proxy-authorization)\2(\s*[:=]\s*)(?:(["'])(?:([A-Za-z]+)\s+)?([^"'\r\n]*)\5?|(?:([A-Za-z]+)\s+)?([^"'\s&,}\]\r\n]+))''',
    caseSensitive: false,
  );

  static final RegExp _bearerTokenRe = RegExp(
    r'''\b(Bearer)\s+([^\s,;"'&}\]<]+)''',
    caseSensitive: false,
  );

  static final RegExp _inlineSecretPairRe = RegExp(
    r'''(^|[\s,{])(["']?)([A-Za-z0-9_-]*(?:api[_-]?key|token|secret|cookie))\2(\s*[:=]\s*)(?:(["'])([^"'\r\n]*)\5?|([^"'\s&,}\]\r\n]+))''',
    caseSensitive: false,
  );

  static final RegExp _urlUserInfoRe = RegExp(
    r'''([A-Za-z][A-Za-z0-9+.-]*://)([^/?#@\s]+)@''',
  );

  static final RegExp _urlQueryParamRe = RegExp(
    r'''([?&])([^=&#]+)=([^&#]*)''',
    caseSensitive: false,
  );

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
