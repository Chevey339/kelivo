import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/chat/utils/thinking_tag_parser.dart';

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
}
