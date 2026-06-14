import 'package:markdown/markdown.dart' as md;

class LatexInlineSyntax extends md.InlineSyntax {
  LatexInlineSyntax() : super(r'(?:\\\((.+?)\\\))', startCharacter: 0x5C);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = (match[1] ?? '').trim();
    if (tex.isEmpty) return false;
    final el = md.Element.text('latex', tex);
    el.attributes['displayMode'] = 'false';
    parser.addNode(el);
    return true;
  }
}
