import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

void main() {
  for (final selectAll in [false, true]) {
    testWidgets(
      'code selection can be disabled without replacing its state (all: $selectAll)',
      (tester) async {
        String? selected;
        final code = List.generate(1201, (i) => 'line $i').join('\n');
        final node =
            MarkdownParser().parse('```text\n$code\n```').children.single
                as CodeBlockNode;
        final view = MarkstreamCodeContent(
          key: GlobalKey(),
          node: node,
          theme: MarkstreamTheme.fromColorScheme(
            ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          highlight: false,
        );
        Widget host(bool enabled) => MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              onSelectionChanged: (content) => selected = content?.plainText,
              child: enabled
                  ? Padding(
                      key: const ValueKey('enabled'),
                      padding: EdgeInsets.zero,
                      child: view,
                    )
                  : SelectionContainer.disabled(
                      key: const ValueKey('disabled'),
                      child: view,
                    ),
            ),
          ),
        );
        await tester.pumpWidget(host(true));
        await tester.pumpAndSettle();
        final state = tester.state(find.byType(MarkstreamCodeContent));
        if (selectAll) {
          tester
              .state<SelectableRegionState>(find.byType(SelectableRegion))
              .selectAll(SelectionChangedCause.keyboard);
        } else {
          final fragment = find.byType(SourceTextSelectionFragment).first;
          final owner = tester
              .widget<SourceTextSelectionFragment>(fragment)
              .owner;
          final paragraph = tester.renderObject<RenderParagraph>(
            find
                .descendant(of: fragment, matching: find.byType(RichText))
                .first,
          );
          Offset at(int offset) => paragraph.localToGlobal(
            paragraph.getOffsetForCaret(
                  TextPosition(offset: offset),
                  Rect.zero,
                ) +
                const Offset(0, 4),
          );
          owner.dispatchSelectionEvent(
            SelectionEdgeUpdateEvent.forStart(globalPosition: at(1)),
          );
          owner.dispatchSelectionEvent(
            SelectionEdgeUpdateEvent.forEnd(globalPosition: at(4)),
          );
          expect(owner.getSelectedContent()?.plainText, code.substring(1, 4));
        }
        await tester.pumpAndSettle();
        await tester.pumpWidget(host(false));
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(MarkstreamCodeContent)), same(state));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(host(true));
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(MarkstreamCodeContent)), same(state));
        tester
            .state<SelectableRegionState>(find.byType(SelectableRegion))
            .selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        expect(selected, code);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent / 2);
        await tester.pumpAndSettle();
        final owner = tester
            .widget<SourceTextSelectionFragment>(
              find.byType(SourceTextSelectionFragment).first,
            )
            .owner;
        expect(owner.getSelectedContent()?.plainText, code);
        for (final fraction in [0.1, 0.4, 0.7, 0.95, 0.0]) {
          scrollable.position.jumpTo(
            scrollable.position.maxScrollExtent * fraction,
          );
          await tester.pumpAndSettle();
          expect(owner.getSelectedContent()?.plainText, code);
          expect(
            find
                .byType(SourceTextSelectionFragment, skipOffstage: false)
                .evaluate()
                .length,
            lessThan(4),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('virtual code can be reselected after typography reflow', (
    tester,
  ) async {
    final code = List.generate(
      1201,
      (i) => 'line ${i.toString().padLeft(4, '0')}',
    ).join('\n');
    final node =
        MarkdownParser().parse('```text\n$code\n```').children.single
            as CodeBlockNode;
    final theme = MarkstreamTheme.fromColorScheme(
      ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    Widget host({
      double fontSize = 12,
      double width = 800,
      double scale = 1,
      Color color = Colors.black,
    }) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SelectionArea(
                child: MarkstreamCodeContent(
                  node: node,
                  theme: theme.copyWith(
                    code: theme.code.copyWith(
                      text: TextStyle(
                        fontFamily: 'Ahem',
                        fontSize: fontSize,
                        height: 1,
                        color: color,
                      ),
                    ),
                  ),
                  highlight: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final owner = tester
        .widget<SourceTextSelectionFragment>(
          find.byType(SourceTextSelectionFragment).first,
        )
        .owner;
    Future<void> selectAndScroll(double lineHeight) async {
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(
        find.byKey(const ValueKey('markstream-virtualized-code')),
      );
      final paragraph = find
          .descendant(
            of: find.byType(SourceTextSelectionFragment),
            matching: find.byType(RichText),
          )
          .evaluate()
          .map((element) => element.renderObject! as RenderParagraph)
          .firstWhere((paragraph) {
            final top = paragraph.localToGlobal(Offset.zero).dy;
            return top < viewport.bottom &&
                top + paragraph.size.height > viewport.top;
          });
      // SliverList can preserve a visible line during reflow by correcting
      // its scroll offset. Select a line inside the viewport, not an offscreen
      // first line of a still-partially-visible 200-line fragment.
      final viewportTop = viewport.topLeft;
      final localTop = paragraph
          .globalToLocal(viewportTop)
          .dy
          .clamp(0.0, double.infinity);
      final lineStart = paragraph
          .getPositionForOffset(Offset(0, localTop + lineHeight / 2))
          .offset;
      Offset at(int offset) => paragraph.localToGlobal(
        paragraph.getOffsetForCaret(
              TextPosition(offset: lineStart + offset),
              Rect.zero,
            ) +
            Offset(0, lineHeight / 2),
      );
      owner.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forStart(globalPosition: at(1)),
      );
      owner.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(globalPosition: at(5)),
      );
      await tester.pumpAndSettle();
      expect(owner.getSelectedContent()?.plainText, code.substring(1, 5));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent / 2);
      await tester.pumpAndSettle();
      expect(owner.getSelectedContent()?.plainText, code.substring(1, 5));
    }

    await selectAndScroll(12);
    await tester.pumpWidget(host(color: Colors.blue));
    await tester.pumpAndSettle();
    expect(owner.getSelectedContent()?.plainText, code.substring(1, 5));
    for (final layout in [
      (16.0, 800.0, 1.0),
      (16.0, 500.0, 1.0),
      (16.0, 500.0, 1.5),
    ]) {
      await tester.pumpWidget(
        host(fontSize: layout.$1, width: layout.$2, scale: layout.$3),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(owner.getSelectedContent(), isNull);
      await selectAndScroll(layout.$1 * layout.$3);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('constraint-only code relayout can update callback state', (
    tester,
  ) async {
    final width = ValueNotifier(800.0);
    addTearDown(width.dispose);
    final code = List.generate(1201, (i) => 'line $i').join('\n');
    final node =
        MarkdownParser().parse('```text\n$code\n```').children.single
            as CodeBlockNode;
    late StateSetter updateHost;
    String? selected;
    final view = SelectionArea(
      onSelectionChanged: (content) =>
          updateHost(() => selected = content?.plainText),
      child: MarkstreamCodeContent(
        node: node,
        theme: MarkstreamTheme.fromColorScheme(
          ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        highlight: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return Column(
              children: [
                Text(selected == null ? 'No selection' : 'Selected'),
                ValueListenableBuilder<double>(
                  valueListenable: width,
                  child: view,
                  builder: (context, value, child) =>
                      SizedBox(width: value, height: 400, child: child),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, code);
    width.value = 500;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(selected, isNull);
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, code);
  });
}
