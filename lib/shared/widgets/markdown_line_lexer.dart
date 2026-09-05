/// Line-level fence / details / inline-code rules.
///
/// Display-math pairing lives in [markdownScanDisplayMath] so the splitter,
/// Details extractor, and trailing-separator classifier cannot drift.
final class MarkdownLineLexer {
  int? _fenceMarker;
  int _fenceLength = 0;
  final MarkdownDetailsWalker _details = MarkdownDetailsWalker();

  bool get protected => _fenceMarker != null || _details.depth > 0;

  bool get fenced => _fenceMarker != null;

  int get detailsDepth => _details.depth;

  int? get detailsClosedAt => _details.closedAt;

  bool get detailsOverflowed => _details.overflowed;

  void resetDetails() => _details.reset();

  void reset() {
    _fenceMarker = null;
    _fenceLength = 0;
    _details.reset();
  }

  /// One LF-delimited line, which may still hold LS/PS/`\r` logical rows.
  /// Block boundaries stay on `\n\n+`; this only updates structure state.
  void consumePhysicalLine(String rawLine) {
    var start = 0;
    while (true) {
      var end = start;
      while (end < rawLine.length &&
          !_isPhysicalLineInternalBreak(rawLine.codeUnitAt(end))) {
        _noteScanVisit();
        end++;
      }
      consumeLine(rawLine.substring(start, end));
      if (end >= rawLine.length) return;
      start = _skipLogicalLineBreak(rawLine, end, rawLine.length);
    }
  }

  /// [line] is one logical row. Fence indent is `[ \t]` only; Details
  /// still use `trimLeft()`.
  void consumeLine(String line) {
    _updateFence(line);
    if (_fenceMarker != null) return;
    final trimmed = line.trimLeft();
    _updateDetails(trimmed, () => _LineBackticks.of(trimmed));
  }

  /// Fence only. True when this line is inside a fence — including the
  /// line that just closed one.
  bool consumeFence(String line) {
    final wasFenced = _fenceMarker != null;
    _updateFence(line);
    return _fenceMarker != null || wasFenced;
  }

  /// CommonMark-style fences: marker plus opening run length. A closer
  /// must use the same character, be at least as long, and allow only
  /// spaces or tabs after the run.
  void _updateFence(String line) {
    final mark = _fenceMarkOf(line, 0);
    if (mark == null) return;
    if (_fenceMarker == null) {
      if (!mark.canOpen) return;
      _fenceMarker = mark.marker;
      _fenceLength = mark.length;
      return;
    }
    if (!mark.canClose) return;
    if (mark.marker != _fenceMarker || mark.length < _fenceLength) return;
    _fenceMarker = null;
    _fenceLength = 0;
  }

  void _updateDetails(String line, _LineBackticks Function() spans) {
    if (_details.depth == 0 &&
        MarkdownDetailsWalker.open.matchAsPrefix(line) == null &&
        MarkdownDetailsWalker.close.matchAsPrefix(line) == null) {
      return;
    }
    _details.consume(line, advance: spans().advance);
  }
}

/// Removes fenced and inline code while preserving the surrounding line
/// structure. Fence and backtick pairing stay identical to the renderer's
/// structural scan.
String markdownRemoveCode(String text) {
  if (!text.contains('`') && !text.contains('~~~')) return text;

  final lexer = MarkdownLineLexer();
  final output = StringBuffer();
  var cursor = 0;
  while (cursor < text.length) {
    var lineEnd = cursor;
    while (lineEnd < text.length &&
        !markdownIsLogicalLineBreak(text.codeUnitAt(lineEnd))) {
      lineEnd++;
    }
    final line = text.substring(cursor, lineEnd);
    final prefix = _markdownFenceContainerPrefix.firstMatch(line)!;
    final fenceLine = line.substring(prefix.end);
    if (lexer.consumeFence(fenceLine)) {
      output.write(' ');
    } else {
      output.write(_LineBackticks.of(line).withoutCode(line));
    }

    if (lineEnd >= text.length) break;
    final next = _skipLogicalLineBreak(text, lineEnd, text.length);
    output.write(text.substring(lineEnd, next));
    cursor = next;
  }
  return output.toString();
}

final _markdownFenceContainerPrefix = RegExp(
  r'^[ \t]*(?:(?:>[ \t]*)|(?:(?:[*+-]|\d+\.)[ \t]+))*',
);

/// Same cap as the recursive [blockPattern] used by [DetailsHtmlMd].
const int markdownDetailsMaxDepth = 6;

/// Tag walker shared with [DetailsHtmlMd]. Token rules:
/// tags stay on one logical line; paired inline code is atomic; nesting
/// stops at [markdownDetailsMaxDepth].
final class MarkdownDetailsWalker {
  /// Attributes may use spaces/tabs only; `<` and line breaks are not
  /// part of the token, so a missing `>` cannot swallow a later closer.
  /// Tag names are written as character classes so [blockPattern] stays
  /// case-insensitive after [MarkdownComponent.generate] recompiles
  /// `.pattern` with the default case-sensitive flag.
  static const openSource =
      r'<[Dd][Ee][Tt][Aa][Ii][Ll][Ss](?:[ \t][^><\r\n\u2028\u2029]*)?>';
  static const closeSource = r'</[Dd][Ee][Tt][Aa][Ii][Ll][Ss]>';
  static const summaryOpenSource =
      r'<[Ss][Uu][Mm][Mm][Aa][Rr][Yy](?:[ \t][^><\r\n\u2028\u2029]*)?>';
  static const summaryCloseSource = r'</[Ss][Uu][Mm][Mm][Aa][Rr][Yy]>';

  static final open = RegExp(openSource, caseSensitive: false);
  static final close = RegExp(closeSource, caseSensitive: false);
  static final summaryOpen = RegExp(summaryOpenSource, caseSensitive: false);
  static final summaryClose = RegExp(summaryCloseSource, caseSensitive: false);

  /// Structure only. Display text is never rewritten; complete blocks are
  /// lifted out by [MarkdownDetailsRegistry] before they reach the renderer.
  static String blockPattern({int depth = markdownDetailsMaxDepth}) {
    final summary =
        r'\s*'
        '$summaryOpenSource'
        '(?:(?!$summaryCloseSource)[\\s\\S])*'
        '$summaryCloseSource';
    final safe = '(?!$openSource|$closeSource)[\\s\\S]';
    if (depth <= 1) {
      return '$openSource$summary(?:$safe)*$closeSource';
    }
    final nested = blockPattern(depth: depth - 1);
    return '$openSource$summary(?:$safe|$nested)*$closeSource';
  }

  final List<_DetailsRegion> _stack = [];
  int _ignoredOpens = 0;
  bool _overflow = false;

  int get depth => _stack.length;

  /// True after a nested open past [markdownDetailsMaxDepth].
  bool get overflowed => _overflow;

  /// Index in the last [consume] line just after a tag that returned to
  /// depth 0. Cleared at the start of each [consume].
  int? closedAt;

  void reset() {
    _stack.clear();
    _ignoredOpens = 0;
    _overflow = false;
    closedAt = null;
  }

  /// Applies the same logical-line + inline-code rules the splitter uses.
  void consumeText(String text) {
    var i = 0;
    while (i < text.length) {
      var lineEnd = i;
      while (lineEnd < text.length &&
          !markdownIsLogicalLineBreak(text.codeUnitAt(lineEnd))) {
        _noteScanVisit();
        lineEnd++;
      }
      final trimmed = text.substring(i, lineEnd).trimLeft();
      consume(trimmed, advance: _LineBackticks.of(trimmed).advance);
      i = _skipLogicalLineBreak(text, lineEnd, text.length);
    }
  }

  void consume(
    String line, {
    required int Function(int start) advance,
    int offset = 0,
    MarkdownDetailsCapture? capture,
  }) {
    closedAt = null;
    var i = 0;
    while (i < line.length) {
      _noteScanVisit();
      if (line.codeUnitAt(i) == 0x60) {
        i = advance(i);
        continue;
      }
      if (line.codeUnitAt(i) != 0x3C) {
        i++;
        continue;
      }
      if (_stack.isEmpty) {
        if (i == 0) {
          final opened = open.matchAsPrefix(line, i);
          if (opened != null) {
            capture?.attrs = _detailsOpenAttrs(opened.group(0)!);
            _stack.add(_DetailsRegion.afterOpen);
            i = opened.end;
            continue;
          }
        }
        i++;
        continue;
      }
      final region = _stack.last;
      if (region == _DetailsRegion.afterOpen) {
        final summary = summaryOpen.matchAsPrefix(line, i);
        if (summary != null) {
          if (capture != null && _stack.length == 1) {
            capture.summaryStart = offset + summary.end;
          }
          _stack[_stack.length - 1] = _DetailsRegion.inSummary;
          i = summary.end;
          continue;
        }
        final closed = close.matchAsPrefix(line, i);
        if (closed != null) {
          _popDetails(closed.end);
          i = closed.end;
          continue;
        }
        i++;
        continue;
      }
      if (region == _DetailsRegion.inSummary) {
        final ended = summaryClose.matchAsPrefix(line, i);
        if (ended != null) {
          if (capture != null && _stack.length == 1) {
            capture.summaryEnd = offset + ended.start;
            capture.bodyStart = offset + ended.end;
          }
          _stack[_stack.length - 1] = _DetailsRegion.inBody;
          i = ended.end;
          continue;
        }
        i++;
        continue;
      }
      final nested = open.matchAsPrefix(line, i);
      if (nested != null) {
        if (_stack.length >= markdownDetailsMaxDepth) {
          _overflow = true;
          _ignoredOpens++;
          i = nested.end;
          continue;
        }
        _stack.add(_DetailsRegion.afterOpen);
        i = nested.end;
        continue;
      }
      final closed = close.matchAsPrefix(line, i);
      if (closed != null) {
        if (_ignoredOpens > 0) {
          _ignoredOpens--;
          i = closed.end;
          continue;
        }
        if (capture != null && _stack.length == 1) {
          capture.bodyEnd = offset + closed.start;
        }
        _popDetails(closed.end);
        i = closed.end;
        continue;
      }
      i++;
    }
  }

