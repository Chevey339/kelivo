import 'package:markdown/markdown.dart' as md;

class LatexBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^(?:\$\$|\\\[)');

  @override
  md.Node parse(md.BlockParser parser) {
    final line = parser.current.content;
    final isDollar = line.startsWith(r'$$');
    final closePattern = RegExp(isDollar ? r'\$\$' : r'\\\]');

    // Single-line: $$...$$ or \[...\] on the same line
    final singleMatch = RegExp(
      isDollar ? r'^\$\$(.*?)\$\$$' : r'^\\\[(.*?)\\\]$',
    ).firstMatch(line);
    if (singleMatch != null) {
      parser.advance();
      final tex = (singleMatch[1] ?? '').trim();
      final el = md.Element.text('latex', tex);
      el.attributes['displayMode'] = 'true';
      return el;
    }

    // Multi-line: read lines until closing delimiter
    final buffer = StringBuffer();
    final afterOpen = line.substring(2).trimLeft();
    if (afterOpen.isNotEmpty) buffer.write(afterOpen);
    parser.advance();

    while (!parser.isDone) {
      final currentLine = parser.current.content;
      final close = closePattern.firstMatch(currentLine);
      if (close != null) {
        if (close.start > 0) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(currentLine.substring(0, close.start));
        }
        parser.advance();
        final tex = buffer.toString().trim();
        final el = md.Element.text('latex', tex);
        el.attributes['displayMode'] = 'true';
        return el;
      }
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(currentLine);
      parser.advance();
    }

    // Unclosed — consume everything
    final tex = buffer.toString().trim();
    final el = md.Element.text('latex', tex);
    el.attributes['displayMode'] = 'true';
    return el;
  }
}
