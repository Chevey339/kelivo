/// A stable source block in an append-only streaming Markdown document.
final class IncrementalMarkdownBlock {
  const IncrementalMarkdownBlock({required this.start, required this.text});

  final int start;
  final String text;
}

/// Splits streaming Markdown at safe blank-line boundaries and only rescans
/// the last (possibly incomplete) block when content is appended.
final class IncrementalMarkdownDocument {
  String _source = '';
  List<IncrementalMarkdownBlock> _blocks = const [];
  final List<IncrementalMarkdownBlock> _stableBlocks = [];
  int _rescannedCodeUnits = 0;
  int _scanCursor = 0;
  int _lineStart = 0;
  int _blockStart = 0;
  String? _fence;

  List<IncrementalMarkdownBlock> get blocks => _blocks;
  int get rescannedCodeUnits => _rescannedCodeUnits;

  List<IncrementalMarkdownBlock> update(String source) {
    if (source == _source) return _blocks;
    if (!source.startsWith(_source)) {
      _stableBlocks.clear();
      _scanCursor = 0;
      _lineStart = 0;
      _blockStart = 0;
      _fence = null;
      _rescannedCodeUnits += source.length;
    } else {
      _rescannedCodeUnits += source.length - _source.length;
    }
    _source = source;
    _scanCompletedLines();
    final tail = IncrementalMarkdownBlock(
      start: _blockStart,
      text: source.substring(_blockStart),
    );
    _blocks = List<IncrementalMarkdownBlock>.unmodifiable([
      ..._stableBlocks,
      tail,
    ]);
    return _blocks;
  }

  void _scanCompletedLines() {
    while (_scanCursor < _source.length) {
      final newline = _source.indexOf('\n', _scanCursor);
      if (newline < 0) {
        _scanCursor = _source.length;
        return;
      }
      final line = _source.substring(_lineStart, newline).trimLeft();
      final marker = line.startsWith('```')
          ? '```'
          : line.startsWith('~~~')
          ? '~~~'
          : null;
      if (marker != null) {
        _fence = _fence == null
            ? marker
            : _fence == marker
            ? null
            : _fence;
      }
      if (_fence == null && line.trim().isEmpty && _lineStart > _blockStart) {
        final end = newline + 1;
        _stableBlocks.add(
          IncrementalMarkdownBlock(
            start: _blockStart,
            text: _source.substring(_blockStart, end),
          ),
        );
        _blockStart = end;
      }
      _lineStart = newline + 1;
      _scanCursor = newline + 1;
    }
  }
}
