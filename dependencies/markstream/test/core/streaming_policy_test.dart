import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

String textOf(MarkdownNode node) =>
    node is TextNode ? node.text : node.children.map(textOf).join();

void main() {
  const parser = MarkdownParser();
  const optimistic = StreamingOptions(optimisticInlines: true);
  test(
    'default policy builds unfinished blocks while keeping inline markers',
    () {
      expect(
        parser
            .parse('**unfinished', streaming: true)
            .children
            .single
            .children
            .single,
        isA<TextNode>(),
      );
      expect(
        parser.parse('```dart\nvalue', streaming: true).children.single,
        isA<CodeBlockNode>().having((n) => n.closed, 'closed', false),
      );
      expect(
        parser.parse(r'$$x+y', streaming: true).children.single,
        isA<MathBlockNode>(),
      );
      expect(
        parser.parse('| A | B |', streaming: true).children.single,
        isA<TableNode>().having((n) => n.provisional, 'provisional', true),
      );
    },
  );
  test(
    'optimistic inline closure never adds characters to source coordinates',
    () {
      final cases = {
        '**strong': 'strong',
        '*emphasis': 'emphasis',
        '***both': 'emphasis',
        '~~old': 'strikethrough',
        '`code': 'code_span',
        r'$x+y': 'math_inline',
      };
      for (final entry in cases.entries) {
        final doc = parser.parse(
          entry.key,
          streaming: true,
          streamingOptions: optimistic,
        );
        expect(doc.source, entry.key);
        final node = doc.children.single.children.single;
        expect(node.type, entry.value);
        expect(node.fields['closed'], false);
        expect(node.span, SourceSpan(0, entry.key.length));
        final pending = <MarkdownNode>[doc];
        while (pending.isNotEmpty) {
          final current = pending.removeLast();
          expect(current.span.end, lessThanOrEqualTo(entry.key.length));
          pending.addAll(current.children);
        }
        expect(
          parser.parse(entry.key).children.single.children.single,
          isA<TextNode>(),
        );
      }
    },
  );
  test('completed paragraphs do not receive optimistic inline closure', () {
    final doc = parser.parse(
      '**literal\n\nlast *open',
      streaming: true,
      streamingOptions: optimistic,
    );
    expect(doc.children.first.children.single, isA<TextNode>());
    expect(
      doc.children.last.children.last,
      isA<EmphasisNode>().having((n) => n.closed, 'closed', false),
    );
  });
  test('pessimistic block policy retains raw delimiters until completion', () {
    const policy = StreamingOptions(optimisticBlocks: false);
    for (final source in [
      '```dart\nx',
      '\$\$\nx',
      '<details>text',
      ':::note\ntext',
    ]) {
      final doc = parser.parse(
        source,
        streaming: true,
        streamingOptions: policy,
      );
      expect(doc.children.single, isA<ParagraphNode>(), reason: source);
      expect(textOf(doc), source);
    }
    expect(
      parser
          .parse('```dart\nx\n```', streaming: true, streamingOptions: policy)
          .children
          .single,
      isA<CodeBlockNode>(),
    );
  });
  test(
    'provisional table headers settle and incomplete rows retain columns',
    () {
      final incremental = IncrementalDocument();
      final header =
          incremental.update('| A | B |\n| --', streaming: true).children.single
              as TableNode;
      expect(header.provisional, true);
      final table =
          incremental
                  .update('| A | B |\n| --- | --- |\n| one |', streaming: true)
                  .children
                  .single
              as TableNode;
      expect(table.provisional, false);
      expect(table.children.last.children, hasLength(2));
      expect(table.children.last.children.last.children, isEmpty);
      expect(table.children.last.children.last.span.isEmpty, true);
      expect(
        incremental.update('| A | B |').children.single,
        isA<ParagraphNode>(),
      );
    },
  );
  test(
    'invalidating a growing fence opener rejoins the preceding paragraph',
    () {
      final incremental = IncrementalDocument();
      incremental.update(
        '😀```- - 😀\r\n```[a]: /x> :note[x]',
        streaming: true,
      );
      const source = '😀```- - 😀\r\n```[a]: /x> :note[x]``';
      final doc = incremental.update(source, streaming: true);
      expect(doc.children, hasLength(1));
      expect(doc.toJson(), parser.parse(source, streaming: true).toJson());
    },
  );
  test('every closure policy matches complete parsing for each prefix', () {
    const source =
        '[ref]\n\n:::note\n[ref]: /x\n\n**open\n:::\n\n| A | B |\n| --- | --- |\n| \$x+y';
    for (final blocks in [true, false]) {
      for (final inlines in [true, false]) {
        final policy = StreamingOptions(
          optimisticBlocks: blocks,
          optimisticInlines: inlines,
        );
        final incremental = IncrementalDocument(streamingOptions: policy);
        for (var i = 0; i <= source.length; i++) {
          final prefix = source.substring(0, i);
          expect(
            incremental.update(prefix, streaming: true).toJson(),
            parser
                .parse(prefix, streaming: true, streamingOptions: policy)
                .toJson(),
            reason: '$blocks/$inlines: $prefix',
          );
        }
        expect(
          incremental.update(source).toJson(),
          parser.parse(source).toJson(),
        );
      }
    }
  });
  test(
    'directive metadata decodes consistently as a streaming opener grows',
    () {
      const source = ':::note{title="A &amp; B"}\nbody';
      final incremental = IncrementalDocument();
      for (var i = 1; i <= source.length; i++)
        incremental.update(source.substring(0, i), streaming: true);
      final node = incremental.document.children.single as NamedBlockNode;
      expect(node.attributes['title'], 'A & B');
      expect(node.span.slice(source), source);
      expect(
        (const MarkdownParser(options: ParserOptions(entities: false))
                    .parse(source)
                    .children
                    .single
                as NamedBlockNode)
            .attributes['title'],
        'A &amp; B',
      );
    },
  );
}
