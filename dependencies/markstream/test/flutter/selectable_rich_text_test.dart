import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

RenderParagraph paragraph() => find
    .byType(RichText)
    .evaluate()
    .map((e) => e.renderObject)
    .whereType<RenderParagraph>()
    .firstWhere((p) => p.text.toPlainText().contains('\uFFFC'));
Offset edge(RenderParagraph p, int offset, bool end) {
  final b = p
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .single;
  final right = end == (b.direction == TextDirection.ltr);
  return p.localToGlobal(
    Offset(right ? b.right - 1 : b.left + 1, (b.top + b.bottom) / 2),
  );
}

Future<void> drag(WidgetTester tester, Offset start, Offset end) async {
  await tester.pump(const Duration(milliseconds: 600));
  final g = await tester.startGesture(start, kind: ui.PointerDeviceKind.mouse);
  await g.moveTo(end);
  await tester.pump();
  await g.up();
  await g.removePointer();
  await tester.pumpAndSettle();
}

Widget atom(String source) => SelectableSpanAdapter(
  selectedText: source,
  child: const SizedBox(width: 22, height: 20),
);
Widget harness(
  Text text,
  SelectionListenerNotifier notifier,
  ValueChanged<SelectedContent?> onSelection,
) => MaterialApp(
  home: Scaffold(
    body: SelectionArea(
      onSelectionChanged: onSelection,
      child: StableSelectionContainer(
        child: SelectionListener(
          selectionNotifier: notifier,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 350, child: buildSelectableText(text)),
          ),
        ),
      ),
    ),
  ),
);
void main() {
  testWidgets(
    'partial source offsets before, across and after an inline atom',
    (tester) async {
      final listener = SelectionListenerNotifier();
      addTearDown(listener.dispose);
      String? selected;
      await tester.pumpWidget(
        harness(
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Before '),
                WidgetSpan(child: atom(r'$中😀$')),
                const TextSpan(text: ' middle '),
                WidgetSpan(child: atom(r'$b$')),
                const TextSpan(text: ' After'),
              ],
            ),
          ),
          listener,
          (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      final p = paragraph();
      // Plain rendered offsets use one U+FFFC per atom; reported offsets count LaTeX UTF-16.
      for (final c in [
        (0, 5, 0, 6, 'Before'),
        (9, 14, 13, 19, 'middle'),
        (18, 22, 24, 29, 'After'),
        (2, 20, 2, 27, r'fore $中😀$ middle $b$ Aft'),
      ]) {
        for (final reverse in [false, true]) {
          tester
              .state<SelectableRegionState>(find.byType(SelectableRegion))
              .clearSelection();
          await tester.pump();
          final a = edge(p, c.$1, false), b = edge(p, c.$2, true);
          await drag(tester, reverse ? b : a, reverse ? a : b);
          expect(selected, c.$5, reason: '$c reverse=$reverse');
          final range = listener.selection.range!;
          expect((
            range.startOffset,
            range.endOffset,
          ), reverse ? (c.$4, c.$3) : (c.$3, c.$4));
        }
      }
    },
  );
  testWidgets('RTL text and atoms copy in source order', (tester) async {
    final listener = SelectionListenerNotifier();
    addTearDown(listener.dispose);
    String? selected;
    await tester.pumpWidget(
      harness(
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'אבג '),
              WidgetSpan(child: atom(r'$x$')),
              const TextSpan(text: ' דהו'),
            ],
          ),
          textDirection: TextDirection.rtl,
        ),
        listener,
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, r'אבג $x$ דהו');
    expect(listener.selection.range!.endOffset, 11);
    final p = paragraph();
    for (final reverse in [false, true]) {
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .clearSelection();
      await tester.pump();
      final start = edge(p, 0, false),
          end = edge(p, p.text.toPlainText().length - 1, true);
      await drag(tester, reverse ? end : start, reverse ? start : end);
      expect(selected, r'אבג $x$ דהו', reason: 'reverse=$reverse');
    }
  });
  testWidgets('paragraph selection includes atoms only in that paragraph', (
    tester,
  ) async {
    final listener = SelectionListenerNotifier();
    addTearDown(listener.dispose);
    String? selected;
    await tester.pumpWidget(
      harness(
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'First '),
              WidgetSpan(child: atom(r'$x$')),
              const TextSpan(text: ' end\nSecond '),
              WidgetSpan(child: atom(r'$y$')),
              const TextSpan(text: ' final'),
            ],
          ),
        ),
        listener,
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    final point = edge(paragraph(), 2, false);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(point, kind: ui.PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(selected, 'First \$x\$ end\n');
    expect(
      (
        listener.selection.range!.startOffset,
        listener.selection.range!.endOffset,
      ),
      (0, 14),
    );
  });
  testWidgets(
    'triple click drag expands and shrinks across inline paragraphs',
    (tester) async {
      final listener = SelectionListenerNotifier();
      addTearDown(listener.dispose);
      String? selected;
      await tester.pumpWidget(
        harness(
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'First '),
                WidgetSpan(child: atom(r'$x$')),
                const TextSpan(text: ' end\nSecond '),
                WidgetSpan(child: atom(r'$y$')),
                const TextSpan(text: ' final\nThird '),
                WidgetSpan(child: atom(r'$z$')),
                const TextSpan(text: ' last'),
              ],
            ),
          ),
          listener,
          (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      final p = paragraph();
      final first = edge(p, 2, false);
      final g = await tester.startGesture(
        first,
        kind: ui.PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 2; i++) {
        await g.up();
        await tester.pump(const Duration(milliseconds: 100));
        await g.down(first);
      }
      await tester.pumpAndSettle();
      expect(selected, 'First \$x\$ end\n');
      await g.moveTo(
        edge(p, p.text.toPlainText().indexOf('Second') + 2, false),
      );
      await tester.pumpAndSettle();
      expect(selected, 'First \$x\$ end\nSecond \$y\$ final\n');
      await g.moveTo(edge(p, p.text.toPlainText().indexOf('Third') + 2, false));
      await tester.pumpAndSettle();
      expect(selected, 'First \$x\$ end\nSecond \$y\$ final\nThird \$z\$ last');
      await g.moveTo(first);
      await tester.pumpAndSettle();
      expect(selected, 'First \$x\$ end\n');
      await g.up();
      await g.removePointer();
    },
    variant: TargetPlatformVariant.desktop(),
  );
  testWidgets('reverse paragraph drag keeps both boundary paragraphs', (
    tester,
  ) async {
    final listener = SelectionListenerNotifier();
    addTearDown(listener.dispose);
    String? selected;
    await tester.pumpWidget(
      harness(
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'First '),
              WidgetSpan(child: atom(r'$x$')),
              const TextSpan(text: ' end\nSecond '),
              WidgetSpan(child: atom(r'$y$')),
              const TextSpan(text: ' final\nThird '),
              WidgetSpan(child: atom(r'$z$')),
              const TextSpan(text: ' last'),
            ],
          ),
        ),
        listener,
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    final p = paragraph(),
        third = edge(
          paragraph(),
          paragraph().text.toPlainText().indexOf('Third') + 2,
          false,
        );
    final g = await tester.startGesture(
      third,
      kind: ui.PointerDeviceKind.mouse,
    );
    for (var i = 0; i < 2; i++) {
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
      await g.down(third);
    }
    await tester.pumpAndSettle();
    expect(selected, r'Third $z$ last');
    await g.moveTo(edge(p, p.text.toPlainText().indexOf('Second') + 2, false));
    await tester.pumpAndSettle();
    expect(selected, 'Second \$y\$ final\nThird \$z\$ last');
    await g.moveTo(edge(p, 2, false));
    await tester.pumpAndSettle();
    expect(selected, 'First \$x\$ end\nSecond \$y\$ final\nThird \$z\$ last');
    await g.moveTo(third);
    await tester.pumpAndSettle();
    expect(selected, r'Third $z$ last');
    await g.up();
    await g.removePointer();
  }, variant: TargetPlatformVariant.desktop());
  testWidgets('accessibility spacing and paragraph metrics match Text.rich', (
    tester,
  ) async {
    Text text() => Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Before ',
            style: TextStyle(height: 1.5, letterSpacing: 0.5),
          ),
          WidgetSpan(child: atom(r'$x$')),
          const TextSpan(text: ' after\nsecond line'),
        ],
      ),
      style: const TextStyle(fontSize: 18, height: 1.8),
      textScaler: TextScaler.linear(1.3),
      strutStyle: const StrutStyle(fontSize: 18, height: 2),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              boldText: true,
              lineHeightScaleFactorOverride: 2.1,
              letterSpacingOverride: 2,
              wordSpacingOverride: 4,
            ),
            child: SelectionArea(
              child: Column(
                children: [
                  SizedBox(width: 350, child: text()),
                  SizedBox(width: 350, child: buildSelectableText(text())),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p = find
        .byType(RichText)
        .evaluate()
        .map((e) => e.renderObject)
        .whereType<RenderParagraph>()
        .where((p) => p.text.toPlainText().startsWith('Before'))
        .toList();
    expect(p, hasLength(2));
    expect(p[0].size, p[1].size);
    expect(p[0].text.style, p[1].text.style);
    expect(
      p[0].getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
      ),
      p[1].getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 5),
      ),
    );
  });
  testWidgets('a selected inline atom can be removed with its parent', (
    tester,
  ) async {
    final listener = SelectionListenerNotifier();
    addTearDown(listener.dispose);
    await tester.pumpWidget(
      harness(
        Text.rich(TextSpan(children: [WidgetSpan(child: atom(r'$x$'))])),
        listener,
        (_) {},
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyed rich text also renders outside a selection owner', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: buildSelectableText(
          Text.rich(
            key: key,
            TextSpan(
              children: [
                const TextSpan(text: 'Before '),
                WidgetSpan(child: atom(r'$x$')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(key), findsOneWidget);
  });
  testWidgets('newline boundaries next to atoms copy exactly during a drag', (
    tester,
  ) async {
    final listener = SelectionListenerNotifier();
    addTearDown(listener.dispose);
    String? selected;
    await tester.pumpWidget(
      harness(
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Before\n'),
              WidgetSpan(child: atom(r'$x$')),
              const TextSpan(text: '\nAfter'),
            ],
          ),
        ),
        listener,
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    final p = paragraph();
    await drag(
      tester,
      edge(p, 0, false),
      edge(p, p.text.toPlainText().length - 1, true),
    );
    expect(selected, 'Before\n\$x\$\nAfter');
  });

  testWidgets('inline selectable churn keeps an active drag valid', (
    tester,
  ) async {
    final count = ValueNotifier(24);
    addTearDown(count.dispose);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: (value) => selected = value?.plainText,
            child: StableSelectionContainer(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 350,
                  child: ValueListenableBuilder<int>(
                    valueListenable: count,
                    builder: (context, value, _) => buildSelectableText(
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          children: [
                            const TextSpan(text: 'Before '),
                            for (var i = 0; i < value; i++) ...[
                              TextSpan(text: 'word$i '),
                              if (i.isEven)
                                WidgetSpan(
                                  child: SelectableSpanAdapter(
                                    selectedText: 'source$i',
                                    child: const SizedBox(
                                      width: 18,
                                      height: 18,
                                    ),
                                  ),
                                ),
                            ],
                            const TextSpan(text: ' After'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    RenderParagraph paragraph() => find
        .byType(RichText)
        .evaluate()
        .map((e) => e.renderObject)
        .whereType<RenderParagraph>()
        .firstWhere((p) => p.text.toPlainText().startsWith('Before'));
    Offset edge(RenderParagraph p, int i, bool end) {
      final box = p
          .getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          )
          .single;
      return p.localToGlobal(
        Offset(end ? box.right - 1 : box.left + 1, (box.top + box.bottom) / 2),
      );
    }

    var p = paragraph();
    final gesture = await tester.startGesture(
      edge(p, 0, false),
      kind: ui.PointerDeviceKind.mouse,
    );
    await gesture.moveTo(edge(p, p.text.toPlainText().length - 1, true));
    await tester.pumpAndSettle();
    for (final value in [25, 23, 1, 0, 30]) {
      count.value = value;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'count=$value');
      p = paragraph();
      await gesture.moveTo(edge(p, p.text.toPlainText().length - 1, true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'continue count=$value');
      final expected =
          'Before ${List.generate(value, (i) => 'word$i ${i.isEven ? 'source$i' : ''}').join()} After';
      expect(selected, expected, reason: 'count=$value');
    }
    await gesture.up();
    await gesture.removePointer();
    await tester.pumpAndSettle();
  });
}
