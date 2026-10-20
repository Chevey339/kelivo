import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

Widget host(
  Widget child, {
  double width = 390,
  double scale = 1,
  bool selectable = false,
  ValueChanged<SelectedContent?>? onSelection,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: selectable
              ? SelectionArea(onSelectionChanged: onSelection, child: child)
              : child,
        ),
      ),
    ),
  ),
);
List<RenderParagraph> paragraphs() {
  final result = <RenderParagraph>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph) result.add(object);
    object.visitChildren(visit);
  }

  for (final view in RendererBinding.instance.renderViews) visit(view);
  return result;
}

RenderParagraph paragraph(String prefix) =>
    paragraphs().firstWhere((p) => p.text.toPlainText().startsWith(prefix));
Offset edge(RenderParagraph p, int offset, {bool end = false}) {
  final box = p
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .single;
  return p.localToGlobal(
    Offset(end ? box.right - 1 : box.left + 1, (box.top + box.bottom) / 2),
  );
}

class _Links implements LinkHandler {
  final opened = <String>[];
  @override
  void open(BuildContext context, LinkNode node) {
    opened.add(node.destination);
  }
}

class _Images implements ImageBuilder {
  final sources = <String>[];
  @override
  Widget build(BuildContext context, ImageNode image, MarkstreamTheme theme) {
    sources.add(image.destination);
    return const SizedBox(
      key: ValueKey('injected-image'),
      width: 48,
      height: 24,
      child: ColoredBox(color: Colors.blue),
    );
  }
}

