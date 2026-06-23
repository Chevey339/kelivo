import '../ast.dart' show Element, Node;
import '../block_parser.dart' show BlockParser;
import '../line.dart';
import '../patterns.dart' show dummyPattern, emptyPattern, footnotePattern;
import 'block_syntax.dart' show BlockSyntax;

/// The spec of GFM about footnotes is [missing](https://github.com/github/cmark-gfm/issues/283#issuecomment-1378868725).
/// For online source code of cmark-gfm, see [master@c32ef78](https://github.com/github/cmark-gfm/blob/c32ef78/src/blocks.c#L1212).
/// A Rust implementation is also [available](https://github.com/wooorm/markdown-rs/blob/2498e31eecead798efc649502bbf5f86feaa94be/src/construct/gfm_footnote_definition.rs).
/// Footnote definition could contain multiple line-children and children could
/// be separated by one empty line.
/// Its first child-line would be the remaining part of the first line after
/// taking definition leading, combining with other child lines parsed by
/// [parseChildLines], is fed into [BlockParser].
class FootnoteDefSyntax extends BlockSyntax {
  const FootnoteDefSyntax();

  @override
  RegExp get pattern => footnotePattern;

  @override
  Node? parse(BlockParser parser) {
    final current = parser.current.content;
    final match = pattern.firstMatch(current)!;
    final label = match[2]!;
    final refs = parser.document.footnoteReferences;
    refs[label] = 0;

    final id = Uri.encodeComponent(label);
    parser.advance();
    final lines = [
      Line(current.substring(match[0]!.length)),
      ...parseChildLines(parser),
    ];
    final children = BlockParser(lines, parser.document).parseLines();
    return Element('li', children)
      ..attributes['id'] = 'fn-$id'
      ..footnoteLabel = label;
  }

  @override
  List<Line> parseChildLines(BlockParser parser) {
    final children = <String>[];
    // As one empty line should not split footnote definition, use this flag.
    var shouldBeBlock = false;
    late final syntaxList = parser.blockSyntaxes.where(
      (s) => !_excludingPattern.contains(s.pattern),
    );

    // Every line is footnote's children util two blank lines or a block.
    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim().isEmpty) {
        children.add(line);
        parser.advance();
        shouldBeBlock = true;
        continue;
      } else if (line.startsWith('    ')) {
        children.add(line.substring(4));
        parser.advance();
        shouldBeBlock = false;
      } else if (shouldBeBlock || _isBlock(syntaxList, line)) {
        break;
      } else {
        children.add(line);
        parser.advance();
      }
    }
    return children.map(Line.new).toList(growable: false);
  }

  /// Patterns that would be used to decide if one line is a block.
  static final _excludingPattern = {emptyPattern, dummyPattern};

  /// Whether this line is any kind of block.
  /// If `true`, the footnote block should end.
  static bool _isBlock(Iterable<BlockSyntax> syntaxList, String line) {
    return syntaxList.any((s) => s.pattern.hasMatch(line));
  }
}
