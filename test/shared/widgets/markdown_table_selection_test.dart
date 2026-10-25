import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';

Widget _harness(Widget child, ValueChanged<SelectedContent?> onSelection) =>
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SelectionArea(
            onSelectionChanged: onSelection,
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    );

SelectableRegionState _region(WidgetTester tester) =>
    tester.state<SelectableRegionState>(find.byType(SelectableRegion));

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    markdownParagraph(tester, text);

Offset _edge(RenderParagraph paragraph, int offset, {required bool trailing}) {
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .single;
  return paragraph.localToGlobal(
    Offset(trailing ? box.right - 1 : box.left + 1, (box.top + box.bottom) / 2),
  );
}

Future<void> _drag(
  WidgetTester tester,
  Offset start,
  Offset end, {
  bool touch = false,
}) async {
  await tester.pump(const Duration(milliseconds: 500));
  final gesture = await tester.startGesture(
    start,
    kind: touch ? ui.PointerDeviceKind.touch : ui.PointerDeviceKind.mouse,
  );
  await tester.pump(touch ? const Duration(milliseconds: 600) : Duration.zero);
  await gesture.moveTo(end);
  await tester.pump();
  await gesture.up();
  await gesture.removePointer();
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 720.0]) {
    testWidgets('table cells join surrounding selection at width $width', (
      tester,
    ) async {
      const source =
          'Before\n\n| A | | C |\n| --- | --- | --- |\n| | B | |\n| D | | E |\n\nAfter';
      const expected = 'Before\n\nA\t\tC\n\tB\t\nD\t\tE\n\nAfter';
      String? selected;
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: width,
            child: const MarkdownWithCodeHighlight(
              text: source,
              useBlockRendering: true,
            ),
          ),
          (value) => selected = value?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectableRegion), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      _region(tester).selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selected, expected);
      final first = _paragraph(tester, 'Before'),
          last = _paragraph(tester, 'After');
      final start = _edge(first, 0, trailing: false),
          end = _edge(last, 4, trailing: true);
      for (final reverse in [false, true]) {
        _region(tester).clearSelection();
        await tester.pump();
        await _drag(tester, reverse ? end : start, reverse ? start : end);
        expect(selected, expected, reason: 'reverse=$reverse');
      }
    }, variant: TargetPlatformVariant.desktop());
  }

  testWidgets('mobile selection includes table cells without toolbar text', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _harness(
        const SizedBox(
          width: 390,
          child: MarkdownWithCodeHighlight(
            text:
                'Before\n\n| Name | Value |\n| --- | --- |\n| Alpha | 42 |\n\nAfter',
            useBlockRendering: true,
          ),
        ),
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    await _drag(
      tester,
      _edge(_paragraph(tester, 'Before'), 0, trailing: false),
      _edge(_paragraph(tester, 'After'), 4, trailing: true),
      touch: true,
    );
    expect(selected, 'Before\n\nName\tValue\nAlpha\t42\n\nAfter');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('TSV keeps boundary empty cells and removes soft wrap markers', (
    tester,
  ) async {
    const token =
        'abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';
    String? selected;
    await tester.pumpWidget(
      _harness(
        const SizedBox(
          width: 390,
          child: MarkdownWithCodeHighlight(
            text: '| | Header | |\n| --- | --- | --- |\n| | $token | |',
          ),
        ),
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    _region(tester).selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, '\tHeader\t\n\t$token\t');
  });
  testWidgets('partial row selections keep selected cells in source order', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _harness(
        const SizedBox(
          width: 720,
          child: MarkdownWithCodeHighlight(
            text: '| Left | Right |\n| --- | --- |\n| AlphaBeta | GammaDelta |',
          ),
        ),
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    final start = _edge(_paragraph(tester, 'AlphaBeta'), 5, trailing: false);
    final end = _edge(_paragraph(tester, 'GammaDelta'), 4, trailing: true);
    for (final reverse in [false, true]) {
      _region(tester).clearSelection();
      await tester.pump();
      await _drag(tester, reverse ? end : start, reverse ? start : end);
      expect(selected, 'Beta\tGamma', reason: 'reverse=$reverse');
    }
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('mobile wide table retains horizontal scrolling', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _harness(
        const SizedBox(
          width: 390,
          child: MarkdownWithCodeHighlight(
            text:
                '| A | B | C | D | E | F |\n| --- | --- | --- | --- | --- | --- |\n| 1 | 2 | 3 | 4 | 5 | 6 |',
          ),
        ),
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    final body = find.byKey(const ValueKey('markstream-table-scroll'));
    final state = tester.state<ScrollableState>(
      find.descendant(of: body, matching: find.byType(Scrollable)).first,
    );
    expect(state.position.maxScrollExtent, greaterThan(0));
    await tester.drag(body, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(state.position.pixels, greaterThan(0));
    expect(selected, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('TSV quotes multiline cells and literal quotes', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _harness(
        const SizedBox(
          width: 390,
          child: MarkdownWithCodeHighlight(
            text:
                '| Name | Value |\n| --- | --- |\n| first<br>second | say "hello" |',
          ),
        ),
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    _region(tester).selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, 'Name\tValue\n"first\nsecond"\t"say ""hello"""');
  });
  testWidgets('wrapped math cell keeps source order and empty TSV edge columns', (
    tester,
  ) async {
    final prefix = List.filled(9, 'before ').join();
    final suffix = List.filled(9, ' after').join();
    String? selected;
    await tester.pumpWidget(
      _harness(
        SizedBox(
          width: 390,
          child: MarkdownWithCodeHighlight(
            text:
                '| | Text | |\n| --- | --- | --- |\n| | $prefix\$a+b\$$suffix | |',
          ),
        ),
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    _region(tester).selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, '\tText\t\n\t$prefix\$a+b\$$suffix\t');
  });

  for (final blocks in [false, true]) {
    testWidgets(
      'nested math table supports cross-document drag, blocks=$blocks',
      (tester) async {
        String? selected;
        await tester.pumpWidget(
          _harness(
            SizedBox(
              width: 390,
              child: MarkdownWithCodeHighlight(
                text:
                    'Before\n\n| A | B |\n| --- | --- |\n| alpha \$x\$ omega | other |\n\nAfter',
                useBlockRendering: blocks,
              ),
            ),
            (value) => selected = value?.plainText,
          ),
        );
        await tester.pumpAndSettle();
        final before = _paragraph(tester, 'Before'),
            after = _paragraph(tester, 'After');
        final start = _edge(
          before,
          before.text.toPlainText().indexOf('Before'),
          trailing: false,
        );
        final end = _edge(
          after,
          after.text.toPlainText().indexOf('After') + 4,
          trailing: true,
        );
        for (final reverse in [false, true]) {
          _region(tester).clearSelection();
          await tester.pump();
          await _drag(tester, reverse ? end : start, reverse ? start : end);
          expect(
            selected,
            'Before\n\nA\tB\nalpha \$x\$ omega\tother\n\nAfter',
            reason: 'reverse=$reverse',
          );
        }
      },
    );
  }
}
