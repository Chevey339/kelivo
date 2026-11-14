import 'dart:convert';

import '../../../core/services/logging/log_payload_elider.dart';

class RequestLogEntry {
  RequestLogEntry({
    required this.id,
    required this.sequence,
    this.startedAt,
    this.lastEventAt,
    this.method,
    this.rawUrl,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    this.requestBodyTruncated = 0,
    this.responseBodyTruncated = 0,
    List<LogPayloadRef>? attachments,
    List<String>? errors,
    List<String>? warnings,
  }) : attachments = attachments ?? <LogPayloadRef>[],
       errors = errors ?? <String>[],
       warnings = warnings ?? <String>[];

  final int id;
  // Monotonic sequence to disambiguate duplicate ids across app restarts.
  final int sequence;

  DateTime? startedAt;
  DateTime? lastEventAt;

  String? method;
  String? rawUrl;

  Map<String, dynamic>? requestHeaders;
  String? requestBody;

  int? statusCode;
  Map<String, dynamic>? responseHeaders;
  String? responseBody;

  /// Characters dropped from each body by the parser's size cap.
  int requestBodyTruncated;
  int responseBodyTruncated;

  /// Inline base64 images/files that were replaced by placeholders.
  final List<LogPayloadRef> attachments;

  final List<String> errors;
  final List<String> warnings;

  // Parsed lazily rather than stored: keeps the entry cheap to send across
  // an isolate boundary, and most entries never need the parsed form.
  Uri? _uri;
  bool _uriParsed = false;

  Uri? get uri {
    if (_uriParsed) return _uri;
    _uriParsed = true;
    final url = rawUrl;
    _uri = (url == null || url.isEmpty) ? null : Uri.tryParse(url);
    return _uri;
  }

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

enum RequestLogKind {
  request,
  requestHeaders,
  requestBody,
  status,
  responseHeaders,
  responseBody,
  chunk,
  done,
  error,
}

/// One timestamped event. Headers may occupy multiple physical lines.
class RequestLogRecord {
  const RequestLogRecord(
    this.timestamp,
    this.id,
    this.kind,
    this.value, {
    this.method,
  });
  final DateTime timestamp;
  final int id;
  final RequestLogKind kind;
  final String value;
  final String? method;

  static final _timestamp = RegExp(
    r'^\[(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3})\]\s+(.*)$',
  );
  static final _event = RegExp(r'^\[(REQ|RES) (\d+)\]\s+(.*)$', dotAll: true);
  static final _method = RegExp(r'^([A-Z]+)\s+(.*)$', dotAll: true);

  static ({DateTime timestamp, String message})? startLine(String line) {
    final match = _timestamp.firstMatch(line.trimRight());
    if (match == null) return null;
    int g(int i) => int.parse(match.group(i)!);
    return (
      timestamp: DateTime(g(1), g(2), g(3), g(4), g(5), g(6), g(7)),
      message: match.group(8)!,
    );
  }

  static RequestLogRecord? parse(DateTime timestamp, String message) {
    final match = _event.firstMatch(message);
    if (match == null) return null;
    final id = int.tryParse(match.group(2)!);
    if (id == null) return null;
    final request = match.group(1) == 'REQ';
    final text = match.group(3)!;
    if (request) {
      final start = _method.firstMatch(text);
      if (start != null) {
        return RequestLogRecord(
          timestamp,
          id,
          RequestLogKind.request,
          start.group(2)!.trim(),
          method: start.group(1),
        );
      }
    }
    final fields = request
        ? const {
            'headers=': RequestLogKind.requestHeaders,
            'body=': RequestLogKind.requestBody,
          }
        : const {
            'status=': RequestLogKind.status,
            'headers=': RequestLogKind.responseHeaders,
            'body=': RequestLogKind.responseBody,
            'chunk=': RequestLogKind.chunk,
            'error=': RequestLogKind.error,
            'dio_error=': RequestLogKind.error,
          };
    for (final field in fields.entries) {
      if (text.startsWith(field.key)) {
        final value = text.substring(field.key.length);
        if (field.value == RequestLogKind.status &&
            int.tryParse(value.trim()) == null) {
          return null;
        }
        return RequestLogRecord(timestamp, id, field.value, value);
      }
    }
    if (!request && text.trimRight() == 'done') {
      return RequestLogRecord(timestamp, id, RequestLogKind.done, '');
    }
    return null;
  }
}

class RequestLogParser {
  static const int defaultMaxBodyChars = 256 * 1024;

  static List<RequestLogEntry> parse(
    String content, {
    bool elide = true,
    int maxBodyChars = defaultMaxBodyChars,
  }) {
    final parser = _RequestLogAccumulator(elide, maxBodyChars);
    final records = _RequestLogLines(parser.add);
    for (final line in LineSplitter.split(content)) {
      records.add(line);
    }
    records.finish();
    return parser.finish();
  }

