import 'dart:convert';

class RequestLogEntry {
  RequestLogEntry({
    required this.id,
    required this.sequence,
    this.startedAt,
    this.lastEventAt,
    this.method,
    this.rawUrl,
    this.uri,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    List<String>? errors,
    List<String>? warnings,
  }) : errors = errors ?? <String>[],
       warnings = warnings ?? <String>[];

  final int id;
  // Monotonic sequence to disambiguate duplicate ids across app restarts.
  final int sequence;

  DateTime? startedAt;
  DateTime? lastEventAt;

  String? method;
  String? rawUrl;
  Uri? uri;

  Map<String, dynamic>? requestHeaders;
  String? requestBody;

  int? statusCode;
  Map<String, dynamic>? responseHeaders;
  String? responseBody;

  final List<String> errors;
  final List<String> warnings;

  bool get hasError =>
      errors.isNotEmpty || (statusCode != null && statusCode! >= 400);
  bool get hasWarning =>
      warnings.isNotEmpty ||
      (statusCode != null && statusCode! >= 300 && statusCode! < 400);

  Duration? get duration {
    final s = startedAt;
    final e = lastEventAt;
    if (s == null || e == null) return null;
    return e.difference(s);
  }
}

class RequestLogParser {
  static final RegExp _tsRe = RegExp(
    r'^\[(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3})\]\s+(.*)$',
  );

  static final RegExp _reqStartRe = RegExp(
    r'^\[REQ (\d+)\]\s+([A-Z]+)\s+(.*)$',
    dotAll: true,
  );
  static final RegExp _reqHeadersRe = RegExp(
    r'^\[REQ (\d+)\]\s+headers=(.*)$',
    dotAll: true,
  );
  static final RegExp _reqBodyRe = RegExp(
    r'^\[REQ (\d+)\]\s+body=(.*)$',
    dotAll: true,
  );

  static final RegExp _resStatusRe = RegExp(
    r'^\[RES (\d+)\]\s+status=(\d+)\s*$',
    dotAll: true,
  );
  static final RegExp _resHeadersRe = RegExp(
    r'^\[RES (\d+)\]\s+headers=(.*)$',
    dotAll: true,
  );
  static final RegExp _resChunkRe = RegExp(
    r'^\[RES (\d+)\]\s+chunk=(.*)$',
    dotAll: true,
  );
  static final RegExp _resDoneRe = RegExp(
    r'^\[RES (\d+)\]\s+done\s*$',
    dotAll: true,
  );
  static final RegExp _resErrRe = RegExp(
    r'^\[RES (\d+)\]\s+error=(.*)$',
    dotAll: true,
  );
  static final RegExp _resDioErrRe = RegExp(
    r'^\[RES (\d+)\]\s+dio_error=(.*)$',
    dotAll: true,
  );

