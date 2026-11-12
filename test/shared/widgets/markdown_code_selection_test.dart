import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:markstream/markstream.dart';
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
  testWidgets('code joins forward and reverse selection with its whitespace', (
    tester,
  ) async {
    const source = 'Before\n\n```dart\n  alpha();\n\n    beta();\n```\n\nAfter';
    const expected = 'Before\n\n  alpha();\n\n    beta();\n\nAfter';
    String? selected;
    await tester.pumpWidget(
      _harness(
        const SizedBox(
          width: 390,
          child: MarkdownWithCodeHighlight(
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
    final start = _edge(_paragraph(tester, 'Before'), 0, trailing: false);
    final end = _edge(_paragraph(tester, 'After'), 4, trailing: true);
    for (final reverse in [false, true]) {
      _region(tester).clearSelection();
      await tester.pump();
      await _drag(tester, reverse ? end : start, reverse ? start : end);
      expect(selected, expected, reason: 'reverse=$reverse');
    }
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('touch selection crosses a code block', (tester) async {
    const source = 'Before\n\n```text\n  alpha\n    beta\n```\n\nAfter';
    String? selected;
    await tester.pumpWidget(
      _harness(
        const SizedBox(
          width: 390,
          child: MarkdownWithCodeHighlight(
            text: source,
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
    expect(selected, 'Before\n\n  alpha\n    beta\n\nAfter');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('long code shares its parent selection without extra regions', (
    tester,
  ) async {
    final code = List.generate(130, (i) => '  value$i = "中😀 $i";').join('\n');
    String? selected;
    await tester.pumpWidget(
      _harness(
        SingleChildScrollView(
          child: SizedBox(
            width: 390,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Before'),
                MarkstreamCodeContent(
                  node: CodeBlockNode(
                    span: SourceSpan(0, code.length),
                    children: [
                      TextNode(span: SourceSpan(0, code.length), text: code),
                    ],
                  ),
                  theme: MarkstreamTheme.fromColorScheme(
                    ThemeData.light().colorScheme,
                  ),
                  highlight: false,
                ),
                const Text('After'),
              ],
            ),
          ),
        ),
        (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableRegion), findsOneWidget);
    _region(tester).selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, 'Before${code}After');
  });
}