  void _popDetails(int end) {
    _stack.removeLast();
    if (_stack.isEmpty) closedAt = end;
  }
}

/// End of a details block that starts at the first non-empty logical line,
/// or -1 if [text] is not a details block under the shared rules.
int markdownDetailsExtent(String text, {bool enableMath = false}) {
  final walker = MarkdownDetailsWalker();
  final math = markdownScanDisplayMath(text, enableMath: enableMath);
  var spanAt = 0;
  var i = 0;
  var opened = false;
  while (i < text.length) {
    var lineEnd = i;
    while (lineEnd < text.length &&
        !markdownIsLogicalLineBreak(text.codeUnitAt(lineEnd))) {
      _noteScanVisit();
      lineEnd++;
    }
    final raw = text.substring(i, lineEnd);
    final trimmed = raw.trimLeft();
    while (spanAt < math.spans.length && math.spans[spanAt].end <= i) {
      _noteScanVisit();
      spanAt++;
    }
    final inMath =
        spanAt < math.spans.length &&
        math.spans[spanAt].start < lineEnd &&
        math.spans[spanAt].end > i;
    if (!inMath) {
      walker.consume(trimmed, advance: _LineBackticks.of(trimmed).advance);
    }
    // A one-line `<details>…</details>` opens and closes in the same
    // consume, so depth is 0 afterwards. closedAt still marks the block.
    if (walker.depth > 0 || walker.closedAt != null) opened = true;
    if (!opened) {
      if (trimmed.isNotEmpty) return -1;
    } else if (walker.depth == 0) {
      if (walker.overflowed) return -1;
      final indent = raw.length - trimmed.length;
      return i + indent + (walker.closedAt ?? trimmed.length);
    }
    i = _skipLogicalLineBreak(text, lineEnd, text.length);
  }
  return -1;
}

final class MarkdownDetailsBlock {
  const MarkdownDetailsBlock({
    required this.attrs,
    required this.summary,
    required this.body,
  });

  final String attrs;
  final String summary;
  final String body;

  bool get initiallyExpanded =>
      RegExp(r'(?:^|\s)open(?:\s|$|=)', caseSensitive: false).hasMatch(attrs);
}

final class MarkdownDetailsCapture {
  String attrs = '';
  int summaryStart = -1;
  int summaryEnd = -1;
  int bodyStart = -1;
  int bodyEnd = -1;
}

MarkdownDetailsBlock? markdownParseDetails(
  String text, {
  bool enableMath = false,
}) {
  final slice = text.trim();
  final end = markdownDetailsExtent(slice, enableMath: enableMath);
  if (end < 0) return null;
  final capture = MarkdownDetailsCapture();
  final walker = MarkdownDetailsWalker();
  final math = markdownScanDisplayMath(slice, end: end, enableMath: enableMath);
  var spanAt = 0;
  var i = 0;
  while (i < end) {
    var lineEnd = i;
    while (lineEnd < end &&
        !markdownIsLogicalLineBreak(slice.codeUnitAt(lineEnd))) {
      _noteScanVisit();
      lineEnd++;
    }
    final raw = slice.substring(i, lineEnd);
    final indent = raw.length - raw.trimLeft().length;
    final trimmed = raw.substring(indent);
    while (spanAt < math.spans.length && math.spans[spanAt].end <= i) {
      _noteScanVisit();
      spanAt++;
    }
    final inMath =
        spanAt < math.spans.length &&
        math.spans[spanAt].start < lineEnd &&
        math.spans[spanAt].end > i;
    if (!inMath) {
      walker.consume(
        trimmed,
        advance: _LineBackticks.of(trimmed).advance,
        offset: i + indent,
        capture: capture,
      );
    }
    i = _skipLogicalLineBreak(slice, lineEnd, end);
  }
  if (capture.summaryStart < 0 ||
      capture.summaryEnd < capture.summaryStart ||
      capture.bodyStart < 0 ||
      capture.bodyEnd < capture.bodyStart) {
    return null;
  }
  return MarkdownDetailsBlock(
    attrs: capture.attrs,
    summary: slice.substring(capture.summaryStart, capture.summaryEnd),
    body: slice.substring(capture.bodyStart, capture.bodyEnd),
  );
}

String _detailsOpenAttrs(String tag) {
  if (tag.length <= 9) return '';
  return tag.substring(8, tag.length - 1);
}

final class MarkdownDetailsSegment {
  const MarkdownDetailsSegment.prose(this.text) : details = null;
  const MarkdownDetailsSegment.details(this.details) : text = '';

  final String text;
  final MarkdownDetailsBlock? details;
}

/// Top-level details blocks, in source order.
///
/// One walker walks the whole string. A block is committed only when
/// global depth goes `0→1→0` without overflow, and the closer sits on a
/// renderer block boundary (end of line, trailing spaces, or EOF). An
/// unclosed or overflowed outer therefore cannot promote an inner opener.
///
/// When [enableMath] is true, tags inside a successful [markdownScanDisplayMath]
/// span are not top-level. Unclosed math openers do not hide tags. Tokens
/// inside a closed span do not update walker depth.
List<MarkdownDetailsSegment> markdownExtractTopLevelDetails(
  String text, {
  bool enableMath = false,
}) {
  final segments = <MarkdownDetailsSegment>[];
  final lexer = MarkdownLineLexer();
  final math = markdownScanDisplayMath(text, enableMath: enableMath);
  var cursor = 0;
  var topStart = -1;
  var spanAt = 0;
  var i = 0;

  bool lineIntersectsMath(int lineStart, int lineEnd) {
    final spans = math.spans;
    while (spanAt < spans.length && spans[spanAt].end <= lineStart) {
      _noteScanVisit();
      spanAt++;
    }
    if (spanAt >= spans.length) return false;
    final span = spans[spanAt];
    return span.start < lineEnd && span.end > lineStart;
  }

  while (i < text.length) {
    var lineEnd = i;
    while (lineEnd < text.length &&
        !markdownIsLogicalLineBreak(text.codeUnitAt(lineEnd))) {
      _noteScanVisit();
      lineEnd++;
    }
    final raw = text.substring(i, lineEnd);
    final indent = raw.length - raw.trimLeft().length;
    final trimmed = raw.substring(indent);
    final inMath = lineIntersectsMath(i, lineEnd);
    if (!inMath &&
        lexer.detailsDepth == 0 &&
        !lexer.fenced &&
        trimmed.isNotEmpty &&
        MarkdownDetailsWalker.open.matchAsPrefix(trimmed) != null) {
      topStart = i;
    }
    if (!inMath) lexer.consumeLine(raw);
    if (topStart >= 0 &&
        lexer.detailsDepth == 0 &&
        lexer.detailsClosedAt != null) {
      final end = i + indent + lexer.detailsClosedAt!;
      final boundary = _detailsBlockBoundaryEnd(text, end);
      if (!lexer.detailsOverflowed &&
          boundary >= 0 &&
          !math.contains(end - 1)) {
        final parsed = markdownParseDetails(
          text.substring(topStart, boundary),
          enableMath: enableMath,
        );
        if (parsed != null) {
          if (topStart > cursor) {
            segments.add(
              MarkdownDetailsSegment.prose(text.substring(cursor, topStart)),
            );
          }
          segments.add(MarkdownDetailsSegment.details(parsed));
          cursor = boundary;
        }
      }
      topStart = -1;
      lexer.resetDetails();
    }
    i = _skipLogicalLineBreak(text, lineEnd, text.length);
  }
  if (cursor < text.length) {
    segments.add(MarkdownDetailsSegment.prose(text.substring(cursor)));
  } else if (segments.isEmpty) {
    segments.add(MarkdownDetailsSegment.prose(text));
  }
  return segments;
}

/// End of the span that can replace a details block, or -1 if [end] is
/// not a block boundary. Trailing spaces/tabs are absorbed so the
/// placeholder can occupy the whole line.
int _detailsBlockBoundaryEnd(String text, int end) {
  var i = end;
  while (i < text.length) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x20 || unit == 0x09) {
      i++;
      continue;
    }
    return markdownIsLogicalLineBreak(unit) ? i : -1;
  }
  return i;
}

/// Replaces complete details blocks with placeholders so [DetailsHtmlMd]
/// can match them without rewriting `<` in the visible source.
///
/// Tokens are minted per registry and only [lookup] of an issued token
/// returns a block. A nonce that does not appear in the source keeps
/// user text shaped like a placeholder from colliding.
final class MarkdownDetailsRegistry {
  MarkdownDetailsRegistry({this.enableMath = false});

  final bool enableMath;
  final Map<String, MarkdownDetailsBlock> _blocks = {};
  final Map<String, String> _rewritten = {};
  String? _nonce;
  int _nextId = 0;

  bool get hasIssuedPlaceholders => _blocks.isNotEmpty;

  String? _rootSource;

  void _bindRoot(String text) {
    if (_rootSource != null) return;
    _rootSource = text;
    _nonce = _nonceFor(text);
  }

  /// Pattern for tokens this registry has issued, or a never-match if none.
  String get placeholderSource {
    final nonce = _nonce;
    if (nonce == null) return '(?!)';
    return '\uE010${RegExp.escape(nonce)}:[0-9]+\uE011';
  }