  static List<RequestLogEntry> parse(String content) {
    final records = _toRecords(content);

    final List<RequestLogEntry> entries = <RequestLogEntry>[];
    final Map<int, int> currentIndexById = <int, int>{};
    int seq = 0;

    RequestLogEntry ensureEntry(int id) {
      final idx = currentIndexById[id];
      if (idx != null) return entries[idx];
      final e = RequestLogEntry(id: id, sequence: ++seq);
      entries.add(e);
      currentIndexById[id] = entries.length - 1;
      return e;
    }

    void touch(RequestLogEntry e, DateTime ts) {
      e.lastEventAt = ts;
      e.startedAt ??= ts;
    }

    for (final record in records) {
      final ts = record.ts;
      final msg = record.message;

      final mStart = _reqStartRe.firstMatch(msg);
      if (mStart != null) {
        final id = int.tryParse(mStart.group(1) ?? '');
        if (id == null) continue;

        final e = RequestLogEntry(id: id, sequence: ++seq);
        e.startedAt = ts;
        e.lastEventAt = ts;
        e.method = (mStart.group(2) ?? '').trim();
        final url = (mStart.group(3) ?? '').trim();
        e.rawUrl = url;
        e.uri = Uri.tryParse(url);
        entries.add(e);
        currentIndexById[id] = entries.length - 1;
        continue;
      }

      final mReqHeaders = _reqHeadersRe.firstMatch(msg);
      if (mReqHeaders != null) {
        final id = int.tryParse(mReqHeaders.group(1) ?? '');
        if (id == null) continue;
        final e = ensureEntry(id);
        touch(e, ts);
        final jsonText = (mReqHeaders.group(2) ?? '').trim();
        e.requestHeaders = _decodeJsonMap(jsonText);
        if (e.requestHeaders == null && jsonText.isNotEmpty) {
          e.warnings.add('Failed to parse request headers JSON');
        }
        continue;
      }

      final mReqBody = _reqBodyRe.firstMatch(msg);
      if (mReqBody != null) {
        final id = int.tryParse(mReqBody.group(1) ?? '');
        if (id == null) continue;
        final e = ensureEntry(id);
        touch(e, ts);
        e.requestBody = unescape((mReqBody.group(2) ?? '').trim());
        continue;
      }

      final mStatus = _resStatusRe.firstMatch(msg);
      if (mStatus != null) {
        final id = int.tryParse(mStatus.group(1) ?? '');
        final code = int.tryParse(mStatus.group(2) ?? '');
        if (id == null) continue;
        final e = ensureEntry(id);
        touch(e, ts);
        e.statusCode = code;
        continue;
      }

      final mResHeaders = _resHeadersRe.firstMatch(msg);
      if (mResHeaders != null) {
        final id = int.tryParse(mResHeaders.group(1) ?? '');
        if (id == null) continue;
        final e = ensureEntry(id);
        touch(e, ts);
        final jsonText = (mResHeaders.group(2) ?? '').trim();
        e.responseHeaders = _decodeJsonMap(jsonText);
        if (e.responseHeaders == null && jsonText.isNotEmpty) {
          e.warnings.add('Failed to parse response headers JSON');
        }
        continue;
      }

      final mChunk = _resChunkRe.firstMatch(msg);
      if (mChunk != null) {
        final id = int.tryParse(mChunk.group(1) ?? '');
        if (id == null) continue;
        final e = ensureEntry(id);
        touch(e, ts);
        final chunk = unescape(mChunk.group(2) ?? '');
        final prev = e.responseBody ?? '';
        e.responseBody = prev + chunk;
        continue;
      }

      final mDone = _resDoneRe.firstMatch(msg);
      if (mDone != null) {
        final id = int.tryParse(mDone.group(1) ?? '');
        if (id == null) continue;
        final e = ensureEntry(id);
        touch(e, ts);
        continue;
      }

      final mErr = _resErrRe.firstMatch(msg);
      if (mErr != null) {
        final id = int.tryParse(mErr.group(1) ?? '');
        if (id == null) continue;
        final e = ensureEntry(id);
        touch(e, ts);
        final err = unescape((mErr.group(2) ?? '').trim());
        if (err.isNotEmpty) e.errors.add(err);
        continue;
      }

      final mDioErr = _resDioErrRe.firstMatch(msg);
      if (mDioErr != null) {
        final id = int.tryParse(mDioErr.group(1) ?? '');
        if (id == null) continue;
        final e = ensureEntry(id);
        touch(e, ts);
        final err = unescape((mDioErr.group(2) ?? '').trim());
        if (err.isNotEmpty) e.errors.add(err);
        continue;
      }
    }

    // Newest first (when possible)
    entries.sort((a, b) {
      final at = a.startedAt ?? a.lastEventAt;
      final bt = b.startedAt ?? b.lastEventAt;
      if (at == null && bt == null) return b.sequence.compareTo(a.sequence);
      if (at == null) return 1;
      if (bt == null) return -1;
      final c = bt.compareTo(at);
      if (c != 0) return c;
      return b.sequence.compareTo(a.sequence);
    });

    return entries;
  }

  static List<_LogRecord> _toRecords(String content) {
    final List<_LogRecord> out = <_LogRecord>[];
    final lines = content.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty && out.isEmpty) continue;

      final m = _tsRe.firstMatch(line);
      if (m != null) {
        final ts = _parseTs(m);
        final msg = m.group(8) ?? '';
        out.add(_LogRecord(ts: ts, message: msg));
        continue;
      }

      if (out.isEmpty) continue;
      out.last.message += '\n$line';
    }
    return out;
  }

  static DateTime _parseTs(RegExpMatch m) {
    int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6), g(7));
  }

  static Map<String, dynamic>? _decodeJsonMap(String text) {
    try {
      final v = jsonDecode(text);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Reverses `RequestLogger.escape()` (handles `\\`, `\\r`, `\\n`, `\\t`).
  static String unescape(String input) {
    if (input.isEmpty) return input;
    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '\\' && i + 1 < input.length) {
        final next = input[i + 1];
        switch (next) {
          case 'n':
            sb.write('\n');
            i++;
            continue;
          case 'r':
            sb.write('\r');
            i++;
            continue;
          case 't':
            sb.write('\t');
            i++;
            continue;
          case '\\':
            sb.write('\\');
            i++;
            continue;
          default:
            // Preserve unknown escape as-is.
            sb.write('\\');
            continue;
        }
      }
      sb.write(ch);
    }
    return sb.toString();
  }
}

class _LogRecord {
  _LogRecord({required this.ts, required this.message});
  final DateTime ts;
  String message;
}
