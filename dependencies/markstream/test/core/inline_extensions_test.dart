import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

String textOf(MarkdownNode node) =>
    node is TextNode ? node.text : node.children.map(textOf).join();

final class _CitationSyntax extends InlineSyntax {
  const _CitationSyntax();
  @override
  Set<int> get startCharacters => const {91};
  @override
  InlineSyntaxMatch? match(InlineSyntaxContext context, int offset) {
    final match = RegExp(r'\[cite:([a-z0-9]+)\]')
        .matchAsPrefix(context.text, offset);
    if (match == null) return null;
    return InlineSyntaxMatch(
      end: match.end,
      node: NamedInlineNode(
        span: context.span(offset, match.end),
        name: 'citation',
        children: context.textNodes(offset + 6, match.end - 1),
        attributes: {'id': match[1]!},
      ),
    );
  }
}

final class _EmptySyntax extends InlineSyntax {
  const _EmptySyntax();
  @override
  Set<int> get startCharacters => const {64};
  @override
  InlineSyntaxMatch? match(InlineSyntaxContext context, int offset) =>
      InlineSyntaxMatch(
        end: offset,
        node: TextNode(span: context.span(offset, offset), text: ''),
      );
}

void main() {
  const parser = InlineParser();
  test('inline dollar and parenthesis math obey CJK and word boundaries', () {
    const source = r'中文$x+y$说明，\( a_b \) then $a$$b$ but a$x$b and $ 3 $';
    final nodes = parser.parse(source);
    expect(nodes.whereType<MathInlineNode>().map((n) => n.tex), [
      'x+y',
      'a_b',
      'a',
      'b',
    ]);
    expect(nodes.last, isA<TextNode>());
    expect(textOf(nodes.last), contains(r'a$x$b'));
  });
  test('math stays within 512 code units and never crosses a line', () {
    expect(parser.parse('\$${'a' * 512}\$').single, isA<MathInlineNode>());
    expect(
      parser.parse('\$${'a' * 513}\$').whereType<MathInlineNode>(),
      isEmpty,
    );
    expect(parser.parse('\$x\ny\$').whereType<MathInlineNode>(), isEmpty);
    expect(
      parser.parse(r'\$x\$ and `$x$`').whereType<MathInlineNode>(),
      isEmpty,
    );
    expect(parser.parse(r'$x').map(textOf).join(), r'$x');
    expect(
      const InlineParser(options: ParserOptions.commonMark())
          .parse(r'$x$')
          .single,
      isA<TextNode>(),
    );
  });
  test('only double tildes strike, with nested emphasis and links', () {
    final node =
        parser.parse('~~old **bold** [link](x)~~').single as StrikethroughNode;
    expect(node.children.whereType<EmphasisNode>().single.strong, true);
    expect(node.children.whereType<LinkNode>().single.destination, 'x');
    expect(
      parser
          .parse('~single~ ~~~triple~~~ ~~~~four~~~~')
          .whereType<StrikethroughNode>(),
      isEmpty,
    );
    expect(parser.parse('~~open').map(textOf).join(), '~~open');
  });
  test('inline directives parse nested labels and decode attributes', () {
    final node =
        parser
                .parse(
                  ':note[**Title** :kbd[key]]{#id .wide title="A &amp; B"}',
                )
                .single
            as NamedInlineNode;
    expect(node.name, 'note');
    expect(node.syntax, NamedInlineSyntax.directive);
    expect(node.attributes, {'id': 'id', 'class': 'wide', 'title': 'A & B'});
    expect(node.children.first, isA<EmphasisNode>());
    expect((node.children.last as NamedInlineNode).name, 'kbd');
    expect(parser.parse(':smile:').map(textOf).join(), ':smile:');
    expect(parser.parse(':bad-[]').whereType<NamedInlineNode>(), isEmpty);
  });
  test('native inline HTML keeps supported tags and strips unknown shells', () {
    const source =
        'Before <b>bold <u>under</u></b> <custom>plain</custom> <br> after';
    final nodes = parser.parse(source);
    expect(nodes.whereType<HtmlElementNode>().map((n) => n.tag), ['b', 'br']);
    expect(
      (nodes.whereType<HtmlElementNode>().first.children.last
              as HtmlElementNode)
          .tag,
      'u',
    );
    expect(nodes.map(textOf).join(), 'Before bold under plain  after');
    expect(
      parser.parse('<script>hidden</script>visible').map(textOf).join(),
      'visible',
    );
    expect(parser.parse('x <iframe>secret').map(textOf).join(), 'x ');
  });
  test('HTML attributes and entity spans stay source mapped', () {
    const source = 'x <span style="color:red" onclick="bad()">&amp;</span> y';
    final node = parser.parse(source).whereType<HtmlElementNode>().single;
    expect(node.attributes, {'style': 'color:red'});
    expect(node.children.single.span.slice(source), '&amp;');
    expect(textOf(node), '&');
  });
  test(
    'registered syntax is source mapped and opaque inside code and math',
    () {
      const source = '> [cite:a1] `[cite:b2]` \$[cite:c3]\$ [1]';
      final doc = const MarkdownParser(inlineSyntaxes: [_CitationSyntax()])
          .parse(source);
      final children = doc.children.single.children.single.children;
      final citation = children.whereType<NamedInlineNode>().single;
      expect(citation.attributes['id'], 'a1');
      expect(citation.span.slice(source), '[cite:a1]');
      expect(children.whereType<CodeSpanNode>().single.code, '[cite:b2]');
      expect(children.whereType<MathInlineNode>().single.tex, '[cite:c3]');
      expect(textOf(children.last), ' [1]');
      expect(
        () => const InlineParser(syntaxes: [_EmptySyntax()]).parse('@'),
        throwsArgumentError,
      );
    },
  );
  test('math pipes remain in a table cell and LaTeX pipe escapes stay intact', () {
    const source =
        '| Formula | Text |\n| --- | --- |\n| \$|x|\$ | one |\n| \$\\|x\\|=1\$ | two |';
    final table =
        const MarkdownParser().parse(source).children.single as TableNode;
    expect(table.children[1].children, hasLength(2));
    expect(
      (table.children[1].children.first.children.single as MathInlineNode).tex,
      '|x|',
    );
    expect(
      (table.children[2].children.first.children.single as MathInlineNode).tex,
      r'\|x\|=1',
    );
  });
  test('directive code labels shield brackets from the label scanner', () {
    final directive =
        parser.parse(':note[`[` and `]`]').single as NamedInlineNode;
    expect(directive.children.whereType<CodeSpanNode>().map((n) => n.code), [
      '[',
      ']',
    ]);
  });
  test('nested directives use an explicit work stack', () {
    final source = '${':note[' * 400}text${']' * 400}';
    var node = parser.parse(source).single;
    var depth = 0;
    while (node is NamedInlineNode) {
      depth++;
      node = node.children.single;
    }
    expect(depth, 400);
    expect(textOf(node), 'text');
  });
  test('mixed extension markers keep original UTF-16 node bounds', () {
    final random = Random(1661);
    const tokens = [
      'text',
      ' ',
      '😀',
      '中',
      r'$',
      r'\(',
      r'\)',
      ':note[',
      ']',
      '{.x}',
      '<b>',
      '</b>',
      '<custom>',
      '<script>',
      '</script>',
      '~~',
      '*',
      '`',
      '&amp;',
      '\n',
    ];
    for (var sample = 0; sample < 1000; sample++) {
      final source = List.generate(
        random.nextInt(80),
        (_) => tokens[random.nextInt(tokens.length)],
      ).join();
      final root = ParagraphNode(
        span: SourceSpan(0, source.length),
        children: parser.parse(source),
      );
      final pending = <MarkdownNode>[root];
      while (pending.isNotEmpty) {
        final parent = pending.removeLast();
        for (final child in parent.children) {
          expect(
            child.span.start,
            greaterThanOrEqualTo(parent.span.start),
            reason: source,
          );
          expect(
            child.span.end,
            lessThanOrEqualTo(parent.span.end),
            reason: source,
          );
          pending.add(child);
        }
      }
    }
  });
  test('colon runs inside prose never become partial inline directives', () {
    const source = 'before ::leaf[label] and :::container after';
    expect(parser.parse(source).whereType<NamedInlineNode>(), isEmpty);
    expect(parser.parse(source).map(textOf).join(), source);
    final doc = const MarkdownParser().parse(':::bad trailing');
    expect(doc.children.single.children.whereType<NamedInlineNode>(), isEmpty);
  });
  test('colons inside words and unfinished citation labels stay literal', () {
    const source = r'key:value [cite:abc \[cite:def] foo:note[label]';
    final parsed = parser.parse(source);
    expect(parsed.whereType<NamedInlineNode>(), isEmpty);
    expect(
      parsed.map(textOf).join(),
      r'key:value [cite:abc [cite:def] foo:note[label]',
    );
    expect(parser.parse(':note[label]').single, isA<NamedInlineNode>());
  });
  test('long malformed angle brackets remain literal and terminate', () {
    final source = '${'<' * 20000}plain';
    expect(parser.parse(source).map(textOf).join(), source);
  });
}
