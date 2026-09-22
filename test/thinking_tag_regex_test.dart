import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/utils/thinking_tag_parser.dart';

void main() {
  group('ThinkingTagParser', () {
    test('extracts closed think block', () {
      const input = '<think>reasoning here</think>answer';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, 'answer');
      expect(parsed.thinkingTexts, const ['reasoning here']);
    });

    test('extracts closed thought block', () {
      const input = '<thought>reasoning here</thought>answer';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, 'answer');
      expect(parsed.thinkingTexts, const ['reasoning here']);
    });

    test('extracts closed thinking block', () {
      const input = '<thinking>reasoning here</thinking>answer';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, 'answer');
      expect(parsed.thinkingTexts, const ['reasoning here']);
    });

    test('extracts Gemma thought channel', () {
      const input = '<|channel>thought\nreasoning here\n<channel|>\nanswer';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, 'answer');
      expect(parsed.thinkingTexts, const ['reasoning here']);
    });

    test('extracts multiple closed blocks', () {
      const input = '<think>a</think>mid<thought>b</thought>end';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, 'midend');
      expect(parsed.thinkingTexts, const ['a', 'b']);
    });

    test('keeps unclosed think tag visible', () {
      const input = '<think>partial reasoning';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, input);
      expect(parsed.thinkingTexts, isEmpty);
    });

    test('keeps mismatched thinking tags visible', () {
      const input = '<think>reasoning</thought>answer';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, input);
      expect(parsed.thinkingTexts, isEmpty);
    });

    test('keeps full-width tags visible', () {
      const input = '＜think＞literal＜/think＞answer';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, input);
      expect(parsed.thinkingTexts, isEmpty);
    });

    test('keeps plain text unchanged', () {
      const input = 'just a normal message';
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(input);

      expect(parsed.visibleContent, input);
      expect(parsed.thinkingTexts, isEmpty);
    });
  });

  group('ThinkingTagParser.stripUtilityThinking', () {
    test('strips closed think blocks and keeps visible text', () {
      expect(
        ThinkingTagParser.stripUtilityThinking(
          '<think>reasoning here</think>answer',
        ),
        'answer',
      );
    });

    test('strips multiple mixed think blocks', () {
      expect(
        ThinkingTagParser.stripUtilityThinking(
          '<think>a</think>mid<thought>b</thought>end',
        ),
        'midend',
      );
    });

    test('discards a truncated think block instead of exposing CoT', () {
      expect(
        ThinkingTagParser.stripUtilityThinking('<think>partial reasoning'),
        isEmpty,
      );
      expect(
        ThinkingTagParser.stripUtilityThinking('visible <think>partial'),
        'visible',
      );
    });

    test('discards a mismatched close tag as a truncated block', () {
      expect(
        ThinkingTagParser.stripUtilityThinking('<think>reasoning</thought>'),
        isEmpty,
      );
    });

    test('strips Gemma thought channels', () {
      expect(
        ThinkingTagParser.stripUtilityThinking(
          '<|channel>thought\nreasoning here\n<channel|>\nanswer',
        ),
        'answer',
      );
    });

    test('trims plain text and keeps it intact', () {
      expect(
        ThinkingTagParser.stripUtilityThinking('  just a normal message  '),
        'just a normal message',
      );
    });
  });

  group('ThinkingTagParser.parseWithRanges', () {
    test('hides a think span that is split across arbitrary offsets', () {
      const input = '<think>secret</think>answer';
      final parsed = ThinkingTagParser.parseWithRanges(input);
      expect(parsed.hiddenRanges, isNotEmpty);
      expect(
        ThinkingTagParser.visibleSlice(
          input,
          start: 0,
          end: 2,
          hiddenRanges: parsed.hiddenRanges,
        ),
        isEmpty,
      );
      expect(
        ThinkingTagParser.visibleSlice(
          input,
          start: 2,
          end: input.length,
          hiddenRanges: parsed.hiddenRanges,
        ),
        'answer',
      );
      expect(parsed.thinkingTexts, ['secret']);
    });

    test('hides an unclosed think block and still returns its text', () {
      const input = 'visible <think>partial';
      final parsed = ThinkingTagParser.parseWithRanges(input);
      expect(parsed.visibleContent, 'visible ');
      expect(parsed.thinkingTexts, ['partial']);
      expect(parsed.hiddenRanges.single.end, input.length);
    });

    test('keeps an empty think range aligned with later thinking text', () {
      const input = 'before<think></think>middle<think>secret</think>after';
      final parsed = ThinkingTagParser.parseWithRanges(input);
      expect(parsed.hiddenRanges, hasLength(2));
      expect(parsed.hiddenRanges[0].bodyStart, parsed.hiddenRanges[0].bodyEnd);
      expect(
        input.substring(
          parsed.hiddenRanges[1].bodyStart,
          parsed.hiddenRanges[1].bodyEnd,
        ),
        'secret',
      );
      expect(parsed.thinkingTexts, ['secret']);
      expect(parsed.visibleContent, 'beforemiddleafter');
    });

    test('visibleSlice without hidden ranges is the original substring', () {
      const input = '    indented\nline  ';
      final parsed = ThinkingTagParser.parseWithRanges(input);
      expect(parsed.hiddenRanges, isEmpty);
      expect(
        ThinkingTagParser.visibleSlice(
          input,
          start: 0,
          end: input.length,
          hiddenRanges: parsed.hiddenRanges,
        ),
        input,
      );
    });
  });
}
