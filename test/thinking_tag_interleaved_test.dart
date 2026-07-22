import 'package:flutter_test/flutter_test.dart';
import 'package:Cuplivo/features/chat/utils/thinking_tag_parser.dart';

void main() {
  group('ThinkingTagParser.hasInlineThinkTags', () {
    test('detects think tag', () {
      expect(ThinkingTagParser.hasInlineThinkTags('<think>x</think>'), true);
    });

    test('detects thought tag case-insensitively', () {
      expect(ThinkingTagParser.hasInlineThinkTags('<THOUGHT>x'), true);
    });

    test('returns false for plain text', () {
      expect(ThinkingTagParser.hasInlineThinkTags('no tags here'), false);
    });
  });
}
