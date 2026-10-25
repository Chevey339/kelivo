import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

String textOf(MarkdownNode node) =>
    node is TextNode ? node.text : node.children.map(textOf).join();

void main() {
  const parser = BlockParser();
  test('inline nested details close their own container before the outer body', () {
    const source =
        '<details><summary>outer</summary>prefix <details><summary>inner</summary>body</details>after</details>';
    final doc = const MarkdownParser().parse(source);
    final outer = doc.children.single as DetailsNode;
    expect(outer.closed, isTrue);
    final inner = outer.children.whereType<DetailsNode>().single;
    expect(inner.closed, isTrue);
    expect(
      inner.span.slice(source),
      '<details><summary>inner</summary>body</details>',
    );
    expect(toPlainText(outer.children.last), 'after');
    expect(
      outer.children
          .whereType<ParagraphNode>()
          .first
          .children
          .single
          .span
          .slice(source),
      'prefix ',
    );
  });
  test('GitHub alerts use the same named nodes as directives', () {
    final doc = parser.parse(
      '> [!WARNING]\n> Be **careful**.\n>\n> - next\n\nAfter',
    );
    final alert = doc.children.first as NamedBlockNode;
    expect(alert.name, 'warning');
    expect(alert.syntax, NamedBlockSyntax.alert);
    expect(alert.children.map((n) => n.type), ['paragraph', 'list']);
    expect(textOf(doc.children.last), 'After');
    expect(
      parser.parse('> [!UNRECOGNIZED]\n> text').children.single,
      isA<BlockQuoteNode>(),
    );
    expect(
      const BlockParser(options: ParserOptions.commonMark())
          .parse('> [!NOTE]\n> text')
          .children
          .single,
      isA<BlockQuoteNode>(),
    );
  });
  test('directive labels, attribute shortcuts and nested fences', () {
    const source =
        '::::note[Title **bold**]{#first #last .red class=green .blue empty title="a } b"}\n'
        'Text\n\n:::tip\n- Nested\n:::\n\nMore\n::::\n\nAfter';
    final doc = parser.parse(source);
    final outer = doc.children.first as NamedBlockNode;
    expect(outer.name, 'note');
    expect(outer.attributes, {
      'id': 'last',
      'class': 'red green blue',
      'empty': '',
      'title': 'a } b',
    });
    expect(outer.closed, true);
    expect(outer.children.map((n) => n.type), [
      'directive_label',
      'paragraph',
      'named_block',
      'paragraph',
    ]);
    expect(textOf(outer.children.first), 'Title **bold**');
    expect((outer.children[2] as NamedBlockNode).closed, true);
    expect(textOf(doc.children.last), 'After');
    expect(outer.children.first.span.slice(source), 'Title **bold**');
  });
  test('leaf directives and invalid punctuation do not consume neighbors', () {
    final doc = parser.parse(
      '::image[Alt [nested]]{src="x.png"}\n\n:::bad trailing\n\n:::bad-\n\nAfter',
    );
    final leaf = doc.children.first as NamedBlockNode;
    expect(leaf.syntax, NamedBlockSyntax.leafDirective);
    expect(leaf.closed, true);
    expect(textOf(leaf.children.single), 'Alt [nested]');
    expect(doc.children.skip(1).every((node) => node is ParagraphNode), true);
  });
  test('an unclosed directive ends with its quote or list parent', () {
    final doc = parser.parse('> :::note\n> content\n\nAfter');
    final quote = doc.children.first as BlockQuoteNode;
    expect((quote.children.single as NamedBlockNode).closed, false);
    expect(textOf(doc.children.last), 'After');
    final longer =
        parser.parse('::::note\ncontent\n:::\nmore').children.single
            as NamedBlockNode;
    expect(longer.closed, false);
    expect(textOf(longer), 'content\n:::\nmore');
  });
  test('code fences protect directive closing markers', () {
    final note =
        parser.parse(':::note\n```\n:::\n```\n:::').children.single
            as NamedBlockNode;
    expect((note.children.single as CodeBlockNode).code, ':::\n');
    expect(note.closed, true);
  });
  test('native HTML blocks preserve supported tags and remove unknown shells', () {
    const source =
        '<div class="box"><h2>Title</h2><custom><b>Bold</b> plain</custom><br><img src="x.png" onerror="bad()"></div>\n\nAfter';
    final doc = parser.parse(source);
    final block = doc.children.first as HtmlBlockNode;
    final div = block.children.single as HtmlElementNode;
    expect(div.tag, 'div');
    expect(
      div.children.map(
        (node) => node is HtmlElementNode ? node.tag : node.type,
      ),
      ['h2', 'b', 'text', 'br', 'img'],
    );
    expect((div.children.last as HtmlElementNode).attributes, {'src': 'x.png'});
    expect(textOf(div), 'TitleBold plain');
    expect(textOf(doc.children.last), 'After');
  });
  test(
    'script, style and iframe bodies disappear including embedded fake tags',
    () {
      final block =
          parser
                  .parse(
                    '<div>before<script><div>bad</div></script>mid<style>x</style><iframe>secret</iframe>after</div>',
                  )
                  .children
                  .single
              as HtmlBlockNode;
      expect(textOf(block), 'beforemidafter');
      expect(
        parser
            .parse('<script>bad\n\nmore</script>\n\nAfter')
            .children
            .map((n) => n.type),
        ['html_block', 'paragraph'],
      );
      final open =
          parser.parse('<div>before<script>secret').children.single
              as HtmlBlockNode;
      expect(textOf(open), 'before');
      expect(open.closed, false);
    },
  );
  test('full HTML documents stay opaque for the app code preview', () {
    const source =
        '<!DOCTYPE html>\n<html><head><style>body{color:red}</style></head>\n<body><p>page</p></body></html>\n\nAfter';
    final block = parser.parse(source).children.first as HtmlBlockNode;
    expect(block.fullDocument, true);
    expect(block.children, isEmpty);
    expect(block.raw, contains('<style>body{color:red}</style>'));
    expect(block.closed, true);
  });
  test('HTML fragments retain CRLF offsets and quote prefix gaps', () {
    const source = '> <div>\r\n> <b>😀</b>\r\n> </div>';
    final quote = parser.parse(source).children.single as BlockQuoteNode;
    final block = quote.children.single as HtmlBlockNode;
    final div = block.children.single as HtmlElementNode;
    final bold = div.children.whereType<HtmlElementNode>().single;
    expect(bold.span.slice(source), '<b>😀</b>');
    expect(bold.children.single.span.slice(source), '😀');
    expect(block.raw, '<div>\n<b>😀</b>\n</div>');
  });
  test('HTML comments are discarded and Markdown-like text stays literal', () {
    final block =
        parser
                .parse(
                  '<div>**literal**<!-- hidden\ncomment --><code>`x`</code></div>',
                )
                .children
                .single
            as HtmlBlockNode;
    expect(textOf(block), '**literal**`x`');
  });
  test('a raw HTML tag name prefix is not a closing tag', () {
    final block =
        parser
                .parse('<div>before<script>hidden</scriptx></div>\n\nsecret')
                .children
                .single
            as HtmlBlockNode;
    expect(block.closed, false);
    expect(textOf(block), 'before');
  });
}
