import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/sse_framing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<SseEvent>> parse(
    String text, {
    bool recoverAdjacentJsonDataRecords = false,
  }) {
    return parseSseEventStrings(
      Stream<String>.value(text),
      recoverAdjacentJsonDataRecords: recoverAdjacentJsonDataRecords,
    ).toList();
  }

  Future<List<SseEvent>> parseChunks(
    List<String> chunks, {
    bool recoverAdjacentJsonDataRecords = false,
  }) {
    return parseSseEventStrings(
      Stream<String>.fromIterable(chunks),
      recoverAdjacentJsonDataRecords: recoverAdjacentJsonDataRecords,
    ).toList();
  }

  List<Map<String, dynamic>> eventSnapshots(Iterable<SseEvent> events) =>
      events.map((event) => event.toJson()).toList();

  List<String> oneCharacterChunks(String source) => <String>[
    for (var index = 0; index < source.length; index++)
      source.substring(index, index + 1),
  ];

  Future<
    ({
      List<Object> sequence,
      StateError sentError,
      StackTrace sentStack,
      StackTrace? receivedStack,
    })
  >
  parseUntilTransportError(String source, {required bool recoveryMode}) async {
    final input = StreamController<String>();
    final sequence = <Object>[];
    final errorSeen = Completer<void>();
    final sentError = StateError('transport failed');
    final sentStack = StackTrace.current;
    StackTrace? receivedStack;
    final subscription =
        parseSseEventStrings(
          input.stream,
          recoverAdjacentJsonDataRecords: recoveryMode,
        ).listen(
          sequence.add,
          onError: (Object error, StackTrace stackTrace) {
            sequence.add(error);
            receivedStack = stackTrace;
            errorSeen.complete();
          },
        );
    input.add(source);
    await Future<void>.delayed(Duration.zero);
    input.addError(sentError, sentStack);
    await errorSeen.future.timeout(const Duration(seconds: 1));
    await input.close();
    await subscription.cancel();
    return (
      sequence: sequence,
      sentError: sentError,
      sentStack: sentStack,
      receivedStack: receivedStack,
    );
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

  test(
    'recovers adjacent JSON data records without blank delimiters',
    () async {
      final events = await parse(
        'data: {"choices":[{"delta":{"content":"*被"}}]}\n'
        'data: {"choices":[{"delta":{"content":"甜*\\n\\n*懒懒地、"}}]}\n'
        'data: [DONE]\n\n',
        recoverAdjacentJsonDataRecords: true,
      );

      expect(events.map((event) => event.data), <String>[
        '{"choices":[{"delta":{"content":"*被"}}]}',
        '{"choices":[{"delta":{"content":"甜*\\n\\n*懒懒地、"}}]}',
        '[DONE]',
      ]);
    },
  );

  test(
    'releases each recovered JSON record when the next data line arrives',
    () async {
      final input = StreamController<String>();
      final events = <SseEvent>[];
      final firstEvent = Completer<void>();
      final secondEvent = Completer<void>();
      final subscription =
          parseSseEventStrings(
            input.stream,
            recoverAdjacentJsonDataRecords: true,
          ).listen((event) {
            events.add(event);
            if (events.length == 1) firstEvent.complete();
            if (events.length == 2) secondEvent.complete();
          });
      addTearDown(() async {
        await input.close();
        await subscription.cancel();
      });

      input.add('data: {"choices":[{"delta":{"content":"one"}}]}\n');
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      input.add('data: {"choices":[{"delta":{"content":"two"}}]}\n');
      await firstEvent.future.timeout(const Duration(seconds: 1));
      expect(events.map((event) => event.data), <String>[
        '{"choices":[{"delta":{"content":"one"}}]}',
      ]);

      input.add('data: {"choices":[{"delta":{"content":"three"}}]}\n');
      await secondEvent.future.timeout(const Duration(seconds: 1));
      expect(events.map((event) => event.data), <String>[
        '{"choices":[{"delta":{"content":"one"}}]}',
        '{"choices":[{"delta":{"content":"two"}}]}',
      ]);
    },
  );

  test(
    'releases DONE without waiting for the recovered stream to close',
    () async {
      final input = StreamController<String>();
      final events = <SseEvent>[];
      final doneEvent = Completer<void>();
      final subscription =
          parseSseEventStrings(
            input.stream,
            recoverAdjacentJsonDataRecords: true,
          ).listen((event) {
            events.add(event);
            if (event.data == '[DONE]') doneEvent.complete();
          });
      addTearDown(() async {
        await input.close();
        await subscription.cancel();
      });

      input.add('data: {"choices":[{"delta":{"content":"last"}}]}\n');
      input.add('data: [DONE]\n');

      await doneEvent.future.timeout(const Duration(seconds: 1));
      expect(events.map((event) => event.data), <String>[
        '{"choices":[{"delta":{"content":"last"}}]}',
        '[DONE]',
      ]);
    },
  );

  test(
    'releases a pending recovered JSON record before a transport error',
    () async {
      final input = StreamController<String>();
      final events = <SseEvent>[];
      final errorSeen = Completer<void>();
      final transportError = StateError('transport failed');
      final transportStack = StackTrace.current;
      Object? receivedError;
      StackTrace? receivedStack;
      final subscription =
          parseSseEventStrings(
            input.stream,
            recoverAdjacentJsonDataRecords: true,
          ).listen(
            events.add,
            onError: (Object error, StackTrace stackTrace) {
              receivedError = error;
              receivedStack = stackTrace;
              errorSeen.complete();
            },
          );
      addTearDown(() async {
        await input.close();
        await subscription.cancel();
      });

      input.add('data: {"choices":[{"delta":{"content":"pending"}}]}\n');
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      input.addError(transportError, transportStack);
      await errorSeen.future.timeout(const Duration(seconds: 1));

      expect(events.map((event) => event.data), <String>[
        '{"choices":[{"delta":{"content":"pending"}}]}',
      ]);
      expect(receivedError, same(transportError));
      expect(receivedStack, same(transportStack));
    },
  );

  test(
    'treats a trailing bare CR as complete before a transport error',
    () async {
      final input = StreamController<String>();
      final events = <SseEvent>[];
      final errorSeen = Completer<void>();
      final transportError = StateError('transport failed after CR');
      final transportStack = StackTrace.current;
      Object? receivedError;
      StackTrace? receivedStack;
      final subscription =
          parseSseEventStrings(
            input.stream,
            recoverAdjacentJsonDataRecords: true,
          ).listen(
            events.add,
            onError: (Object error, StackTrace stackTrace) {
              receivedError = error;
              receivedStack = stackTrace;
              errorSeen.complete();
            },
          );
      addTearDown(() async {
        await input.close();
        await subscription.cancel();
      });

      input.add('data: {"n":1}\r');
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      input.addError(transportError, transportStack);
      await errorSeen.future.timeout(const Duration(seconds: 1));

      expect(events.map((event) => event.data), <String>['{"n":1}']);
      expect(receivedError, same(transportError));
      expect(receivedStack, same(transportStack));
    },
  );

  test(
    'releases a strict bare-CR framed event before a transport error',
    () async {
      final result = await parseUntilTransportError(
        'data: {"n":1}\r\r',
        recoveryMode: false,
      );

      expect(result.sequence, hasLength(2));
      expect((result.sequence.first as SseEvent).data, '{"n":1}');
      expect(result.sequence.last, same(result.sentError));
      expect(result.receivedStack, same(result.sentStack));
    },
  );

  test(
    'keeps metadata on a bare-CR framed event before a transport error',
    () async {
      final result = await parseUntilTransportError(
        'id: 7\revent: update\rretry: 1500\rdata: {"n":1}\r\r',
        recoveryMode: true,
      );

      expect(result.sequence, hasLength(2));
      expect((result.sequence.first as SseEvent).toJson(), <String, dynamic>{
        'id': '7',
        'event': 'update',
        'data': '{"n":1}',
        'retryMillis': 1500,
      });
      expect(result.sequence.last, same(result.sentError));
      expect(result.receivedStack, same(result.sentStack));
    },
  );

  test(
    'does not flush strict or incomplete payloads before a transport error',
    () async {
      Future<List<SseEvent>> eventsBeforeError(
        String source, {
        required bool recoveryMode,
      }) async {
        final input = StreamController<String>();
        final events = <SseEvent>[];
        final errorSeen = Completer<void>();
        final subscription =
            parseSseEventStrings(
              input.stream,
              recoverAdjacentJsonDataRecords: recoveryMode,
            ).listen(
              events.add,
              onError: (Object _, StackTrace __) => errorSeen.complete(),
            );
        input.add(source);
        await Future<void>.delayed(Duration.zero);
        input.addError(StateError('transport failed'), StackTrace.current);
        await errorSeen.future.timeout(const Duration(seconds: 1));
        await input.close();
        await subscription.cancel();
        return events;
      }

      expect(
        await eventsBeforeError('data: {"choices":[]}\n', recoveryMode: false),
        isEmpty,
      );
      expect(await eventsBeforeError('data: {\n', recoveryMode: true), isEmpty);
      expect(
        await eventsBeforeError('data: not-json\n', recoveryMode: true),
        isEmpty,
      );
      expect(
        await eventsBeforeError('data: [DONE]', recoveryMode: true),
        isEmpty,
      );
      expect(
        await eventsBeforeError('data: {"n":1}', recoveryMode: true),
        isEmpty,
      );
      expect(
        await eventsBeforeError('data: {"n":1}\r', recoveryMode: false),
        isEmpty,
      );
      expect(await eventsBeforeError('data: {\r', recoveryMode: true), isEmpty);
      expect(
        await eventsBeforeError('data: not-json\r', recoveryMode: true),
        isEmpty,
      );
      expect(
        await eventsBeforeError('id: 7\ndata: {"n":1}\r', recoveryMode: true),
        isEmpty,
      );
    },
  );

  test(
    'does not report recovery for a standard blank-delimited stream',
    () async {
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      try {
        final events = await parse(
          'data: {"choices":[{"delta":{"content":"complete"}}]}\n\n'
          'data: [DONE]\n\n',
          recoverAdjacentJsonDataRecords: true,
        );

        expect(events.map((event) => event.data), <String>[
          '{"choices":[{"delta":{"content":"complete"}}]}',
          '[DONE]',
        ]);
        expect(
          messages.where((message) => message.contains('SseFramingRecovery')),
          isEmpty,
        );
      } finally {
        debugPrint = previousDebugPrint;
      }
    },
  );

  test(
    'keeps a pretty multiline JSON record pending until its blank line',
    () async {
      final input = StreamController<String>();
      final events = <SseEvent>[];
      final parsedEvent = Completer<void>();
      final subscription =
          parseSseEventStrings(
            input.stream,
            recoverAdjacentJsonDataRecords: true,
          ).listen((event) {
            events.add(event);
            parsedEvent.complete();
          });
      addTearDown(() async {
        await input.close();
        await subscription.cancel();
      });

      input.add('data: {\n');
      input.add('data:   "choices": []\n');
      input.add('data: }\n');
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      input.add('\n');
      await parsedEvent.future.timeout(const Duration(seconds: 1));
      expect(events.single.data, '{\n  "choices": []\n}');
    },
  );

  test('keeps a recovered error object separate from DONE', () async {
    final events = await parse(
      'data: {"choices":[{"delta":{"content":"partial"}}]}\n'
      'data: {"error":{"message":"upstream failed","code":502}}\n'
      'data: [DONE]\n',
      recoverAdjacentJsonDataRecords: true,
    );

    expect(events.map((event) => event.data), <String>[
      '{"choices":[{"delta":{"content":"partial"}}]}',
      '{"error":{"message":"upstream failed","code":502}}',
      '[DONE]',
    ]);
  });

  test('recovers data records when CRLF is split across chunks', () async {
    final events = await parseChunks(<String>[
      'data: {"choices":[{"delta":{"content":"one"}}]}\r',
      '\ndata: {"choices":[{"delta":{"content":"two"}}]}\r',
      '\ndata: [DONE]\r',
      '\n',
    ], recoverAdjacentJsonDataRecords: true);

    expect(events.map((event) => event.data), <String>[
      '{"choices":[{"delta":{"content":"one"}}]}',
      '{"choices":[{"delta":{"content":"two"}}]}',
      '[DONE]',
    ]);
  });

  test(
    'pretty multiline CRLF is invariant when every character is a chunk',
    () async {
      const wire =
          'data: {\r\n'
          'data:   "choices": []\r\n'
          'data: }\r\n'
          '\r\n';
      for (final recoveryMode in <bool>[false, true]) {
        final singleChunk = await parse(
          wire,
          recoverAdjacentJsonDataRecords: recoveryMode,
        );
        final characterChunks = await parseChunks(
          oneCharacterChunks(wire),
          recoverAdjacentJsonDataRecords: recoveryMode,
        );

        expect(eventSnapshots(singleChunk), <Map<String, dynamic>>[
          <String, dynamic>{'data': '{\n  "choices": []\n}'},
        ], reason: 'recoveryMode=$recoveryMode');
        expect(
          eventSnapshots(characterChunks),
          eventSnapshots(singleChunk),
          reason: 'recoveryMode=$recoveryMode',
        );
      }
    },
  );

  test('recovery CRLF is invariant when every character is a chunk', () async {
    const wire =
        'data: {"n":1}\r\n'
        'data: {"n":2}\r\n'
        'data: [DONE]\r\n';
    final singleChunk = await parse(wire, recoverAdjacentJsonDataRecords: true);
    final characterChunks = await parseChunks(
      oneCharacterChunks(wire),
      recoverAdjacentJsonDataRecords: true,
    );

    expect(eventSnapshots(singleChunk), <Map<String, dynamic>>[
      <String, dynamic>{'data': '{"n":1}'},
      <String, dynamic>{'data': '{"n":2}'},
      <String, dynamic>{'data': '[DONE]'},
    ]);
    expect(eventSnapshots(characterChunks), eventSnapshots(singleChunk));
  });

  test('a split CRLF does not masquerade as a blank recovery line', () async {
    final input = StreamController<String>();
    final events = <SseEvent>[];
    final firstEvent = Completer<void>();
    final subscription =
        parseSseEventStrings(
          input.stream,
          recoverAdjacentJsonDataRecords: true,
        ).listen((event) {
          events.add(event);
          if (!firstEvent.isCompleted) firstEvent.complete();
        });
    addTearDown(() async {
      await input.close();
      await subscription.cancel();
    });

    input.add('data: {"n":1}\r');
    input.add('\n');
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);

    input.add('data: {"n":2}\r');
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);

    input.add('\n');
    await firstEvent.future.timeout(const Duration(seconds: 1));
    expect(events.map((event) => event.data), <String>['{"n":1}']);
  });

  test('keeps JSON-looking multiline data joined by default', () async {
    final events = await parse(
      'event: batch\n'
      'id: 7\n'
      'data: {"a":1}\n'
      'data: {"b":2}\n\n',
    );

    expect(events, hasLength(1));
    expect(events.single.event, 'batch');
    expect(events.single.id, '7');
    expect(events.single.data, '{"a":1}\n{"b":2}');
  });

  test(
    'keeps one valid multiline JSON object joined in recovery mode',
    () async {
      final events = await parse(
        'data: {\n'
        'data:   "choices": []\n'
        'data: }\n\n',
        recoverAdjacentJsonDataRecords: true,
      );

      expect(events, hasLength(1));
      expect(events.single.data, '{\n  "choices": []\n}');
    },
  );

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

  test(
    'EOF applies recovery lookahead before an unterminated DONE line',
    () async {
      final events = await parse(
        'data: {\n'
        'data:   "choices": []\n'
        'data: }\n'
        'data: [DONE]',
        recoverAdjacentJsonDataRecords: true,
      );

      expect(events.map((event) => event.data), <String>[
        '{\n  "choices": []\n}',
        '[DONE]',
      ]);
    },
  );

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
