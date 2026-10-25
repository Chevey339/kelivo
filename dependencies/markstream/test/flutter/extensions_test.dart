import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

void main() {
  final theme = MarkstreamTheme.fromColorScheme(
    ColorScheme.fromSeed(seedColor: Colors.blue),
  );
  final document = const MarkdownParser().parse(
    '```DaRt title\ncode\n```\n\n:::NoTe\nbody\n:::\n\n:Badge[label]',
  );
  MarkstreamRenderContext rendering() => MarkstreamRenderContext(
    document: document,
    theme: theme,
    streaming: true,
    buildBlock: (node) => Text(node.type),
    buildInline: (node, style) => TextSpan(text: node.type, style: style),
  );

  testWidgets('named and language builders take priority over type builders', (
    tester,
  ) async {
    final extensions = MarkstreamExtensions(
      nodeBuilders: NodeBuilderRegistry(
        blocks: {
          CodeBlockNode: (_, _, _) => const Text('generic code'),
          NamedBlockNode: (_, _, _) => const Text('generic named block'),
        },
        inlines: {
          NamedInlineNode: (_, node, _) => RenderedInline(
            span: const TextSpan(text: 'generic inline'),
            segments: [
              TextSegment(
                text: 'generic inline',
                sourceSpan: node.span,
                node: node,
              ),
            ],
          ),
        },
      ),
      codeBlockBuilders: {' DART ': (_, _, _) => const Text('dart custom')},
      directiveBuilders: {
        'NOTE': (_, node, rendering) =>
            rendering.buildBlock(node.children.single as BlockNode),
      },
      namedInlineBuilders: {
        'BADGE': (_, node, _) => RenderedInline(
          span: const TextSpan(text: 'badge custom'),
          segments: [
            TextSegment(
              text: 'badge custom',
              sourceSpan: node.span,
              node: node,
            ),
          ],
        ),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              extensions.buildBlock(
                context,
                document.children[0],
                rendering(),
              )!,
              extensions.buildBlock(
                context,
                document.children[1],
                rendering(),
              )!,
              Text.rich(
                extensions
                    .buildInline(
                      context,
                      document.children[2].children.single as InlineNode,
                      rendering(),
                    )!
                    .span,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('dart custom'), findsOneWidget);
    expect(find.text('paragraph'), findsOneWidget);
    expect(find.text('badge custom'), findsOneWidget);
    expect(find.text('generic code'), findsNothing);
  });
  testWidgets('unregistered names use a registered type or remain unhandled', (
    tester,
  ) async {
    final extensions = MarkstreamExtensions(
      nodeBuilders: NodeBuilderRegistry(
        blocks: {CodeBlockNode: (_, _, _) => const Text('generic code')},
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(
              extensions.buildBlock(context, document.children[1], rendering()),
              isNull,
            );
            expect(
              const MarkstreamExtensions.empty().buildInline(
                context,
                document.children[2].children.single as InlineNode,
                rendering(),
              ),
              isNull,
            );
            return extensions.buildBlock(
              context,
              document.children.first,
              rendering(),
            )!;
          },
        ),
      ),
    );
    expect(find.text('generic code'), findsOneWidget);
  });
  test('registrations are immutable snapshots of caller collections', () {
    final blocks = <Type, BlockNodeBuilder>{
      CodeBlockNode: (_, _, _) => const SizedBox(),
    };
    final languages = <String, CodeBlockBuilder>{
      ' DART ': (_, _, _) => const SizedBox(),
    };
    final extensions = MarkstreamExtensions(
      nodeBuilders: NodeBuilderRegistry(blocks: blocks),
      codeBlockBuilders: languages,
    );
    blocks.clear();
    languages.clear();
    expect(extensions.nodeBuilders.blocks, hasLength(1));
    expect(extensions.codeBlockBuilders.keys, ['dart']);
    expect(() => extensions.codeBlockBuilders.clear(), throwsUnsupportedError);
    expect(
      () => extensions.nodeBuilders.blocks.clear(),
      throwsUnsupportedError,
    );
    expect(() => extensions.inlineSyntaxes.clear(), throwsUnsupportedError);
  });
}
