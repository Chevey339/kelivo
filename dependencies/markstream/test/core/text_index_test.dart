import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  const parser = MarkdownParser();
  test(
    'selectable offsets exclude generated paragraph and table separators',
    () {
      final doc = parser.parse(
        'First\n\n| A | B |\n| --- | --- |\n| one | two |\n\nLast',
      );
      final index = TextIndex.fromDocument(doc);
      expect(index.text, 'FirstABonetwoLast');
      expect(toPlainText(doc), 'First\n\nA\tB\none\ttwo\n\nLast');
      final offset = index.text.indexOf('one');
      expect(
        index.sourceSpanForRange(offset, offset + 3).slice(doc.source),
        'one',
      );
    },
  );
  test(
    'entities, code newlines and escaped pipes preserve complete source units',
    () {
      const source =
          '> **😀 &amp;**\r\n> `a\r\nb`\n\n| Cell |\n| --- |\n| a \\| b |';
      final doc = parser.parse(source);
      final index = TextIndex.fromDocument(doc);
      final amp = index.text.indexOf('&');
      expect(index.sourceSpanForRange(amp, amp + 1).slice(source), '&amp;');
      final pipe = index.text.lastIndexOf('|');
      expect(index.sourceSpanForRange(pipe, pipe + 1).slice(source), r'\|');
      final original = source.indexOf('😀');
      final range = index.textRangeForSource(
        SourceSpan(original, original + 2),
      )!;
      expect(index.text.substring(range.start, range.end), '😀');
    },
  );
  test(
    'rendered projections can hide details and map inserted soft wrap glyphs',
    () {
      final index = TextIndex.fromSegments(const [
        TextSegment(text: 'first', sourceSpan: SourceSpan(2, 7)),
        TextSegment(text: '\u200B', sourceSpan: SourceSpan(7, 7)),
        TextSegment(text: 'second', sourceSpan: SourceSpan(12, 18)),
      ]);
      expect(index.sourceSpanForRange(5, 6), const SourceSpan(7, 7));
      expect(index.sourceSpanForRange(6, 12), const SourceSpan(12, 18));
      expect(index.textRangeForSource(const SourceSpan(12, 18)), (
        start: 6,
        end: 12,
      ));
      expect(
        index.segmentsForRange(4, 8).map((s) => s.text).join(),
        't\u200Bse',
      );
      expect(() => index.sourceSpanForRange(0, 99), throwsRangeError);
    },
  );
  test('code indexes exclude one structural final newline and preserve indentation', () {
    const source = '```\n  a\n  b\n```';
    final index = TextIndex.fromDocument(parser.parse(source));
    expect(index.text, '  a\n  b');
    expect(index.sourceSpanForRange(0, index.length).slice(source), '  a\n  b');
  });
  test('full HTML code retains quote-prefix and CRLF gaps in its index', () {
    const source = '> <html>\r\n> <body>page</body>\r\n> </html>';
    final doc = parser.parse(source);
    final index = TextIndex.fromDocument(doc);
    final page = index.text.indexOf('page');
    expect(index.sourceSpanForRange(page, page + 4).slice(source), 'page');
  });
}