  String rewrite(String text) {
    return _rewritten.putIfAbsent(text, () {
      _bindRoot(text);
      final segments = markdownExtractTopLevelDetails(
        text,
        enableMath: enableMath,
      );
      if (segments.length == 1 && segments.first.details == null) {
        return text;
      }
      final out = StringBuffer();
      for (final segment in segments) {
        final details = segment.details;
        if (details == null) {
          out.write(segment.text);
          continue;
        }
        final token = '\uE010$_nonce:${_nextId++}\uE011';
        _blocks[token] = details;
        out.write(token);
      }
      return out.toString();
    });
  }

  MarkdownDetailsBlock? lookup(String text) {
    if (_nonce == null || _blocks.isEmpty) return null;
    final match = _issuedToken.firstMatch(text.trim());
    if (match == null) return null;
    return _blocks[match.group(0)!];
  }

  static String _nonceFor(String text) {
    final used = <int>{};
    var i = 0;
    while (i < text.length) {
      _noteScanVisit();
      if (text.codeUnitAt(i) != 0xE010) {
        i++;
        continue;
      }
      var j = i + 1;
      var n = 0;
      var digits = false;
      while (j < text.length) {
        _noteScanVisit();
        final unit = text.codeUnitAt(j);
        if (unit >= 0x30 && unit <= 0x39) {
          digits = true;
          n = n * 10 + (unit - 0x30);
          j++;
          continue;
        }
        if (digits && unit == 0x3A) used.add(n);
        break;
      }
      i++;
    }
    var nonce = 0;
    while (used.contains(nonce)) {
      nonce++;
    }
    return '$nonce';
  }

  RegExp get _issuedToken =>
      RegExp('\uE010${RegExp.escape(_nonce ?? '')}:[0-9]+\uE011');
}

enum _DetailsRegion { afterOpen, inSummary, inBody }

/// Backtick runs on one line, paired in a single left-to-right pass.
///
/// An unmatched opener stays only that run: treating it as code through the
/// end of the line would hide a later `$$` on the same line, and looking
/// for a closer from every opener would rescan the tail once per run.
final class _LineBackticks {
  const _LineBackticks._(this._jump);

  static const empty = _LineBackticks._(null);

  final Map<int, int>? _jump;

  int get slotCount => _jump?.length ?? 0;

  int advance(int i) => _jump![i] ?? i + 1;

  String withoutCode(String line) {
    if (_jump == null) return line;
    final output = StringBuffer();
    var cursor = 0;
    var index = 0;
    var removed = false;
    while (index < line.length) {
      if (line.codeUnitAt(index) != 0x60) {
        index++;
        continue;
      }
      var runEnd = index + 1;
      while (runEnd < line.length && line.codeUnitAt(runEnd) == 0x60) {
        runEnd++;
      }
      final spanEnd = advance(index);
      if (spanEnd > runEnd) {
        output
          ..write(line.substring(cursor, index))
          ..write(' ');
        cursor = spanEnd;
        index = spanEnd;
        removed = true;
      } else {
        index = runEnd;
      }
    }
    if (!removed) return line;
    output.write(line.substring(cursor));
    return output.toString();
  }

  static _LineBackticks of(String line) {
    final starts = <int>[];
    final lengths = <int>[];
    var i = 0;
    while (i < line.length) {
      _noteScanVisit();
      if (line.codeUnitAt(i) != 0x60) {
        i++;
        continue;
      }
      final start = i;
      i++;
      while (i < line.length && line.codeUnitAt(i) == 0x60) {
        _noteScanVisit();
        i++;
      }
      starts.add(start);
      lengths.add(i - start);
    }
    if (starts.isEmpty) return empty;

    final runCount = starts.length;
    final nextSame = List<int>.filled(runCount, -1);
    final lastByLength = <int, int>{};
    for (var r = runCount - 1; r >= 0; r--) {
      nextSame[r] = lastByLength[lengths[r]] ?? -1;
      lastByLength[lengths[r]] = r;
    }

    final jump = <int, int>{};
    final consumed = List<bool>.filled(runCount, false);
    for (var r = 0; r < runCount; r++) {
      if (consumed[r]) continue;
      final closer = nextSame[r];
      if (closer >= 0) {
        jump[starts[r]] = starts[closer] + lengths[closer];
        for (var k = r; k <= closer; k++) {
          consumed[k] = true;
        }
      } else {
        jump[starts[r]] = starts[r] + lengths[r];
        consumed[r] = true;
      }
    }
    return _LineBackticks._(jump);
  }
}

int debugMarkdownScanVisits = 0;
bool _markdownScanCounting = false;

void debugResetMarkdownScanVisits() {
  debugMarkdownScanVisits = 0;
  _markdownScanCounting = true;
}

void debugDisableMarkdownScanVisits() {
  _markdownScanCounting = false;
}

/// Jump slots kept for [line]. Proportional to backtick runs, not line length.
int debugBacktickJumpSlotCount(String line) =>
    _LineBackticks.of(line).slotCount;

/// Upper bound on visits per source code unit. Several linear passes are
/// expected; a per-opener rescan of the leftover line would exceed this
/// on unmatched backtick runs of increasing length.
const int debugMarkdownScanVisitBudgetFactor = 12;

void _noteScanVisit() {
  assert(() {
    if (_markdownScanCounting) debugMarkdownScanVisits++;
    return true;
  }());
}

/// Line terminators a Dart multiline `^` / `$` recognises. The splitter
/// still only ends blocks on `\n`; these marks stay content there.
bool markdownIsLogicalLineBreak(int unit) =>
    unit == 0x0A || unit == 0x0D || unit == 0x2028 || unit == 0x2029;

bool _isPhysicalLineInternalBreak(int unit) =>
    unit == 0x0D || unit == 0x2028 || unit == 0x2029;

int _skipLogicalLineBreak(String content, int lineEnd, int end) {
  if (lineEnd >= end) return end;
  if (content.codeUnitAt(lineEnd) == 0x0D &&
      lineEnd + 1 < end &&
      content.codeUnitAt(lineEnd + 1) == 0x0A) {
    return lineEnd + 2;
  }
  return lineEnd + 1;
}

final class _FenceMark {
  const _FenceMark({
    required this.start,
    required this.marker,
    required this.length,
    required this.canClose,
    required this.canOpen,
  });

  final int start;
  final int marker;
  final int length;
  final bool canClose;
  final bool canOpen;
}

_FenceMark? _fenceMarkOf(String rawLine, int lineStart) {
  var indent = 0;
  while (indent < rawLine.length) {
    final unit = rawLine.codeUnitAt(indent);
    if (unit != 0x20 && unit != 0x09) break;
    _noteScanVisit();
    indent++;
  }
  if (indent >= rawLine.length) return null;
  final marker = rawLine.codeUnitAt(indent);
  if (marker != 0x60 && marker != 0x7E) return null;
  var n = indent + 1;
  while (n < rawLine.length && rawLine.codeUnitAt(n) == marker) {
    _noteScanVisit();
    n++;
  }
  final length = n - indent;
  if (length < 3) return null;
  var canClose = true;
  var canOpen = true;
  for (var i = n; i < rawLine.length; i++) {
    _noteScanVisit();
    final unit = rawLine.codeUnitAt(i);
    if (unit != 0x20 && unit != 0x09) {
      canClose = false;
    }
    // CommonMark: a backtick fence info string cannot contain a backtick.
    // Tilde fences allow backticks in the info string.
    if (marker == 0x60 && unit == 0x60) {
      canOpen = false;
    }
  }
  return _FenceMark(
    start: lineStart + indent,
    marker: marker,
    length: length,
    canClose: canClose,
    canOpen: canOpen,
  );
}

/// Math environments understood by the bundled TeX parser.
const markdownMathEnvironments = <String>[
  'array',
  'darray',
  'matrix',
  'pmatrix',
  'bmatrix',
  'Bmatrix',
  'vmatrix',
  'Vmatrix',
  'smallmatrix',
  'subarray',
  'cases',
  'dcases',
  'rcases',
  'drcases',
  'aligned',
  'alignedat',
  'equation',
  'equation*',
  'align',
  'align*',
  'alignat',
  'alignat*',
  'gather',
  'gather*',
  'gathered',
  'split',
];

final _mathEnvironmentToken = RegExp(
  r'\\(begin|end)\{('
  '${markdownMathEnvironments.map(RegExp.escape).join('|')}'
  r')\}',
);

final _mathEnvironmentTokenTexts = <String>[
  for (final name in markdownMathEnvironments) ...[
    '\\begin{$name}',
    '\\end{$name}',
  ],
];
final _maxMathEnvironmentTokenLength = _mathEnvironmentTokenTexts.fold<int>(
  0,
  (longest, token) => token.length > longest ? token.length : longest,
);

final class _MathEnvironmentMark {
  const _MathEnvironmentMark(this.name, this.start, this.end);

  final String name;
  final int start;
  final int end;
}

final class _MathEnvironmentToken {
  const _MathEnvironmentToken(this.start, this.end, this.opening);

  final int start;
  final int end;
  final bool opening;
}

final class _MathEnvironmentCloser {
  const _MathEnvironmentCloser(this.start, this.tokenEnd, this.spanEnd);

  final int start;
  final int tokenEnd;
  final int spanEnd;
}

enum _TexVerbProbeStatus { none, pending, complete }

final class _TexVerbProbe {
  const _TexVerbProbe._none()
    : status = _TexVerbProbeStatus.none,
      end = null,
      delimiter = null,
      searchedTo = 0;

  static const none = _TexVerbProbe._none();

  const _TexVerbProbe.pending({this.delimiter, required this.searchedTo})
    : status = _TexVerbProbeStatus.pending,
      end = null;

  const _TexVerbProbe.complete(this.end)
    : status = _TexVerbProbeStatus.complete,
      delimiter = null,
      searchedTo = 0;

  final _TexVerbProbeStatus status;
  final int? end;
  final int? delimiter;
  final int searchedTo;
}

