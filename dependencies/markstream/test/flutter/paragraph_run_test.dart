import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

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
