import 'markdown_line_lexer.dart'
    show markdownIsWhitespace, markdownIsLogicalLineBreak;

/// A complete root fence, including an unfinished streamed body.
class StreamingCodeFence {
  const StreamingCodeFence(this.language, this.code, this.closed);
  final String language;
  final String code;
  final bool closed;
}

/// Recognizes ordinary root fences without repeatedly searching the whole body
/// for a closing delimiter. More involved fence syntax stays with the existing
/// Markdown preprocessor/parser, including indented/list-contained fences.
class StreamingCodeFenceParser {
  static final _runs = RegExp(r'`+|~+');
  static final _listMarker = RegExp(r'^\s*(?:[*+-]|\d+\.)$');
  int? _sourceStart;
  int _sourceLength = 0;
  int _bodyStart = 0;
  int _cursor = 0;
  int _marker = 0;
  int _runLength = 0;
  String _language = '';
  bool _unsupported = false;

  StreamingCodeFence? update(
    String source, {
    int? sourceStart,
    bool appendOnly = false,
  }) {
    final continues =
        appendOnly &&
        sourceStart != null &&
        sourceStart == _sourceStart &&
        source.length >= _sourceLength;
    _sourceLength = source.length;
    if (continues && _unsupported) return null;
    if (!continues || _bodyStart == 0) {
      _sourceStart = sourceStart;
      _bodyStart = 0;
      _unsupported = false;
      if (source.isEmpty) return null;
      _marker = source.codeUnitAt(0);
      if (_marker != 0x60 && _marker != 0x7e) return null;
      var end = 0;
      while (end < source.length && source.codeUnitAt(end) == _marker) {
        end++;
      }
      if (end < 3) return null;
      _runLength = end;
      final newline = source.indexOf('\n', end);
      if (newline < 0) return null;
      _language = source.substring(end, newline).trim();
      if (_language.contains('<')) return null;
      _bodyStart = _cursor = newline + 1;
    }
    // The incremental Markdown document normally supplies normalized LF text.
    if (source.contains('\r')) return null;
    var pending = source.length;
    for (final run in _runs.allMatches(source, _cursor)) {
      if (run.end == source.length) pending = run.start;
      if (run.end - run.start < 3) continue;
      var lineStart = run.start;
      while (lineStart > _bodyStart &&
          source.codeUnitAt(lineStart - 1) != 0x0a) {
        lineStart--;
      }
      var prefixIsBlank = true;
      for (var i = lineStart; i < run.start; i++) {
        final unit = source.codeUnitAt(i);
        if (unit != 0x20 && unit != 0x09) prefixIsBlank = false;
      }
      var lineEnd = source.indexOf('\n', run.end);
      if (lineEnd < 0) lineEnd = source.length;
      var suffixIsBlank = true;
      for (var i = run.end; i < lineEnd; i++) {
        final unit = source.codeUnitAt(i);
        if (unit != 0x20 && unit != 0x09) suffixIsBlank = false;
      }
      if (source.codeUnitAt(run.start) == _marker &&
          prefixIsBlank &&
          run.end - run.start < _runLength &&
          run.end == source.length) {
        _cursor = run.start;
        return StreamingCodeFence(
          _language,
          source.substring(_bodyStart),
          false,
        );
      }
      // Internal fence runs can participate in list/fence preprocessing. Only
      // bypass that parser when this run is an unambiguous final closer.
      var before = run.start;
      while (before > _bodyStart &&
          markdownIsWhitespace(source.codeUnitAt(before - 1))) {
        before--;
      }
      if (before > _bodyStart &&
          const [
            0x2a,
            0x2b,
            0x2d,
            0x2e,
          ].contains(source.codeUnitAt(before - 1))) {
        var previousStart = before;
        while (previousStart > _bodyStart &&
            !markdownIsLogicalLineBreak(source.codeUnitAt(previousStart - 1))) {
          previousStart--;
        }
        if (_listMarker.hasMatch(source.substring(previousStart, before))) {
          _unsupported = true;
          return null;
        }
      }
      if (source.codeUnitAt(run.start) != _marker ||
          run.end - run.start < _runLength ||
          !prefixIsBlank ||
          !suffixIsBlank ||
          source.substring(lineEnd).trim().isNotEmpty) {
        _unsupported = true;
        return null;
      }
      _cursor = run.start; // A closer at EOF can still grow into a code line.
      return StreamingCodeFence(
        _language,
        source.substring(_bodyStart, lineStart),
        true,
      );
    }
    _cursor = pending;
    return StreamingCodeFence(_language, source.substring(_bodyStart), false);
  }
}