final class _DisplayMathLineState {
  const _DisplayMathLineState({
    required this.lineLeading,
    required this.environmentLineLeading,
    required this.environmentIndentColumns,
    required this.environmentComment,
    required this.pendingEnvironmentName,
    required this.pendingEnvironmentStart,
    required this.pendingEnvironmentTokenAt,
    required this.pendingEnvironmentDepth,
    required this.commentMatchedEnvironmentName,
    required this.commentMatchedEnvironmentStart,
    required this.commentMatchedEnvironmentCloseStart,
    required this.commentMatchedEnvironmentCloseAt,
  });

  final bool lineLeading;
  final bool environmentLineLeading;
  final int environmentIndentColumns;
  final bool environmentComment;
  final String? pendingEnvironmentName;
  final int? pendingEnvironmentStart;
  final int pendingEnvironmentTokenAt;
  final int pendingEnvironmentDepth;
  final String? commentMatchedEnvironmentName;
  final int? commentMatchedEnvironmentStart;
  final int? commentMatchedEnvironmentCloseStart;
  final int? commentMatchedEnvironmentCloseAt;
}

final class _IncrementalBacktickResult {
  _IncrementalBacktickResult({
    required this.start,
    required this.end,
    required this.length,
    required this.paired,
    this.state,
  });

  final int start;
  final int end;
  final int length;
  final bool paired;
  final _DisplayMathLineState? state;
  late final int index;
}

/// Resolves current-line backtick runs with the same greedy rule as
/// [_LineBackticks], while allowing the final run to grow across appends.
final class _IncrementalLineBackticks {
  final _results = <_IncrementalBacktickResult>[];
  final _standaloneByLength = <int, _IncrementalBacktickResult>{};
  int? _trailingStart;
  var _trailingLength = 0;
  _DisplayMathLineState? _trailingState;

  void reset() {
    _results.clear();
    _standaloneByLength.clear();
    _trailingStart = null;
    _trailingLength = 0;
    _trailingState = null;
  }

  void consume(int offset, _DisplayMathLineState state) {
    if (_trailingStart == null) {
      _trailingStart = offset;
      _trailingLength = 1;
      _trailingState = state;
    } else {
      _trailingLength++;
    }
  }

  _DisplayMathLineState? finishRun() {
    final start = _trailingStart;
    if (start == null) return null;
    final length = _trailingLength;
    final end = start + length;
    final opener = _standaloneByLength[length];
    _DisplayMathLineState? restored;
    if (opener == null) {
      restored = _trailingState;
      _append(
        _IncrementalBacktickResult(
          start: start,
          end: end,
          length: length,
          paired: false,
          state: _trailingState,
        ),
      );
    } else {
      restored = opener.state;
      while (_results.length > opener.index) {
        final removed = _results.removeLast();
        if (!removed.paired) {
          _standaloneByLength.remove(removed.length);
        }
      }
      _append(
        _IncrementalBacktickResult(
          start: opener.start,
          end: end,
          length: length,
          paired: true,
        ),
      );
    }
    _trailingStart = null;
    _trailingLength = 0;
    _trailingState = null;
    return restored;
  }

  _DisplayMathLineState? get provisionalState =>
      _standaloneByLength[_trailingLength]?.state;

  bool get hasTrailingRun => _trailingStart != null;

  bool get hasStandaloneRuns => _standaloneByLength.isNotEmpty;

  bool hasStandaloneRun(int length) => _standaloneByLength.containsKey(length);

  _DisplayMathLineState? get pairingState {
    if (_trailingStart == null) return null;
    return _standaloneByLength[_trailingLength]?.state ?? _trailingState;
  }

  bool contains(int offset) => hiddenSpanEnd(offset) != null;

