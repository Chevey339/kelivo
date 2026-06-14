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
        r'(?<![\\*])\*\*(?!\*)(.+?)(?<![\\*])\*\*(?!\*)',
        startCharacter: 0x2A,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final children = _splitContentWithMath(match[1] ?? '');
    parser.addNode(md.Element('strong', children));
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
    : super(r'(?<![\\*])\*(?!\*)(.+?)(?<![\\*])\*(?!\*)', startCharacter: 0x2A);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final children = _splitContentWithMath(match[1] ?? '');
    parser.addNode(md.Element('em', children));
    return true;
  }
}

/// Splits [content] at `\(...\)` boundaries so inline math survives
/// inside bold/italic elements.
///
/// Returns a list of [md.Node]s that alternates between [md.Text] and
/// [md.Element] (`latex`) nodes. When no math is present returns a single
/// [md.Text] node.
List<md.Node> _splitContentWithMath(String content) {
  const mathPattern = r'\\\((.+?)\\\)';
  final matches = RegExp(mathPattern).allMatches(content).toList();
  if (matches.isEmpty) return [md.Text(content)];

  final children = <md.Node>[];
  int lastEnd = 0;

  for (final m in matches) {
    if (m.start > lastEnd) {
      children.add(md.Text(content.substring(lastEnd, m.start)));
    }
    final tex = (m[1] ?? '').trim();
    if (tex.isNotEmpty) {
      final el = md.Element.text('latex', tex);
      el.attributes['displayMode'] = 'false';
      children.add(el);
    }
    lastEnd = m.end;
  }

  if (lastEnd < content.length) {
    children.add(md.Text(content.substring(lastEnd)));
  }
  return children;
}