class _Math implements MathRenderer {
  @override
  Widget build(
    BuildContext context,
    String tex, {
    required TextStyle style,
    required bool displayMode,
  }) => Baseline(
    baseline: 30,
    baselineType: TextBaseline.alphabetic,
    child: SizedBox(
      key: ValueKey('injected-math'),
      width: 900,
      height: 40,
      child: Text(tex, style: style),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe({required this.label});
  final String label;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => Text(widget.label);
}

void main() {
  testWidgets('inline atoms apply inherited text scaling exactly once', (
    tester,
  ) async {
    final widths = <double>[];
    for (final scale in [1.0, 1.3]) {
      await tester.pumpWidget(
        host(
          const MarkstreamView(source: r'Before `code` $x$ after'),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      final code = paragraph('code');
      expect(code.textScaler, TextScaler.noScaling);
      final bounds = MatrixUtils.transformRect(
        code.getTransformTo(null),
        Offset.zero & code.size,
      );
      widths.add(bounds.width);
      expect(paragraph('x').textScaler, TextScaler.noScaling);
    }
    expect(widths.last / widths.first, closeTo(1.3, .001));
  });

  testWidgets('basic AST blocks render with tasks and inherited font scaling', (
    tester,
  ) async {
    const source =
        '# Title\n\nParagraph **strong** and _em_.\n\n> Quote\n\n- [x] Done\n- [ ] Open\n  - Child\n\n3) Three\n4) Four\n\n(x) Radio\n\n---';
    for (final width in [180.0, 390.0, 720.0]) {
      for (final scale in [1.0, 1.3]) {
        await tester.pumpWidget(
          host(
            const MarkstreamView(source: source),
            width: width,
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        final text = paragraphs().map((p) => p.text.toPlainText()).join('|');
        for (final expected in [
          'Title',
          'Paragraph strong and em.',
          'Quote',
          'Done',
          'Open',
          'Child',
          '3.',
          '4.',
          'Radio',
        ]) {
          expect(text, contains(expected));
        }
        expect(find.byType(SelectableRegion), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.checked == true,
          ),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets(
    'default ink inherits its owner and Chinese spacing is unscaled',
    (tester) async {
      await tester.pumpWidget(
        host(
          DefaultTextStyle(
            style: const TextStyle(color: Colors.purple),
            child: const MarkstreamView(source: '中文 text'),
          ),
        ),
      );
      final p = paragraph('中文');
      expect(p.text.style!.color, Colors.purple);
      expect(p.text.style!.letterSpacing, 0);
      expect(p.text.style!.fontSize, 15.5);
    },
  );
  testWidgets('RTL inline atoms retain source order inside lists', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      host(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: MarkstreamView(source: '- אבג `x` דהו'),
        ),
        selectable: true,
        onSelection: (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, '- אבג x דהו');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unbroken inline code remains visible inside a narrow paragraph',
    (tester) async {
      final token = List.filled(200, 'x').join();
      await tester.pumpWidget(
        host(MarkstreamView(source: 'Before `$token` After'), width: 180),
      );
      final code = paragraph(token.substring(0, 20));
      final boxes = code.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: token.length),
      );
      expect(boxes.length, greaterThan(1));
      expect(boxes.every((box) => box.right <= code.size.width + .01), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('soft line breaks follow the selected parsing profile', (
    tester,
  ) async {
    await tester.pumpWidget(host(const MarkstreamView(source: 'one\ntwo')));
    expect(paragraph('one').text.toPlainText(), 'one\ntwo');
    await tester.pumpWidget(
      host(
        const MarkstreamView(
          source: 'one\ntwo',
          options: ParserOptions.commonMark(),
        ),
      ),
    );
    expect(paragraph('one').text.toPlainText(), 'one two');
  });
  testWidgets(
    'links retain heading size and styled text plus code are clickable',
    (tester) async {
      final links = _Links();
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source:
                '# [Big](https://big.test)\n\n[**bold** `code`](https://code.test)',
            linkHandler: links,
          ),
        ),
      );
      final heading = paragraph('Big');
      final styles = <TextStyle?>[];
      heading.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'Big') styles.add(span.style);
        return true;
      });
      expect(styles.single!.fontSize, 15.5 * 1.45);
      await tester.tapAt(edge(heading, 1));
      await tester.tapAt(edge(paragraph('bold'), 1));
      await tester.tap(find.byType(InlineCodeCapsule));
      expect(links.opened, [
        'https://big.test',
        'https://code.test',
        'https://code.test',
      ]);
    },
  );
  testWidgets(
    'a cached link still works after appending and finishing the stream',
    (tester) async {
      final links = _Links();
      var source = '[first](https://first.test)\n\ntail';
      await tester.pumpWidget(
        host(
          MarkstreamView(source: source, streaming: true, linkHandler: links),
        ),
      );
      final first = paragraph('first');
      source += ' appended';
      await tester.pumpWidget(
        host(
          MarkstreamView(source: source, streaming: true, linkHandler: links),
        ),
      );
      expect(paragraph('first'), same(first));
      await tester.tapAt(edge(first, 1));
      await tester.pumpWidget(
        host(MarkstreamView(source: source, linkHandler: links)),
      );
      expect(paragraph('first'), same(first));
      await tester.tapAt(edge(first, 1));
      expect(links.opened, ['https://first.test', 'https://first.test']);
      await tester.pumpWidget(host(MarkstreamView(source: source)));
      await tester.tapAt(edge(paragraph('first'), 1));
      expect(links.opened, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'inline code, math and images join the consumer selection owner',
    (tester) async {
      final images = _Images();
      String? selected;
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: r'Before `run(中😀)` $x+y$ ![alt](image.png) After',
            mathRenderer: _Math(),
            imageBuilder: images,
          ),
          width: 180,
          selectable: true,
          onSelection: (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      expect(images.sources, ['image.png']);
      expect(find.byType(SelectableRegion), findsOneWidget);
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selected, r'Before run(中😀) $x+y$ alt After');
      expect(paragraph('Before').size.height, lessThan(250));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dragging across linked text and code selects without opening links',
    (tester) async {
      final links = _Links();
      String? selected;
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: 'Before [**bold** `code`](https://link.test) After',
            linkHandler: links,
          ),
          selectable: true,
          onSelection: (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      final p = paragraph('Before');
      final gesture = await tester.startGesture(
        edge(p, 0),
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.moveTo(edge(p, p.text.toPlainText().length - 1, end: true));
      await tester.pump();
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      expect(selected, 'Before bold code After');
      expect(links.opened, isEmpty);
    },
  );
  testWidgets(
    'source updates retain prefix widgets and rebuild the active tail',
    (tester) async {
      final built = <String>[];
      final extensions = MarkstreamExtensions(
        nodeBuilders: NodeBuilderRegistry(
          blocks: {
            ParagraphNode: (_, node, rendering) {
              final text = toPlainText(node);
              built.add('$text:${rendering.streaming}');
              return _Probe(label: text);
            },
          },
        ),
      );
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: 'first\n\nlast',
            streaming: true,
            extensions: extensions,
          ),
        ),
      );
      final first = tester.state<_ProbeState>(find.byType(_Probe).first);
      expect(built, ['first:false', 'last:true']);
      built.clear();
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: 'first\n\nlast appended',
            streaming: true,
            extensions: extensions,
          ),
        ),
      );
      expect(built, ['last appended:true']);
      expect(tester.state(find.byType(_Probe).first), same(first));
      built.clear();
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: 'first\n\nlast appended',
            extensions: extensions,
          ),
        ),
      );
      expect(built, ['last appended:false']);
      expect(tester.state(find.byType(_Probe).first), same(first));
    },
  );
  testWidgets(
    'provided snapshots update the tail policy and arbitrary edited blocks',
    (tester) async {
      final document = const MarkdownParser().parse('first\n\nlast');
      final built = <String>[];
      final extensions = MarkstreamExtensions(
        nodeBuilders: NodeBuilderRegistry(
          blocks: {
            ParagraphNode: (_, node, rendering) {
              built.add('${toPlainText(node)}:${rendering.streaming}');
              return Text(toPlainText(node));
            },
          },
        ),
      );
      await tester.pumpWidget(
        host(
          MarkstreamView(
            document: document,
            streaming: true,
            extensions: extensions,
          ),
        ),
      );
      built.clear();
      await tester.pumpWidget(
        host(MarkstreamView(document: document, extensions: extensions)),
      );
      expect(built, ['last:false']);
      final changed = DocumentNode(
        source: 'other\n\nlast',
        children: [
          const MarkdownParser().parse('other').children.single,
          document.children.last,
        ],
      );
      await tester.pumpWidget(
        host(MarkstreamView(document: changed, extensions: extensions)),
      );
      expect(find.text('other'), findsOneWidget);
      expect(find.text('first'), findsNothing);
    },
  );
  testWidgets('provided snapshots regroup when paragraph builders change', (
    tester,
  ) async {
    final document = const MarkdownParser().parse(
      'first\n\nsecond\n\n# boundary\n\nlast',
    );
    final extensions = MarkstreamExtensions(
      nodeBuilders: NodeBuilderRegistry(
        blocks: {ParagraphNode: (_, node, _) => Text(toPlainText(node))},
      ),
    );
    await tester.pumpWidget(host(MarkstreamView(document: document)));
    await tester.pumpWidget(
      host(MarkstreamView(document: document, extensions: extensions)),
    );
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('last'), findsOneWidget);
    await tester.pumpWidget(host(MarkstreamView(document: document)));
    expect(paragraph('second').text.toPlainText(), 'second');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reference definitions create no extra visible block or active tail',
    (tester) async {
      final flags = <bool>[];
      final extensions = MarkstreamExtensions(
        nodeBuilders: NodeBuilderRegistry(
          blocks: {
            ParagraphNode: (_, node, rendering) {
              flags.add(rendering.streaming);
              return Text(toPlainText(node));
            },
          },
        ),
      );
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: '[id]\n\n[id]: /url',
            streaming: true,
            extensions: extensions,
          ),
        ),
      );
      expect(flags, [false]);
      expect(paragraphs(), hasLength(1));
      expect(find.text('id'), findsOneWidget);
    },
  );
}
