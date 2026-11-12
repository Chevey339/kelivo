import '../ast/nodes.dart';
import '../ast/source_span.dart';
import 'block_parser.dart';
import 'dialect.dart';
import 'inline_parser.dart';
import 'source_line.dart';

/// Source structure shared by speech, paragraph splitting and attachment scans.
/// Uses the renderer's block parser, including open streaming containers, so
/// consumers do not maintain a second fence, math or details grammar.
final class MarkdownStructure {
  factory MarkdownStructure(
    String source, {
    ParserOptions options = const ParserOptions(),
  }) {
    final document = BlockParser(options: options)
        .parse(source, streaming: true);
    final code = <CodeBlockNode>[];
    final protected = <SourceSpan>[];
    final pending = <MarkdownNode>[document];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node is CodeBlockNode) {
        code.add(node);
        protected.add(node.span);
        continue;
      }
      if (node is MathBlockNode ||
          node is DetailsNode ||
          node is NamedBlockNode ||
          node is HtmlBlockNode) {
        protected.add(node.span);
      }
      pending.addAll(node.children.reversed);
    }
    return MarkdownStructure._(
      source,
      options,
      List.unmodifiable(code),
      _merge(code.map((node) => node.span)),
      _merge(protected),
    );
  }
  MarkdownStructure._(
    this.source,
    this.options,
    this.codeBlocks,
    this._code,
    this._protected,
  );
  final String source;
  final ParserOptions options;
  final List<CodeBlockNode> codeBlocks;
  final List<SourceSpan> _code, _protected;

  /// True inside a block whose internal blank lines must stay together.
  bool protects(int offset) => _intersects(_protected, offset, offset + 1);

  /// Code includes opening and closing fence lines. Line endings retain their
  /// original UTF-16 coordinates, including CRLF and LLM Unicode separators.
  Iterable<({SourceLine line, bool code})> get lines sync* {
    for (final line in SourceLine.scan(
      source,
      unicodeLineBreaks: options.unicodeLineBreaks,
    )) {
      yield (line: line, code: _intersects(_code, line.start, line.next));
    }
  }
}

List<SourceSpan> _merge(Iterable<SourceSpan> spans) {
  final sorted = spans.toList()..sort((a, b) => a.start.compareTo(b.start));
  final merged = <SourceSpan>[];
  for (final span in sorted) {
    if (merged.isNotEmpty && span.start <= merged.last.end) {
      final previous = merged.removeLast();
      merged.add(
        SourceSpan(
          previous.start,
          span.end > previous.end ? span.end : previous.end,
        ),
      );
    } else {
      merged.add(span);
    }
  }
  return List.unmodifiable(merged);
}

bool _intersects(List<SourceSpan> ranges, int start, int end) {
  var low = 0, high = ranges.length;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (ranges[mid].end <= start) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low < ranges.length && ranges[low].start < end;
}

/// Removes fenced code and closed inline-code spans for speech while keeping
/// surrounding Markdown and original line endings. Inline code is deliberately
/// line-local: an unmatched backtick in one speech line cannot hide later prose.
/// An unfinished fence, however, suppresses its complete remaining body.
String removeCode(String source) {
  if (!source.contains('`') && !source.contains('~~~')) return source;
  final output = StringBuffer();
  for (final entry in MarkdownStructure(source).lines) {
    final line = entry.line;
    if (entry.code) {
      output.write(' ');
    } else {
      final text = line.text;
      final ranges = <SourceSpan>[];
      if (text.contains('`')) {
        final pending = <MarkdownNode>[
          ...const InlineParser().parse(text).reversed,
        ];
        while (pending.isNotEmpty) {
          final node = pending.removeLast();
          if (node is CodeSpanNode) {
            ranges.add(node.span);
          } else {
            pending.addAll(node.children.reversed);
          }
        }
      }
      var cursor = 0;
      for (final range in _merge(ranges)) {
        output
          ..write(text.substring(cursor, range.start))
          ..write(' ');
        cursor = range.end;
      }
      output.write(text.substring(cursor));
    }
    output.write(source.substring(line.end, line.next));
  }
  return output.toString();
}
