import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

String _text(MarkdownNode node) =>
    node is TextNode ? node.text : node.children.map(_text).join();

void main() {
  const parser = BlockParser();
  test('display math splits surrounding prose and crosses blank lines', () {
    const source = '说明文字 \$\$\na + b\n\nc + d\n\$\$ 后续文字';
    final doc = parser.parse(source);
    expect(doc.children.map((n) => n.type), [
      'paragraph',
      'math_block',
      'paragraph',
    ]);
    final math = doc.children[1] as MathBlockNode;
    expect(math.tex, 'a + b\n\nc + d');
    expect(math.closed, isTrue);
    expect(math.span.slice(source), '\$\$\na + b\n\nc + d\n\$\$');
    expect(_text(doc.children.last), '后续文字');
  });
  test('empty escaped brackets remain visible punctuation', () {
    const source = r'Before \[ \] \# after';
    final doc = const MarkdownParser().parse(source);
    expect(doc.children.single, isA<ParagraphNode>());
    expect(toPlainText(doc), 'Before [ ] # after');
    for (final streaming in [false, true]) {
      final incremental = IncrementalDocument();
      for (var end = 1; end <= source.length; end++) {
        final prefix = source.substring(0, end);
        expect(
          incremental.update(prefix, streaming: streaming).toJson(),
          const MarkdownParser().parse(prefix, streaming: streaming).toJson(),
        );
      }
    }
  });
  test('bracket math preserves original body positions under a quote', () {
    const source = '> \\[\r\n> x + y\r\n> \\]';
    final quote = parser.parse(source).children.single as BlockQuoteNode;
    final math = quote.children.single as MathBlockNode;
    expect(math.tex, 'x + y');
    expect(math.delimiter, r'\[');
    expect(
      math.children
          .where((n) => n.text.contains('x'))
          .single
          .span
          .slice(source),
      'x + y',
    );
  });
  test('same-line display bodies can close after a blank line', () {
    const source = 'Before \$\$a + b\n\nc + d\$\$ after';
    final doc = parser.parse(source);
    expect(doc.children.map((node) => node.type), [
      'paragraph',
      'math_block',
      'paragraph',
    ]);
    final math = doc.children[1] as MathBlockNode;
    expect(math.tex, 'a + b\n\nc + d');
    expect(math.span.slice(source), '\$\$a + b\n\nc + d\$\$');
    expect(math.closed, isTrue);
    expect(
      parser.parse('Before \$\$a + b', streaming: true).children.last,
      isA<MathBlockNode>(),
    );
    expect(
      parser.parse('Before \$\$a + b').children.single,
      isA<ParagraphNode>(),
    );
    expect(
      parser
          .parse('Before \$\$a\n\nb\\\$\$')
          .children
          .whereType<MathBlockNode>(),
      isEmpty,
    );
  });
  test('fences and inline code protect math markers', () {
    final doc = parser.parse('`\$\$x\$\$`\n\n```\n\$\$\nx\n\$\$\n```');
    expect(doc.children.map((n) => n.type), ['paragraph', 'code_block']);
    expect(_text(doc.children.first), r'`$$x$$`');
  });
  test('literal dollars in words and explanations stay text', () {
    const source = r'b$$c x$$=$$1 $$符号通常用于块级公式。后文';
    expect(_text(parser.parse(source).children.single), source);
  });
  test('open math uses a deliberate line opener or streaming context', () {
    expect(parser.parse('\$\$\nx+y').children.single, isA<MathBlockNode>());
    expect(parser.parse(r'$$x+y').children.single, isA<ParagraphNode>());
    final open =
        parser.parse(r'$$x+y', streaming: true).children.single
            as MathBlockNode;
    expect(open.tex, 'x+y');
    expect(open.closed, isFalse);
    expect(
      const BlockParser(options: ParserOptions.commonMark())
          .parse('\$\$\nx+y')
          .children
          .single,
      isA<ParagraphNode>(),
    );
  });
  test('closing math does not make a list loose', () {
    final list =
        parser.parse('- \$\$x\$\$\n- next').children.single as ListNode;
    expect(list.tight, isTrue);
    expect(list.children, hasLength(2));
  });

  test('standalone checkbox and radio lines retain their source markers', () {
    const source = '[ ] first\n[x] second\n( ) third\n(X) fourth';
    final nodes = parser.parse(source).children.cast<TaskItemNode>().toList();
    expect(nodes.map((n) => n.checked), [false, true, false, true]);
    expect(nodes.map((n) => n.radio), [false, false, true, true]);
    expect(nodes.map(_text), ['first', 'second', 'third', 'fourth']);
    expect(nodes[1].markerSpan.slice(source), '[x] ');
  });
  test('list checkboxes are first-paragraph metadata, not heading starts', () {
    const source = '- [x] # label\n- [ ] **next**';
    final list = parser.parse(source).children.single as ListNode;
    expect(list.children.map((n) => n.checked), [true, false]);
    expect(list.children.map(_text), ['# label', '**next**']);
    expect(list.children.first.children.single, isA<ParagraphNode>());
    expect(list.children.first.markerSpan!.slice(source), '[x] ');
    expect(
      const BlockParser(options: ParserOptions.commonMark())
          .parse(source)
          .children
          .single
          .children
          .first,
      isA<ListItemNode>().having((n) => n.checked, 'checked', isNull),
    );
  });
  test('several display expressions on one line do not recurse', () {
    final doc = parser.parse(List.filled(1200, r'$$x$$ ').join());
    expect(doc.children, hasLength(1200));
    expect(doc.children.every((n) => n is MathBlockNode), isTrue);
  });
  test(
    'table alignment, ragged rows and escaped pipes retain source spans',
    () {
      const source =
          '| Left | Mid | Right |\r\n|:---|:---:|---:|\r\n'
          '| a \\| b | `x\\|y` | \$P(A\\mid B)\$ |\r\n'
          '| short |\r\n| one | two | three | ignored |';
      final table = parser.parse(source).children.single as TableNode;
      expect(table.alignments, [
        TableAlignment.left,
        TableAlignment.center,
        TableAlignment.right,
      ]);
      expect(table.children.map((row) => row.children.map(_text).toList()), [
        ['Left', 'Mid', 'Right'],
        ['a | b', '`x|y`', r'$P(A\mid B)$'],
        ['short', '', ''],
        ['one', 'two', 'three'],
      ]);
      final pipe = table.children[1].children.first.children
          .whereType<TextNode>()
          .firstWhere((n) => n.text == '|');
      expect(pipe.span.slice(source), r'\|');
      expect(table.children.first.header, isTrue);
      expect(table.children.last.header, isFalse);
    },
  );
  test('delimiter cells must match the single-line header', () {
    expect(parser.parse('text\n---').children.map((n) => n.type), [
      'paragraph',
      'thematic_break',
    ]);
    expect(
      parser.parse('a | b\n--- | --- | ---').children.single,
      isA<ParagraphNode>(),
    );
    expect(
      parser.parse('intro\na | b\n--- | ---').children.single,
      isA<ParagraphNode>(),
    );
    final table = parser
        .parse('name | value\n--- | ---\nline\n\nAfter')
        .children;
    expect(table.map((n) => n.type), ['table', 'paragraph']);
    expect(
      _text((table.first as TableNode).children[1].children.first),
      'line',
    );
    expect(
      const BlockParser(options: ParserOptions.commonMark())
          .parse('a | b\n--- | ---')
          .children
          .single,
      isA<ParagraphNode>(),
    );
  });
  test('tables remain inside list and quote containers', () {
    const source = '> - A | B\n>   --- | ---\n>   one | two\n> - Next';
    final quote = parser.parse(source).children.single as BlockQuoteNode;
    final list = quote.children.single as ListNode;
    expect(list.children, hasLength(2));
    expect(list.children.first.children.single, isA<TableNode>());
  });
  test(
    'details summary, nested Markdown, open attribute and trailing text',
    () {
      const source =
          '<details open title="a > b"><summary>More **info**</summary>\n\n'
          'Hidden content.\n\n- One\n- Two\n\n</details>After';
      final doc = parser.parse(source);
      final details = doc.children.first as DetailsNode;
      expect(details.open, isTrue);
      expect(details.closed, isTrue);
      expect(details.children.map((n) => n.type), [
        'details_summary',
        'paragraph',
        'list',
      ]);
      expect(_text(details.children.first), 'More **info**');
      expect(details.span.slice(source).endsWith('</details>'), isTrue);
      expect(_text(doc.children.last), 'After');
    },
  );
  test('nested details and same-line math keep all intervening prose', () {
    const source =
        r'<details><summary>A</summary>before $$x$$ after</details> tail';
    final doc = parser.parse(source);
    final details = doc.children.first as DetailsNode;
    expect(details.children.map((n) => n.type), [
      'details_summary',
      'paragraph',
      'math_block',
      'paragraph',
    ]);
    expect(_text(details.children.last), 'after');
    expect(_text(doc.children.last), 'tail');
    final nested =
        parser
                .parse(
                  '<details>\n<details><summary>B</summary>inside</details>\n</details>',
                )
                .children
                .single
            as DetailsNode;
    expect(nested.children.single, isA<DetailsNode>());
    expect((nested.children.single as DetailsNode).closed, isTrue);
  });
  test('details closing tags in code are literal; an open container stays open', () {
    const source =
        '<details><summary>A</summary>\n\n`</details>`\n\n```html\n</details>\n```';
    final details = parser.parse(source).children.single as DetailsNode;
    expect(details.closed, isFalse);
    expect(details.children.last, isA<CodeBlockNode>());
    expect(_text(details.children[1]), '`</details>`');
    expect(
      parser.parse('<detailsx>Text</detailsx>').children.single,
      isA<ParagraphNode>(),
    );
  });
  test('task marker permits a tab but requires separation before label', () {
    final list =
        parser.parse('- [\t] task\n- [x]literal').children.single as ListNode;
    expect(list.children.first.checked, false);
    expect(list.children.last.checked, isNull);
  });
  test('same-line details close truncates its active list container', () {
    const source = '<details>\n1. item</details> after';
    final doc = parser.parse(source);
    final details = doc.children.first as DetailsNode;
    final list = details.children.single as ListNode;
    expect(list.span.end, source.indexOf('</details>'));
    expect(list.children.single.span.end, list.span.end);
    expect(_text(doc.children.last), 'after');
  });
}
