class ThinkingTagParseResult {
  const ThinkingTagParseResult({
    required this.visibleContent,
    required this.thinkingTexts,
  });

  final String visibleContent;
  final List<String> thinkingTexts;

  bool get hasThinking => thinkingTexts.isNotEmpty;
}

class ThinkingTagParser {
  static final RegExp _openTagRe = RegExp(
    r'<(think|thought)>',
    caseSensitive: false,
  );

  static ThinkingTagParseResult parseLegacyInlineBlocks(String input) {
    final visible = StringBuffer();
    final thinkingTexts = <String>[];
    var cursor = 0;

    while (cursor < input.length) {
      final openMatch = _openTagRe.firstMatch(input.substring(cursor));
      if (openMatch == null) {
        visible.write(input.substring(cursor));
        break;
      }

      final openStart = cursor + openMatch.start;
      final openEnd = cursor + openMatch.end;
      final tagName = (openMatch.group(1) ?? '').toLowerCase();
      final closeTag = '</$tagName>';
      final closeStart = input.toLowerCase().indexOf(closeTag, openEnd);

      if (closeStart == -1) {
        visible.write(input.substring(cursor));
        break;
      }

      visible.write(input.substring(cursor, openStart));
      final thinking = input.substring(openEnd, closeStart).trim();
      if (thinking.isNotEmpty) {
        thinkingTexts.add(thinking);
      }
      cursor = closeStart + closeTag.length;
    }

    return ThinkingTagParseResult(
      visibleContent: visible.toString().trim(),
      thinkingTexts: List.unmodifiable(thinkingTexts),
    );
  }
}
