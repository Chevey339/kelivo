import 'package:markdown/markdown.dart' as md;

const String _citationOpenMarker = '\uFFF0';
const String _citationCloseMarker = '\uFFF1';

String convertCitationLinks(String input) {
  final citationLink = RegExp(
    r'\[citation\]\((\d+)(?::([^\s)]+))?\)',
    caseSensitive: false,
  );
  return input.replaceAllMapped(citationLink, (match) {
    final index = match[1] ?? '';
    final id = match[2] ?? index;
    return '${_citationOpenMarker}citation:$index:$id$_citationCloseMarker';
  });
}

class CitationInlineSyntax extends md.InlineSyntax {
  CitationInlineSyntax()
    : super(
        '${_citationOpenMarker}citation:([^:]+):([^$_citationCloseMarker]+)$_citationCloseMarker',
        startCharacter: _citationOpenMarker.codeUnitAt(0),
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element('citation', [md.Text(match[1]!), md.Text(match[2]!)]),
    );
    return true;
  }
}
