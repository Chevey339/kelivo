import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_emit.dart';
import 'package:flutter_test/flutter_test.dart';

void expectValidUtf16(String value) {
  for (var i = 0; i < value.length; i++) {
    final codeUnit = value.codeUnitAt(i);
    if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
      expect(
        i + 1 < value.length &&
            value.codeUnitAt(i + 1) >= 0xDC00 &&
            value.codeUnitAt(i + 1) <= 0xDFFF,
        isTrue,
        reason: 'lone high surrogate at $i',
      );
      i++;
    } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
      fail('lone low surrogate at $i');
    }
  }
}

Stream<StreamChunk> chunks(Iterable<StreamChunk> source) =>
    Stream.fromIterable(source);

void main() {
  test('rejoins emoji split across TextDelta boundaries', () async {
    const id = 'text-1';
    final out = await carrySplitSurrogates(
      chunks([
        const TextDelta(id: id, text: 'a\ud83c'),
        const TextDelta(id: id, text: '\udf1fb'),
      ]),
    ).toList();

    expect(out, hasLength(2));
    expect(out[0], isA<TextDelta>());
    expect(out[1], isA<TextDelta>());
    expect((out[0] as TextDelta).id, id);
    expect((out[0] as TextDelta).text, 'a');
    expect((out[1] as TextDelta).id, id);
    expect((out[1] as TextDelta).text, '\u{1F31F}b');
    for (final chunk in out) {
      if (chunk is TextDelta) expectValidUtf16(chunk.text);
    }
  });

  test('flushes trailing lone high surrogate on Finish', () async {
    const id = 'text-1';
    final out = await carrySplitSurrogates(
      chunks([const TextDelta(id: id, text: '\ud83c'), const Finish()]),
    ).toList();

    expect(out, hasLength(2));
    expect(out[0], isA<TextDelta>());
    expect(out[1], isA<Finish>());
    expect((out[0] as TextDelta).id, id);
    expect((out[0] as TextDelta).text, '\uFFFD');
    expectValidUtf16((out[0] as TextDelta).text);
  });

  test('replaces lone low surrogate in the middle with U+FFFD', () async {
    const id = 'text-1';
    final out = await carrySplitSurrogates(
      chunks([const TextDelta(id: id, text: 'a\udf1fb')]),
    ).toList();

    expect(out, hasLength(1));
    expect(out.single, isA<TextDelta>());
    expect((out.single as TextDelta).text, 'a\uFFFDb');
    expectValidUtf16((out.single as TextDelta).text);
  });

  test('text and reasoning carries are independent', () async {
    const textId = 'text-1';
    const reasoningId = 'reasoning-1';
    final out = await carrySplitSurrogates(
      chunks([
        const TextDelta(id: textId, text: 'a\ud83c'),
        const ReasoningDelta(id: reasoningId, text: 'x\ud83c'),
        const TextDelta(id: textId, text: '\udf1fb'),
        const ReasoningDelta(id: reasoningId, text: '\udf1fy'),
      ]),
    ).toList();

    expect(out, hasLength(4));
    expect((out[0] as TextDelta).text, 'a');
    expect((out[1] as ReasoningDelta).text, 'x');
    expect((out[2] as TextDelta).text, '\u{1F31F}b');
    expect((out[3] as ReasoningDelta).text, '\u{1F31F}y');
    for (final chunk in out) {
      switch (chunk) {
        case TextDelta(:final text):
          expectValidUtf16(text);
        case ReasoningDelta(:final text):
          expectValidUtf16(text);
        default:
      }
    }
  });

  test('ReasoningDelta with empty text but details passes through', () async {
    const id = 'reasoning-1';
    const details = {'type': 'reasoning'};
    final out = await carrySplitSurrogates(
      chunks([const ReasoningDelta(id: id, text: '', details: details)]),
    ).toList();

    expect(out, hasLength(1));
    expect(out.single, isA<ReasoningDelta>());
    final delta = out.single as ReasoningDelta;
    expect(delta.id, id);
    expect(delta.text, isEmpty);
    expect(delta.details, details);
  });

  test('forwards non-text chunks in order', () async {
    const textId = 'text-1';
    const toolId = 'tool-1';
    final out = await carrySplitSurrogates(
      chunks([
        const TextStart(textId),
        const TextDelta(id: textId, text: 'hi'),
        const ToolCallStart(id: toolId, toolName: 'search'),
        const ToolCallEnd(toolId),
        const TextEnd(textId),
        const Finish(finishReason: 'stop'),
      ]),
    ).toList();

    expect(out, hasLength(6));
    expect(out[0], isA<TextStart>());
    expect(out[1], isA<TextDelta>());
    expect((out[1] as TextDelta).text, 'hi');
    expect(out[2], isA<ToolCallStart>());
    expect(out[3], isA<ToolCallEnd>());
    expect(out[4], isA<TextEnd>());
    expect(out[5], isA<Finish>());
    expect((out[5] as Finish).finishReason, 'stop');
  });

  test('flushes carry on stream end without Finish', () async {
    const id = 'text-1';
    final out = await carrySplitSurrogates(
      chunks([const TextDelta(id: id, text: 'tail\ud83c')]),
    ).toList();

    expect(out, hasLength(2));
    expect((out[0] as TextDelta).text, 'tail');
    expect((out[1] as TextDelta).text, '\uFFFD');
  });
}
