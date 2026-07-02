import 'package:Cuplivo/core/services/tts/tts_text_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsTextSelection', () {
    test('keeps full text by default', () {
      expect(
        TtsTextSelection.apply(
          '旁白 “你好” (动作)',
          mode: TtsTextSelectionMode.fullText,
        ),
        '旁白 “你好” (动作)',
      );
    });

    test('extracts full-width and half-width quoted text', () {
      expect(
        TtsTextSelection.apply(
          '旁白 “你好” then \'世界\' and "again" plus ‘再见’.',
          mode: TtsTextSelectionMode.quotedOnly,
        ),
        '你好\n世界\nagain\n再见',
      );
    });

    test(
      'extracts half-width quotes next to CJK text but skips apostrophes',
      () {
        expect(
          TtsTextSelection.apply(
            '他说\'你好\'，她说"世界"，don\'t read apostrophes.',
            mode: TtsTextSelectionMode.quotedOnly,
          ),
          '你好\n世界',
        );
      },
    );

    test('does not close an unmatched quote with an apostrophe in a word', () {
      expect(
        TtsTextSelection.apply(
          '他说\'你好，don\'t stop.',
          mode: TtsTextSelectionMode.quotedOnly,
        ),
        '他说\'你好，don\'t stop.',
      );
    });

    test('keeps text outside full-width and half-width parentheses', () {
      expect(
        TtsTextSelection.apply(
          '你好（动作）世界 (stage direction) 继续',
          mode: TtsTextSelectionMode.outsideParentheses,
        ),
        '你好 世界 继续',
      );
    });

    test('extracts markdown and html italic text', () {
      expect(
        TtsTextSelection.apply(
          '正体 *斜体一* and _斜体二_ plus <em>斜体三</em>.',
          mode: TtsTextSelectionMode.italicOnly,
        ),
        '斜体一\n斜体二\n斜体三',
      );
    });

    test('removes markdown and html italic text for non-italic mode', () {
      expect(
        TtsTextSelection.apply(
          '正体 *斜体一* and _斜体二_ plus <i>斜体三</i> done.',
          mode: TtsTextSelectionMode.nonItalic,
        ),
        '正体 and plus done.',
      );
    });

    test('falls back to original text when selected content is empty', () {
      expect(
        TtsTextSelection.apply(
          '没有引号的内容',
          mode: TtsTextSelectionMode.quotedOnly,
        ),
        '没有引号的内容',
      );
    });
  });
}
