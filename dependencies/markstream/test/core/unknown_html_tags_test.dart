import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  const parser = MarkdownParser();
  for (final streaming in [false, true]) {
    group('unknown HTML tags with streaming=$streaming', () {
      test('preserve standalone, inline, paired and self-closing tags', () {
        for (final source in [
          '<hello>',
          '前文 <hello> 后文',
          '<hello>内容</hello>',
          '<hello/>',
          '</hello>',
          '<Custom-Tag DATA-value="&amp; **literal** <b>">',
          '<input value="text">',
        ]) {
          final doc = parser.parse(source, streaming: streaming);
          expect(toPlainText(doc), source, reason: source);
          expect(doc.children.single, isA<ParagraphNode>());
          expect(
            doc.children.single.children.every((n) => n is TextNode),
            true,
          );
        }
      });

      test('leave following and enclosed Markdown available to the parser', () {
        for (final source in [
          'Before <hello> **bold**',
          '<hello>\n**bold**',
          '<hello>**bold**</hello>',
        ]) {
          final doc = parser.parse(source, streaming: streaming);
          expect(toPlainText(doc), source.replaceAll('**', ''));
          expect(
            doc.children.single.children
                .whereType<EmphasisNode>()
                .single
                .strong,
            true,
          );
        }
        final doc = parser.parse(
          '<hello>\n\n- **item**\n\n</hello>',
          streaming: streaming,
        );
        expect(doc.children.map((n) => n.type), [
          'paragraph',
          'list',
          'paragraph',
        ]);
        expect(toPlainText(doc), '<hello>\n\n- item\n\n</hello>');
      });

      test(
        'retain native HTML and discard active content inside unknown tags',
        () {
          const source =
              '<hello><b>Bold</b><script><hello>SECRET</hello></script>'
              '<style>SECRET</style><iframe>SECRET</iframe><!-- SECRET -->'
              '</hello> **After**';
          final doc = parser.parse(source, streaming: streaming);
          expect(toPlainText(doc), '<hello>Bold</hello> After');
          expect(
            toHtml(doc),
            contains('&lt;hello&gt;<b>Bold</b>&lt;/hello&gt;'),
          );
          expect(toHtml(doc), isNot(contains('SECRET')));
          expect(toHtml(doc), contains('<strong>After</strong>'));
        },
      );
    });
  }

  test(
    'unknown tags inside native HTML preserve raw attributes and source spans',
    () {
      const tag = '<Custom title="&amp; **literal** <b>" onclick="bad()">';
      for (final source in [
        'Before <span>$tag<b>Bold</b></Custom></span>',
        '> <div>\r\n> $tag<b>Bold</b></Custom>\r\n> </div>',
      ]) {
        final doc = parser.parse(source);
        final index = plainTextIndex(doc);
        expect(index.text, contains('${tag}Bold</Custom>'));
        final start = index.text.indexOf(tag);
        expect(
          index.sourceSpanForRange(start, start + tag.length).slice(source),
          tag,
        );
        final end = index.text.indexOf('</Custom>');
        expect(
          index.sourceSpanForRange(end, end + 9).slice(source),
          '</Custom>',
        );
        final html = toHtml(doc);
        expect(
          html,
          contains(
            '&lt;Custom title=&quot;&amp;amp; **literal** &lt;b&gt;&quot; onclick=&quot;bad()&quot;&gt;',
          ),
        );
        expect(html, contains('<b>Bold</b>&lt;/Custom&gt;'));
        expect(html, isNot(contains('<Custom')));
      }
    },
  );

  test('unknown tags do not change the nesting of native HTML containers', () {
    const source =
        '<div>\n<hello><div>One</hello>\nTwo</div>\nThree\n</div>\n\n**After**';
    final doc = parser.parse(source);
    final block = doc.children.first as HtmlBlockNode;
    expect(block.raw, source.substring(0, source.indexOf('\n\n') + 1));
    expect(block.closed, true);
    final outer = block.children.single as HtmlElementNode;
    final inner = outer.children.whereType<HtmlElementNode>().single;
    expect(toPlainText(inner), 'One</hello>\nTwo');
    expect(
      outer.children.whereType<TextNode>().map((n) => n.text).join(),
      contains('Three'),
    );
    expect(toPlainText(doc.children.last), 'After');
  });

  test(
    'native HTML still filters active content next to literal unknown tags',
    () {
      const source =
          '<div><hello/><hello><b onclick="bad()">Bold</b>'
          '<script>SECRET</script><style>SECRET</style><iframe>SECRET</iframe>'
          '<a href="javascript:bad()">Link</a></hello></div>';
      final doc = parser.parse(source);
      expect(toPlainText(doc), '<hello/><hello>BoldLink</hello>');
      final html = toHtml(doc);
      expect(html, contains('&lt;hello/&gt;&lt;hello&gt;<b>Bold</b>'));
      expect(html, contains('<a>Link</a>&lt;/hello&gt;'));
      for (final hidden in ['SECRET', 'onclick', 'javascript:']) {
        expect(html, isNot(contains(hidden)));
      }
      expect(
        toPlainText(parser.parse('<div><hello>Before<script>SECRET')),
        '<hello>Before',
      );
    },
  );

  test(
    'incremental parsing retains literal tags through streaming completion',
    () {
      const source =
          '<hello>\n**Bold**\n\n<div><custom>Text</custom></div>\n\nAfter';
      final incremental = IncrementalDocument();
      for (var end = 1; end <= source.length; end++) {
        final prefix = source.substring(0, end);
        final doc = incremental.update(prefix, streaming: true);
        expect(
          doc.toJson(),
          parser.parse(prefix, streaming: true).toJson(),
          reason: prefix,
        );
        if (end >= '<hello>'.length) {
          expect(toPlainText(doc), startsWith('<hello>'));
        }
      }
      expect(
        toPlainText(incremental.update(source)),
        '<hello>\nBold\n\n<custom>Text</custom>\n\nAfter',
      );
    },
  );

  test('list and table projections retain literal non-structural text', () {
    const cases = {
      '<ul><hello><li>Item</li></hello></ul>': '<hello>\n- Item\n</hello>',
      '<ol start="3"><li>A</li><hello/><li>B</li></ol>': '3. A\n<hello/>\n4. B',
      '<ul><hello/></ul>': '<hello/>',
      '<table><caption>Title</caption><tr><td>Cell</td></tr></table>':
          '<caption>Title</caption>\nCell',
      '<table><tbody><hello/><tr><td>A</td></tr></tbody></table>':
          '<hello/>\nA',
      '<table><tr><td>A</td></tr><hello/><tr><td>B</td></tr></table>':
          'A\n<hello/>\nB',
      '<table><tr><hello/><td>A</td><td>B</td></tr></table>':
          '<hello/>\n\nA\n\nB',
      '<table><tr><td></td></tr><tr><td>A</td></tr></table>': '\nA',
    };
    for (final entry in cases.entries) {
      final doc = parser.parse(entry.key);
      expect(toPlainText(doc), entry.value, reason: entry.key);
      final index = plainTextIndex(doc);
      expect(index.text, entry.value);
      for (final match in RegExp(r'<[^>]+>').allMatches(entry.value)) {
        expect(
          index.sourceSpanForRange(match.start, match.end).slice(entry.key),
          match[0],
        );
      }
    }
  });
}
