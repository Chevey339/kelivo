import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

class _Texts extends RecursiveAstVisitor {
  final values = <String>[];
  @override
  void visitText(TextNode node) => values.add(node.text);
}

void main() {
  test('source intervals use original UTF-16 offsets', () {
    const source = '前😀e\u0301\r\n后';
    const emoji = SourceSpan(1, 3);
    expect(emoji.length, 2);
    expect(emoji.slice(source), '😀');
    expect(emoji.contains(1), isTrue);
    expect(emoji.contains(3), isFalse);
    expect(emoji.overlaps(const SourceSpan(2, 4)), isTrue);
    expect(emoji.overlaps(const SourceSpan(3, 4)), isFalse);
    expect(emoji.overlaps(const SourceSpan(2, 2)), isFalse);
    expect(const SourceSpan(2, 2).overlaps(emoji), isFalse);
    expect(emoji.shift(2), const SourceSpan(3, 5));
    expect(emoji.hashCode, const SourceSpan(1, 3).hashCode);
    expect(() => SourceSpan(-1, 0), throwsAssertionError);
    expect(() => SourceSpan(2, 1), throwsAssertionError);
  });

  test(
    'document snapshots are immutable and visitors preserve source order',
    () {
      const source = 'first\n\nsecond';
      final inline = <InlineNode>[
        const TextNode(span: SourceSpan(0, 5), text: 'first'),
      ];
      final blocks = <BlockNode>[
        ParagraphNode(span: const SourceSpan(0, 5), children: inline),
        ParagraphNode(
          span: const SourceSpan(7, 13),
          children: [const TextNode(span: SourceSpan(7, 13), text: 'second')],
        ),
      ];
      final document = DocumentNode(source: source, children: blocks);
      inline.clear();
      blocks.clear();
      final visitor = _Texts();
      document.accept(visitor);
      expect(visitor.values, ['first', 'second']);
      expect(document.span, const SourceSpan(0, 13));
      expect(() => document.children.clear(), throwsUnsupportedError);
      expect(
        () => document.children.first.children.clear(),
        throwsUnsupportedError,
      );
      expect(document.toJson(), {
        'type': 'document',
        'span': {'start': 0, 'end': 13},
        'source': source,
        'children': [
          {
            'type': 'paragraph',
            'span': {'start': 0, 'end': 5},
            'children': [
              {
                'type': 'text',
                'span': {'start': 0, 'end': 5},
                'text': 'first',
              },
            ],
          },
          {
            'type': 'paragraph',
            'span': {'start': 7, 'end': 13},
            'children': [
              {
                'type': 'text',
                'span': {'start': 7, 'end': 13},
                'text': 'second',
              },
            ],
          },
        ],
      });
    },
  );
}
