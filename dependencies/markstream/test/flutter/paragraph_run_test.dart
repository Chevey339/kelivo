import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:markstream/src/flutter/render/native_paragraph_run.dart';

import 'markstream_view_test.dart' show host, paragraph, edge;

Future<(Size, Uint8List)> pixels(
  WidgetTester tester,
  String source, {
  required bool batch,
  double scale = 1,
}) async {
  final key = GlobalKey();
  final extensions = batch
      ? const MarkstreamExtensions.empty()
      : MarkstreamExtensions(
          nodeBuilders: NodeBuilderRegistry(
            blocks: {
              ParagraphNode: (context, node, rendering) => StreamingText(
                streaming: rendering.streaming,
                text: Text.rich(
                  TextSpan(
                    style: rendering.theme.body,
                    children: [
                      for (final child in node.children)
                        rendering.buildInline(
                          child as InlineNode,
                          rendering.theme.body,
                        ),
                    ],
                  ),
                  style: rendering.theme.body,
                ),
              ),
            },
          ),
        );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 390,
                child: MarkstreamView(
                  source: source,
                  extensions: extensions,
                  cullToViewport: false,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final size = boundary.size;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  });
  return (size, bytes!);
}

Future<Uint8List> movingScene(WidgetTester tester, bool batch) async {
  final boundary = GlobalKey();
  final offset = ValueNotifier(70.0);
  final source = List.generate(
    40,
    (i) => 'Paragraph $i with visible glyphs.',
  ).join('\n\n');
  final extensions = batch
      ? const MarkstreamExtensions.empty()
      : MarkstreamExtensions(
          nodeBuilders: NodeBuilderRegistry(
            blocks: {
              ParagraphNode: (context, node, rendering) => Text.rich(
                TextSpan(
                  style: rendering.theme.body,
                  children: [
                    for (final child in node.children)
                      rendering.buildInline(
                        child as InlineNode,
                        rendering.theme.body,
                      ),
                  ],
                ),
              ),
            },
          ),
        );
  final markdown = RepaintBoundary(
    child: MarkstreamView(source: source, extensions: extensions),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: Colors.white,
            child: SizedBox(
              width: 390,
              height: 120,
              child: SingleChildScrollView(
                child: ValueListenableBuilder<double>(
                  valueListenable: offset,
                  child: markdown,
                  builder: (context, value, child) => Column(
                    children: [
                      SizedBox(height: value),
                      child!,
                    ],
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
  offset.value = 0;
  await tester.pump();
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await render.toImage();
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  });
  await tester.pumpWidget(const SizedBox());
  offset.dispose();
  return bytes!;
}

void main() {
  testWidgets(
    'inline selection order survives theme, width and direction changes',
    (tester) async {
      for (final rtl in [false, true]) {
        final start = rtl ? 'مرحبا بالعالم ' : 'Leading words ';
        final tail = rtl ? ' نهاية الفقرة' : ' trailing words';
        for (final width in [390.0, 140.0, 270.0]) {
          for (final brightness in Brightness.values) {
            final source =
                '${List.filled(32, start).join()} `code` $tail **bold**';
            final expected = '${List.filled(32, start).join()} code $tail bold';
            SelectedContent? selected;
            await tester.pumpWidget(
              host(
                MarkstreamView(
                  source: source,
                  theme: MarkstreamTheme.fromColorScheme(
                    ColorScheme.fromSeed(
                      seedColor: Colors.blue,
                      brightness: brightness,
                    ),
                    bodyStyle: TextStyle(fontSize: width == 140 ? 19 : 15),
                  ),
                ),
                width: width,
                selectable: true,
                onSelection: (value) => selected = value,
              ),
            );
            await tester.pumpAndSettle();
            final region = tester.state<SelectableRegionState>(
              find.byType(SelectableRegion),
            );
            region.selectAll(SelectionChangedCause.keyboard);
            await tester.pump();
            expect(selected?.plainText, expected);
            expect(tester.takeException(), isNull);
            region.clearSelection();
            await tester.pump();
          }
        }
      }
    },
  );

  testWidgets('completed paragraph paint survives tail growth and new chunks', (
    tester,
  ) async {
    var source = List.generate(
      17,
      (i) => 'Paragraph $i with stable words.',
    ).join('\n\n');
    Future<void> show() => tester.pumpWidget(
      host(
        MarkstreamView(source: source, streaming: true, cullToViewport: false),
      ),
    );
    await show();
    final first = tester.renderObject(find.byType(NativeParagraphRun).first);
    final boundary = first.parent! as RenderRepaintBoundary;
    final picture = boundary.debugLayer!.firstChild;
    final tail = paragraph('Paragraph 16');
    source += ' appended';
    await show();
    expect(boundary.debugLayer!.firstChild, same(picture));
    expect(paragraph('Paragraph 16'), same(tail));
    source += List.generate(9, (i) => '\n\nParagraph ${i + 17} next.').join();
    await show();
    expect(boundary.debugLayer!.firstChild, same(picture));
    expect(paragraph('Paragraph 16'), same(tail));
    expect(paragraph('Paragraph 25').text.toPlainText(), 'Paragraph 25 next.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('native paragraphs support hosts without MediaQuery', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MarkstreamView(
          source: 'Standalone paragraph',
          theme: MarkstreamTheme.fromColorScheme(
            ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(paragraph('Standalone').text.toPlainText(), 'Standalone paragraph');
  });

  testWidgets(
    'native paragraph selection survives tail edits during an active drag',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      final prefix = List.generate(
        12,
        (i) => 'Line $i with stable words.',
      ).join('\n\n');
      Future<void> show(String tail) async => tester.pumpWidget(
        host(
          MarkstreamView(
            source: '$prefix\n\n$tail',
            streaming: true,
            selectionController: controller,
          ),
          selectable: true,
        ),
      );
      await show('Tail');
      await tester.pumpAndSettle();
      final first = paragraph('Line 0');
      final gesture = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.addPointer();
      await gesture.down(edge(first, 0));
      await show('Tail extended');
      await tester.pump();
      expect(identical(first, paragraph('Line 0')), isTrue);
      await gesture.moveTo(edge(paragraph('Tail'), 12, end: true));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.selectedPlainText, startsWith('Line 0'));
      expect(controller.selectedPlainText, endsWith('Tail extended'));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'active selection survives appending across a native paint chunk',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      var source = List.generate(8, (i) => 'Line $i stable.').join('\n\n');
      Future<void> show() => tester.pumpWidget(
        host(
          MarkstreamView(
            source: source,
            streaming: true,
            selectionController: controller,
          ),
          selectable: true,
        ),
      );
      await show();
      await tester.pumpAndSettle();
      final existingTail = paragraph('Line 7');
      final gesture = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await gesture.addPointer();
      await gesture.down(edge(paragraph('Line 0'), 0));
      await gesture.moveTo(edge(existingTail, 5, end: true));
      source += '\n\nLine 8 newly appended.';
      await show();
      await tester.pumpAndSettle();
      expect(paragraph('Line 7'), same(existingTail));
      await gesture.moveTo(edge(paragraph('Line 8'), 21, end: true));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.selectedPlainText, startsWith('Line 0'));
      expect(controller.selectedPlainText, endsWith('Line 8 newly appended.'));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'cached native paragraphs repaint when an ancestor reveals new glyphs',
    (tester) async {
      final reference = await movingScene(tester, false);
      final native = await movingScene(tester, true);
      expect(native, reference);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'paragraph batches preserve native heights, glyph pixels and fixed gaps',
    (tester) async {
      for (final source in [
        List.filled(
          6,
          'Plain paragraph **bold** and _emphasis_ with enough words to wrap over a line.',
        ).join('\n\n'),
        List.filled(
          6,
          'Paragraph with `code` capsule and [link](https://example.com).',
        ).join('\n\n'),
        List.filled(
          6,
          '中文段落 **加粗**，间距保持一致。跨行内容再加上更多的中文和 English.',
        ).join('\n\n'),
        'אבג one\n\nדהו two\n\nEnglish paragraph\n\nאבג three',
        List.generate(
          40,
          (i) => '跨分组 $i **粗体** and wrapped English words.',
        ).join('\n\n'),
      ]) {
        for (final scale in [1.0, 1.3]) {
          final normal = await pixels(
            tester,
            source,
            batch: false,
            scale: scale,
          );
          final batched = await pixels(
            tester,
            source,
            batch: true,
            scale: scale,
          );
          expect(batched.$1.width, closeTo(normal.$1.width, 1e-9));
          expect(batched.$1.height, closeTo(normal.$1.height, 1e-9));
          expect(batched.$2, normal.$2);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