  /// Consumes physical lines without retaining the whole file or its records.
  /// [requestId] avoids assembling other requests' bodies in a selected range.
  static Future<List<RequestLogEntry>> parseStream(
    Stream<String> lines, {
    bool elide = true,
    int maxBodyChars = defaultMaxBodyChars,
    int? requestId,
  }) async {
    final parser = _RequestLogAccumulator(elide, maxBodyChars);
    final records = _RequestLogLines((record) {
      if (requestId == null || record.id == requestId) parser.add(record);
    });
    await for (final line in lines) {
      records.add(line);
    }
    records.finish();
    return parser.finish();
  }

  static Map<String, dynamic>? decodeHeaders(String text) {
    try {
      final value = jsonDecode(text);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) {
      return null;
    }
  }

  static final RegExp _escapeRe = RegExp(r'\\[nrt\\]');

  /// Reverses RequestLogger.escape() in a single native pass.
  static String unescape(String input) =>
      input.replaceAllMapped(_escapeRe, (m) {
        switch (m[0]![1]) {
          case 'n':
            return '\n';
          case 'r':
            return '\r';
          case 't':
            return '\t';
          default:
            return '\\';
        }
      });
}

class _RequestLogLines {
  _RequestLogLines(this.onRecord);
  final void Function(RequestLogRecord) onRecord;
  DateTime? _timestamp;
  StringBuffer _message = StringBuffer();

  void add(String rawLine) {
    final line = rawLine.trimRight();
    final start = RequestLogRecord.startLine(line);
    if (start != null) {
      finish();
      _timestamp = start.timestamp;
      _message.write(start.message);
    } else if (_timestamp != null) {
      _message.write('\n$line');
    }
  }

  void finish() {
    final timestamp = _timestamp;
    if (timestamp == null) return;
    final record = RequestLogRecord.parse(timestamp, _message.toString());
    if (record != null) onRecord(record);
    _timestamp = null;
    _message = StringBuffer();
  }
}

class _RequestLogAccumulator {
  _RequestLogAccumulator(this.elide, this.maxBodyChars);
  final bool elide;
  final int maxBodyChars;
  final _entries = <RequestLogEntry>[];
  final _current = <int, RequestLogEntry>{};
  final _chunks = <int, StringBuffer>{};
  int _sequence = 0;

  RequestLogEntry _create(int id) {
    final entry = RequestLogEntry(id: id, sequence: ++_sequence);
    _entries.add(entry);
    return _current[id] = entry;
  }

  ({String text, int truncated}) _body(String body, RequestLogEntry entry) {
    final result = LogPayloadElider.process(body, rewrite: elide);
    entry.attachments.addAll(result.refs);
    final text = result.text;
    if (maxBodyChars > 0 && text.length > maxBodyChars) {
      return (
        text: text.substring(0, maxBodyChars),
        truncated: text.length - maxBodyChars,
      );
    }
    return (text: text, truncated: 0);
  }

  void add(RequestLogRecord record) {
    final entry = record.kind == RequestLogKind.request
        ? _create(record.id)
        : (_current[record.id] ?? _create(record.id));
    entry.lastEventAt = record.timestamp;
    entry.startedAt ??= record.timestamp;
    final value = record.value;
    switch (record.kind) {
      case RequestLogKind.request:
        entry.method = record.method;
        entry.rawUrl = value;
      case RequestLogKind.requestHeaders:
      case RequestLogKind.responseHeaders:
        final headers = RequestLogParser.decodeHeaders(value.trim());
        final request = record.kind == RequestLogKind.requestHeaders;
        if (request) {
          entry.requestHeaders = headers;
        } else {
          entry.responseHeaders = headers;
        }
        if (headers == null && value.trim().isNotEmpty) {
          entry.warnings.add(
            'Failed to parse ${request ? 'request' : 'response'} headers JSON',
          );
        }
      case RequestLogKind.requestBody:
        final body = _body(RequestLogParser.unescape(value.trim()), entry);
        entry.requestBody = body.text;
        entry.requestBodyTruncated = body.truncated;
      case RequestLogKind.status:
        entry.statusCode = int.parse(value.trim());
      case RequestLogKind.responseBody:
        final body = _body(RequestLogParser.unescape(value.trim()), entry);
        entry.responseBody = body.text;
        entry.responseBodyTruncated = body.truncated;
        if (body.text.isNotEmpty &&
            (entry.statusCode == null || entry.statusCode! >= 400) &&
            (entry.errors.isEmpty || entry.errors.last != body.text)) {
          entry.errors.add(body.text);
        }
      case RequestLogKind.chunk:
        _chunks
            .putIfAbsent(
              entry.sequence,
              () => StringBuffer(entry.responseBody ?? ''),
            )
            .write(RequestLogParser.unescape(value));
      case RequestLogKind.done:
        break;
      case RequestLogKind.error:
        final error = RequestLogParser.unescape(value.trim());
        if (error.isNotEmpty) entry.errors.add(error);
    }
  }

  List<RequestLogEntry> finish() {
    for (final entry in _entries) {
      final chunks = _chunks[entry.sequence];
      if (chunks == null) continue;
      final body = _body(chunks.toString(), entry);
      entry.responseBody = body.text;
      entry.responseBodyTruncated = body.truncated;
    }
    _entries.sort((a, b) {
      final time = b.startedAt!.compareTo(a.startedAt!);
      return time != 0 ? time : b.sequence.compareTo(a.sequence);
    });
    return _entries;
  }
}
