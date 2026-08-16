import 'dart:convert';

import 'sse_event.dart';

/// Parse a UTF-8 SSE byte stream into [SseEvent]s.
///
/// Handles `id:` / `event:` / `data:` (multiline joined with `\n`) / `retry:`,
/// CRLF, comments, and a final frame that lacks a trailing newline.
Stream<SseEvent> parseSseEvents(Stream<List<int>> bytes) {
  return parseSseEventStrings(bytes.transform(utf8.decoder));
}

/// Parse an already-decoded SSE text stream into [SseEvent]s.
Stream<SseEvent> parseSseEventStrings(Stream<String> chunks) async* {
  final parser = SseEventParser();
  await for (final chunk in chunks) {
    for (final event in parser.add(chunk)) {
      yield event;
    }
  }
  for (final event in parser.close()) {
    yield event;
  }
}

/// Incremental SSE framer. One instance per response stream.
class SseEventParser {
  final StringBuffer _carry = StringBuffer();
  final List<String> _dataLines = <String>[];
  String? _id;
  String? _event;
  int? _retryMillis;
  bool _started = false;
  bool _lastLineWasBlank = false;

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
    final pending = _takeEvent();
    if (pending != null) events.add(pending);
    return events;
  }

  List<SseEvent> _drain({required bool flushIncompleteLine}) {
    var buffer = _carry
        .toString()
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    _carry.clear();
    final events = <SseEvent>[];
    while (true) {
      final index = buffer.indexOf('\n');
      if (index < 0) {
        if (flushIncompleteLine) {
          if (buffer.isNotEmpty) _handleLine(buffer);
        } else if (buffer.isNotEmpty) {
          _carry.write(buffer);
        }
        break;
      }
      _handleLine(buffer.substring(0, index));
      buffer = buffer.substring(index + 1);
      if (_lastLineWasBlank) {
        final event = _takeEvent();
        if (event != null) events.add(event);
      }
    }
    return events;
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

  SseEvent? _takeEvent() {
    if (_id == null &&
        _event == null &&
        _retryMillis == null &&
        _dataLines.isEmpty) {
      return null;
    }
    final event = SseEvent(
      id: _id,
      event: _event,
      data: _dataLines.join('\n'),
      retryMillis: _retryMillis,
    );
    _resetFields();
    return event;
  }

  void _resetFields() {
    _id = null;
    _event = null;
    _retryMillis = null;
    _dataLines.clear();
    _lastLineWasBlank = false;
  }
}
