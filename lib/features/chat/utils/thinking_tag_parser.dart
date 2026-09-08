import '../../../core/models/message_part.dart';

class ThinkingTagParseResult {
  const ThinkingTagParseResult({
    required this.visibleContent,
    required this.thinkingTexts,
  });

  final String visibleContent;
  final List<String> thinkingTexts;

  bool get hasThinking => thinkingTexts.isNotEmpty;
}

class ThinkingTagHiddenRange {
  const ThinkingTagHiddenRange({
    required this.start,
    required this.end,
    required this.bodyStart,
    required this.bodyEnd,
  });

  /// Inclusive-start, exclusive-end span covering the open tag, body, and
  /// close tag (or the rest of the string when the block is unclosed).
  final int start;
  final int end;

  /// Inclusive-start, exclusive-end span of the think body only.
  final int bodyStart;
  final int bodyEnd;
}

class ThinkingTagParseRanges {
  const ThinkingTagParseRanges({
    required this.visibleContent,
    required this.thinkingTexts,
    required this.hiddenRanges,
  });

  final String visibleContent;
  final List<String> thinkingTexts;

  /// One entry per think block, including empty `<think></think>`.
  final List<ThinkingTagHiddenRange> hiddenRanges;

  bool get hasThinking => thinkingTexts.isNotEmpty || hiddenRanges.isNotEmpty;
}

final _legacyThinkOpenTagRe = RegExp(
  r'<(think|thinking|thought)>|<\|channel>thought',
  caseSensitive: false,
);

class ThinkingTagParser {
  /// Test hook: number of [parseLegacyInlineBlocks] executions.
  static int debugParseCount = 0;

  /// Whole-string parse with hidden ranges in input coordinates.
  ///
  /// An unclosed think block at the end is a hidden range plus a thinking
  /// text so export can hide it or render it in the thinking section.
  static ThinkingTagParseRanges parseWithRanges(
    String input, {
    bool includeUnclosed = true,
  }) {
    final visible = StringBuffer();
    final thinkingTexts = <String>[];
    final hiddenRanges = <ThinkingTagHiddenRange>[];
    var cursor = 0;

    while (cursor < input.length) {
      final openMatch = _legacyThinkOpenTagRe.firstMatch(
        input.substring(cursor),
      );
      if (openMatch == null) {
        visible.write(input.substring(cursor));
        break;
      }

      final openStart = cursor + openMatch.start;
      final openEnd = cursor + openMatch.end;
      final tagName = openMatch.group(1)?.toLowerCase();
      final closeTag = tagName == null ? '<channel|>' : '</$tagName>';
      final closeStart = input.toLowerCase().indexOf(closeTag, openEnd);
      visible.write(input.substring(cursor, openStart));

      if (closeStart < 0) {
        if (!includeUnclosed) {
          visible.write(input.substring(openStart));
          break;
        }
        hiddenRanges.add(
          ThinkingTagHiddenRange(
            start: openStart,
            end: input.length,
            bodyStart: openEnd,
            bodyEnd: input.length,
          ),
        );
        final thinking = input.substring(openEnd);
        if (thinking.isNotEmpty) thinkingTexts.add(thinking);
        break;
      }

      hiddenRanges.add(
        ThinkingTagHiddenRange(
          start: openStart,
          end: closeStart + closeTag.length,
          bodyStart: openEnd,
          bodyEnd: closeStart,
        ),
      );
      final thinking = input.substring(openEnd, closeStart);
      if (thinking.isNotEmpty) thinkingTexts.add(thinking);
      cursor = closeStart + closeTag.length;
    }

    return ThinkingTagParseRanges(
      visibleContent: visible.toString(),
      thinkingTexts: List.unmodifiable(thinkingTexts),
      hiddenRanges: List.unmodifiable(hiddenRanges),
    );
  }

  /// Walk text spans without moving intervening tools or attachments.
  static void walkSlices(
    List<MessagePart> parts,
    String joined,
    ThinkingTagParseRanges ranges, {
    required void Function(String text) onVisible,
    required void Function(int rangeIndex, String text) onThinking,
    required void Function(MessagePart part) onOther,
  }) {
    var offset = 0;
    var hiddenIndex = 0;
    var pendingRangeIndex = -1;
    final hiddenRanges = ranges.hiddenRanges;
    final pendingThinking = StringBuffer();

    void flushThinking() {
      final thinking = pendingThinking.toString();
      pendingThinking.clear();
      if (thinking.isNotEmpty && pendingRangeIndex >= 0) {
        onThinking(pendingRangeIndex, thinking);
      }
      pendingRangeIndex = -1;
    }

    for (final part in parts) {
      if (part is! TextPart) {
        flushThinking();
        onOther(part);
        continue;
      }
      final start = offset;
      final end = offset + part.text.length;
      var cursor = start;
      while (cursor < end) {
        if (hiddenIndex < hiddenRanges.length &&
            hiddenRanges[hiddenIndex].start <= cursor &&
            cursor < hiddenRanges[hiddenIndex].end) {
          final range = hiddenRanges[hiddenIndex];
          final sliceStart = cursor < range.bodyStart
              ? range.bodyStart
              : cursor;
          final sliceEnd = range.bodyEnd < end ? range.bodyEnd : end;
          if (sliceEnd > sliceStart) {
            pendingRangeIndex = hiddenIndex;
            pendingThinking.write(joined.substring(sliceStart, sliceEnd));
          }
          cursor = range.end < end ? range.end : end;
          if (cursor >= range.end) {
            hiddenIndex++;
            flushThinking();
          }
          continue;
        }
        final visibleEnd = hiddenIndex < hiddenRanges.length
            ? hiddenRanges[hiddenIndex].start
            : end;
        final sliceEnd = visibleEnd < end ? visibleEnd : end;
        if (sliceEnd > cursor) {
          flushThinking();
          onVisible(joined.substring(cursor, sliceEnd));
        }
        cursor = sliceEnd;
      }
      offset = end;
    }
    flushThinking();
  }

  /// Visible characters of `[start, end)` after subtracting [hiddenRanges].
  static String visibleSlice(
    String input, {
    required int start,
    required int end,
    required List<ThinkingTagHiddenRange> hiddenRanges,
  }) {
    if (start >= end) return '';
    if (hiddenRanges.isEmpty) return input.substring(start, end);
    final out = StringBuffer();
    var cursor = start;
    for (final range in hiddenRanges) {
      if (range.end <= cursor) continue;
      if (range.start >= end) break;
      if (range.start > cursor) {
        out.write(input.substring(cursor, range.start.clamp(cursor, end)));
      }
      if (range.end > cursor) {
        cursor = range.end < end ? range.end : end;
      }
    }
    if (cursor < end) out.write(input.substring(cursor, end));
    return out.toString();
  }

  static ThinkingTagParseResult parseLegacyInlineBlocks(String input) {
    debugParseCount++;
    final visible = StringBuffer();
    final thinkingTexts = <String>[];
    var cursor = 0;

    while (cursor < input.length) {
      final openMatch = _legacyThinkOpenTagRe.firstMatch(
        input.substring(cursor),
      );
      if (openMatch == null) {
        visible.write(input.substring(cursor));
        break;
      }

      final openStart = cursor + openMatch.start;
      final openEnd = cursor + openMatch.end;
      final tagName = openMatch.group(1)?.toLowerCase();
      final closeTag = tagName == null ? '<channel|>' : '</$tagName>';
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
