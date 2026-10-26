import 'package:Kelivo/features/chat/widgets/tool_detail_text_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:markstream/markstream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(String label, String text) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 400,
        child: CustomScrollView(
          slivers: [ToolDetailTextSection(label: label, text: text)],
        ),
      ),
    ),
  );

  test('range boundaries preserve line endings and surrogate pairs', () {
    for (final source in [
      '',
      for (final lines in [39, 40, 41, 120, 121])
        for (final ending in ['\n', '\r\n'])
          List.filled(lines, 'line😀').join(ending) + ending,
      '${'x' * 3999}😀${'y' * 9000}',
      '${'x' * 3999}\r\n${'y' * 9000}',
    ]) {
      final chunks = ToolDetailTextSection.chunkRangesOf(
        source,
      ).map((range) => range.textInside(source)).toList();
      expect(chunks.join(), source);
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(4000));
        expect('\n'.allMatches(chunk).length, lessThanOrEqualTo(40));
        expect(chunk.isNotEmpty, isTrue);
        final first = chunk.codeUnitAt(0);
        final last = chunk.codeUnitAt(chunk.length - 1);
        expect(first >= 0xDC00 && first <= 0xDFFF, isFalse);
        expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
        expect(chunk.endsWith('\r'), isFalse);
      }
    }
  });

  testWidgets('giant single lines are bounded and refresh on source change', (
    tester,
  ) async {
    final source = 'a' * 500000;
    await tester.pumpWidget(harness('Result', source));
    final visible = tester.widgetList<Text>(find.byType(Text));
    expect(visible.length, lessThan(10));
    expect(visible.every((text) => (text.data?.length ?? 0) <= 4000), isTrue);
    await tester.pumpWidget(harness('Updated label', source));
    expect(find.text('Updated label'), findsOneWidget);
    await tester.pumpWidget(harness('Result', 'replacement'));
    expect(find.text('replacement'), findsOneWidget);
    expect(find.byKey(ToolDetailTextSection.lazyListKey), findsNothing);
  });

  testWidgets(
    'malformed tool text is safe to render without changing the source',
    (tester) async {
      for (final source in ['bad\uD800value\uDC00😀', '${'x' * 9000}\uD800']) {
        await tester.pumpWidget(harness('Result', source));
        expect(
          tester
              .widget<ToolDetailTextSection>(find.byType(ToolDetailTextSection))
              .text,
          source,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(harness('Result', 'bad\uD800value\uDC00😀'));
      expect(find.text('bad�value�😀'), findsOneWidget);
    },
  );

  testWidgets('small result renders as a single eager text block', (
    tester,
  ) async {
    await tester.pumpWidget(harness('Result', 'short result'));

    expect(find.text('Result'), findsOneWidget);
    expect(find.text('short result'), findsOneWidget);
    expect(find.byKey(ToolDetailTextSection.lazyListKey), findsNothing);
  });

  test('character budgets do not split combining or joined emoji clusters', () {
    for (final cluster in ['e\u0301', '👨‍👩‍👧‍👦', '👍🏽', '🇨🇳']) {
      final source = '${'x' * 3999}$cluster${'y' * 9000}';
      final ranges = ToolDetailTextSection.chunkRangesOf(source);
      final chunks = ranges.map((range) => range.textInside(source)).toList();
      expect(chunks.join(), source);
      expect(chunks.first, 'x' * 3999);
      for (final range in ranges) {
        expect(CharacterRange.at(source, range.end).isEmpty, isTrue);
      }
    }
    final longCluster = 'e${'\u0301' * 4500}';
    final source = '${longCluster}tail';
    final ranges = ToolDetailTextSection.chunkRangesOf(source);
    expect(ranges.first.textInside(source), longCluster);
    expect(ranges.map((range) => range.textInside(source)).join(), source);
  });

  testWidgets('line chunks do not add visual blank lines', (tester) async {
    final source = List.generate(161, (i) => 'row-$i').join('\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ToolDetailTextSection(
                label: 'Result',
                text: source,
                textStyle: const TextStyle(
                  fontFamily: 'Ahem',
                  fontSize: 12,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey('tool-detail-text-chunk-0'));
    final second = find.byKey(const ValueKey('tool-detail-text-chunk-1'));
    expect(tester.widget<Text>(first).data!.endsWith('\n'), isFalse);
    expect(tester.getSize(first).height, 40 * 12);
    expect(tester.getTopLeft(second).dy - tester.getTopLeft(first).dy, 40 * 12);
  });

  testWidgets(
    'select all copies an entire virtualized single line after scrolling',
    (tester) async {
      final source = '${'0123456789' * 5000}END';
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: SelectionArea(
                child: CustomScrollView(
                  controller: scroll,
                  slivers: [
                    ToolDetailTextSection(label: 'Result', text: source),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tool-detail-text-chunk-12')),
        findsNothing,
      );
      expect(
        tester
            .widgetList<SourceTextSelectionFragment>(
              find.byType(SourceTextSelectionFragment, skipOffstage: false),
            )
            .length,
        lessThan(5),
      );
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      final owner = tester
          .widget<SourceTextSelectionFragment>(
            find.byType(SourceTextSelectionFragment).first,
          )
          .owner;
      expect(owner.getSelectedContent()!.plainText, source);
      for (final fraction in [0.1, 0.25, 0.5, 0.75, 0.95, 0.4, 0.0]) {
        scroll.jumpTo(scroll.position.maxScrollExtent * fraction);
        await tester.pumpAndSettle();
        expect(owner.getSelectedContent()!.plainText, source);
        expect(
          tester
              .widgetList<SourceTextSelectionFragment>(
                find.byType(SourceTextSelectionFragment, skipOffstage: false),
              )
              .length,
          lessThan(5),
        );
      }
      region.contextMenuButtonItems
          .singleWhere((item) => item.type == ContextMenuButtonType.copy)
          .onPressed!();
      await tester.pumpAndSettle();
      expect(copied, 'Result$source');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'partial selection preserves source separators and anchors while scrolling',
    (tester) async {
      final source = List.generate(
        400,
        (i) => 'row-${i.toString().padLeft(3, '0')}',
      ).join('\r\n');
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: CustomScrollView(
                controller: scroll,
                slivers: [
                  ToolDetailTextSection(
                    label: 'Result',
                    text: source,
                    textStyle: const TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Offset caret(int chunk, int offset) {
        final rich = find.descendant(
          of: find.byKey(ValueKey('tool-detail-text-chunk-$chunk')),
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(rich);
        return paragraph.localToGlobal(
          paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero) +
              const Offset(0, 6),
        );
      }

      final owner = tester
          .widget<SourceTextSelectionFragment>(
            find.byType(SourceTextSelectionFragment).first,
          )
          .owner;
      const start = 39 * 9 + 2;
      const end = 40 * 9 + 4;
      for (final reversed in [false, true]) {
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        owner.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forStart(
            globalPosition: reversed ? caret(1, 4) : caret(0, start),
          ),
        );
        owner.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forEnd(
            globalPosition: reversed ? caret(0, start) : caret(1, 4),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          owner.getSelectedContent()!.plainText,
          source.substring(start, end),
        );
        scroll.jumpTo(1200);
        await tester.pumpAndSettle();
        expect(
          owner.getSelectedContent()!.plainText,
          source.substring(start, end),
        );
        // Extend while the fixed anchor lives in an offscreen kept-alive chunk.
        const newEnd = 100 * 9 + 4;
        owner.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forEnd(globalPosition: caret(2, 20 * 9 + 4)),
        );
        await tester.pumpAndSettle();
        expect(
          owner.getSelectedContent()!.plainText,
          source.substring(reversed ? end : start, newEnd),
        );
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        // Now move the other edge with the end anchor below the viewport.
        const newStart = 10 * 9 + 1;
        owner.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forStart(globalPosition: caret(0, newStart)),
        );
        await tester.pumpAndSettle();
        expect(
          owner.getSelectedContent()!.plainText,
          source.substring(newStart, newEnd),
        );
        owner.dispatchSelectionEvent(const ClearSelectionEvent());
        await tester.pumpAndSettle();
        expect(owner.getSelectedContent(), isNull);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('select all survives a fully offscreen text section', (
    tester,
  ) async {
    final source = List.generate(200, (i) => 'line $i').join('\n');
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                ToolDetailTextSection(label: 'Result', text: source),
                const SliverToBoxAdapter(child: SizedBox(height: 6000)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final owner = tester
        .widget<SourceTextSelectionFragment>(
          find.byType(SourceTextSelectionFragment).first,
        )
        .owner;
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    // SliverList retains its final laid-out child to establish scroll extent,
    // but previously visited selected rows must not remain in the keep-alive bucket.
    final retained = find.byType(
      SourceTextSelectionFragment,
      skipOffstage: false,
    );
    expect(retained, findsOneWidget);
    RenderObject? row = retained.evaluate().single.renderObject;
    while (row != null && row.parentData is! SliverMultiBoxAdaptorParentData) {
      row = row.parent;
    }
    expect(
      (row!.parentData! as SliverMultiBoxAdaptorParentData).keepAlive,
      isFalse,
    );
    expect(owner.getSelectedContent()?.plainText, source);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byType(SourceTextSelectionFragment), findsWidgets);
    expect(owner.getSelectedContent()?.plainText, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi-page partial selection retains only its source anchors', (
    tester,
  ) async {
    final source = List.generate(
      2000,
      (i) => 'row-${i.toString().padLeft(4, '0')}',
    ).join('\r\n');
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: SelectionArea(
              child: CustomScrollView(
                controller: scroll,
                slivers: [
                  ToolDetailTextSection(
                    label: 'Result',
                    text: source,
                    textStyle: const TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final owner = tester
        .widget<SourceTextSelectionFragment>(
          find.byType(SourceTextSelectionFragment).first,
        )
        .owner;
    Future<void> showRow(int row) async {
      scroll.jumpTo(
        (row * 12.0 - 180).clamp(0, scroll.position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
    }

    Offset at(int row, int column) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(ValueKey('tool-detail-text-chunk-${row ~/ 40}')),
          matching: find.byType(RichText),
        ),
      );
      return paragraph.localToGlobal(
        paragraph.getOffsetForCaret(
              TextPosition(offset: row % 40 * 10 + column),
              Rect.zero,
            ) +
            const Offset(0, 6),
      );
    }

    for (final reverse in [false, true]) {
      final fixedRow = reverse ? 1900 : 10;
      final fixedColumn = reverse ? 5 : 1;
      final fixed = fixedRow * 10 + fixedColumn;
      await showRow(fixedRow);
      owner.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forStart(
          globalPosition: at(fixedRow, fixedColumn),
        ),
      );
      owner.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(
          globalPosition: at(fixedRow, reverse ? 1 : 5),
        ),
      );
      await tester.pumpAndSettle();
      for (final row
          in reverse
              ? [1800, 1400, 1000, 640, 320, 160, 80]
              : [80, 160, 320, 640, 1000, 1400, 1800]) {
        await showRow(row);
        final column = reverse ? 1 : 5;
        owner.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forEnd(globalPosition: at(row, column)),
        );
        await tester.pumpAndSettle();
        final moving = row * 10 + column;
        expect(
          owner.getSelectedContent()?.plainText,
          source.substring(reverse ? moving : fixed, reverse ? fixed : moving),
        );
        expect(
          find
              .byType(SourceTextSelectionFragment, skipOffstage: false)
              .evaluate()
              .length,
          lessThan(6),
        );
      }
      owner.dispatchSelectionEvent(const ClearSelectionEvent());
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout changes end offscreen selection and allow reselection', (
    tester,
  ) async {
    final source = List.generate(
      400,
      (i) => 'row-${i.toString().padLeft(3, '0')}',
    ).join('\r\n');
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
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
            height: 600,
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SelectionArea(
                child: CustomScrollView(
                  controller: scroll,
                  slivers: [
                    ToolDetailTextSection(
                      label: 'Result',
                      text: source,
                      textStyle: TextStyle(
                        fontFamily: 'Ahem',
                        fontSize: fontSize,
                        height: 1,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final owner = tester
        .widget<SourceTextSelectionFragment>(
          find.byType(SourceTextSelectionFragment).first,
        )
        .owner;
    Future<void> selectAndScroll(double lineHeight) async {
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const ValueKey('tool-detail-text-chunk-0')),
          matching: find.byType(RichText),
        ),
      );
      Offset at(int offset) => paragraph.localToGlobal(
        paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero) +
            Offset(0, lineHeight / 2),
      );
      owner.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forStart(globalPosition: at(1)),
      );
      owner.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(globalPosition: at(5)),
      );
      await tester.pumpAndSettle();
      expect(owner.getSelectedContent()?.plainText, source.substring(1, 5));
      scroll.jumpTo(1400);
      await tester.pumpAndSettle();
      expect(owner.getSelectedContent()?.plainText, source.substring(1, 5));
    }

    await selectAndScroll(12);
    await tester.pumpWidget(host(color: Colors.blue));
    await tester.pumpAndSettle();
    expect(owner.getSelectedContent()?.plainText, source.substring(1, 5));
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
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(owner.getSelectedContent()?.plainText, source);
    await tester.pumpWidget(host(width: 600));
    await tester.pumpAndSettle();
    expect(owner.getSelectedContent(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('constraint-only relayout can update selection callback state', (
    tester,
  ) async {
    final width = ValueNotifier(800.0);
    addTearDown(width.dispose);
    final source = 'word ' * 3000;
    late StateSetter updateHost;
    String? selected;
    final view = SelectionArea(
      onSelectionChanged: (content) =>
          updateHost(() => selected = content?.plainText),
      child: CustomScrollView(
        slivers: [ToolDetailTextSection(label: 'Result', text: source)],
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
    expect(selected, 'Result$source');
    width.value = 500;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(selected, isNull);
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, 'Result$source');
  });

  for (final selectAll in [false, true]) {
    testWidgets('selected lazy text can become eager (all: $selectAll)', (
      tester,
    ) async {
      final long = 'word ' * 3000;
      String? selected;
      Widget host(String text) => MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (content) => selected = content?.plainText,
            child: CustomScrollView(
              slivers: [ToolDetailTextSection(label: 'Result', text: text)],
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(long));
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(ToolDetailTextSection));
      final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      if (selectAll) {
        region.selectAll(SelectionChangedCause.keyboard);
      } else {
        final fragment = find.byType(SourceTextSelectionFragment).first;
        final owner = tester
            .widget<SourceTextSelectionFragment>(fragment)
            .owner;
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: fragment, matching: find.byType(RichText)).first,
        );
        Offset at(int offset) => paragraph.localToGlobal(
          paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero) +
              const Offset(0, 6),
        );
        owner.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forStart(globalPosition: at(1)),
        );
        owner.dispatchSelectionEvent(
          SelectionEdgeUpdateEvent.forEnd(globalPosition: at(4)),
        );
      }
      await tester.pumpAndSettle();
      await tester.pumpWidget(host('short result'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ToolDetailTextSection)), same(state));
      expect(find.byKey(ToolDetailTextSection.lazyListKey), findsNothing);
      expect(tester.takeException(), isNull);
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selected, 'Resultshort result');
      await tester.pumpWidget(host(long));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ToolDetailTextSection)), same(state));
      region.selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      final owner = tester
          .widget<SourceTextSelectionFragment>(
            find.byType(SourceTextSelectionFragment).first,
          )
          .owner;
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent / 2);
      await tester.pumpAndSettle();
      expect(owner.getSelectedContent()?.plainText, long);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('huge result is chunked and only builds visible chunks', (
    tester,
  ) async {
    final text = List<String>.generate(
      10000,
      (index) => 'result-$index',
    ).join('\n');

    await tester.pumpWidget(harness('Result', text));

    expect(find.byKey(ToolDetailTextSection.lazyListKey), findsOneWidget);
    expect(find.textContaining('result-0'), findsOneWidget);
    expect(find.textContaining('result-9999'), findsNothing);

    final builtChunks = tester.widgetList<Text>(find.byType(Text)).length;
    expect(builtChunks, lessThan(20));
  });

  testWidgets('chunk boundaries preserve the original text', (tester) async {
    final text = List<String>.generate(
      500,
      (index) => 'line-$index',
    ).join('\n');

    expect(
      ToolDetailTextSection.chunkRangesOf(
        text,
      ).map((range) => range.textInside(text)).join(),
      text,
    );
    expect(ToolDetailTextSection.shouldChunk(text), isTrue);
    expect(ToolDetailTextSection.shouldChunk('a\nb\nc'), isFalse);
  });

  testWidgets('chunked content can still be scrolled to the end', (
    tester,
  ) async {
    final text = List<String>.generate(400, (index) => 'row-$index').join('\n');

    await tester.pumpWidget(harness('Result', text));
    expect(find.byKey(ToolDetailTextSection.lazyListKey), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tool-detail-text-chunk-9')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('row-399'), findsOneWidget);
  });
}
