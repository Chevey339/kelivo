import 'package:markdown/markdown.dart' as md;

/// Replaces the built-in [md.CodeSyntax] so inline code produces a
/// `codespan` tag instead of `code`, allowing a dedicated builder
/// in flutter_markdown_plus without conflicting with `<code>` elements
/// nested inside `<pre>` (fenced code blocks).
/// Replaces built-in [md.CodeSyntax] to use `codespan` tag instead of
/// `code`, avoiding collision with `<code>` inside `<pre>` (fenced code).
///
/// Currently matches single-backtick inline code. Double-backtick
/// can be added if needed.
class CodespanSyntax extends md.InlineSyntax {
  CodespanSyntax() : super(r'(?<!`)`([^`\n]+)`(?!`)', startCharacter: 0x60);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('codespan', [md.Text(match[1]!)]));
    return true;
  }
}
