import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../logging/flutter_logger.dart';
import 'sse_event.dart';

/// Parse a UTF-8 SSE byte stream into [SseEvent]s.
///
/// Handles `id:` / `event:` / `data:` (multiline joined with `\n`) / `retry:`,
/// CRLF, comments, and a final frame that lacks a trailing newline.
Stream<SseEvent> parseSseEvents(
  Stream<List<int>> bytes, {
  bool recoverAdjacentJsonDataRecords = false,
}) {
  return parseSseEventStrings(
    bytes.transform(utf8.decoder),
    recoverAdjacentJsonDataRecords: recoverAdjacentJsonDataRecords,
  );
}

/// Parse an already-decoded SSE text stream into [SseEvent]s.
Stream<SseEvent> parseSseEventStrings(
  Stream<String> chunks, {
  bool recoverAdjacentJsonDataRecords = false,
}) async* {
  final parser = SseEventParser(
    recoverAdjacentJsonDataRecords: recoverAdjacentJsonDataRecords,
  );
  try {
    await for (final chunk in chunks) {
      for (final event in parser.add(chunk)) {
        yield event;
      }
    }
  } catch (error, stackTrace) {
    for (final event in parser._takeEventsBeforeError()) {
      yield event;
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
  for (final event in parser.close()) {
    yield event;
  }
}

/// Incremental SSE framer. One instance per response stream.
class SseEventParser {
  SseEventParser({this.recoverAdjacentJsonDataRecords = false});

  /// Compatibility mode for OpenAI-compatible proxies that omit the blank
  /// delimiter between adjacent, data-only JSON events.
  ///
  /// Enabling this assumes each standalone JSON `data:` line is a complete
  /// event and that `id` / `event` / `retry` fields do not accompany it.
  /// Keep it disabled for general SSE: multiple `data:` lines normally belong
  /// to one event and must be joined with a newline.
  final bool recoverAdjacentJsonDataRecords;

  final StringBuffer _carry = StringBuffer();
  final List<String> _dataLines = <String>[];
  String? _id;
  String? _event;
  int? _retryMillis;
  bool _started = false;
  bool _lastLineWasBlank = false;
  bool _reportedAdjacentJsonRecovery = false;

  List<SseEvent> add(String chunk) {
    if (chunk.isEmpty) return const <SseEvent>[];
    var text = chunk;
    if (!_started) {
      _started = true;
      if (text.startsWith('\uFEFF')) {
        text = text.substring(1);
      }
    }
    _carry.write(text);
    return _drain(flushIncompleteLine: false);
  }

  List<SseEvent> close() {
    final events = _drain(flushIncompleteLine: true);
    events.addAll(_takeEvents());
    return events;
  }

  List<SseEvent> _drain({required bool flushIncompleteLine}) {
    var buffer = _carry.toString();
    _carry.clear();
    final deferTrailingCarriageReturn =
        !flushIncompleteLine && buffer.endsWith('\r');
    if (deferTrailingCarriageReturn) {
      buffer = buffer.substring(0, buffer.length - 1);
    }
    buffer = buffer.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final events = <SseEvent>[];
    while (true) {
      final index = buffer.indexOf('\n');
      if (index < 0) {
        if (flushIncompleteLine) {
          if (buffer.isNotEmpty) _processLine(buffer, events);
        } else if (buffer.isNotEmpty) {
          _carry.write(buffer);
        }
        break;
      }
      _processLine(buffer.substring(0, index), events);
      buffer = buffer.substring(index + 1);
    }
    if (deferTrailingCarriageReturn) _carry.write('\r');
    return events;
  }

  void _processLine(String line, List<SseEvent> events) {
    if (_shouldReleasePendingJsonBefore(line)) {
      _reportAdjacentJsonRecovery(1);
      events.addAll(_takeEvents());
    }
    _handleLine(line);
    if (_lastLineWasBlank || _shouldReleaseDoneNow()) {
      events.addAll(_takeEvents());
    }
  }

  /// In compatibility mode, one complete JSON record is held as one-line
  /// lookahead. The next non-empty `data:` line proves that appending more
  /// payload would no longer be one JSON object, so release the pending record
  /// before buffering the new line.
  bool _shouldReleasePendingJsonBefore(String line) {
    if (!recoverAdjacentJsonDataRecords ||
        _id != null ||
        _event != null ||
        _retryMillis != null ||
        _dataLines.isEmpty) {
      return false;
    }
    final nextData = _dataValueOf(line);
    if (nextData == null || nextData.trim().isEmpty) return false;
    return _isStandaloneJsonObjectOrDone(_dataLines.join('\n'));
  }

  bool _shouldReleaseDoneNow() =>
      recoverAdjacentJsonDataRecords &&
      _id == null &&
      _event == null &&
      _retryMillis == null &&
      _dataLines.length == 1 &&
      _dataLines.single == '[DONE]';

  List<SseEvent> _takeEventsBeforeError() {
    final recovered = <SseEvent>[];
    if (_carry.toString().endsWith('\r')) {
      recovered.addAll(_drain(flushIncompleteLine: true));
    }

    if (!recoverAdjacentJsonDataRecords ||
        _id != null ||
        _event != null ||
        _retryMillis != null ||
        _dataLines.isEmpty ||
        !_isStandaloneJsonObject(_dataLines.join('\n'))) {
      return recovered;
    }
    _reportAdjacentJsonRecovery(1);
    recovered.addAll(_takeEvents());
    return recovered;
  }

  void _handleLine(String line) {
    _lastLineWasBlank = line.isEmpty;
    if (line.isEmpty) return;
    if (line.startsWith(':')) return;

    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'id':
        if (!value.contains('\u0000')) _id = value;
      case 'event':
        _event = value;
      case 'data':
        _dataLines.add(value);
      case 'retry':
        _retryMillis = int.tryParse(value);
    }
  }

  List<SseEvent> _takeEvents() {
    if (_id == null &&
        _event == null &&
        _retryMillis == null &&
        _dataLines.isEmpty) {
      return const <SseEvent>[];
    }
    final joinedData = _dataLines.join('\n');
    // A few OpenAI-compatible proxies occasionally omit the blank line
    // between adjacent `data:` records. In the opt-in compatibility mode,
    // recover data-only events when the combined payload is not one JSON
    // object but every physical data line is. This matches the tolerant line
    // parser used before the provider-independent streaming refactor while
    // preserving genuine multiline SSE by default.
    final splitJsonRecords =
        recoverAdjacentJsonDataRecords &&
        _id == null &&
        _event == null &&
        _retryMillis == null &&
        _dataLines.length > 1 &&
        !_isStandaloneJsonObjectOrDone(joinedData) &&
        _dataLines.every(_isStandaloneJsonObjectOrDone);
    final payloads = splitJsonRecords
        ? List<String>.of(_dataLines)
        : <String>[joinedData];
    if (splitJsonRecords) _reportAdjacentJsonRecovery(payloads.length);
    final events = <SseEvent>[
      for (final data in payloads)
        SseEvent(id: _id, event: _event, data: data, retryMillis: _retryMillis),
    ];
    _resetFields();
    return events;
  }

  void _resetFields() {
    _id = null;
    _event = null;
    _retryMillis = null;
    _dataLines.clear();
    _lastLineWasBlank = false;
  }

  void _reportAdjacentJsonRecovery(int count) {
    if (_reportedAdjacentJsonRecovery) return;
    _reportedAdjacentJsonRecovery = true;
    final message = 'recoveredAdjacentJsonDataRecords count=$count';
    debugPrint('[SseFramingRecovery] $message');
    FlutterLogger.log(message, tag: 'SseFramingRecovery');
  }
}

String? _dataValueOf(String line) {
  if (line.isEmpty || line.startsWith(':')) return null;
  final colon = line.indexOf(':');
  final field = colon < 0 ? line : line.substring(0, colon);
  if (field != 'data') return null;
  var value = colon < 0 ? '' : line.substring(colon + 1);
  if (value.startsWith(' ')) value = value.substring(1);
  return value;
}

bool _isStandaloneJsonObjectOrDone(String data) {
  if (data == '[DONE]') return true;
  return _isStandaloneJsonObject(data);
}

bool _isStandaloneJsonObject(String data) {
  try {
    final decoded = jsonDecode(data);
    return decoded is Map;
  } catch (_) {
    return false;
  }
}
