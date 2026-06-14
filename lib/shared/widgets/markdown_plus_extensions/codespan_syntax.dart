import 'package:markdown/markdown.dart' as md;

/// Replaces the built-in [md.CodeSyntax] so inline code produces a
/// `code` tag (same as default) but available for styling via
/// [md.ExtensionSet.gitHubFlavored] block syntax ordering.
class CodespanSyntax extends md.InlineSyntax {
  CodespanSyntax() : super(r'(?<!`)`([^`\n]+)`(?!`)', startCharacter: 0x60);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('code', [md.Text(match[1]!)]));
    return true;
  }
}
