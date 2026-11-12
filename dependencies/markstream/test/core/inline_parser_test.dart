import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

String textOf(MarkdownNode node) => node is TextNode
    ? node.text
    : node is LineBreakNode
    ? '\n'
    : node.children.map(textOf).join();
String shape(MarkdownNode n) =>
    n is TextNode ? n.text : '${n.type}(${n.children.map(shape).join()})';

void main() {
  const parser = InlineParser(options: ParserOptions.commonMark());
  test('delimiter runs pair nested emphasis and preserve unmatched pieces', () {
    final cases = {
      '***both***': 'emphasis(strong(both))',
      '**strong *inside* end**': 'strong(strong emphasis(inside) end)',
      '*one **two** three*': 'emphasis(one strong(two) three)',
      '**x*': '*emphasis(x)',
      'foo_bar_baz': 'foo_bar_baz',
      '_word_': 'emphasis(word)',
      'a**b**c': 'astrong(b)c',
      '*a _b* c_': 'emphasis(a _b) c_',
      '*foo**bar**baz*': 'emphasis(foostrong(bar)baz)',
    };
    for (final entry in cases.entries) {
      expect(
        parser.parse(entry.key).map(shape).join(),
        entry.value,
        reason: entry.key,
      );
    }
  });
  test('CJK relaxation permits emphasis beside Chinese punctuation', () {
    const source = '这是**「重点」**说明';
    final nodes = const InlineParser().parse(source);
    expect(nodes.whereType<EmphasisNode>().single.strong, true);
    expect(nodes.map(textOf).join(), '这是「重点」说明');
    expect(parser.parse(source).whereType<EmphasisNode>(), isEmpty);
  });
  test('backticks match only equal runs and protect other markup', () {
    final nodes = parser.parse('`` `a` **b** `` and ` x\ny ` then ``open`');
    final code = nodes.whereType<CodeSpanNode>().toList();
    expect(code.map((n) => n.code), ['`a` **b**', 'x y']);
    expect(nodes.map(textOf).join(), '`a` **b** and x y then ``open`');
    expect((parser.parse('`   `').single as CodeSpanNode).code, '   ');
    expect(parser.parse(r'\`literal\`').map(textOf).join(), '`literal`');
  });
  test('escapes and entities keep their complete source intervals', () {
    const source = r'\* &amp; &#x1F600; &NotEqualTilde; \&amp; &#0;';
    final nodes = parser.parse(source);
    expect(nodes.map(textOf).join(), '* & 😀 ≂̸ &amp; �');
    final emoji = nodes.whereType<TextNode>().firstWhere((n) => n.text == '😀');
    expect(emoji.span.slice(source), '&#x1F600;');
    expect(
      parser.parse('&bogus; &amp &#x110000;').map(textOf).join(),
      '&bogus; &amp �',
    );
  });
  test(
    'soft and hard breaks trim line-edge spaces and preserve CRLF spans',
    () {
      const source = 'one  \r\ntwo\nthree\\\nfour';
      final nodes = parser.parse(source);
      expect(nodes.whereType<LineBreakNode>().map((n) => n.hard), [
        true,
        false,
        true,
      ]);
      expect(nodes.map(textOf).join(), 'one\ntwo\nthree\nfour');
      expect(
        nodes.whereType<LineBreakNode>().first.span.slice(source),
        '  \r\n',
      );
      expect(
        const InlineParser()
            .parse('a\nb')
            .whereType<LineBreakNode>()
            .single
            .hard,
        true,
      );
    },
  );
  test('inline destinations, titles, images and angle autolinks', () {
    const source =
        r'[**title**](https://example.com/a(b) "tooltip") ![alt *text*](<a b.png>) <a@b.example> <https://x.test?a=1&b=2>';
    final nodes = parser.parse(source);
    final links = nodes.whereType<LinkNode>().toList();
    expect(links.first.destination, 'https://example.com/a(b)');
    expect(links.first.title, 'tooltip');
    expect(links.first.children.single, isA<EmphasisNode>());
    final image = nodes.whereType<ImageNode>().single;
    expect(image.destination, 'a b.png');
    expect(textOf(image), 'alt text');
    expect(links[1].destination, 'mailto:a@b.example');
    expect(links.last.destination, 'https://x.test?a=1&b=2');
    expect(parser.parse('[](url)').single, isA<LinkNode>());
    expect((parser.parse('[a]()').single as LinkNode).destination, '');
  });
  test('bracket stack prevents nested links while preserving image labels', () {
    final nodes = parser.parse('[outer [inner](two)](one)');
    expect(nodes.whereType<LinkNode>().single.destination, 'two');
    expect(nodes.map(textOf).join(), '[outer inner](one)');
    final link = parser.parse('[![alt](image)](link)').single as LinkNode;
    expect(link.children.single, isA<ImageNode>());
    expect(link.destination, 'link');
    expect(parser.parse('[1]').map(textOf).join(), '[1]');
  });
  test('bare URLs trim punctuation and respect balanced parentheses', () {
    const source =
        'Read https://example.com/a(b)). www.example.com/path, or a+b@example.org.';
    final nodes = const InlineParser().parse(source);
    expect(nodes.whereType<LinkNode>().map((n) => n.destination), [
      'https://example.com/a(b)',
      'http://www.example.com/path',
      'mailto:a+b@example.org',
    ]);
    expect(parser.parse(source).whereType<LinkNode>(), isEmpty);
  });
  test('two-phase parser resolves references across nested blocks', () {
    const source =
        '[a *label*][ID] and [ID][] and [id]\n\n> [ID]: /path "title"\n\n[ID]: /ignored\n\nNext';
    final doc = const MarkdownParser(options: ParserOptions.commonMark())
        .parse(source);
    final links = doc.children.first.children.whereType<LinkNode>().toList();
    expect(links, hasLength(3));
    expect(
      links.every(
        (link) => link.destination == '/path' && link.title == 'title',
      ),
      true,
    );
    expect(links.first.children.whereType<EmphasisNode>().single.strong, false);
    expect(doc.children[1].children.single, isA<ReferenceDefinitionNode>());
    expect(doc.children[2], isA<ReferenceDefinitionNode>());
  });
  test('definitions can precede prose without a blank line', () {
    final doc = const MarkdownParser().parse('[a]: /url\n[a] is a link.');
    expect(doc.children.first, isA<ReferenceDefinitionNode>());
    expect(doc.children.last.children.first, isA<LinkNode>());
  });
  test('code, math and HTML bodies bypass Markdown inline interpretation', () {
    final doc = const MarkdownParser().parse(
      '```lang&amp;\n**literal**\n```\n\n\$\$\n**math**\n\$\$\n\n<div>**html** &amp;</div>',
    );
    expect((doc.children.first as CodeBlockNode).info, 'lang&');
    expect((doc.children[1] as MathBlockNode).tex, '**math**');
    expect(textOf(doc.children.last), '**html** &');
  });
  test('random malformed markers keep all inline spans inside parents', () {
    final random = Random(6417);
    const tokens = [
      'word',
      ' ',
      '😀',
      '中',
      '*',
      '**',
      '_',
      '__',
      '`',
      '``',
      '[',
      ']',
      '(',
      ')',
      '!',
      '\\',
      '&amp;',
      '\n',
      '<',
      '>',
    ];
    for (var sample = 0; sample < 1000; sample++) {
      final source = List.generate(
        random.nextInt(100),
        (_) => tokens[random.nextInt(tokens.length)],
      ).join();
      final root = DocumentNode(
        source: source,
        children: [
          ParagraphNode(
            span: SourceSpan(0, source.length),
            children: parser.parse(source),
          ),
        ],
      );
      final pending = <MarkdownNode>[root];
      while (pending.isNotEmpty) {
        final node = pending.removeLast();
        for (final child in node.children) {
          expect(
            child.span.start,
            greaterThanOrEqualTo(node.span.start),
            reason: source,
          );
          expect(
            child.span.end,
            lessThanOrEqualTo(node.span.end),
            reason: source,
          );
          pending.add(child);
        }
      }
    }
  });
  test(
    'explicit links own their URL labels and angle links take precedence',
    () {
      final link =
          const InlineParser().parse('[https://example.com](other)').single
              as LinkNode;
      expect(link.destination, 'other');
      expect(link.children.single, isA<TextNode>());
      final angle = const InlineParser().parse(
        '[<https://example.com>](other)',
      );
      expect(
        angle.whereType<LinkNode>().single.destination,
        'https://example.com',
      );
      expect(
        const InlineParser()
            .parse('[https://example.com]')
            .whereType<LinkNode>()
            .single
            .destination,
        'https://example.com',
      );
    },
  );
  test(
    'decoded destinations and quoted attributes honor escaped ampersands',
    () {
      final link =
          parser.parse(r'[label](a\&amp;b "A &amp; B")').single as LinkNode;
      expect(link.destination, 'a&amp;b');
      expect(link.title, 'A & B');
    },
  );
  test('inline spans cross quote prefixes without mapping them to text', () {
    const source = '> **😀 one\r\n> two**';
    final quote =
        const MarkdownParser().parse(source).children.single as BlockQuoteNode;
    final strong = quote.children.single.children.single as EmphasisNode;
    expect(strong.span.slice(source), '**😀 one\r\n> two**');
    expect(strong.children.first.span.slice(source), '😀 one');
    expect(strong.children.last.span.slice(source), 'two');
    expect(textOf(strong), '😀 one\ntwo');
  });
  test(
    'long unmatched brackets and repeated delimiters terminate with valid text',
    () {
      final source = List.filled(12000, 'text [').join();
      expect(parser.parse(source).map(textOf).join(), source);
      final run = '${'*' * 1000}content${'*' * 1000}';
      final parsed = parser.parse(run);
      var node = parsed.single;
      var levels = 0;
      while (node is EmphasisNode) {
        levels++;
        node = node.children.single;
      }
      expect(levels, 500);
      expect(textOf(node), 'content');
    },
  );
  test('escaping the first backtick leaves the remaining run available', () {
    final nodes = parser.parse(r'\```inside``');
    expect(nodes.map(textOf).join(), '`inside');
    expect(nodes.last, isA<CodeSpanNode>());
    final unmatched = '${'[' * 12000}text${']' * 12000}';
    expect(parser.parse(unmatched).map(textOf).join(), unmatched);
  });
}
