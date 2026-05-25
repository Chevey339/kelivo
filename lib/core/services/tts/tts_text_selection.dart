enum TtsTextSelectionMode {
  fullText,
  quotedOnly,
  outsideParentheses,
  italicOnly,
  nonItalic,
}

extension TtsTextSelectionModeStorage on TtsTextSelectionMode {
  String get storageValue => name;

  static TtsTextSelectionMode fromStorageValue(String? value) {
    for (final mode in TtsTextSelectionMode.values) {
      if (mode.name == value) return mode;
    }
    return TtsTextSelectionMode.fullText;
  }
}

class TtsTextSelection {
  const TtsTextSelection._();

  static String apply(
    String input, {
    required TtsTextSelectionMode mode,
    bool fallbackToOriginal = true,
  }) {
    final original = input.trim();
    if (original.isEmpty) return '';

    final selected = switch (mode) {
      TtsTextSelectionMode.fullText => original,
      TtsTextSelectionMode.quotedOnly => _quotedText(original),
      TtsTextSelectionMode.outsideParentheses => _outsideParentheses(original),
      TtsTextSelectionMode.italicOnly => _italicText(original),
      TtsTextSelectionMode.nonItalic => _nonItalicText(original),
    };
    final normalized = _normalizeSelectedText(selected);
    if (normalized.isNotEmpty || !fallbackToOriginal) return normalized;
    return original;
  }

  static String _quotedText(String input) {
    final ranges = <_TextRange>[];
    const pairedQuotes = <String, String>{
      '“': '”',
      '‘': '’',
      '「': '」',
      '『': '』',
    };

    var i = 0;
    while (i < input.length) {
      final char = input[i];
      final close = pairedQuotes[char];
      if (close != null) {
        final end = input.indexOf(close, i + 1);
        if (end > i + 1) {
          ranges.add(_TextRange(i + 1, end));
          i = end + 1;
          continue;
        }
      } else if ((char == '"' || char == "'") &&
          _isStraightQuoteOpening(input, i)) {
        final end = _findStraightQuoteClose(input, i + 1, char);
        if (end > i + 1) {
          ranges.add(_TextRange(i + 1, end));
          i = end + 1;
          continue;
        }
      }
      i++;
    }

    return _joinRanges(input, ranges);
  }

  static String _outsideParentheses(String input) {
    final buffer = StringBuffer();
    var depth = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '(' || char == '（') {
        if (buffer.isNotEmpty) buffer.write(' ');
        depth++;
        continue;
      }
      if ((char == ')' || char == '）') && depth > 0) {
        depth--;
        continue;
      }
      if (depth == 0) buffer.write(char);
    }
    return buffer.toString();
  }

  static String _italicText(String input) {
    final matches = _collectItalicMatches(input);
    return matches
        .map((match) => _normalizeInlineWhitespace(match.text))
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  static String _nonItalicText(String input) {
    final ranges = _collectItalicMatches(
      input,
    ).map((match) => match.range).toList(growable: false);
    return _removeRanges(input, ranges);
  }

  static List<_ItalicMatch> _collectItalicMatches(String input) {
    final matches = <_ItalicMatch>[];
    final htmlPattern = RegExp(
      r'<(em|i)\b[^>]*>([\s\S]*?)</\1>',
      caseSensitive: false,
    );
    for (final match in htmlPattern.allMatches(input)) {
      matches.add(
        _ItalicMatch(
          range: _TextRange(match.start, match.end),
          text: match.group(2) ?? '',
        ),
      );
    }

    var i = 0;
    while (i < input.length) {
      final marker = input[i];
      if ((marker == '*' || marker == '_') &&
          _isSingleMarkdownMarker(input, i, marker) &&
          _isMarkdownItalicOpening(input, i, marker)) {
        final end = _findMarkdownItalicClose(input, i + 1, marker);
        if (end > i + 1) {
          matches.add(
            _ItalicMatch(
              range: _TextRange(i, end + 1),
              text: input.substring(i + 1, end),
            ),
          );
          i = end + 1;
          continue;
        }
      }
      i++;
    }

    matches.sort((a, b) => a.range.start.compareTo(b.range.start));
    return _withoutOverlaps(matches);
  }

  static List<_ItalicMatch> _withoutOverlaps(List<_ItalicMatch> matches) {
    final result = <_ItalicMatch>[];
    var lastEnd = -1;
    for (final match in matches) {
      if (match.range.start < lastEnd) continue;
      result.add(match);
      lastEnd = match.range.end;
    }
    return result;
  }

  static int _findMarkdownItalicClose(String input, int start, String marker) {
    for (var i = start; i < input.length; i++) {
      if (input[i] != marker) continue;
      if (!_isSingleMarkdownMarker(input, i, marker)) continue;
      if (i == start || _isWhitespace(input[i - 1])) continue;
      if (marker == '_' &&
          i + 1 < input.length &&
          _isAsciiLetterOrDigit(input[i + 1])) {
        continue;
      }
      return i;
    }
    return -1;
  }

  static bool _isMarkdownItalicOpening(String input, int index, String marker) {
    if (index + 1 >= input.length || _isWhitespace(input[index + 1])) {
      return false;
    }
    if (marker == '_' && index > 0 && _isAsciiLetterOrDigit(input[index - 1])) {
      return false;
    }
    return true;
  }

  static bool _isSingleMarkdownMarker(String input, int index, String marker) {
    final previousSame = index > 0 && input[index - 1] == marker;
    final nextSame = index + 1 < input.length && input[index + 1] == marker;
    return !previousSame && !nextSame;
  }

  static bool _isStraightQuoteOpening(String input, int index) {
    if (index + 1 >= input.length || _isWhitespace(input[index + 1])) {
      return false;
    }
    if (index == 0) return true;
    final previous = input[index - 1];
    return !_isAsciiLetterOrDigit(previous);
  }

  static int _findStraightQuoteClose(String input, int start, String quote) {
    for (var i = start; i < input.length; i++) {
      if (input[i] != quote) continue;
      if (i == start || _isWhitespace(input[i - 1])) continue;
      if (quote == "'" &&
          i + 1 < input.length &&
          _isAsciiLetterOrDigit(input[i - 1]) &&
          _isAsciiLetterOrDigit(input[i + 1])) {
        continue;
      }
      return i;
    }
    return -1;
  }

  static String _joinRanges(String input, List<_TextRange> ranges) {
    return ranges
        .map((range) => input.substring(range.start, range.end))
        .map(_normalizeInlineWhitespace)
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  static String _removeRanges(String input, List<_TextRange> ranges) {
    if (ranges.isEmpty) return input;
    final sorted = List<_TextRange>.of(ranges)
      ..sort((a, b) => a.start.compareTo(b.start));
    final buffer = StringBuffer();
    var cursor = 0;
    for (final range in sorted) {
      if (range.start < cursor) continue;
      buffer.write(input.substring(cursor, range.start));
      cursor = range.end;
    }
    buffer.write(input.substring(cursor));
    return buffer.toString();
  }

  static String _normalizeSelectedText(String input) {
    return input
        .split(RegExp(r'\n+'))
        .map(_normalizeInlineWhitespace)
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  static String _normalizeInlineWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isWhitespace(String char) => char.trim().isEmpty;

  static bool _isAsciiLetterOrDigit(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122);
  }
}

class _TextRange {
  const _TextRange(this.start, this.end);

  final int start;
  final int end;
}

class _ItalicMatch {
  const _ItalicMatch({required this.range, required this.text});

  final _TextRange range;
  final String text;
}
