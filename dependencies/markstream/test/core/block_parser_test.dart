import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

String text(MarkdownNode node) =>
    node is TextNode ? node.text : node.children.map(text).join();

void main() {
  const parser = BlockParser();
  const strict = BlockParser(options: ParserOptions.commonMark());

  test('ATX headings, thematic breaks and paragraph interruption', () {
    final doc = parser.parse('# first ##\n\n##literal\n\n***\n---\n');
    expect(doc.children.map((n) => n.type), [
      'heading',
      'paragraph',
      'thematic_break',
      'thematic_break',
    ]);
    expect((doc.children.first as HeadingNode).level, 1);
    expect(text(doc.children.first), 'first');
    expect(text(doc.children[1]), '##literal');
    expect(doc.children.first.span.slice(doc.source), '# first ##');
  });
  test('quotes keep lazy paragraphs and contain sibling list items', () {
    const source =
        '> Lorem ipsum dolor\nsit amet.\n> - Qui *quodsi iracundia*\n> - aliquando id';
    final quote = parser.parse(source).children.single as BlockQuoteNode;
    expect(quote.children.map((n) => n.type), ['paragraph', 'list']);
    expect(text(quote.children.first), 'Lorem ipsum dolor\nsit amet.');
    final list = quote.children.last as ListNode;
    expect(list.children.map(text), ['Qui *quodsi iracundia*', 'aliquando id']);
    expect(list.tight, isTrue);
    expect(quote.span, SourceSpan(0, source.length));
  });
  test('markers inside fenced code are literal and closer length matters', () {
    final doc = parser.parse('````dart\n```\n# text\n- list\n````\nAfter');
    final code = doc.children.first as CodeBlockNode;
    expect(code.code, '```\n# text\n- list\n');
    expect(code.info, 'dart');
    expect(code.closed, isTrue);
    expect(text(doc.children.last), 'After');
    final open =
        parser.parse('~~~ x`y\nbody\n~~').children.single as CodeBlockNode;
    expect(open.info, 'x`y');
    expect(open.code, 'body\n~~\n');
    expect(open.closed, isFalse);
  });
  test('a missing quote prefix closes its unclosed code container', () {
    final doc = parser.parse('> ```\n> inside\noutside');
    final quote = doc.children.first as BlockQuoteNode;
    final code = quote.children.single as CodeBlockNode;
    expect(code.code, 'inside\n');
    expect(code.closed, isFalse);
    expect(text(doc.children.last), 'outside');
  });
  test('ordered start and marker families delimit lists', () {
    final doc = parser.parse('3. three\n4. four\n+ plus\n* star');
    expect(doc.children, hasLength(3));
    final ordered = doc.children.first as ListNode;
    expect(ordered.ordered, isTrue);
    expect(ordered.start, 3);
    expect(ordered.children.map(text), ['three', 'four']);
    expect((doc.children[1] as ListNode).marker, '+');
  });
  test('only ordered start one interrupts an existing paragraph', () {
    expect(
      text(parser.parse('text\n2. continuation').children.single),
      'text\n2. continuation',
    );
    expect(parser.parse('text\n1. item').children.map((n) => n.type), [
      'paragraph',
      'list',
    ]);
  });
  test('nested list indentation is strict or the LLM two-space rule', () {
    const source = '100. outer\n  - inner';
    final relaxed = parser.parse(source).children.single as ListNode;
    expect(relaxed.children.single.children.map((n) => n.type), [
      'paragraph',
      'list',
    ]);
    expect(strict.parse(source).children, hasLength(2));
  });
  test('blank lines make continuing lists loose, not trailing blanks', () {
    expect(
      (parser.parse('- a\n\n- b').children.single as ListNode).tight,
      isFalse,
    );
    final trailing = parser.parse('- a\n\noutside');
    expect((trailing.children.first as ListNode).tight, isTrue);
    expect(text(trailing.children.last), 'outside');
    final internal = parser.parse('- a\n\n  b').children.single as ListNode;
    expect(internal.tight, isFalse);
    expect(internal.children.single.children, hasLength(2));
  });
  test(
    'CommonMark supports setext and indented code while LLM text stays visible',
    () {
      expect(strict.parse('first\n---').children.single, isA<HeadingNode>());
      expect(parser.parse('first\n---').children.map((n) => n.type), [
        'paragraph',
        'thematic_break',
      ]);
      final code =
          strict.parse('    a\n\nnext').children.first as CodeBlockNode;
      expect(code.fenced, isFalse);
      expect(code.code, 'a\n');
      expect(parser.parse('    a').children.single, isA<ParagraphNode>());
    },
  );
  test('tabs are consumed by indentation but preserved inside code', () {
    final item = (strict.parse('-\tfoo\n\tbar').children.single as ListNode)
        .children
        .single;
    expect(text(item), 'foo\nbar');
    final code =
        strict.parse('```\n\tvalue\n```').children.single as CodeBlockNode;
    expect(code.code, '\tvalue\n');
  });
  test('paragraph fragments retain original UTF-16 and CRLF coordinates', () {
    const source = '> 中😀\r\n> e\u0301\r\n';
    final paragraph =
        (parser.parse(source).children.single as BlockQuoteNode).children.single
            as ParagraphNode;
    expect(text(paragraph), '中😀\ne\u0301');
    final first = paragraph.children.first as TextNode;
    expect(first.span.slice(source), '中😀');
    expect(first.span.length, 3);
    expect(paragraph.children[1].span.slice(source), '\r\n');
  });

  test('a thematic break terminates the preceding list', () {
    final doc = parser.parse('* first\n* * *');
    expect(doc.children.map((node) => node.type), ['list', 'thematic_break']);
  });
  test(
    'arbitrary block markers keep node spans within their original source',
    () {
      final random = Random(1731);
      const tokens = [
        'a',
        '中',
        '😀',
        '\t',
        ' ',
        '\n',
        '\r\n',
        '> ',
        '- ',
        '1. ',
        '## ',
        '```',
        '~~~',
        '***',
        '<details>',
        '<summary>',
        '</summary>',
        '</details>',
        r'$$',
        '[x] ',
        '( ) ',
        '| a | b |',
        '| --- | --- |',
        ':::note',
        '::::',
        '::image[caption]{src=x}',
        '> [!TIP]',
        '<div>',
        '</div>',
        '<script>',
        '</script>',
        '<!--',
        '-->',
      ];
      for (var sample = 0; sample < 700; sample++) {
        final source = List.generate(
          random.nextInt(80),
          (i) => tokens[random.nextInt(tokens.length)],
        ).join();
        for (final options in [
          const ParserOptions(),
          const ParserOptions.commonMark(),
        ]) {
          final doc = BlockParser(options: options).parse(source);
          final pending = <MarkdownNode>[doc];
          while (pending.isNotEmpty) {
            final node = pending.removeLast();
            expect(node.span.start, greaterThanOrEqualTo(0), reason: source);
            expect(
              node.span.end,
              lessThanOrEqualTo(source.length),
              reason: source,
            );
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
      }
    },
  );

  test(
    'code body fragments retain container prefixes and CRLF source gaps',
    () {
      const source = '> ```\r\n> a\t😀\r\n> b\r\n> ```';
      final quote = parser.parse(source).children.single as BlockQuoteNode;
      final code = quote.children.single as CodeBlockNode;
      expect(code.code, 'a\t😀\nb\n');
      expect(code.children.map((node) => node.span.slice(source)), [
        'a\t😀',
        '\r\n',
        'b',
        '\r\n',
      ]);
    },
  );
  test('partial tab removal preserves the original tab span', () {
    const source = ' ```\n\tbody\n ```';
    final code = parser.parse(source).children.single as CodeBlockNode;
    expect(code.code, '   body\n');
    expect(code.children.first.text, '   ');
    expect(code.children.first.span.slice(source), '\t');
    final eof = parser.parse('```\na').children.single as CodeBlockNode;
    expect(eof.children.last.text, '\n');
    expect(eof.children.last.span.isEmpty, isTrue);
  });
}
