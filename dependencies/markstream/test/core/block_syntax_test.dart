import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

class _NoteSyntax extends BlockSyntax {
  const _NoteSyntax();
  @override
  BlockNode? parse(BlockSyntaxContext context) {
    final block = context.block;
    if (block is! ParagraphNode || !toPlainText(block).startsWith('NOTE:'))
      return null;
    return NamedBlockNode(
      span: block.span,
      name: 'note',
      syntax: NamedBlockSyntax.containerDirective,
      children: [block],
    );
  }
}

class _CallbackSyntax extends BlockSyntax {
  const _CallbackSyntax(this.callback);
  final BlockNode? Function(BlockSyntaxContext) callback;
  @override
  BlockNode? parse(BlockSyntaxContext context) => callback(context);
}

void main() {
  const parser = MarkdownParser(blockSyntaxes: [_NoteSyntax()]);
  test('leaf syntax runs after inline parsing inside nested containers', () {
    final doc = parser.parse('> NOTE: **bold** [id]\n\n[id]: /url');
    final note = doc.children.first.children.single as NamedBlockNode;
    expect(note.name, 'note');
    final paragraph = note.children.single as ParagraphNode;
    expect(paragraph.children.whereType<EmphasisNode>(), hasLength(1));
    expect(paragraph.children.whereType<LinkNode>().single.destination, '/url');
    expect(note.span, paragraph.span);
    expect(doc.references['id']!.destination, '/url');
  });
  test(
    'syntax ordering stops at the first match and preserves source context',
    () {
      final calls = <int>[];
      final parser = MarkdownParser(
        blockSyntaxes: [
          _CallbackSyntax((context) {
            calls.add(1);
            expect(context.sourceText, 'Text');
            expect(context.streaming, isTrue);
            return null;
          }),
          _CallbackSyntax((context) {
            calls.add(2);
            return context.block;
          }),
          _CallbackSyntax((context) {
            calls.add(3);
            return context.block;
          }),
        ],
      );
      parser.parse('Text', streaming: true);
      expect(calls, [1, 2]);
    },
  );
  test(
    'syntax cannot change scanned boundaries or introduce invalid children',
    () {
      final invalidBoundary = MarkdownParser(
        blockSyntaxes: [
          _CallbackSyntax(
            (context) => ParagraphNode(
              span: SourceSpan(0, context.source.length + 1),
              children: const [],
            ),
          ),
        ],
      );
      expect(() => invalidBoundary.parse('text'), throwsArgumentError);
      final invalidChild = MarkdownParser(
        blockSyntaxes: [
          _CallbackSyntax(
            (context) => ParagraphNode(
              span: context.block.span,
              children: [
                TextNode(
                  span: SourceSpan(0, context.source.length + 1),
                  text: 'bad',
                ),
              ],
            ),
          ),
        ],
      );
      expect(() => invalidChild.parse('text'), throwsArgumentError);
    },
  );
  test('reference metadata is never offered to rendering block syntaxes', () {
    var calls = 0;
    final doc = MarkdownParser(
      blockSyntaxes: [
        _CallbackSyntax((context) {
          calls++;
          return context.block;
        }),
      ],
    ).parse('[id]: /url');
    expect(calls, 0);
    expect(doc.references['id']!.destination, '/url');
  });
  test('incremental extensions match full parsing at every prefix', () {
    const source = 'Before\n\nNOTE: **new text**\n\n> NOTE: nested\n\nAfter';
    final stream = IncrementalDocument(parser: parser);
    for (var i = 0; i <= source.length; i++) {
      final prefix = source.substring(0, i);
      expect(
        stream.update(prefix, streaming: true).toJson(),
        parser.parse(prefix, streaming: true).toJson(),
        reason: 'prefix $i',
      );
    }
    final before = stream.document.children.first;
    stream.update('$source appended', streaming: true);
    expect(stream.document.children.first, same(before));
  });
}
