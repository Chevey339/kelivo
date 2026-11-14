import 'dart:convert';
import 'dart:io';

import '../../../core/services/logging/reverse_log_reader.dart';
import '../../../core/services/logging/log_payload_elider.dart';
import 'request_log_parser.dart';

/// A request instance is identified by its newest event's byte offset. IDs
/// alone are not unique: the writer resets them on every app launch.
class RequestLogItem {
  RequestLogItem(this.entry, this.end, this.earliest, this.snapshot);

  final RequestLogEntry entry;
  final int end;
  final LogFileSnapshot snapshot;
  int earliest;
  int? start;
  String? _pendingBody;
  String? _bodyError;
  String? _explicitError;

  RequestLogItem copy() =>
      RequestLogItem(
          RequestLogEntry(
            id: entry.id,
            sequence: entry.sequence,
            startedAt: entry.startedAt,
            lastEventAt: entry.lastEventAt,
            method: entry.method,
            rawUrl: entry.rawUrl,
            statusCode: entry.statusCode,
            warnings: List.of(entry.warnings),
            errors: List.of(entry.errors),
          ),
          end,
          earliest,
          snapshot,
        )
        ..start = start
        .._pendingBody = _pendingBody
        .._bodyError = _bodyError
        .._explicitError = _explicitError;

  void _add(RequestLogRecord record, int offset, bool elide) {
    earliest = offset;
    entry.startedAt = record.timestamp;
    entry.lastEventAt ??= record.timestamp;
    switch (record.kind) {
      case RequestLogKind.request:
        start = offset;
        entry.method = record.method;
        entry.rawUrl = record.value;
      case RequestLogKind.status:
        final status = int.parse(record.value.trim());
        entry.statusCode ??= status;
        if (status >= 400 && _pendingBody != null) _bodyError = _pendingBody;
        _pendingBody = null;
      case RequestLogKind.requestHeaders:
      case RequestLogKind.responseHeaders:
        final value = record.value.trim();
        if (value.isNotEmpty && RequestLogParser.decodeHeaders(value) == null) {
          final side = record.kind == RequestLogKind.requestHeaders
              ? 'request'
              : 'response';
          final warning = 'Failed to parse $side headers JSON';
          if (!entry.warnings.contains(warning)) entry.warnings.add(warning);
        }
      case RequestLogKind.error:
        final text = _preview(record.value);
        if (text.isNotEmpty) _explicitError = text;
      case RequestLogKind.responseBody:
        final body = LogPayloadElider.process(
          RequestLogParser.unescape(record.value.trim()),
          rewrite: elide,
        ).text;
        final text = body.length > 512 ? body.substring(0, 512) : body;
        if (text.isNotEmpty) _pendingBody = text;
      case RequestLogKind.requestBody:
      case RequestLogKind.chunk:
      case RequestLogKind.done:
        break;
    }
    entry.errors.clear();
    final error = _explicitError ?? _bodyError ?? _pendingBody;
    if (error != null) entry.errors.add(error);
  }

  static String _preview(String value) {
    final text = value.trim();
    return RequestLogParser.unescape(
      text.length > 512 ? text.substring(0, 512) : text,
    );
  }
}

class RequestLogTailCursor {
  const RequestLogTailCursor({
    this.position,
    this.open = const {},
    this.snapshot,
  });
  final LogFileSnapshot? snapshot;
  final int? position;

  /// Only requests whose start has not yet been encountered going backwards.
  final Map<int, RequestLogItem> open;
}

class RequestLogTailPage {
  const RequestLogTailPage(this.items, this.cursor);

  /// New or updated summaries; merge by entry.sequence, not request ID.
  final List<RequestLogItem> items;
  final RequestLogTailCursor cursor;
  bool get hasMore => cursor.position != null && cursor.position! > 0;
}

class RequestLogTailReader {
  static Future<RequestLogTailPage> readPage({
    required String path,
    RequestLogTailCursor cursor = const RequestLogTailCursor(),
    int limit = 30,
    bool elide = true,
    int maxBytes = 256 * 1024,
    int chunkSize = 128 * 1024,
  }) async {
    final reader = await ReverseLogReader.open(
      File(path),
      end: cursor.position,
      chunkSize: chunkSize,
      snapshot: cursor.snapshot,
    );
    try {
      final end = reader.position;
      final open = {
        for (final pair in cursor.open.entries) pair.key: pair.value.copy(),
      };
      final changed = <int, RequestLogItem>{};
      var completed = 0;
      // The byte budget is soft: finish the current timestamped record so
      // multi-line headers and UTF-8 characters never straddle page cursors.
      while (reader.position > 0 &&
          completed < limit &&
          end - reader.position < maxBytes) {
        final record = await _readRecord(reader);
        if (record == null) continue;
        final event = record.event;
        final item = open.putIfAbsent(
          event.id,
          () => RequestLogItem(
            RequestLogEntry(id: event.id, sequence: record.end),
            record.end,
            record.start,
            reader.snapshot,
          ),
        );
        item._add(event, record.start, elide);
        changed[item.entry.sequence] = item;
        if (event.kind == RequestLogKind.request) {
          open.remove(event.id);
          completed++;
        }
      }
      return RequestLogTailPage(
        changed.values.toList(),
        RequestLogTailCursor(
          position: reader.position,
          snapshot: reader.snapshot,
          open: reader.position == 0 ? const {} : open,
        ),
      );
    } finally {
      await reader.close();
    }
  }

  /// Resolve an unfinished request back to its start, then stream only that
  /// instance's range. Other interleaved IDs never enter the body accumulator.
  static Future<RequestLogEntry> readDetail({
    required String path,
    required RequestLogItem item,
    required bool elide,
  }) async {
    final reader = await ReverseLogReader.open(
      File(path),
      end: item.earliest,
      snapshot: item.snapshot,
    );
    try {
      var start = item.start;
      if (start == null) {
        while (reader.position > 0) {
          final record = await _readRecord(reader);
          if (record?.event.id == item.entry.id &&
              record?.event.kind == RequestLogKind.request) {
            start = record!.start;
            break;
          }
        }
        start ??= 0;
      }
      final entries = await RequestLogParser.parseStream(
        reader
            .readRange(start, item.end)
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
        requestId: item.entry.id,
        elide: elide,
      );
      if (entries.isEmpty) {
        throw const FormatException('Request is no longer in the log');
      }
      return entries.first;
    } finally {
      await reader.close();
    }
  }

  static Future<({RequestLogRecord event, int start, int end})?> _readRecord(
    ReverseLogReader reader,
  ) async {
    final end = reader.position;
    final continuation = <String>[];
    while (reader.position > 0) {
      final line = await reader.readLine();
      if (line == null) break;
      final text = utf8.decode(line.bytes, allowMalformed: true).trimRight();
      final header = RequestLogRecord.startLine(text);
      if (header != null) {
        final message = StringBuffer(header.message);
        for (final part in continuation.reversed) {
          message.write('\n$part');
        }
        final event = RequestLogRecord.parse(
          header.timestamp,
          message.toString(),
        );
        return event == null
            ? null
            : (event: event, start: reader.position, end: end);
      }
      continuation.add(text);
    }
    return null;
  }
}
