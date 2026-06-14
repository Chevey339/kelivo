import 'package:markdown/markdown.dart' as md;

/// A bold syntax that does not use CommonMark flanking rules.
///
/// This allows `**bold（全角）**` to work where the standard
/// [md.EmphasisSyntax] would reject the closing `**` because fullwidth
/// right-punctuation (e.g. `）` U+FF09) is treated as a punctuation
/// character, making the delimiter run left-flanking-only (can-open but
/// not can-close).
///
/// Registered before [md.EmphasisSyntax.asterisk] in the inline syntax
/// list so it wins for all `**...**` patterns.
class CjkFriendlyBoldSyntax extends md.InlineSyntax {
  CjkFriendlyBoldSyntax()
    : super(
        r'(?<!\*)\*\*(?!\*)(.+?)(?<!\*)\*\*(?!\*)',
        startCharacter: 0x2A,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('strong', [md.Text(match[1]!)]));
    return true;
  }
}

/// A italic syntax that does not use CommonMark flanking rules.
///
/// Same rationale as [CjkFriendlyBoldSyntax] — standard underscore and
/// asterisk emphasis reject delimiter runs preceded or followed by
/// punctuation characters common in CJK text.
class CjkFriendlyItalicSyntax extends md.InlineSyntax {
  CjkFriendlyItalicSyntax()
    : super(
        r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)',
        startCharacter: 0x2A,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('em', [md.Text(match[1]!)]));
    return true;
  }
}
