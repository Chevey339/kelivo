import '../ast/nodes.dart';
import 'dialect.dart';
import 'markdown_parser.dart';
import 'source_line.dart';
import 'syntax/math_block.dart';

/// Reuses complete leading blocks and reparses the final open block chain.
final class IncrementalDocument {
  IncrementalDocument({
    this.parser = const MarkdownParser(),
    this.streamingOptions = const StreamingOptions(),
  });
  final MarkdownParser parser;
  final StreamingOptions streamingOptions;
  DocumentNode _document = DocumentNode(source: '', children: const []);
  bool _streaming = false;
  DocumentNode get document => _document;
  String get source => _document.source;

  DocumentNode update(String source, {bool streaming = false}) {
    if (source == _document.source && streaming == _streaming) return _document;
    var prefixLength = 0;
    var start = 0;
    if (source.startsWith(_document.source) && _document.children.isNotEmpty) {
      prefixLength = _document.children.length - 1;
      start = _lineStart(_document.source, _document.children.last.span.start);
      // A still-growing opener can stop being a block (for example a
      // backtick in a fence info string), joining the preceding paragraph.
      if (prefixLength > 0 &&
          start == _lineStart(_document.source, _document.source.length) &&
          !_blankLineBefore(_document.source, start)) {
        prefixLength--;
        start = _lineStart(
          _document.source,
          _document.children[prefixLength].span.start,
        );
      }
      while (prefixLength > 0 &&
          _document.children[prefixLength - 1].span.end > start) {
        prefixLength--;
        start = _lineStart(
          _document.source,
          _document.children[prefixLength].span.start,
        );
      }
      // Static and pessimistic input can keep an unfinished display formula
      // as prose across blank lines. A new closer or resuming optimistic input
      // can reclassify an earlier block. Ongoing optimistic streams already
      // retain that open math node.
      final startsOptimisticMath =
          streaming && !_streaming && streamingOptions.optimisticBlocks;
      if (parser.options.mathBlocks &&
          (startsOptimisticMath ||
              (!(streaming &&
                      _streaming &&
                      streamingOptions.optimisticBlocks) &&
                  _newMathCloser(source)))) {
        for (var i = 0; i < prefixLength; i++) {
          if (_hasOpenMathText(_document.children[i])) {
            prefixLength = i;
            start = _lineStart(
              _document.source,
              _document.children[i].span.start,
            );
            break;
          }
        }
      }
    }
    final leadingReferences = {
      for (final entry in _document.references.entries)
        if (entry.value.span.start < start) entry.key: entry.value,
    };
    var tail = parser.parse(
      source,
      start: start,
      streaming: streaming,
      streamingOptions: streamingOptions,
      initialReferences: leadingReferences,
    );
    if (prefixLength > 0 &&
        !_sameReferences(_document.references, tail.references)) {
      prefixLength = 0;
      tail = parser.parse(
        source,
        streaming: streaming,
        streamingOptions: streamingOptions,
      );
    }
    _streaming = streaming;
    return _document = DocumentNode(
      source: source,
      children: [..._document.children.take(prefixLength), ...tail.children],
      references: tail.references,
    );
  }

  static final _mathCloser = RegExp(r'\$\$|\\\]');
  bool _newMathCloser(String source) =>
      source.length > _document.source.length &&
      _mathCloser.hasMatch(
        source.substring(
          _document.source.isEmpty ? 0 : _document.source.length - 1,
        ),
      );

  bool _hasOpenMathText(BlockNode root) {
    final pending = <BlockNode>[root];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node is ParagraphNode) {
        final raw = node.span.slice(_document.source);
        if (!raw.contains(r'$$') && !raw.contains(r'\[')) continue;
        for (final line in SourceLine.scan(
          raw,
          unicodeLineBreaks: parser.options.unicodeLineBreaks,
        )) {
          if (findMathBlockStart(raw, line.start, line.end, streaming: true) !=
              null)
            return true;
        }
      } else {
        pending.addAll(node.children.whereType<BlockNode>());
      }
    }
    return false;
  }

  int _lineStart(String source, int offset) {
    for (var i = offset - 1; i >= 0; i--) {
      final unit = source.codeUnitAt(i);
      if (unit == 10 ||
          unit == 13 ||
          (parser.options.unicodeLineBreaks &&
              (unit == 0x2028 || unit == 0x2029))) {
        return i + 1;
      }
    }
    return 0;
  }

  bool _blankLineBefore(String source, int start) {
    if (start == 0) return false;
    var end = start - 1;
    if (source.codeUnitAt(end) == 10 &&
        end > 0 &&
        source.codeUnitAt(end - 1) == 13)
      end--;
    return source.substring(_lineStart(source, end), end).trim().isEmpty;
  }

  bool _sameReferences(
    Map<String, ReferenceDefinitionNode> a,
    Map<String, ReferenceDefinitionNode> b,
  ) =>
      a.length == b.length &&
      a.entries.every((entry) {
        final other = b[entry.key];
        return other != null &&
            entry.value.destination == other.destination &&
            entry.value.title == other.title;
      });
}
