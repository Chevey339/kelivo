import 'package:markdown/markdown.dart' as md;

class LatexBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(
    r'^(?:\$\$([\s\S]*?)\$\$|\\\[([\s\S]*?)\\\])$',
    multiLine: true,
    dotAll: true,
  );

  @override
  md.Node parse(md.BlockParser parser) {
    final m = pattern.firstMatch(parser.current.content);
    final tex = ((m?.group(1) ?? m?.group(2) ?? '')).trim();
    parser.advance();
    final el = md.Element.text('latex', tex);
    el.attributes['displayMode'] = 'true';
    return el;
  }
}
