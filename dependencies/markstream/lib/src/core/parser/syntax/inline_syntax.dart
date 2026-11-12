import '../../ast/nodes.dart';
import '../../ast/source_span.dart';
import '../dialect.dart';
import '../mapped_text.dart';

/// A pure Dart extension. It is never invoked inside code or math bodies.
abstract class InlineSyntax {
  const InlineSyntax();
  Set<int> get startCharacters;
  InlineSyntaxMatch? match(InlineSyntaxContext context, int offset);
}

final class InlineSyntaxMatch {
  const InlineSyntaxMatch({required this.end, required this.node});

  /// Exclusive offset in [InlineSyntaxContext.text], not the original source.
  final int end;
  final InlineNode node;
}

final class InlineSyntaxContext {
  const InlineSyntaxContext(this._input, this.options);
  final MappedText _input;
  final ParserOptions options;
  String get text => _input.text;
  SourceSpan span(int start, int end) => _input.span(start, end);
  List<TextNode> textNodes(int start, int end) => _input.slice(start, end);
}
