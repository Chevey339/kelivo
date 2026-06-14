import 'package:markdown/markdown.dart' as md;

/// An [md.EscapeSyntax] that does NOT escape `\(` or `\)`.
///
/// This allows [LatexInlineSyntax] to match `\(...\)` before the escape
/// pass consumes the backslash. Registered before [CjkFriendlyItalicSyntax]
/// so `\*` is escaped before emphasis matching sees the asterisk.
class LatexFriendlyEscapeSyntax extends md.InlineSyntax {
  LatexFriendlyEscapeSyntax()
    : super(
        r'\\([!"#$%&'
        '*+,.\/:;<=>?@\[\\\]^_`{|}~-])',
        startCharacter: 0x5C,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match[1]!;
    parser.addNode(md.Text(text));
    return true;
  }
}
