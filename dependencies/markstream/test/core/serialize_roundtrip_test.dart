import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  const parser = MarkdownParser();
  test('HTML ordered-list starts retain signed and large integer values', () {
    for (final start in [-3, 0, 100000]) {
      final doc = parser.parse('<ol start="$start"><li>Item</li></ol>');
      expect(toHtml(doc), contains('<ol start="$start">'));
      expect(toHtml(parser.parse(toMarkdown(doc))), toHtml(doc));
    }
    expect(
      toHtml(parser.parse('<ol start="invalid"><li>Item</li></ol>')),
      isNot(contains('start=')),
    );
  });
  test('plain clipboard text includes structure and TSV quoting', () {
    final doc = parser.parse(
      '# Title\n\n- [x] Done\n- Next\n\n| A | B |\n| --- | --- |\n| "quote" | `x` |\n\n```\n  first\n\tsecond\n```\n\n\$x+y\$',
    );
    expect(
      toPlainText(doc),
      'Title\n\n- [x] Done\n- Next\n\nA\tB\n"""quote"""\tx\n\n  first\n\tsecond\n\n\$x+y\$',
    );
    final table = doc.children.whereType<TableNode>().single;
    expect(tableToCsv(table), 'A,B\r\n"""quote""",x');
  });
  test('TSV and CSV retain leading, trailing and multiline empty cells', () {
    TableCellNode cell(String value) => TableCellNode(
      span: const SourceSpan(0, 0),
      children: [TextNode(span: const SourceSpan(0, 0), text: value)],
    );
    final table = TableNode(
      span: const SourceSpan(0, 0),
      alignments: const [
        TableAlignment.none,
        TableAlignment.none,
        TableAlignment.none,
      ],
      children: [
        TableRowNode(
          span: const SourceSpan(0, 0),
          header: true,
          children: [cell(''), cell('a\tb\nc'), cell('')],
        ),
      ],
    );
    expect(toPlainText(table), '\t"a\tb\nc"\t');
    expect(tableToCsv(table), ',"a\tb\nc",');
  });
  test('canonical Markdown preserves rendered meaning across round trips', () {
    const fixtures = [
      '# Title\n\nParagraph **strong** and _emphasis_ with ~~strike~~.',
      r'Literal \&amp; and (x+y) and &#91;id&#93;',
      '<!doctype html><html><body>page</body></html>',
      '<!doctype html><html><body>page</body></html>\n',
      r'[link](a\&amp;b "A \&amp; B")',
      r':note[label]{title="A \&amp; B"}',
      '```lang\\&amp;\nx\n```',

      '- [x] Done\n- Next\n  - Nested\n\n7) Seven\n8) Eight',
      '> Quote\n>\n> More\n\n---',
      '`` `code` `` and [label](https://example.com "Title") and ![alt](image.png)',
      '```dart\n  code\n```\n\n\$\$\nx + y\n\$\$',
      '| A | B |\n| :--- | ---: |\n| a \\| b | `x\\|y` |',
      '<details open><summary>Summary</summary>\n\nBody **bold**\n</details>',
      '::::note[Title]{#one .wide}\nText\n\n:::tip\nInside\n:::\n::::',
      ':note[Label **bold**]{title="A &amp; B"}',
      '<div><b>Bold</b> <span style="color:red">red</span></div>',
      '[id]\n\n[id]: /url "Title"',
      'Literal \\*text\\* and &amp; and \\[1\\] and a\\_b',
    ];
    for (final source in fixtures) {
      final doc = parser.parse(source);
      final serialized = toMarkdown(doc);
      final reparsed = parser.parse(serialized);
      expect(toHtml(reparsed), toHtml(doc), reason: '$source\n=>\n$serialized');
      expect(toPlainText(reparsed), toPlainText(doc), reason: serialized);
    }
  });
  test('strict HTML serialization follows basic CommonMark output shape', () {
    final doc = const MarkdownParser(options: ParserOptions.commonMark()).parse(
      '# Title\n\none *two*\nthree\n\n- a\n- b\n\n> quote\n\n```dart\nx\n```',
    );
    expect(
      toHtml(doc),
      '<h1>Title</h1>\n<p>one <em>two</em>\nthree</p>\n<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n<blockquote>\n<p>quote</p>\n</blockquote>\n<pre><code class="language-dart">x\n</code></pre>\n',
    );
  });
  test('HTML excludes active content, dangerous schemes and unsafe styles', () {
    final doc = parser.parse(
      '[bad](javascript:alert(1)) ![image](data:text/html,hello)\n\n<div onclick="x"><script>secret</script><span style="color:red;background:url(evil);font-size:expression(x)" onmouseover="x">safe</span><a href="java&#10;script:alert(1)">link</a></div>',
    );
    final html = toHtml(doc);
    expect(html, isNot(contains('javascript:')));
    expect(html, isNot(contains('data:text/html')));
    expect(html, isNot(contains('onclick')));
    expect(html, isNot(contains('onmouseover')));
    expect(html, isNot(contains('secret')));
    expect(html, isNot(contains('expression')));
    expect(html, isNot(contains('url(')));
    expect(html, contains('style="color:red"'));
    expect(html, contains('<a>link</a>'));
  });
  test(
    'full HTML documents serialize as escaped code for clipboard export',
    () {
      final doc = parser.parse(
        '<!doctype html><html><script>code</script><body>page</body></html>',
      );
      expect(toHtml(doc), startsWith('<pre><code class="language-html">'));
      expect(toHtml(doc), contains('&lt;script&gt;code&lt;/script&gt;'));
      expect(toPlainText(doc), contains('<script>code</script>'));
    },
  );
  test('loose task lists place the checkbox inside the first paragraph', () {
    final doc = parser.parse('- [x] First\n\n- [ ] Second');
    final html = toHtml(doc);
    expect(
      html,
      contains(
        '<li>\n<p><input type="checkbox" disabled="" checked="" /> First</p>',
      ),
    );
    expect(toHtml(parser.parse(toMarkdown(doc))), html);
  });
  test('task labels that resemble reference definitions remain visible', () {
    final doc = parser.parse('- [x] [id]: /url');
    expect(doc.references, isEmpty);
    expect(
      doc.children.single.children.single.children.single,
      isA<ParagraphNode>(),
    );
    expect(toPlainText(doc), '- [x] [id]: /url');
    expect(toHtml(parser.parse(toMarkdown(doc))), toHtml(doc));
  });
  test('streaming task labels never define earlier reference links', () {
    const source = '[ref]\n\n- [x] [ref]: /url';
    final incremental = IncrementalDocument();
    for (var i = 0; i <= source.length; i++) {
      final prefix = source.substring(0, i);
      final doc = incremental.update(prefix, streaming: true);
      expect(doc.toJson(), parser.parse(prefix, streaming: true).toJson());
      expect(doc.references, isEmpty);
    }
  });
  test('empty code blocks stay empty through Markdown and HTML export', () {
    final doc = parser.parse('```dart\n```');
    expect((doc.children.single as CodeBlockNode).code, '');
    expect(toHtml(doc), '<pre><code class="language-dart"></code></pre>\n');
    expect(toHtml(parser.parse(toMarkdown(doc))), toHtml(doc));
  });
  test('reference metadata preserves literal entity-looking values', () {
    final doc = parser.parse(r'[id]: a\&amp;b "A \&amp; B"');
    final reparsed = parser.parse(toMarkdown(doc));
    expect(
      reparsed.references['id']!.destination,
      doc.references['id']!.destination,
    );
    expect(reparsed.references['id']!.title, doc.references['id']!.title);
  });
}
