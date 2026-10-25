import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  const parser = MarkdownParser();
  test('highlight retains nested syntax, source ranges and copy formats', () {
    const source = '前==**bold** [link](https://example.com) `code`==后';
    final doc = parser.parse(source);
    final mark = doc.children.single.children.whereType<HighlightNode>().single;
    expect(
      mark.span.slice(source),
      '==**bold** [link](https://example.com) `code`==',
    );
    expect(mark.children.whereType<EmphasisNode>().single.strong, isTrue);
    expect(
      mark.children.whereType<LinkNode>().single.destination,
      'https://example.com',
    );
    expect(toPlainText(doc), '前bold link code后');
    expect(toHtml(doc), contains('<mark><strong>bold</strong>'));
    expect(toHtml(parser.parse(toMarkdown(doc))), toHtml(doc));
    final index = TextIndex.fromDocument(doc);
    expect(index.text, contains('bold link code'));
  });

  test('highlight excludes escapes, code, math, URLs and invalid runs', () {
    for (final source in [
      r'\==plain==',
      '`==code==`',
      r'$a==b==c$',
      '```\n==code==\n```',
      '[link](https://example.com/==path==)',
      '=single=',
      '===triple===',
      '====four====',
      '== open ==',
    ]) {
      expect(
        toHtml(parser.parse(source)),
        isNot(contains('<mark>')),
        reason: source,
      );
    }
    expect(
      toHtml(parser.parse('[==link==](https://example.com)')),
      contains('<mark>link</mark>'),
    );
    expect(
      toHtml(parser.parse('==https://example.com==')),
      contains('<mark><a'),
    );
    for (final options in [
      const ParserOptions.commonMark(),
      const ParserOptions.gfm(),
      const ParserOptions(highlight: false),
    ]) {
      expect(
        toHtml(MarkdownParser(options: options).parse('==plain==')),
        isNot(contains('<mark>')),
      );
    }
  });

  test('highlight and custom alert titles survive every streaming prefix', () {
    const source =
        '> [!note] A &amp; B\n> ==**bold** [link](url)==\n>\n> - item\n\nAfter';
    final incremental = IncrementalDocument();
    for (var i = 0; i <= source.length; i++) {
      final prefix = source.substring(0, i);
      expect(
        incremental.update(prefix, streaming: true).toJson(),
        parser.parse(prefix, streaming: true).toJson(),
        reason: 'prefix $i',
      );
    }
    final doc = incremental.update(source);
    final alert = doc.children.first as NamedBlockNode;
    expect(alert.name, 'note');
    expect(alert.attributes['title'], 'A & B');
    expect(toMarkdown(doc), startsWith('> [!NOTE] A &amp; B\n'));
    expect(toHtml(parser.parse(toMarkdown(doc))), toHtml(doc));
    expect(toPlainText(alert), 'bold link\n\n- item');
  });

  test(
    'unfinished highlighting stays literal by default and can be optimistic',
    () {
      expect(toPlainText(parser.parse('==open', streaming: true)), '==open');
      final doc = parser.parse(
        '==open',
        streaming: true,
        streamingOptions: const StreamingOptions(optimisticInlines: true),
      );
      final mark = doc.children.single.children.single as HighlightNode;
      expect(mark.closed, isFalse);
      expect(mark.span.slice(doc.source), '==open');
    },
  );
}
