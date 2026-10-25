import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:markstream/src/flutter/render/source_highlights.dart';

import 'markstream_view_test.dart' show host, paragraphs, paragraph, edge;
import 'rich_blocks_test.dart' show selectAll;

const _color = Color(0x66ffbb22);

String markedText() {
  final output = StringBuffer();
  void visit(InlineSpan span, TextStyle parent) {
    final style = parent.merge(span.style);
    if (span is TextSpan) {
      if ((style.backgroundColor ?? style.background?.color)?.toARGB32() ==
          _color.toARGB32())
        output.write(span.text ?? '');
      for (final child in span.children ?? <InlineSpan>[]) visit(child, style);
    }
  }

  for (final p in paragraphs()) visit(p.text, const TextStyle());
  return output.toString();
}

class _Links implements LinkHandler {
  final urls = <String>[];
  @override
  void open(BuildContext context, LinkNode node) => urls.add(node.destination);
}

class _Highlighter implements CodeHighlighter {
  int calls = 0;
  @override
  TextSpan highlight(
    String source, {
    required String language,
    required TextStyle style,
    required Brightness brightness,
  }) {
    calls++;
    return TextSpan(
      style: style,
      children: [
        TextSpan(
          text: source,
          style: const TextStyle(color: Colors.blue),
        ),
      ],
    );
  }
}

