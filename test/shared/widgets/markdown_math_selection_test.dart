import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:markstream/markstream.dart' show SelectableSpanAdapter;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';
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
  for (final source in [r'Before $a+b$ After', r'Before \(a+b\) After']) {
    testWidgets('inline formula joins forward and reverse selection: $source', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _harness(
          MarkdownWithCodeHighlight(text: source),
          (content) => selected = content?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      _region(tester).selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selected, source);
      final paragraph = _paragraph(tester, 'Before');
      final length = paragraph.text.toPlainText().length;
      final start = _edge(paragraph, 0, trailing: false);
      final end = _edge(paragraph, length - 1, trailing: true);
      for (final reverse in [false, true]) {
        _region(tester).clearSelection();
        await tester.pump();
        await _drag(tester, reverse ? end : start, reverse ? start : end);
        expect(selected, source, reason: 'reverse=$reverse');
      }
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.desktop());
  }

  testWidgets('copy shortcut includes selected formula source', (tester) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      _harness(
        const MarkdownWithCodeHighlight(text: r'Before $a+b$ After'),
        (_) {},
      ),
    );
    await tester.pumpAndSettle();
    final paragraph = _paragraph(tester, 'Before');
    await _drag(
      tester,
      _edge(paragraph, 0, trailing: false),
      _edge(paragraph, paragraph.text.toPlainText().length - 1, trailing: true),
    );
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(copied, r'Before $a+b$ After');
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('block formula joins the surrounding text as LaTeX', (
    tester,
  ) async {
    const source = 'Before\n\n\$\$\na+b\n\$\$\n\nAfter';
    String? selected;
    await tester.pumpWidget(
      _harness(
        const MarkdownWithCodeHighlight(text: source, useBlockRendering: true),
        (content) => selected = content?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    _region(tester).selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selected, source);
    final start = _edge(_paragraph(tester, 'Before'), 0, trailing: false);
    final end = _edge(_paragraph(tester, 'After'), 4, trailing: true);
    for (final reverse in [false, true]) {
      _region(tester).clearSelection();
      await tester.pump();
      await _drag(tester, reverse ? end : start, reverse ? start : end);
      expect(selected, source, reason: 'reverse=$reverse');
    }
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('touch selection can extend across an inline formula', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _harness(
        const MarkdownWithCodeHighlight(text: r'Before $a+b$ After'),
        (content) => selected = content?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    final paragraph = _paragraph(tester, 'Before');
    await _drag(
      tester,
      _edge(paragraph, 0, trailing: false),
      _edge(paragraph, paragraph.text.toPlainText().length - 1, trailing: true),
      touch: true,
    );
    expect(selected, r'Before $a+b$ After');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'adapter reports UTF-16 source offsets and updates reused source',
    (tester) async {
      const first = r'$\text{😀}$';
      const next = r'$x^2+y^2$';
      final source = ValueNotifier(first);
      final listener = SelectionListenerNotifier();
      addTearDown(source.dispose);
      addTearDown(listener.dispose);
      String? selected;
      await tester.pumpWidget(
        _harness(
          SelectionListener(
            selectionNotifier: listener,
            child: ValueListenableBuilder<String>(
              valueListenable: source,
              builder: (_, text, _) => Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'A'),
                    WidgetSpan(
                      child: SelectableSpanAdapter(
                        selectedText: text,
                        child: const SizedBox(width: 60, height: 24),
                      ),
                    ),
                    const TextSpan(text: 'Z'),
                  ],
                ),
              ),
            ),
          ),
          (content) => selected = content?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      for (final value in [first, next]) {
        source.value = value;
        await tester.pumpAndSettle();
        _region(tester).selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        expect(selected, 'A${value}Z');
        expect(listener.selection.range?.startOffset, 0);
        expect(listener.selection.range?.endOffset, value.length + 2);
        _region(tester).clearSelection();
        await tester.pump();
      }
    },
  );

  testWidgets('wide inline formula scales its size and baseline to the line', (
    tester,
  ) async {
    final body = List.filled(30, r'\frac{a+b}{c+d}').join('+');
    await tester.pumpWidget(
      _harness(
        SizedBox(
          width: 280,
          child: MarkdownWithCodeHighlight(text: r'\(' + body + r'\)'),
        ),
        (_) {},
      ),
    );
    await tester.pumpAndSettle();
    final fitter = find.byWidgetPredicate((w) => w is FittedBox);
    expect(fitter, findsOneWidget);
    final fitted = tester.renderObject<RenderFittedBox>(fitter);
    final math = tester.renderObject<RenderBox>(find.byType(Math));
    expect(fitted.size.width, lessThanOrEqualTo(280));
    expect(fitted.size.height, lessThan(math.size.height));
    // A baseline forwarded without scaling would enlarge this line to the
    // unscaled fraction's ascent, even though its painted box is tiny.
    expect(_paragraph(tester, '\uFFFC').size.height, lessThan(30));
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
