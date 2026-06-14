import 'package:markdown/markdown.dart' as md;

const String _detailsOpenMarker = '\uFFF2';
const String _detailsCloseMarker = '\uFFF3';

String convertDetailsBlocks(String input) {
  final openTag = RegExp(r'<details(?:\s+([^>]*))?>', caseSensitive: false);
  final summaryTag = RegExp(
    r'<summary(?:\s+[^>]*)?>(.*?)</summary>',
    caseSensitive: false,
    dotAll: true,
  );
  final closeTag = RegExp(r'</details>', caseSensitive: false);

  final out = StringBuffer();
  var pos = 0;

  while (pos < input.length) {
    final openMatch = openTag.firstMatch(input.substring(pos));
    if (openMatch == null) {
      out.write(input.substring(pos));
      break;
    }

    // Write text before the <details> tag
    out.write(input.substring(pos, pos + openMatch.start));

    final attrs = (openMatch[1] ?? '').trim();
    final openFlag = RegExp(r'(?:^|\s)open(?:\s|$)').hasMatch(attrs);
    var scanPos = pos + openMatch.end;

    // Find summary
    final summaryRemaining = input.substring(scanPos);
    final summaryMatch = summaryTag.firstMatch(summaryRemaining);
    String summary = '&nbsp;';
    if (summaryMatch != null) {
      summary = _stripHtml(summaryMatch[1] ?? '').trim();
      scanPos += summaryMatch.end;
    }

    // Find body with depth tracking for nested <details>
    final bodyBuf = StringBuffer();
    var depth = 1;
    while (scanPos < input.length && depth > 0) {
      final nextOpen = openTag.firstMatch(input.substring(scanPos));
      final nextClose = closeTag.firstMatch(input.substring(scanPos));
      if (nextClose == null) break;

      if (nextOpen != null && nextOpen.start < nextClose.start) {
        depth++;
        bodyBuf.write(input.substring(scanPos, scanPos + nextOpen.end));
        scanPos += nextOpen.end;
      } else {
        depth--;
        if (depth == 0) {
          bodyBuf.write(input.substring(scanPos, scanPos + nextClose.start));
          scanPos += nextClose.end;
          break;
        }
        bodyBuf.write(input.substring(scanPos, scanPos + nextClose.end));
        scanPos += nextClose.end;
      }
    }

    out.write('$_detailsOpenMarker${openFlag ? ' open' : ''}\n');
    out.write('$summary\n');
    final body = bodyBuf.toString().trim();
    if (body.isNotEmpty) {
      out.write('${convertDetailsBlocks(body)}\n');
    }
    out.write('$_detailsCloseMarker\n');

    pos = scanPos;
  }

  return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _stripHtml(String input) {
  return input
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();
}

class DetailsBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp('^$_detailsOpenMarker( open)?\$');

  @override
  md.Node? parse(md.BlockParser parser) {
    final firstLine = parser.current.content;
    final isOpen = firstLine.contains(' open');
    parser.advance();

    String? summary;
    final bodyParts = <String>[];
    var depth = 1;

    while (!parser.isDone) {
      final line = parser.current.content;
      if (line == _detailsCloseMarker) {
        depth--;
        parser.advance();
        if (depth == 0) break;
        bodyParts.add(line);
        continue;
      }
      if (line.startsWith(_detailsOpenMarker)) {
        depth++;
        bodyParts.add(line);
        parser.advance();
        continue;
      }
      if (summary == null) {
        summary = line;
      } else {
        bodyParts.add(line);
      }
      parser.advance();
    }

    final body = bodyParts.join('\n').trim();

    final el = md.Element('details', [
      md.Element('summary_text', [md.Text(summary ?? '')]),
      md.Element('body_text', [md.Text(body)]),
    ]);
    el.attributes['open'] = isOpen ? 'true' : 'false';
    return el;
  }
}
