import 'markdown_line_lexer.dart';

/// A source block in an append-only streaming Markdown document.
final class IncrementalMarkdownBlock {
  const IncrementalMarkdownBlock({
    required this.start,
    required this.text,
    required this.stable,
  });

  final int start;

  /// The block's source, without the blank run that separates it from the
  /// next block. The splitter skips that run on its own; the widget inserts
  /// one separator in its place.
  final String text;

  /// Whether the scanner has committed this block. The unfinished tail —
  /// and a temporary indent merge of that tail with the last committed
  /// block — are not stable. Only the tail may receive streaming
  /// stabilization (tables, unfinished math).
  final bool stable;
}

/// Splits streaming Markdown at safe blank-line boundaries and only rescans
/// the last (possibly incomplete) block when content is appended.
final class IncrementalMarkdownDocument {
  static final _listMarker = RegExp(
    r'^(?:[*+-](?:\s+\[[ xX]\])?|\d{1,9}[.)])(?:\s|$)',
  );

  String _rawSource = '';
  String _source = '';
  bool _rawEndsWithCR = false;
  List<IncrementalMarkdownBlock> _blocks = const [];
  final List<IncrementalMarkdownBlock> _stableBlocks = [];
  final MarkdownLineLexer _lexer = MarkdownLineLexer();
  final MarkdownDisplayMathScanner _mathScanner = MarkdownDisplayMathScanner();
  int _rescannedCodeUnits = 0;
  bool _lastUpdateAppended = true;
  int _scanCursor = 0;
  int _lineStart = 0;
  int _blockStart = 0;
  int? _pendingListBlankEnd;
  int? _pendingListContentEnd;
  bool _blankRunCarriesWhitespace = false;

  List<IncrementalMarkdownBlock> get blocks => _blocks;
  int get rescannedCodeUnits => _rescannedCodeUnits;

  /// The last source retained its previous prefix. Blocks at the same start
  /// offset therefore retain their prefix too (apart from trailing whitespace).
  bool get lastUpdateAppended => _lastUpdateAppended;

  /// Whether [_source] is still the caller's raw string. False after a CR
  /// forced a normalized copy.
  bool get debugReusesCallerSource => identical(_source, _rawSource);

  /// [appendOnly] may be supplied when the owner already compared this exact
  /// source with the preceding update. Omit it for independently rewritten text.
  List<IncrementalMarkdownBlock> update(String source, {bool? appendOnly}) {
    if (source == _rawSource) {
      _lastUpdateAppended = true;
      return _blocks;
    }
    _lastUpdateAppended = appendOnly ?? source.startsWith(_rawSource);
    if (!_lastUpdateAppended) {
      _stableBlocks.clear();
      _scanCursor = 0;
      _lineStart = 0;
      _blockStart = 0;
      _lexer.reset();
      _mathScanner.reset();
      _pendingListBlankEnd = null;
      _pendingListContentEnd = null;
      _blankRunCarriesWhitespace = false;
      final normalized = _normalizeNewlines(source);
      _rescannedCodeUnits += normalized.length;
      _source = normalized;
    } else {
      final rawSuffix = source.substring(_rawSource.length);
      if (_canReuseCallerSource(rawSuffix)) {
        _rescannedCodeUnits += rawSuffix.length;
        _source = source;
      } else {
        final suffix = _normalizeAppendedSuffix(rawSuffix);
        _rescannedCodeUnits += suffix.length;
        _source += suffix;
      }
    }
    _rawSource = source;
    _rawEndsWithCR =
        source.isNotEmpty && source.codeUnitAt(source.length - 1) == 0x0D;
    _scanCompletedLines();
    _blocks = List<IncrementalMarkdownBlock>.unmodifiable(_visibleBlocks());
    return _blocks;
  }

  /// The common path never contained a CR, so [source] is already the
  /// accumulated document. Reuse it instead of copying `_source + suffix`.
  bool _canReuseCallerSource(String rawSuffix) {
    return identical(_source, _rawSource) &&
        !_rawEndsWithCR &&
        !rawSuffix.contains('\r');
  }