  int? hiddenSpanEnd(int offset) {
    final provisionalOpener = _standaloneByLength[_trailingLength];
    if (provisionalOpener != null &&
        offset >= provisionalOpener.start &&
        offset < _trailingStart! + _trailingLength) {
      return _trailingStart! + _trailingLength;
    }
    final resultLimit = provisionalOpener?.index ?? _results.length;
    if (resultLimit == 0 || offset < _results.first.start) return null;
    var low = 0;
    var high = resultLimit;
    while (low < high) {
      _noteScanVisit();
      final middle = (low + high) >> 1;
      if (_results[middle].start <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    if (low == 0) return null;
    final result = _results[low - 1];
    return result.paired && offset < result.end ? result.end : null;
  }

  void _append(_IncrementalBacktickResult result) {
    result.index = _results.length;
    _results.add(result);
    if (!result.paired) _standaloneByLength[result.length] = result;
  }
}

/// A successful display-math span under the shared pairing rules.
final class MarkdownDisplayMathSpan {
  const MarkdownDisplayMathSpan({required this.start, required this.end});

  final int start;
  final int end;
}

/// Closed display-math spans plus the leftmost unclosed opener, if any.
///
/// [contains] is the extractor/classifier view: only successful spans occupy
/// later content. [covers] is the splitter view: an unclosed opener holds a
/// later blank until a closer arrives or a later successful span abandons it.
/// Raw environments retain their unfinished outer body, including completed
/// nested environments, until their matching outer end arrives.
final class MarkdownDisplayMathScan {
  const MarkdownDisplayMathScan({this.spans = const [], this.unclosedStart});

  final List<MarkdownDisplayMathSpan> spans;
  final int? unclosedStart;

  bool contains(int offset) {
    for (final span in spans) {
      if (offset >= span.start && offset < span.end) return true;
    }
    return false;
  }

  bool covers(int offset) {
    if (contains(offset)) return true;
    return unclosedStart != null && offset >= unclosedStart!;
  }
}

/// Incremental collector shared by the splitter, Details extractor, and
/// trailing-separator classifier. Current-line candidates roll back by
/// length checkpoint; pairing resumes from the earliest unresolved opener.
final class MarkdownDisplayMathScanner {
  String _text = '';
  var _scannedTo = 0;
  var _lineStart = 0;
  var _lineLeading = true;
  var _environmentLineLeading = true;
  var _environmentIndentColumns = 0;
  var _environmentComment = false;
  var _precedingBackslashes = 0;
  final _currentLineBackticks = _IncrementalLineBackticks();
  var _currentLineBackticksChanged = false;
  _DisplayMathLineState? _lineStartPairState;
  final _dollarOpens = <int>[];
  final _dollarCloses = <int>[];
  final _bracketOpens = <int>[];
  final _bracketCloses = <int>[];
  final _environmentOpens = <_MathEnvironmentMark>[];
  final _environmentCloses = <String, List<_MathEnvironmentCloser>>{};
  final _environmentTokens = <String, List<_MathEnvironmentToken>>{};
  final _fenceOpens = <_FenceMark>[];
  final _fenceCloses = <_FenceMark>[];
  var _chkDollarOpens = 0;
  var _chkDollarCloses = 0;
  var _chkBracketOpens = 0;
  var _chkBracketCloses = 0;
  var _chkEnvironmentOpens = 0;
  final _chkEnvironmentCloses = <String, int>{};
  final _chkEnvironmentTokens = <String, int>{};
  var _chkFenceOpens = 0;
  var _chkFenceCloses = 0;
  final _spans = <MarkdownDisplayMathSpan>[];
  var _frozenSpanCount = 0;
  var _frozenPos = 0;
  var _frozenDollarOpenAt = 0;
  var _frozenBracketOpenAt = 0;
  var _frozenDollarCloseAt = 0;
  var _frozenBracketCloseAt = 0;
  var _frozenEnvironmentOpenAt = 0;
  final _frozenEnvironmentCloseAt = <String, int>{};
  final _frozenEnvironmentTokenAt = <String, int>{};
  var _frozenFenceOpenAt = 0;
  var _frozenFenceCloseAt = 0;
  String? _pendingEnvironmentName;
  int? _pendingEnvironmentStart;
  var _pendingEnvironmentTokenAt = 0;
  var _pendingEnvironmentDepth = 0;
  String? _commentMatchedEnvironmentName;
  int? _commentMatchedEnvironmentStart;
  int? _commentMatchedEnvironmentCloseStart;
  int? _commentMatchedEnvironmentCloseAt;
  int? _pendingTexVerbStart;
  int? _pendingTexVerbDelimiter;
  int? _pendingTexVerbCompleteEnd;
  var _pendingTexVerbSearchedTo = 0;
  var _pendingTexVerbBacktickSearchedTo = 0;
  int? _pendingTexVerbBacktickRunStart;
  var _pendingTexVerbBacktickRunLength = 0;

  void reset() {
    _text = '';
    _scannedTo = 0;
    _lineStart = 0;
    _lineLeading = true;
    _environmentLineLeading = true;
    _environmentIndentColumns = 0;
    _environmentComment = false;
    _precedingBackslashes = 0;
    _currentLineBackticks.reset();
    _currentLineBackticksChanged = false;
    _lineStartPairState = null;
    _dollarOpens.clear();
    _dollarCloses.clear();
    _bracketOpens.clear();
    _bracketCloses.clear();
    _environmentOpens.clear();
    _environmentCloses.clear();
    _environmentTokens.clear();
    _fenceOpens.clear();
    _fenceCloses.clear();
    _chkDollarOpens = 0;
    _chkDollarCloses = 0;
    _chkBracketOpens = 0;
    _chkBracketCloses = 0;
    _chkEnvironmentOpens = 0;
    _chkEnvironmentCloses.clear();
    _chkEnvironmentTokens.clear();
    _chkFenceOpens = 0;
    _chkFenceCloses = 0;
    _spans.clear();
    _frozenSpanCount = 0;
    _frozenPos = 0;
    _frozenDollarOpenAt = 0;
    _frozenBracketOpenAt = 0;
    _frozenDollarCloseAt = 0;
    _frozenBracketCloseAt = 0;
    _frozenEnvironmentOpenAt = 0;
    _frozenEnvironmentCloseAt.clear();
    _frozenEnvironmentTokenAt.clear();
    _frozenFenceOpenAt = 0;
    _frozenFenceCloseAt = 0;
    _clearPendingEnvironment();
    _clearCommentMatchedEnvironment();
    _clearPendingTexVerb();
  }

  MarkdownDisplayMathScan synchronize(
    String text, {
    int? end,
    bool enableMath = true,
  }) {
    final limit = end ?? text.length;
    if (!enableMath || limit <= 0) {
      reset();
      return const MarkdownDisplayMathScan();
    }
    if (_text.isNotEmpty &&
        (_scannedTo > limit ||
            _scannedTo > text.length ||
            !text.startsWith(
              _text.substring(0, _scannedTo.clamp(0, _text.length)),
            ))) {
      reset();
    }
    final pendingTexVerbValidatedTo =
        _pendingTexVerbBacktickSearchedTo > _pendingTexVerbSearchedTo
        ? _pendingTexVerbBacktickSearchedTo
        : _pendingTexVerbSearchedTo;
    if (_pendingTexVerbStart != null &&
        (pendingTexVerbValidatedTo > limit ||
            pendingTexVerbValidatedTo > text.length ||
            !text.startsWith(
              _text.substring(
                0,
                pendingTexVerbValidatedTo.clamp(0, _text.length),
              ),
            ))) {
      _clearPendingTexVerb();
    }
    _text = text;
    _feed(limit);
    if (_currentLineBackticksChanged) {
      final state = _currentLineBackticks.pairingState;
      if (state != null) _restorePairState(state);
      _currentLineBackticksChanged = false;
    }
    return _pair(limit);
  }

  void _feed(int limit) {
    while (_scannedTo < limit) {
      final unit = _text.codeUnitAt(_scannedTo);
      if (unit != 0x60) {
        final restored = _currentLineBackticks.finishRun();
        if (restored != null) _restoreLineState(restored);
      }
      if (!_environmentComment &&
          unit == 0x5C &&
          _precedingBackslashes.isEven) {
        final resumesVerb = _pendingTexVerbStart == _scannedTo;
        final verb = resumesVerb && _pendingTexVerbCompleteEnd != null
            ? _TexVerbProbe.complete(_pendingTexVerbCompleteEnd!)
            : _probeTexVerb(
                _text,
                _scannedTo,
                limit,
                knownDelimiter: resumesVerb ? _pendingTexVerbDelimiter : null,
                searchFrom: resumesVerb ? _pendingTexVerbSearchedTo : null,
              );
        final interruptedByCode = _verbClosingBacktickRun(
          verb,
          limit,
          resumesVerb: resumesVerb,
        );
        if (interruptedByCode != null) {
          if (interruptedByCode.provisional) {
            _pendingTexVerbStart = _scannedTo;
            _pendingTexVerbDelimiter = verb.delimiter;
            _pendingTexVerbCompleteEnd =
                verb.status == _TexVerbProbeStatus.complete ? verb.end : null;
            _pendingTexVerbSearchedTo =
                verb.status == _TexVerbProbeStatus.complete
                ? verb.end!
                : verb.searchedTo;
            _revokeEnvironmentClosersThrough(_scannedTo);
            return;
          }
          _clearPendingTexVerb();
          _pair(interruptedByCode.start);
          _lineLeading = false;
          _environmentLineLeading = false;
          for (
            var i = interruptedByCode.start;
            i < interruptedByCode.end;
            i++
          ) {
            _currentLineBackticks.consume(i, _lineState());
          }
          _currentLineBackticksChanged = true;
          _scannedTo = interruptedByCode.end;
          _precedingBackslashes = 0;
          continue;
        }
        if (verb.status == _TexVerbProbeStatus.pending) {
          _pendingTexVerbStart = _scannedTo;
          _pendingTexVerbDelimiter = verb.delimiter;
          _pendingTexVerbCompleteEnd = null;
          _pendingTexVerbSearchedTo = verb.searchedTo;
          _revokeEnvironmentClosersThrough(_scannedTo);
          return;
        }
        if (verb.status == _TexVerbProbeStatus.complete) {
          final skipEnd = _pendingTexVerbBacktickSearchedTo > verb.end!
              ? _pendingTexVerbBacktickSearchedTo
              : verb.end!;
          _clearPendingTexVerb();
          _revokeClosersThrough(_scannedTo);
          _lineLeading = false;
          _environmentLineLeading = false;
          _scannedTo = skipEnd;
          _precedingBackslashes = 0;
          continue;
        }
        _clearPendingTexVerb();
      }
      if (!markdownIsLogicalLineBreak(unit) &&
          _scannedTo + 1 >= limit &&
          (unit == 0x24 || unit == 0x5C)) {
        if (!_environmentComment) {
          _revokeEnvironmentClosersThrough(_scannedTo);
        }
        return;
      }
      if (!_environmentComment &&
          unit == 0x5C &&
          _precedingBackslashes.isEven &&
          _hasIncompleteEnvironmentToken(_scannedTo, limit)) {
        _revokeEnvironmentClosersThrough(_scannedTo);
        return;
      }
      _noteScanVisit();
      if (markdownIsLogicalLineBreak(unit)) {
        final lineStartPairState = _lineStartPairState;
        if (lineStartPairState == null) {
          _clearPendingEnvironment();
          _clearCommentMatchedEnvironment();
        } else {
          _restorePairState(lineStartPairState);
        }
        _rollbackCurrentLine();
        _collectCompleteLine(_lineStart, _scannedTo);
        // Complete-line collection has already applied the authoritative
        // backtick walk. Do not filter those exact candidates through the
        // provisional current-line resolver again.
        _currentLineBackticks.reset();
        _currentLineBackticksChanged = false;
        _environmentComment = false;
        _pair(_scannedTo);
        _clearCommentMatchedEnvironment();
        _scannedTo = _skipLogicalLineBreak(_text, _scannedTo, limit);
        _lineStart = _scannedTo;
        _lineLeading = true;
        _environmentLineLeading = true;
        _environmentIndentColumns = 0;
        _environmentComment = false;
        _precedingBackslashes = 0;
        _lineStartPairState = _lineState();
        _checkpointCurrentLine();
        continue;
      }
      _consumeAt(_scannedTo, limit);
    }
  }

  void _checkpointCurrentLine() {
    _chkDollarOpens = _dollarOpens.length;
    _chkDollarCloses = _dollarCloses.length;
    _chkBracketOpens = _bracketOpens.length;
    _chkBracketCloses = _bracketCloses.length;
    _chkEnvironmentOpens = _environmentOpens.length;
    for (final entry in _environmentCloses.entries) {
      _chkEnvironmentCloses[entry.key] = entry.value.length;
    }
    for (final entry in _environmentTokens.entries) {
      _chkEnvironmentTokens[entry.key] = entry.value.length;
    }
    _chkFenceOpens = _fenceOpens.length;
    _chkFenceCloses = _fenceCloses.length;
  }

  void _rollbackCurrentLine() {
    _dollarOpens.length = _chkDollarOpens;
    _dollarCloses.length = _chkDollarCloses;
    _bracketOpens.length = _chkBracketOpens;
    _bracketCloses.length = _chkBracketCloses;
    _environmentOpens.length = _chkEnvironmentOpens;
    for (final entry in _environmentCloses.entries) {
      entry.value.length = _chkEnvironmentCloses[entry.key] ?? 0;
    }
    for (final entry in _environmentTokens.entries) {
      entry.value.length = _chkEnvironmentTokens[entry.key] ?? 0;
    }
    _fenceOpens.length = _chkFenceOpens;
    _fenceCloses.length = _chkFenceCloses;
  }

  void _consumeAt(int i, int limit) {
    final unit = _text.codeUnitAt(i);
    if (unit == 0x60) {
      if (!_currentLineBackticks.hasTrailingRun) _pair(i);
      _currentLineBackticksChanged = true;
    }
    final environmentCanOpen =
        _environmentLineLeading && _environmentIndentColumns < 4;
    final beginsEnvironmentComment =
        !_environmentComment && unit == 0x25 && _precedingBackslashes.isEven;
    if (!_environmentComment &&
        !beginsEnvironmentComment &&
        !markdownIsWhitespace(unit)) {
      _revokeEnvironmentClosersThrough(i);
    }
    if (beginsEnvironmentComment) {
      _environmentComment = true;
    }
    if (!_environmentComment && unit == 0x5C && _precedingBackslashes.isEven) {
      final token = _mathEnvironmentToken.matchAsPrefix(_text, i);
      if (token != null && token.end <= limit) {
        final name = token.group(2)!;
        final opening = token.group(1) == 'begin';
        (_environmentTokens[name] ??= []).add(
          _MathEnvironmentToken(i, token.end, opening),
        );
        _revokeClosersThrough(i);
        if (opening) {
          if (environmentCanOpen) {
            _environmentOpens.add(_MathEnvironmentMark(name, i, token.end));
          }
        } else {
          (_environmentCloses[name] ??= []).add(
            _MathEnvironmentCloser(i, token.end, token.end),
          );
        }
        _lineLeading = false;
        _environmentLineLeading = false;
        _scannedTo = token.end;
        _precedingBackslashes = 0;
        return;
      }
    }
    if (i + 1 < limit && _atDoubleDollar(_text, i)) {
      if (_lineLeading) _dollarOpens.add(i);
      _dollarCloses.add(i);
      _lineLeading = false;
      _environmentLineLeading = false;
      _scannedTo = i + 2;
      _precedingBackslashes = 0;
      return;
    }
    if (i + 1 < limit &&
        _precedingBackslashes.isEven &&
        _atEscaped(_text, i, 0x5B)) {
      if (_lineLeading) _bracketOpens.add(i);
      _lineLeading = false;
      _environmentLineLeading = false;
      _scannedTo = i + 2;
      _precedingBackslashes = 0;
      return;
    }
    if (i + 1 < limit &&
        _precedingBackslashes.isEven &&
        _atEscaped(_text, i, 0x5D)) {
      _bracketCloses.add(i);
      _lineLeading = false;
      _environmentLineLeading = false;
      _scannedTo = i + 2;
      _precedingBackslashes = 0;
      return;
    }
    if (_environmentLineLeading) {
      if (unit == 0x20) {
        _environmentIndentColumns++;
      } else if (unit == 0x09) {
        _environmentIndentColumns += 4 - (_environmentIndentColumns % 4);
      } else {
        _environmentLineLeading = false;
      }
    }
    if (!markdownIsWhitespace(unit)) {
      _lineLeading = false;
      _revokeClosersThrough(i, includeEnvironments: !_environmentComment);
    }
    _scannedTo = i + 1;
    _precedingBackslashes = unit == 0x5C ? _precedingBackslashes + 1 : 0;
    if (unit == 0x60) {
      _currentLineBackticks.consume(i, _lineState());
    }
  }

  _DisplayMathLineState _lineState() => _DisplayMathLineState(
    lineLeading: _lineLeading,
    environmentLineLeading: _environmentLineLeading,
    environmentIndentColumns: _environmentIndentColumns,
    environmentComment: _environmentComment,
    pendingEnvironmentName: _pendingEnvironmentName,
    pendingEnvironmentStart: _pendingEnvironmentStart,
    pendingEnvironmentTokenAt: _pendingEnvironmentTokenAt,
    pendingEnvironmentDepth: _pendingEnvironmentDepth,
    commentMatchedEnvironmentName: _commentMatchedEnvironmentName,
    commentMatchedEnvironmentStart: _commentMatchedEnvironmentStart,
    commentMatchedEnvironmentCloseStart: _commentMatchedEnvironmentCloseStart,
    commentMatchedEnvironmentCloseAt: _commentMatchedEnvironmentCloseAt,
  );

  void _restoreLineState(_DisplayMathLineState state) {
    _lineLeading = state.lineLeading;
    _environmentLineLeading = state.environmentLineLeading;
    _environmentIndentColumns = state.environmentIndentColumns;
    _environmentComment = state.environmentComment;
    _precedingBackslashes = 0;
    _clearPendingTexVerb();
    _restorePairState(state);
  }

  void _restorePairState(_DisplayMathLineState state) {
    _pendingEnvironmentName = state.pendingEnvironmentName;
    _pendingEnvironmentStart = state.pendingEnvironmentStart;
    _pendingEnvironmentTokenAt = state.pendingEnvironmentTokenAt;
    _pendingEnvironmentDepth = state.pendingEnvironmentDepth;
    _commentMatchedEnvironmentName = state.commentMatchedEnvironmentName;
    _commentMatchedEnvironmentStart = state.commentMatchedEnvironmentStart;
    _commentMatchedEnvironmentCloseStart =
        state.commentMatchedEnvironmentCloseStart;
    _commentMatchedEnvironmentCloseAt = state.commentMatchedEnvironmentCloseAt;
  }

  ({int start, int end, bool provisional})? _verbClosingBacktickRun(
    _TexVerbProbe verb,
    int limit, {
    required bool resumesVerb,
  }) {
    if (!_currentLineBackticks.hasStandaloneRuns ||
        verb.status == _TexVerbProbeStatus.none) {
      return null;
    }
    final verbEnd = verb.status == _TexVerbProbeStatus.complete
        ? verb.end!
        : verb.searchedTo;
    var i = resumesVerb ? _pendingTexVerbBacktickSearchedTo : _scannedTo;
    var runStart = resumesVerb ? _pendingTexVerbBacktickRunStart : null;
    var runLength = resumesVerb ? _pendingTexVerbBacktickRunLength : 0;
    while (i < verbEnd) {
      _noteScanVisit();
      if (_text.codeUnitAt(i) == 0x60) {
        runStart ??= i;
        runLength++;
        i++;
        continue;
      }
      if (runStart != null &&
          _currentLineBackticks.hasStandaloneRun(runLength)) {
        return (start: runStart, end: i, provisional: false);
      }
      runStart = null;
      runLength = 0;
      i++;
    }
    if (runStart != null && verb.status == _TexVerbProbeStatus.complete) {
      while (i < limit && _text.codeUnitAt(i) == 0x60) {
        _noteScanVisit();
        runLength++;
        i++;
      }
      if (i < limit) {
        if (_currentLineBackticks.hasStandaloneRun(runLength)) {
          return (start: runStart, end: i, provisional: false);
        }
        runStart = null;
        runLength = 0;
      }
    }
    _pendingTexVerbBacktickSearchedTo = i;
    _pendingTexVerbBacktickRunStart = runStart;
    _pendingTexVerbBacktickRunLength = runLength;
    if (runStart != null) {
      return (start: runStart, end: i, provisional: true);
    }
    if (verb.status == _TexVerbProbeStatus.pending) {
      _pendingTexVerbBacktickSearchedTo = verbEnd;
      _pendingTexVerbBacktickRunStart = runStart;
      _pendingTexVerbBacktickRunLength = runLength;
    }
    return null;
  }

  void _revokeClosersThrough(int nonWsAt, {bool includeEnvironments = true}) {
    while (_dollarCloses.length > _chkDollarCloses) {
      _noteScanVisit();
      final closer = _dollarCloses.last;
      if (closer + 2 > nonWsAt) break;
      _dollarCloses.removeLast();
    }
    while (_bracketCloses.length > _chkBracketCloses) {
      _noteScanVisit();
      final closer = _bracketCloses.last;
      if (closer + 2 > nonWsAt) break;
      _bracketCloses.removeLast();
    }
    if (includeEnvironments) _revokeEnvironmentClosersThrough(nonWsAt);
  }

  void _revokeEnvironmentClosersThrough(int nonWsAt) {
    for (final entry in _environmentCloses.entries) {
      final closes = entry.value;
      final checkpoint = _chkEnvironmentCloses[entry.key] ?? 0;
      while (closes.length > checkpoint) {
        _noteScanVisit();
        if (closes.last.tokenEnd > nonWsAt) break;
        closes.removeLast();
      }
    }
  }

  bool _hasIncompleteEnvironmentToken(int start, int limit) {
    // Every supported token is short; avoid copying a potentially large tail.
    if (limit - start > _maxMathEnvironmentTokenLength) return false;
    final tail = _text.substring(start, limit);
    return _mathEnvironmentTokenTexts.any(
      (token) => token.length > tail.length && token.startsWith(tail),
    );
  }

  void _collectCompleteLine(int start, int end) {
    final rawLine = _text.substring(start, end);
    final fence = _fenceMarkOf(rawLine, start);
    if (fence != null) {
      if (fence.canOpen) _fenceOpens.add(fence);
      if (fence.canClose) _fenceCloses.add(fence);
    }
    final ticks = _LineBackticks.of(rawLine);
    var lineLeading = true;
    var environmentLineLeading = true;
    var environmentIndentColumns = 0;
    var environmentComment = false;
    var precedingBackslashes = 0;
    var j = 0;
    while (j < rawLine.length) {
      _noteScanVisit();
      if (rawLine.codeUnitAt(j) == 0x60) {
        j = ticks.advance(j);
        lineLeading = false;
        environmentLineLeading = false;
        precedingBackslashes = 0;
        continue;
      }
      if (rawLine.codeUnitAt(j) == 0x25 && precedingBackslashes.isEven) {
        environmentComment = true;
      }
      if (!environmentComment && rawLine.codeUnitAt(j) == 0x5C) {
        if (precedingBackslashes.isEven) {
          final verb = _probeTexVerb(rawLine, j, rawLine.length);
          if (verb.status == _TexVerbProbeStatus.complete) {
            lineLeading = false;
            environmentLineLeading = false;
            j = verb.end!;
            precedingBackslashes = 0;
            continue;
          }
        }
        if (precedingBackslashes.isEven) {
          final token = _mathEnvironmentToken.matchAsPrefix(rawLine, j);
          if (token != null) {
            final name = token.group(2)!;
            final opening = token.group(1) == 'begin';
            (_environmentTokens[name] ??= []).add(
              _MathEnvironmentToken(start + j, start + token.end, opening),
            );
            if (opening) {
              if (environmentLineLeading && environmentIndentColumns < 4) {
                _environmentOpens.add(
                  _MathEnvironmentMark(name, start + j, start + token.end),
                );
              }
            } else {
              final closerEnd = _environmentCloserEnd(rawLine, token.end);
              if (closerEnd != null) {
                (_environmentCloses[name] ??= []).add(
                  _MathEnvironmentCloser(
                    start + j,
                    start + token.end,
                    start + closerEnd,
                  ),
                );
              }
            }
            lineLeading = false;
            environmentLineLeading = false;
            j = token.end;
            precedingBackslashes = 0;
            continue;
          }
        }
      }
      if (_atDoubleDollar(rawLine, j)) {
        final at = start + j;
        if (lineLeading) _dollarOpens.add(at);
        if (_onlyWhitespaceAfter(rawLine, j + 2)) _dollarCloses.add(at);
        lineLeading = false;
        environmentLineLeading = false;
        j += 2;
        precedingBackslashes = 0;
        continue;
      }
      if (precedingBackslashes.isEven && _atEscaped(rawLine, j, 0x5B)) {
        if (lineLeading) _bracketOpens.add(start + j);
        lineLeading = false;
        environmentLineLeading = false;
        j += 2;
        precedingBackslashes = 0;
        continue;
      }
      if (precedingBackslashes.isEven && _atEscaped(rawLine, j, 0x5D)) {
        if (_onlyWhitespaceAfter(rawLine, j + 2)) {
          _bracketCloses.add(start + j);
        }
        lineLeading = false;
        environmentLineLeading = false;
        j += 2;
        precedingBackslashes = 0;
        continue;
      }
      if (environmentLineLeading) {
        final unit = rawLine.codeUnitAt(j);
        if (unit == 0x20) {
          environmentIndentColumns++;
        } else if (unit == 0x09) {
          environmentIndentColumns += 4 - (environmentIndentColumns % 4);
        } else {
          environmentLineLeading = false;
        }
      }
      final unit = rawLine.codeUnitAt(j);
      if (!markdownIsWhitespace(unit)) lineLeading = false;
      precedingBackslashes = unit == 0x5C ? precedingBackslashes + 1 : 0;
      j++;
    }
  }

  MarkdownDisplayMathScan _pair(int limit) {
    _spans.length = _frozenSpanCount;
    var pos = _frozenPos;
    var dollarOpenAt = _frozenDollarOpenAt;
    var bracketOpenAt = _frozenBracketOpenAt;
    var dollarCloseAt = _frozenDollarCloseAt;
    var bracketCloseAt = _frozenBracketCloseAt;
    var environmentOpenAt = _frozenEnvironmentOpenAt;
    final environmentCloseAt = Map<String, int>.of(_frozenEnvironmentCloseAt);
    final environmentTokenAt = Map<String, int>.of(_frozenEnvironmentTokenAt);
    var fenceOpenAt = _frozenFenceOpenAt;
    var fenceCloseAt = _frozenFenceCloseAt;
    int? unclosedStart;
    int? earliestUnresolved;
    final peeked = _peekIncompleteFence(limit);
    final currentEnvironmentComment =
        _currentLineBackticks.provisionalState?.environmentComment ??
        _environmentComment;

    bool hiddenByInlineCode(int offset) =>
        offset >= _lineStart && _currentLineBackticks.contains(offset);

    int advanceInt(List<int> values, int index, int min) {
      while (index < values.length &&
          (values[index] < min || hiddenByInlineCode(values[index]))) {
        _noteScanVisit();
        index++;
      }
      return index;
    }

    int advanceEnvironmentClose(
      List<_MathEnvironmentCloser> values,
      int index,
      int min,
    ) {
      while (index < values.length &&
          (values[index].start < min ||
              hiddenByInlineCode(values[index].start))) {
        _noteScanVisit();
        index++;
      }
      return index;
    }

    int advanceFence(int index, int min) {
      while (index < _fenceOpens.length && _fenceOpens[index].start < min) {
        _noteScanVisit();
        index++;
      }
      return index;
    }

    void freeze(
      int nextPos,
      int nextDollarOpen,
      int nextBracketOpen,
      int nextDollarClose,
      int nextBracketClose,
      int nextFenceOpen,
      int nextFenceClose,
    ) {
      if (nextPos > _lineStart) return;
      if (earliestUnresolved != null) return;
      _frozenSpanCount = _spans.length;
      _frozenPos = nextPos;
      _frozenDollarOpenAt = nextDollarOpen;
      _frozenBracketOpenAt = nextBracketOpen;
      _frozenDollarCloseAt = nextDollarClose;
      _frozenBracketCloseAt = nextBracketClose;
      _frozenEnvironmentOpenAt = environmentOpenAt;
      _frozenEnvironmentCloseAt
        ..clear()
        ..addAll(environmentCloseAt);
      _frozenEnvironmentTokenAt
        ..clear()
        ..addAll(environmentTokenAt);
      _frozenFenceOpenAt = nextFenceOpen;
      _frozenFenceCloseAt = nextFenceClose;
    }

    while (true) {
      _noteScanVisit();
      fenceOpenAt = advanceFence(fenceOpenAt, pos);
      dollarOpenAt = advanceInt(_dollarOpens, dollarOpenAt, pos);
      bracketOpenAt = advanceInt(_bracketOpens, bracketOpenAt, pos);
      while (environmentOpenAt < _environmentOpens.length &&
          (_environmentOpens[environmentOpenAt].start < pos ||
              hiddenByInlineCode(_environmentOpens[environmentOpenAt].start))) {
        _noteScanVisit();
        environmentOpenAt++;
      }
      final dollarAt = dollarOpenAt < _dollarOpens.length
          ? _dollarOpens[dollarOpenAt]
          : null;
      final bracketAt = bracketOpenAt < _bracketOpens.length
          ? _bracketOpens[bracketOpenAt]
          : null;
      _FenceMark? fenceAt;
      if (fenceOpenAt < _fenceOpens.length) {
        fenceAt = _fenceOpens[fenceOpenAt];
      }
      if (peeked != null &&
          peeked.start >= pos &&
          (fenceAt == null || peeked.start <= fenceAt.start)) {
        fenceAt = peeked;
      }
      final useDollar =
          dollarAt != null && (bracketAt == null || dollarAt <= bracketAt);
      final delimitedMathAt = useDollar ? dollarAt : bracketAt;
      final environment = environmentOpenAt < _environmentOpens.length
          ? _environmentOpens[environmentOpenAt]
          : null;
      final useEnvironment =
          environment != null &&
          (delimitedMathAt == null || environment.start < delimitedMathAt);
      final mathAt = useEnvironment ? environment.start : delimitedMathAt;
      if (mathAt == null && fenceAt == null) break;

      final mathFirst =
          mathAt != null && (fenceAt == null || mathAt <= fenceAt.start);
      if (mathFirst && useEnvironment) {
        final closes =
            _environmentCloses[environment.name] ??
            const <_MathEnvironmentCloser>[];
        final resumesCommentMatch =
            currentEnvironmentComment &&
            _commentMatchedEnvironmentStart == environment.start &&
            _commentMatchedEnvironmentName == environment.name;
        if (resumesCommentMatch) {
          final cachedCloseStart = _commentMatchedEnvironmentCloseStart!;
          final closeAt = _commentMatchedEnvironmentCloseAt!;
          environmentCloseAt[environment.name] = closeAt;
          if (closeAt < closes.length &&
              closes[closeAt].start == cachedCloseStart) {
            environmentOpenAt++;
            pos = limit;
            _spans.add(
              MarkdownDisplayMathSpan(start: environment.start, end: pos),
            );
            unclosedStart = null;
            break;
          }
          _clearCommentMatchedEnvironmentFor(environment);
        }
        final tokens = _environmentTokens[environment.name]!;
        final resumesPending =
            _pendingEnvironmentStart == environment.start &&
            _pendingEnvironmentName == environment.name;
        var tokenAt = resumesPending
            ? _pendingEnvironmentTokenAt
            : environmentTokenAt[environment.name] ?? 0;
        var depth = resumesPending ? _pendingEnvironmentDepth : 0;
        if (!resumesPending) {
          while (tokenAt < tokens.length &&
              tokens[tokenAt].start < environment.start) {
            _noteScanVisit();
            tokenAt++;
          }
        }
        environmentTokenAt[environment.name] = tokenAt;
        var stableTokenAt = tokenAt;
        var stableDepth = depth;
        _MathEnvironmentToken? closingToken;
        for (var i = tokenAt; i < tokens.length; i++) {
          _noteScanVisit();
          final token = tokens[i];
          final hiddenEnd = _currentLineBackticks.hiddenSpanEnd(token.start);
          if (hiddenEnd != null) {
            var low = i + 1;
            var high = tokens.length;
            while (low < high) {
              _noteScanVisit();
              final middle = (low + high) >> 1;
              if (tokens[middle].start < hiddenEnd) {
                low = middle + 1;
              } else {
                high = middle;
              }
            }
            stableTokenAt = low;
            stableDepth = depth;
            i = low - 1;
            continue;
          }
          stableTokenAt = i + 1;
          depth += token.opening ? 1 : -1;
          stableDepth = depth;
          if (depth == 0) {
            closingToken = token;
            break;
          }
        }
        final closeAt = advanceEnvironmentClose(
          closes,
          environmentCloseAt[environment.name] ?? 0,
          closingToken?.start ?? environment.end,
        );
        environmentCloseAt[environment.name] = closeAt;
        environmentOpenAt++;
        if (closingToken != null &&
            closeAt < closes.length &&
            closes[closeAt].start == closingToken.start) {
          _clearPendingEnvironmentFor(environment);
          final close = closes[closeAt];
          final commentExtendsCurrentLine =
              currentEnvironmentComment && close.start >= _lineStart;
          if (commentExtendsCurrentLine) {
            _commentMatchedEnvironmentName = environment.name;
            _commentMatchedEnvironmentStart = environment.start;
            _commentMatchedEnvironmentCloseStart = close.start;
            _commentMatchedEnvironmentCloseAt = closeAt;
          } else {
            _clearCommentMatchedEnvironmentFor(environment);
          }
          pos = commentExtendsCurrentLine ? limit : close.spanEnd;
          _spans.add(
            MarkdownDisplayMathSpan(start: environment.start, end: pos),
          );
          unclosedStart = null;
          freeze(
            pos,
            dollarOpenAt,
            bracketOpenAt,
            dollarCloseAt,
            bracketCloseAt,
            fenceOpenAt,
            fenceCloseAt,
          );
          if (commentExtendsCurrentLine) break;
        } else if (closingToken == null) {
          _clearCommentMatchedEnvironmentFor(environment);
          _pendingEnvironmentName = environment.name;
          _pendingEnvironmentStart = environment.start;
          _pendingEnvironmentTokenAt = stableTokenAt;
          _pendingEnvironmentDepth = stableDepth;
          unclosedStart ??= environment.start;
          earliestUnresolved ??= environment.start;
          // A later environment may be a nested matrix or alignment whose
          // outer end has not streamed in yet. Keep the outer body together.
          break;
        } else {
          _clearPendingEnvironmentFor(environment);
          _clearCommentMatchedEnvironmentFor(environment);
          // The balanced environment ends mid-line, so it is ordinary text
          // rather than a standalone display block.
          pos = closingToken.end;
        }
        continue;
      }
      if (mathFirst) {
        final openAt = mathAt;
        final closes = useDollar ? _dollarCloses : _bracketCloses;
        var closeAt = useDollar ? dollarCloseAt : bracketCloseAt;
        while (closeAt < closes.length &&
            (closes[closeAt] < openAt + 2 ||
                hiddenByInlineCode(closes[closeAt]))) {
          _noteScanVisit();
          closeAt++;
        }
        if (useDollar) {
          dollarCloseAt = closeAt;
          dollarOpenAt++;
        } else {
          bracketCloseAt = closeAt;
          bracketOpenAt++;
        }
        if (closeAt < closes.length) {
          final closer = closes[closeAt];
          _spans.add(MarkdownDisplayMathSpan(start: openAt, end: closer + 2));
          pos = closer + 2;
          unclosedStart = null;
          freeze(
            pos,
            dollarOpenAt,
            bracketOpenAt,
            dollarCloseAt,
            bracketCloseAt,
            fenceOpenAt,
            fenceCloseAt,
          );
        } else {
          unclosedStart ??= openAt;
          earliestUnresolved ??= openAt;
          pos = openAt + 2;
        }
        continue;
      }

      final fence = fenceAt!;
      if (!identical(fence, peeked)) fenceOpenAt++;
      var closerEnd = -1;
      while (fenceCloseAt < _fenceCloses.length) {
        _noteScanVisit();
        final close = _fenceCloses[fenceCloseAt];
        if (close.start <= fence.start) {
          fenceCloseAt++;
          continue;
        }
        if (close.marker == fence.marker && close.length >= fence.length) {
          closerEnd = close.start + close.length;
          fenceCloseAt++;
          break;
        }
        fenceCloseAt++;
      }
      if (closerEnd < 0 &&
          peeked != null &&
          peeked.canClose &&
          peeked.start > fence.start &&
          peeked.marker == fence.marker &&
          peeked.length >= fence.length) {
        _noteScanVisit();
        closerEnd = peeked.start + peeked.length;
      }
      if (closerEnd >= 0) {
        pos = closerEnd;
        freeze(
          pos,
          dollarOpenAt,
          bracketOpenAt,
          dollarCloseAt,
          bracketCloseAt,
          fenceOpenAt,
          fenceCloseAt,
        );
      } else {
        earliestUnresolved ??= fence.start;
        break;
      }
    }

    if (earliestUnresolved == null &&
        unclosedStart == null &&
        pos <= _lineStart) {
      freeze(
        pos,
        dollarOpenAt,
        bracketOpenAt,
        dollarCloseAt,
        bracketCloseAt,
        fenceOpenAt,
        fenceCloseAt,
      );
    }
    return MarkdownDisplayMathScan(spans: _spans, unclosedStart: unclosedStart);
  }

  void _clearPendingEnvironmentFor(_MathEnvironmentMark environment) {
    if (_pendingEnvironmentStart == environment.start &&
        _pendingEnvironmentName == environment.name) {
      _clearPendingEnvironment();
    }
  }

  void _clearPendingEnvironment() {
    _pendingEnvironmentName = null;
    _pendingEnvironmentStart = null;
    _pendingEnvironmentTokenAt = 0;
    _pendingEnvironmentDepth = 0;
  }

  void _clearCommentMatchedEnvironmentFor(_MathEnvironmentMark environment) {
    if (_commentMatchedEnvironmentStart == environment.start &&
        _commentMatchedEnvironmentName == environment.name) {
      _clearCommentMatchedEnvironment();
    }
  }

  void _clearCommentMatchedEnvironment() {
    _commentMatchedEnvironmentName = null;
    _commentMatchedEnvironmentStart = null;
    _commentMatchedEnvironmentCloseStart = null;
    _commentMatchedEnvironmentCloseAt = null;
  }

  void _clearPendingTexVerb() {
    _pendingTexVerbStart = null;
    _pendingTexVerbDelimiter = null;
    _pendingTexVerbCompleteEnd = null;
    _pendingTexVerbSearchedTo = 0;
    _pendingTexVerbBacktickSearchedTo = 0;
    _pendingTexVerbBacktickRunStart = null;
    _pendingTexVerbBacktickRunLength = 0;
  }

  _FenceMark? _peekIncompleteFence(int limit) {
    var i = _lineStart;
    while (i < limit) {
      final unit = _text.codeUnitAt(i);
      if (markdownIsLogicalLineBreak(unit)) return null;
      if (unit != 0x20 && unit != 0x09) {
        if (unit != 0x60 && unit != 0x7E) return null;
        return _fenceMarkOf(_text.substring(_lineStart, limit), _lineStart);
      }
      _noteScanVisit();
      i++;
    }
    return null;
  }
}

/// Successful display-math spans in [text] for Markdown rendering: a closer
/// may be followed only by whitespace on
/// its line; an unclosed opener does not occupy later content; a candidate
/// that starts inside a successful outer span is discarded; leftmost
/// successful dollar wins over bracket at the same site.
/// Named environments balance nested instances of the same name, and an
/// unfinished outer environment protects its body from paragraph splitting.
///
/// Fence and math candidates are merged by start: a successful earlier
/// fence hides inner math, and a successful earlier math span treats inner
/// fence markers as content. Unclosed fences that start first occupy the
/// rest of the scan. Details tags are ordinary content.
MarkdownDisplayMathScan markdownScanDisplayMath(
  String text, {
  int? end,
  bool enableMath = true,
}) {
  return MarkdownDisplayMathScanner().synchronize(
    text,
    end: end,
    enableMath: enableMath,
  );
}

/// Whether [content] ends (at [end]) with a successful display-math span
/// that the renderer recognizes after normalizing raw environments.
bool markdownEndsWithDisplayMath(String content, int end) {
  final spans = markdownScanDisplayMath(content, end: end).spans;
  return spans.isNotEmpty && spans.last.end == end;
}

bool _atDoubleDollar(String line, int i) {
  return i + 1 < line.length &&
      line.codeUnitAt(i) == 0x24 &&
      line.codeUnitAt(i + 1) == 0x24;
}

bool _atEscaped(String line, int i, int unit) {
  return i + 1 < line.length &&
      line.codeUnitAt(i) == 0x5C &&
      line.codeUnitAt(i + 1) == unit;
}

_TexVerbProbe _probeTexVerb(
  String text,
  int start,
  int limit, {
  int? knownDelimiter,
  int? searchFrom,
}) {
  const prefix = r'\verb';
  var prefixAt = 0;
  while (prefixAt < prefix.length && start + prefixAt < limit) {
    _noteScanVisit();
    if (text.codeUnitAt(start + prefixAt) != prefix.codeUnitAt(prefixAt)) {
      return _TexVerbProbe.none;
    }
    prefixAt++;
  }
  if (prefixAt < prefix.length) {
    return _TexVerbProbe.pending(searchedTo: limit);
  }

  var delimiterAt = start + prefix.length;
  if (delimiterAt >= limit) {
    return _TexVerbProbe.pending(searchedTo: limit);
  }
  var delimiter = text.codeUnitAt(delimiterAt);
  if (delimiter == 0x2A) {
    delimiterAt++;
    if (delimiterAt >= limit) {
      return _TexVerbProbe.pending(searchedTo: limit);
    }
    delimiter = text.codeUnitAt(delimiterAt);
  } else if (_isAsciiLetter(delimiter)) {
    return _TexVerbProbe.none;
  }
  if (markdownIsLogicalLineBreak(delimiter)) return _TexVerbProbe.none;

  final payloadStart = delimiterAt + 1;
  var i = knownDelimiter == delimiter && searchFrom != null
      ? searchFrom
      : payloadStart;
  if (i < payloadStart) i = payloadStart;
  while (i < limit) {
    _noteScanVisit();
    final unit = text.codeUnitAt(i);
    if (markdownIsLogicalLineBreak(unit)) return _TexVerbProbe.none;
    if (unit == delimiter) return _TexVerbProbe.complete(i + 1);
    i++;
  }
  return _TexVerbProbe.pending(delimiter: delimiter, searchedTo: i);
}

bool _isAsciiLetter(int unit) =>
    (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A);

bool _texCharacterIsEscaped(String text, int index) {
  var backslashes = 0;
  for (var i = index - 1; i >= 0 && text.codeUnitAt(i) == 0x5C; i--) {
    _noteScanVisit();
    backslashes++;
  }
  return backslashes.isOdd;
}

int? _environmentCloserEnd(String line, int tokenEnd) {
  var i = tokenEnd;
  while (i < line.length && markdownIsWhitespace(line.codeUnitAt(i))) {
    _noteScanVisit();
    i++;
  }
  if (i == line.length) return tokenEnd;
  if (line.codeUnitAt(i) == 0x25 && !_texCharacterIsEscaped(line, i)) {
    return line.length;
  }
  return null;
}

bool _onlyWhitespaceAfter(String line, int start) {
  for (var i = start; i < line.length; i++) {
    _noteScanVisit();
    if (!markdownIsWhitespace(line.codeUnitAt(i))) return false;
  }
  return true;
}

bool markdownIsWhitespace(int unit) {
  if (unit == 0x20) return true;
  if (unit >= 0x09 && unit <= 0x0D) return true;
  if (unit < 0x80) return false;
  return unit == 0xA0 ||
      unit == 0x1680 ||
      (unit >= 0x2000 && unit <= 0x200A) ||
      unit == 0x2028 ||
      unit == 0x2029 ||
      unit == 0x202F ||
      unit == 0x205F ||
      unit == 0x3000 ||
      unit == 0xFEFF;
}
