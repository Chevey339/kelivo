import 'dart:convert';

import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/sse_framing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<SseEvent>> parse(String text) {
    return parseSseEventStrings(Stream<String>.value(text)).toList();
  }

  Future<List<SseEvent>> parseChunks(List<String> chunks) {
    return parseSseEventStrings(Stream<String>.fromIterable(chunks)).toList();
  }

  test('parses id, event, data, and retry', () async {
    final events = await parse(
      'id: 42\nevent: message_delta\nretry: 1500\ndata: {"ok":true}\n\n',
    );

    expect(events, hasLength(1));
    expect(events.single.id, '42');
    expect(events.single.event, 'message_delta');
    expect(events.single.retryMillis, 1500);
    expect(events.single.data, '{"ok":true}');
  });

  test('joins multiline data with a newline', () async {
    final events = await parse('data: hello\ndata: world\n\n');
    expect(events.single.data, 'hello\nworld');
  });

  test('strips only one leading space after the colon', () async {
    final events = await parse('data:  {"a":1}\n\n');
    expect(events.single.data, ' {"a":1}');
  });

  test('accepts a field with no space after the colon', () async {
    final events = await parse('data:{"a":1}\n\n');
    expect(events.single.data, '{"a":1}');
  });

  test('treats CRLF as a line ending', () async {
    final events = await parse('data: one\r\n\r\ndata: two\r\n\r\n');
    expect(events.map((e) => e.data), <String>['one', 'two']);
  });

  test('ignores comment lines', () async {
    final events = await parse(': keep-alive\ndata: hi\n\n');
    expect(events, hasLength(1));
    expect(events.single.data, 'hi');
  });

  test('flushes a final frame that lacks a trailing newline', () async {
    final events = await parseChunks(['data: {"n":1}\n\n', 'data: [DONE]']);
    expect(events.map((e) => e.data), <String>['{"n":1}', '[DONE]']);
  });

  test('flushes a final data line without [DONE] or a blank line', () async {
    final events = await parse('data: {"n":2}');
    expect(events.single.data, '{"n":2}');
  });

  test(
    'does not duplicate an event that already ended with a blank line',
    () async {
      final events = await parse('data: once\n\n');
      expect(events, hasLength(1));
      expect(events.single.data, 'once');
    },
  );

  test('a split JSON payload across chunks is reassembled', () async {
    final events = await parseChunks(['data: {"msg":"hel', 'lo"}\n\n']);
    expect(events.single.data, '{"msg":"hello"}');
  });

  test(
    'close can emit a completed event and a trailing unfinished frame',
    () async {
      final events = await parseChunks(['data: a\n\ndata: b']);
      expect(events.map((e) => e.data), <String>['a', 'b']);
    },
  );

  test('byte stream entry point decodes UTF-8', () async {
    final events = await parseSseEvents(
      Stream<List<int>>.value(utf8.encode('data: 你好\n\n')),
    ).toList();
    expect(events.single.data, '你好');
  });

  test('strips a leading UTF-8 BOM', () async {
    final events = await parse('\uFEFFdata: bom\n\n');
    expect(events.single.data, 'bom');
  });
}