void main() {
  test(
    'source intervals merge and map nonlinear entities without changing text',
    () {
      final highlights = SourceHighlights(const [
        SourceSpan(9, 10),
        SourceSpan(0, 2),
        SourceSpan(1, 4),
        SourceSpan(9, 9),
      ], _color);
      expect(highlights.ranges, const [SourceSpan(0, 4), SourceSpan(9, 10)]);
      expect(
        highlights.textRanges(const [
          TextSegment(text: 'abc', sourceSpan: SourceSpan(1, 4)),
          TextSegment(text: '&', sourceSpan: SourceSpan(5, 10)),
        ]),
        const [SourceSpan(0, 3), SourceSpan(3, 4)],
      );
      final span = paintTextHighlights(const TextSpan(text: 'A😀B'), const [
        SourceSpan(2, 3),
      ], _color);
      expect(span.toPlainText(), 'A😀B');
      final parts = span.children!.cast<TextSpan>();
      expect(
        parts
            .singleWhere(
              (part) =>
                  (part.style?.backgroundColor ?? part.style?.background?.color)
                      ?.toARGB32() ==
                  _color.toARGB32(),
            )
            .text,
        '😀',
      );
      expect(SourceHighlights(const [], _color), SourceHighlights.empty);
    },
  );

  test('paint retains semantics overrides and replaces an existing background paint', () {
    final original = TextSpan(
      text: 'word',
      semanticsLabel: 'spoken',
      style: TextStyle(background: Paint()..color = Colors.blue),
    );
    final marked = paintTextHighlights(original, const [
      SourceSpan(1, 2),
    ], _color);
    expect(marked.toPlainText(), 'spoken');
    expect(marked.toPlainText(includeSemanticsLabels: false), 'word');
    expect(marked.style!.background!.color.toARGB32(), _color.toARGB32());
  });

  test(
    'custom mixed spans highlight atomically and retain placeholder text',
    () {
      const source = TextSpan(
        text: 'A',
        children: [
          WidgetSpan(child: Text('atomic')),
          TextSpan(text: 'B'),
        ],
      );
      final highlights = SourceHighlights(const [SourceSpan(8, 9)], _color);
      final marked = highlights.customInline(
        source,
        const SourceSpan(0, 9),
        const [TextSegment(text: 'AatomicB', sourceSpan: SourceSpan(0, 9))],
      ) as TextSpan;
      expect(marked.toPlainText(), source.toPlainText());
      expect(marked.style!.background!.color.toARGB32(), _color.toARGB32());
      final atom = marked.children!.whereType<WidgetSpan>().single;
      expect(atom.child, isA<DecoratedBox>());
      expect(
        identical(
          SourceHighlights.empty.customInline(
            source,
            const SourceSpan(0, 9),
            const [],
          ),
          source,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'ranges highlight decoded entities, escaped punctuation and link text',
    (tester) async {
      const source = r'One &amp; \* [Link](https://example.com) 😀 end';
      final links = _Links();
      final ranges = [
        SourceSpan(source.indexOf('amp'), source.indexOf('amp') + 1),
        SourceSpan(source.indexOf(r'\*'), source.indexOf(r'\*') + 1),
        SourceSpan(source.indexOf('Link') + 1, source.indexOf('Link') + 3),
        SourceSpan(source.indexOf('😀') + 1, source.indexOf('😀') + 2),
      ];
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: source,
            highlightRanges: ranges,
            highlightColor: _color,
            linkHandler: links,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(markedText(), '&*in😀');
      final p = paragraph('One');
      await tester.tapAt(edge(p, p.text.toPlainText().indexOf('Link') + 1));
      expect(links.urls, ['https://example.com']);
    },
  );

  testWidgets(
    'range-only changes repaint cached prefixes without reparsing or changing copy',
    (tester) async {
      const source = '**First** paragraph.\n\nSecond paragraph.\n\nThird.';
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      Future<void> pump(List<SourceSpan> ranges, {bool select = true}) async {
        await tester.pumpWidget(
          host(
            MarkstreamView(
              source: source,
              selectionController: controller,
              highlightRanges: ranges,
              highlightColor: _color,
            ),
            selectable: true,
          ),
        );
        await tester.pumpAndSettle();
        if (select) {
          selectAll(tester);
          await tester.pumpAndSettle();
        }
      }

      await pump(const [SourceSpan(2, 7)]);
      final size = tester.getSize(find.byType(MarkstreamView));
      final document = controller.selections.single.document;
      final markdown = controller.selectedMarkdown;
      expect(markedText(), 'First');
      final start = source.indexOf('Second');
      await pump([SourceSpan(start, start + 6)], select: false);
      expect(markedText(), 'Second');
      expect(tester.getSize(find.byType(MarkstreamView)), size);
      expect(
        identical(controller.selections.single.document, document),
        isTrue,
      );
      expect(controller.selectedMarkdown, markdown);
      await pump(const [], select: false);
      expect(markedText(), isEmpty);
      expect(
        identical(controller.selections.single.document, document),
        isTrue,
      );
    },
  );

  testWidgets('atomic code, math and images paint without changing selection', (
    tester,
  ) async {
    const source =
        r'Before `code` $x+1$ ![Alt](image.png)'
        '\n\n'
        r'$$'
        '\nx^2\n'
        r'$$';
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: source,
          selectionController: controller,
          highlightRanges: [SourceSpan(0, source.length)],
          highlightColor: _color,
        ),
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.position == DecorationPosition.foreground &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == _color,
      ),
      findsNWidgets(4),
    );
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(controller.selectedMarkdown, contains('`code`'));
    expect(controller.selectedMarkdown, contains(r'$x+1$'));
    expect(controller.selectedMarkdown, contains('![Alt](<image.png>)'));
    expect(
      controller.selectedMarkdown,
      contains(
        r'$$'
        '\nx^2\n'
        r'$$',
      ),
    );
  });

  testWidgets(
    'code ranges use original offsets and retain cached syntax colors',
    (tester) async {
      const source = '> ```dart\n> int value = 1;\n> ```';
      final highlighter = _Highlighter();
      final start = source.indexOf('value');
      Future<void> pump(List<SourceSpan> ranges) async {
        await tester.pumpWidget(
          host(
            MarkstreamView(
              source: source,
              codeHighlighter: highlighter,
              highlightRanges: ranges,
              highlightColor: _color,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump([SourceSpan(start, start + 5)]);
      expect(markedText(), 'value');
      final calls = highlighter.calls;
      await pump([SourceSpan(start + 8, start + 9)]);
      expect(markedText(), '1');
      expect(highlighter.calls, calls);
      expect(paragraph('int').text.toPlainText(), 'int value = 1;');
    },
  );

  testWidgets(
    'streaming appends, truncation and completion keep ranges source based',
    (tester) async {
      final text = ValueNotifier('Start **bold');
      addTearDown(text.dispose);
      await tester.pumpWidget(
        host(
          ValueListenableBuilder<String>(
            valueListenable: text,
            builder: (_, source, _) => MarkstreamView(
              source: source,
              streaming: true,
              highlightRanges: const [SourceSpan(8, 12)],
              highlightColor: _color,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(markedText(), 'bold');
      text.value = 'Start **bold** tail';
      await tester.pumpAndSettle();
      expect(markedText(), 'bold');
      text.value = 'Start';
      await tester.pumpAndSettle();
      expect(markedText(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('virtual code chunks map highlights after their source offset', (
    tester,
  ) async {
    final code = List.generate(
      1105,
      (i) => 'line ${i.toString().padLeft(4, '0')}',
    ).join('\n');
    final source = '```\n$code\n```';
    final start = source.indexOf('line 1050');
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: source,
          highlightRanges: [SourceSpan(start, start + 9)],
          highlightColor: _color,
        ),
        width: 390,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('markstream-virtualized-code')),
      findsOneWidget,
    );
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(markedText(), 'line 1050');
    expect(tester.takeException(), isNull);
  });

  testWidgets('table cells and HTML styles share source range paint', (
    tester,
  ) async {
    const source = '| H |\n| - |\n| <b>Cell</b> &amp; |';
    final start = source.indexOf('Cell');
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: source,
          highlightRanges: [SourceSpan(start, start + 4)],
          highlightColor: _color,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(markedText(), 'Cell');
    expect(tester.takeException(), isNull);
  });
}
