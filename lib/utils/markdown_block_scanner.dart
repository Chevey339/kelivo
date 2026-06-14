enum BlockType { fencedCode, inlineCode }

class BlockSpan {
  final BlockType type;
  final int start;
  final int end;

  const BlockSpan({required this.type, required this.start, required this.end});

  bool contains(int index) => index >= start && index < end;
}

class BlockScanResult {
  final List<BlockSpan> spans;

  const BlockScanResult(this.spans);

  bool isProtected(int index) {
    for (final s in spans) {
      if (s.contains(index)) return true;
    }
    return false;
  }

  BlockSpan? spanAt(int index) {
    for (final s in spans) {
      if (s.contains(index)) return s;
      if (s.start > index) return null;
    }
    return null;
  }
}

class MarkdownBlockScanner {
  static const String _codeDollarMask = '___CODE_DOLLAR_MASK___';

  static BlockScanResult scan(String text) {
    final spans = <BlockSpan>[];
    var i = 0;
    while (i < text.length) {
      // \` escape: skip both, never triggers fence or inline code
      final ch = text[i];
      if (ch == '\\' && i + 1 < text.length && text[i + 1] == '`') {
        i += 2;
        continue;
      }

      // Fenced code block: 3+ backticks at line start
      if (ch == '`' && _isFenceStart(text, i)) {
        final start = i;
        final marker = ch;
        var fenceLen = 0;
        while (i + fenceLen < text.length && text[i + fenceLen] == marker) {
          fenceLen++;
        }
        i += fenceLen;
        // Skip info string (rest of opening line)
        while (i < text.length && text[i] != '\n') {
          i++;
        }
        if (i < text.length) i++; // skip \n
        // Scan for closing fence
        while (i < text.length) {
          if (text[i] == '\n' && _closesFence(text, i + 1, marker, fenceLen)) {
            final closeStart = i + 1;
            i = closeStart + fenceLen;
            // Skip trailing content on closing fence line
            while (i < text.length && text[i] != '\n') {
              i++;
            }
            if (i < text.length) i++; // skip \n
            break;
          }
          i++;
        }
        spans.add(BlockSpan(type: BlockType.fencedCode, start: start, end: i));
        continue;
      }

      // Inline code: 1+ backticks (not at fence-start)
      if (ch == '`') {
        final start = i;
        var tickLen = 0;
        while (i + tickLen < text.length && text[i + tickLen] == '`') {
          tickLen++;
        }
        i += tickLen;
        var closed = false;
        // Inline code does not cross line boundaries
        while (i < text.length && text[i] != '\n') {
          // \` inside inline code: skip both as literal content
          if (text[i] == '\\' && i + 1 < text.length && text[i + 1] == '`') {
            i += 2;
            continue;
          }
          if (text[i] == '`') {
            var closingLen = 0;
            while (i + closingLen < text.length &&
                text[i + closingLen] == '`') {
              closingLen++;
            }
            if (closingLen == tickLen) {
              i += tickLen;
              closed = true;
              break;
            }
          }
          i++;
        }
        if (closed) {
          spans.add(
            BlockSpan(type: BlockType.inlineCode, start: start, end: i),
          );
        }
        continue;
      }

      i++;
    }
    return BlockScanResult(spans);
  }

  /// Replace all [spans] in [text] with mask placeholders.
  /// For inline code spans, [$] signs are replaced with [___CODE_DOLLAR_MASK___]
  /// to prevent downstream LaTeX normalization.
  static (String, Map<String, String>) applyMask(
    String text,
    List<BlockSpan> spans,
  ) {
    if (spans.isEmpty) return (text, const {});

    final codeMap = <String, String>{};
    final buf = StringBuffer();
    var codeCount = 0;
    var lastEnd = 0;

    for (final span in spans) {
      if (span.start > lastEnd) {
        buf.write(text.substring(lastEnd, span.start));
      }
      final key = '__CODE_MASK_${codeCount++}__';
      var content = text.substring(span.start, span.end);
      if (span.type == BlockType.inlineCode) {
        content = content.replaceAll(r'$', _codeDollarMask);
      } else {
        // Mask <details> and <summary> tags inside fenced code.
        //
        // ROOT CAUSE: MarkdownComponent.generate() dispatches via hasMatch()
        // with multiLine:true. ^ matches any line start (not just string
        // start), and $ matches before any \n. When the combined regex from
        // splitMapJoin matches the entire fenced code block, the dispatcher
        // wraps each component's pattern in ^...$ and calls hasMatch().
        // DetailsHtmlMd's pattern "^\ *?(?:<details...>...<\/details>)$"
        // matches from the <details> line (line boundary via ^) to the
        // </details> line (line boundary via $), even though the matched text
        // is the full fenced code block. DetailsHtmlMd wins because it is
        // listed before FencedCodeBlockMd in component priority.
        //
        // Masking < with \uE002 breaks DetailsHtmlMd's leading "<details",
        // causing hasMatch to return false, allowing FencedCodeBlockMd to
        // match correctly.
        content = content.replaceAllMapped(
          RegExp(r'</?(?:details|summary)\b', caseSensitive: false),
          (match) => '\uE002${match[0]!.substring(1)}',
        );
      }
      codeMap[key] = content;
      buf.write(key);
      lastEnd = span.end;
    }
    if (lastEnd < text.length) {
      buf.write(text.substring(lastEnd));
    }

    return (buf.toString(), codeMap);
  }

  /// The opening sequence must start at a line boundary.
  /// Only backtick fences (3+) are supported; tilde fences are not.
  static bool _isFenceStart(String text, int i) {
    if (i > 0 && text[i - 1] != '\n') return false;
    if (text[i] != '`') return false;
    var len = 0;
    while (i + len < text.length && text[i + len] == '`') {
      len++;
    }
    return len >= 3;
  }

  /// The candidate at [i] must start with the same [marker] and be at least
  /// [minLen] characters long.
  static bool _closesFence(String text, int i, String marker, int minLen) {
    if (i >= text.length) return false;
    if (text[i] != marker) return false;
    var len = 0;
    while (i + len < text.length && text[i + len] == marker) {
      len++;
    }
    return len >= minLen;
  }
}
