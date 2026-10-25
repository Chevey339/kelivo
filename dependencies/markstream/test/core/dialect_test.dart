import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

String textOf(MarkdownNode node) =>
    node is TextNode ? node.text : node.children.map(textOf).join();

void main() {
  const llm = ParserOptions.llm();
  DocumentNode parse(String source, [ParserOptions options = llm]) =>
      MarkdownParser(options: options).parse(source);
  test('LLM visible newlines do not enable setext or indented code', () {
    expect(
      parse('first\nsecond').children.single.children
          .whereType<LineBreakNode>()
          .single
          .hard,
      true,
    );
    expect(parse('Title\n---').children.map((n) => n.type), [
      'paragraph',
      'thematic_break',
    ]);
    expect(parse('    ordinary text').children.single, isA<ParagraphNode>());
    expect(
      parse('Title\n---', llm.copyWith(setextHeadings: true)).children.single,
      isA<HeadingNode>(),
    );
    expect(
      parse('    code', llm.copyWith(indentedCode: true)).children.single,
      isA<CodeBlockNode>(),
    );
    expect(
      parse(
        'first\nsecond',
        llm.copyWith(softBreakAsHardBreak: false),
      ).children.single.children.whereType<LineBreakNode>().single.hard,
      false,
    );
  });
  test(
    'underscore, plus lists and closing-parenthesis markers are enabled',
    () {
      expect(
        parse('_word_').children.single.children.single,
        isA<EmphasisNode>(),
      );
      expect(
        parse(
          '_word_',
          llm.copyWith(underscoreEmphasis: false),
        ).children.single.children.single,
        isA<TextNode>(),
      );
      expect(parse('+ item').children.single, isA<ListNode>());
      expect(parse('1) item').children.single, isA<ListNode>());
      expect(
        parse('+ item', llm.copyWith(plusListMarker: false)).children.single,
        isA<ParagraphNode>(),
      );
      expect(
        parse(
          '1) item',
          llm.copyWith(orderedParenthesis: false),
        ).children.single,
        isA<ParagraphNode>(),
      );
    },
  );
  test('bare URLs and entities can be disabled independently', () {
    const source = 'https://example.com &amp;';
    expect(parse(source).children.single.children.first, isA<LinkNode>());
    final plain = parse(source, llm.copyWith(autolinks: false));
    expect(plain.children.single.children.whereType<LinkNode>(), isEmpty);
    expect(textOf(plain), 'https://example.com &');
    expect(textOf(parse('&amp;', llm.copyWith(entities: false))), '&amp;');
    expect(
      textOf(parse('<div>&amp;</div>', llm.copyWith(entities: false))),
      '&amp;',
    );
  });
  test('standalone checkboxes and radios have independent controls', () {
    expect(parse('[ ] Task').children.single, isA<TaskItemNode>());
    expect(parse('(x) Choice').children.single, isA<TaskItemNode>());
    expect(
      parse(
        '[ ] Task',
        llm.copyWith(standaloneTaskLine: false),
      ).children.single,
      isA<ParagraphNode>(),
    );
    expect(
      parse(
        '- [x] Task',
        llm.copyWith(standaloneTaskLine: false),
      ).children.single.children.single,
      isA<ListItemNode>().having((n) => n.checked, 'checked', true),
    );
    expect(
      parse(
        '(x) Choice',
        llm.copyWith(taskItems: false, standaloneTaskLine: false),
      ).children.single,
      isA<TaskItemNode>(),
    );
    expect(
      parse('(x) Choice', llm.copyWith(radioItems: false)).children.single,
      isA<ParagraphNode>(),
    );
    expect(
      parse(
        '- [x] Task',
        llm.copyWith(taskItems: false),
      ).children.single.children.single,
      isA<ListItemNode>().having((n) => n.checked, 'checked', isNull),
    );
  });
  test('table pipes may be optional or required for every row', () {
    const source = 'A | B\n--- | ---\none | two';
    expect(parse(source).children.single, isA<TableNode>());
    expect(
      parse(source, llm.copyWith(tablePipesOptional: false)).children.single,
      isA<ParagraphNode>(),
    );
    final strict = parse(
      '| A | B |\n| --- | --- |\none | two',
      llm.copyWith(tablePipesOptional: false),
    );
    expect(strict.children.map((n) => n.type), ['table', 'paragraph']);
    expect(
      parse(source, llm.copyWith(tables: false)).children.single,
      isA<ParagraphNode>(),
    );
  });
  test('math body limit applies equally in text and table cells', () {
    final small = llm.copyWith(maxInlineMathLength: 3);
    expect(
      parse(r'$abc$', small).children.single.children.single,
      isA<MathInlineNode>(),
    );
    expect(
      parse(r'$abcd$', small).children.single.children.single,
      isA<TextNode>(),
    );
    final table =
        parse('| A |\n| --- |\n| \$abcd\$ |', small).children.single
            as TableNode;
    expect(
      table.children.last.children.single.children.single,
      isA<TextNode>(),
    );
  });
  test('plain bracketed numbers have no built-in citation behavior', () {
    final doc = parse('[1] [42]');
    expect(doc.children.single.children.every((n) => n is TextNode), true);
    expect(textOf(doc), '[1] [42]');
  });
  test('GFM extends the strict profile without standalone LLM structures', () {
    const gfm = ParserOptions.gfm();
    final doc = parse(
      '- [x] ~~Done~~\n\nA | B\n--- | ---\none | two\n\n[ ] standalone',
      gfm,
    );
    expect((doc.children.first.children.single as ListItemNode).checked, true);
    expect(doc.children[1], isA<TableNode>());
    expect(doc.children.last, isA<ParagraphNode>());
    expect(parse('Title\n===', gfm).children.single, isA<HeadingNode>());
    expect(parse(r'$x$', gfm).children.single.children.single, isA<TextNode>());
    expect(
      parse('    code', gfm.copyWith(autolinks: false)).children.single,
      isA<CodeBlockNode>(),
    );
  });
  test('CJK emphasis can retain strict delimiter flanking', () {
    const source = '这是**「重点」**说明';
    expect(
      parse(source).children.single.children.whereType<EmphasisNode>(),
      hasLength(1),
    );
    expect(
      parse(
        source,
        llm.copyWith(cjkFlankingRelax: false),
      ).children.single.children.whereType<EmphasisNode>(),
      isEmpty,
    );
  });
  test('extension families can each be disabled', () {
    expect(
      parse(
        '~~text~~',
        llm.copyWith(strikethrough: false),
      ).children.single.children.single,
      isA<TextNode>(),
    );
    expect(
      parse(
        ':note[label]',
        llm.copyWith(directives: false),
      ).children.single.children.whereType<NamedInlineNode>(),
      isEmpty,
    );
    expect(
      parse('> [!TIP]\n> text', llm.copyWith(alerts: false)).children.single,
      isA<BlockQuoteNode>(),
    );
    expect(
      parse(
        'before <b>text</b>',
        llm.copyWith(inlineHtml: false),
      ).children.single.children.whereType<HtmlElementNode>(),
      isEmpty,
    );
    expect(
      parse(
        '<div>text</div>',
        llm.copyWith(htmlBlocks: false, inlineHtml: false),
      ).children.single,
      isA<ParagraphNode>(),
    );
    expect(
      parse(
        '<details>text</details>',
        llm.copyWith(details: false),
      ).children.single,
      isA<HtmlBlockNode>(),
    );
  });
}