  /// CRLF and bare CR become LF, the same way `GptMarkdown` rewrites them
  /// before it parses. U+2028 / U+2029 stay as content: `NewLines` only
  /// matches `\n\n+`.
  static String _normalizeNewlines(String source) {
    if (!source.contains('\r')) return source;
    return source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Only the newly appended raw suffix is rewritten. A CR that closed the
  /// previous chunk plus an LF that opens this one is one newline, not two.
  String _normalizeAppendedSuffix(String suffix) {
    if (suffix.isEmpty) return '';
    var rest = suffix;
    if (_rawEndsWithCR && rest.codeUnitAt(0) == 0x0A) {
      rest = rest.substring(1);
    }
    return _normalizeNewlines(rest);
  }

  /// Completed blocks plus the unfinished tail. A non-empty indented tail
  /// is folded into the last block for the returned list only — the scanner
  /// itself is left alone until that line is finished. A tail of only
  /// whitespace is dropped: `GptMarkdown` trims it, so merging would only
  /// rebuild a block that lays out the same.
  ///
  /// A real indented tail re-parses the last committed block on each token
  /// of that one unfinished line. That is the cost of keeping indent as
  /// syntax; the alternative is a layout jump when the line completes.
  List<IncrementalMarkdownBlock> _visibleBlocks() {
    final tailText = _source.substring(_blockStart);
    if (tailText.trim().isEmpty) return List.of(_stableBlocks);
    if (_stableBlocks.isNotEmpty && _startsWithIndent(tailText)) {
      final last = _stableBlocks.last;
      return [
        ..._stableBlocks.sublist(0, _stableBlocks.length - 1),
        IncrementalMarkdownBlock(
          start: last.start,
          text: _source.substring(last.start),
          stable: false,
        ),
      ];
    }
    return [
      ..._stableBlocks,
      IncrementalMarkdownBlock(
        start: _blockStart,
        text: tailText,
        stable: false,
      ),
    ];
  }

  void _scanCompletedLines() {
    // update already validated the prefix and reset both scanners on edits.
    final mathScan = _mathScanner.synchronize(_source, appendOnly: true);
    while (_scanCursor < _source.length) {
      final newline = _source.indexOf('\n', _scanCursor);
      if (newline < 0) {
        _scanCursor = _source.length;
        return;
      }
      final rawLine = _source.substring(_lineStart, newline);
      final line = rawLine.trimLeft();
      _lexer.consumePhysicalLine(rawLine);
      final protected = _lexer.protected || mathScan.covers(_lineStart);
      final isBlank = line.trim().isEmpty;
      if (!protected && isBlank) {
        final end = newline + 1;
        if (_hasWhitespaceContent(rawLine)) _blankRunCarriesWhitespace = true;
        if (_blankRunCarriesWhitespace) {
          // A blank line carrying whitespace is content to the renderers around
          // it: a rule, a heading and a display-math block each absorb it into
          // their own match, and plain text lays it out as a line of its own.
          // Rather than model all of that, refuse the boundary and leave the
          // run inside one block, which renders the way the document reads.
          _clearPendingList();
          if (_lineStart == _blockStart) _mergeLastBlockBack();
        } else if (_lineStart > _blockStart) {
          if (_currentBlockIsList()) {
            _pendingListContentEnd ??= _contentEndBeforeBlank();
            _pendingListBlankEnd = end;
          } else {
            _emitStableBlock(_contentEndBeforeBlank(), end);
          }
        } else {
          // A blank line with no content behind it continues the run that
          // ended the block before it. `NewLines` collapses the whole run
          // to one gap, so the completed block stays as it is.
          _blockStart = end;
        }
      } else if (!protected && !isBlank) {
        _blankRunCarriesWhitespace = false;
        if (_pendingListBlankEnd != null) {
          if (_isListContinuation(rawLine, line)) {
            _clearPendingList();
          } else {
            _emitStableBlock(_pendingListContentEnd!, _pendingListBlankEnd!);
            _clearPendingList();
          }
        } else if (_lineStart == _blockStart && _isIndented(rawLine)) {
          // Indentation is part of the syntax — four spaces stop a heading
          // from being one — and a block-by-block render trims the leading
          // whitespace off every block. Keep the line with the block above
          // so both reach the renderer the way they read in the document.
          _mergeLastBlockBack();
        }
      }
      _lineStart = newline + 1;
      _scanCursor = newline + 1;
    }
  }

  /// The last content character sits just before the `\n` that starts the
  /// `\n\n+` run we are looking at.
  int _contentEndBeforeBlank() => _lineStart > 0 ? _lineStart - 1 : 0;

  void _emitStableBlock(int contentEnd, int nextStart) {
    if (contentEnd > _blockStart) {
      _stableBlocks.add(
        IncrementalMarkdownBlock(
          start: _blockStart,
          text: _source.substring(_blockStart, contentEnd),
          stable: true,
        ),
      );
    }
    _blockStart = nextStart;
  }

  /// Reopens the last block so the line just scanned joins it.
  void _mergeLastBlockBack() {
    if (_stableBlocks.isEmpty) return;
    _blockStart = _stableBlocks.removeLast().start;
  }

  void _clearPendingList() {
    _pendingListBlankEnd = null;
    _pendingListContentEnd = null;
  }

  static bool _isIndented(String rawLine) =>
      rawLine.isNotEmpty && _isWhitespace(rawLine.codeUnitAt(0));

  static bool _startsWithIndent(String text) =>
      text.isNotEmpty && _isWhitespace(text.codeUnitAt(0));

  /// Whether a blank [rawLine] carries something other than a line break.
  /// After CRLF normalization the only break left in a raw line is a stray
  /// CR; U+2028 / U+2029 / NBSP / spaces are content, not a `NewLines` gap.
  static bool _hasWhitespaceContent(String rawLine) {
    for (var i = 0; i < rawLine.length; i++) {
      final unit = rawLine.codeUnitAt(i);
      if (unit != 0x0A && unit != 0x0D) return true;
    }
    return false;
  }

  static bool _isWhitespace(int unit) =>
      unit == 0x20 ||
      (unit >= 0x09 && unit <= 0x0D) ||
      (unit >= 0x80 && _isWideWhitespace(unit));

  static bool _isWideWhitespace(int unit) =>
      unit == 0x85 ||
      unit == 0xA0 ||
      unit == 0x1680 ||
      (unit >= 0x2000 && unit <= 0x200A) ||
      unit == 0x2028 ||
      unit == 0x2029 ||
      unit == 0x202F ||
      unit == 0x205F ||
      unit == 0x3000 ||
      unit == 0xFEFF;

  bool _currentBlockIsList() {
    var i = _blockStart;
    while (i < _source.length) {
      final nl = _source.indexOf('\n', i);
      final end = nl < 0 ? _source.length : nl;
      final raw = _source.substring(i, end);
      if (raw.trim().isNotEmpty) {
        return _listMarker.hasMatch(raw.trimLeft());
      }
      if (nl < 0) break;
      i = nl + 1;
    }
    return false;
  }

  bool _isListContinuation(String rawLine, String trimmedLeft) {
    if (rawLine.isNotEmpty &&
        (rawLine.codeUnitAt(0) == 0x20 || rawLine.codeUnitAt(0) == 0x09)) {
      return true;
    }
    return _listMarker.hasMatch(trimmedLeft);
  }
}
