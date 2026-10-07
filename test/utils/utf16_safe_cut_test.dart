import 'dart:convert';

import 'package:Kelivo/utils/utf16_safe_cut.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('utf16SafeHeadEnd', () {
    test('leaves non-pair cuts unchanged', () {
      expect(utf16SafeHeadEnd('abc', 2), 2);
      expect(utf16SafeHeadEnd('abc', 0), 0);
      expect(utf16SafeHeadEnd('abc', 3), 3);
    });

    test('moves a cut inside a surrogate pair back by one', () {
      // '😀' is U+1F600 = \uD83D\uDE00 (two code units). Cutting at the low
      // surrogate would leave a lone high surrogate behind in the head.
      expect(utf16SafeHeadEnd('a😀b', 2), 1);
    });
  });

  group('utf16SafeTailStart', () {
    test('leaves non-pair cuts unchanged', () {
      expect(utf16SafeTailStart('abc', 1), 1);
      expect(utf16SafeTailStart('abc', 0), 0);
      expect(utf16SafeTailStart('abc', 3), 3);
    });

    test(
      'keeps a cut at the high surrogate (pair stays whole in the tail)',
      () {
        // substring(1) of 'a😀b' starts at the high surrogate and keeps the
        // whole pair, so no adjustment is needed.
        expect(utf16SafeTailStart('a😀b', 1), 1);
      },
    );

    test('moves a cut at the low surrogate forward by one', () {
      // substring(2) of 'a😀b' would start with a lone low surrogate.
      expect(utf16SafeTailStart('a😀b', 2), 3);
    });
  });

  group('redistributeTextUtf16Safe', () {
    test('keeps cumulative boundaries independent of text block grouping', () {
      for (final value in ['😀BC', 'A😀BC', '😀😄Z', 'ABCD', 'A', '']) {
        final split = redistributeTextUtf16Safe(value, [1, 1, 1]);
        final merged = redistributeTextUtf16Safe(value, [2, 1]);
        expect([split.take(2).join(), split.last], merged);
        expect(split.join(), value);
        for (final text in split) {
          expectValidUtf16(text);
        }
      }
      expect(redistributeTextUtf16Safe('😀BC', [1, 1, 1]), ['😀', '', 'BC']);
    });

    test('retains empty slots and gives the last slot all remaining text', () {
      expect(redistributeTextUtf16Safe('😀B', [0, 1, 0, 1]), [
        '',
        '😀',
        '',
        'B',
      ]);
      expect(redistributeTextUtf16Safe('😀', [1, 1, 1]), ['😀', '', '']);
      expect(redistributeTextUtf16Safe('😀B', [1]), ['😀B']);
      expect(redistributeTextUtf16Safe('', [1, 1]), ['', '']);
      expect(redistributeTextUtf16Safe('😀B', []), isEmpty);
    });
  });

  group('truncateHeadUtf16Safe', () {
    test('keeps short values untouched', () {
      const value = 'hello';
      expect(truncateHeadUtf16Safe(value, 100), value);
    });

    test('truncates ASCII without a marker', () {
      expect(truncateHeadUtf16Safe('abcdef', 3), 'abc');
    });

    test('never splits a surrogate pair at the cut', () {
      // '😀' occupies code units 3..4; a raw cut at 4 would tear it.
      const value = 'abc😀def';
      final out = truncateHeadUtf16Safe(value, 4);
      expect(out, 'abc');
      expect(() => jsonEncode(out), returnsNormally);
    });
  });

  group('truncateHeadTailUtf16Safe', () {
    const marker = '\n...[truncated]...\n';

    test('keeps short values untouched', () {
      const value = 'hello';
      expect(truncateHeadTailUtf16Safe(value, 100, marker: marker), value);
    });

    test('stays within the length budget', () {
      final value = 'x' * 1000;
      final out = truncateHeadTailUtf16Safe(value, 100, marker: marker);
      expect(out.length, lessThanOrEqualTo(100));
      expect(out, contains(marker));
    });

    test('never splits a surrogate pair at either cut', () {
      // marker is 19 chars -> budget 24 leaves available 5, head 2, tail 3.
      // The first pair straddles the head cut (high at 1, low at 2) and the
      // last pair straddles the tail cut (high at 23, low at 24). Both pairs
      // are dropped whole.
      const value = 'a😀xxxxxxxxxxxxxxxxxxxx😀bb';
      final out = truncateHeadTailUtf16Safe(value, 24, marker: marker);
      expect(out, 'a${marker}bb');
      expectValidUtf16(out);
      expect(() => jsonEncode(out), returnsNormally);
    });
  });

  group('splitUtf16SafeHalves', () {
    test('splits ASCII at the midpoint and covers the original', () {
      final halves = splitUtf16SafeHalves('abcdefgh');
      expect(halves, isNotNull);
      expect(halves!.left, 'abcd');
      expect(halves.right, 'efgh');
      expect('${halves.left}${halves.right}', 'abcdefgh');
    });

    test('does not tear a surrogate pair at a naive length~/2 cut', () {
      // 'x' + 20 emoji = 41 units; mid = 20 falls on the low surrogate of
      // the 10th emoji. Naive substring(0, 20) would leave a lone high.
      final text = 'x${'😀' * 20}';
      expect(text.length ~/ 2, 20);
      final naive = text.substring(0, text.length ~/ 2);
      final naiveLast = naive.codeUnitAt(naive.length - 1);
      expect(naiveLast >= 0xD800 && naiveLast <= 0xDBFF, isTrue);

      final halves = splitUtf16SafeHalves(text);
      expect(halves, isNotNull);
      expect('${halves!.left}${halves.right}', text);
      expectValidUtf16(halves.left);
      expectValidUtf16(halves.right);
      expect(() => jsonEncode(halves.left), returnsNormally);
      expect(() => jsonEncode(halves.right), returnsNormally);
    });

    test('returns null when a single surrogate pair cannot be split', () {
      expect(splitUtf16SafeHalves('😀'), isNull);
      expect(splitUtf16SafeHalves('a'), isNull);
      expect(splitUtf16SafeHalves(''), isNull);
    });
  });

  group('splitUtf16SafeChunks', () {
    test('keeps short values as a single chunk', () {
      expect(splitUtf16SafeChunks('hello', 100), ['hello']);
    });

    test('splits ASCII on the budget', () {
      expect(splitUtf16SafeChunks('abcdef', 2), ['ab', 'cd', 'ef']);
    });

    test('never splits a surrogate pair', () {
      const emoji = '😀';
      final chunks = splitUtf16SafeChunks('aa${emoji}bb', 3);
      expect(chunks.join(), 'aa${emoji}bb');
      for (final chunk in chunks) {
        expectValidUtf16(chunk);
        expect(() => jsonEncode(chunk), returnsNormally);
      }
    });
  });
}

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
