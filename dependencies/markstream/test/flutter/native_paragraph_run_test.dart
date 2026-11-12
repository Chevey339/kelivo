import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/src/flutter/render/block_list.dart';
import 'package:markstream/src/flutter/render/native_paragraph_run.dart';

void main() {
  testWidgets('native paragraphs match RichText after edits and DPI changes', (
    tester,
  ) async {
    final ratio = ValueNotifier(1.0);
    addTearDown(ratio.dispose);
    RichText paragraph(String text) => RichText(
      key: const ValueKey('reference-paragraph'),
      text: TextSpan(text: text, style: const TextStyle(fontSize: 16)),
      textDirection: TextDirection.rtl,
      locale: const Locale('ar'),
      textAlign: TextAlign.end,
      textScaler: const TextScaler.linear(1.3),
    );
    var reference = paragraph('مرحبا بالعالم. A paragraph that wraps. ' * 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: ratio,
            builder: (_, value, _) => MediaQuery(
              data: MediaQueryData(devicePixelRatio: value),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 240,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NativeParagraphRun(paragraphs: [reference], spacing: 0),
                      reference,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    RenderParagraph nativeParagraph() {
      late RenderParagraph paragraph;
      tester.renderObject(find.byType(NativeParagraphRun)).visitChildren((
        child,
      ) {
        paragraph = child as RenderParagraph;
      });
      return paragraph;
    }

    Object? diagnostic(RenderParagraph paragraph, String name) => paragraph
        .toDiagnosticsNode()
        .getProperties()
        .where((property) => property.name == name)
        .firstOrNull
        ?.value;
    final initial = nativeParagraph();
    for (final value in [1.0, 3.0, 2.0]) {
      if (value == 2) reference = paragraph('Updated مرحبا بالعالم.');
      ratio.value = value;
      await tester.pump();
      final native = nativeParagraph();
      final normal = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('reference-paragraph')),
      );
      expect(native, same(initial));
      expect(native.text.toPlainText(), normal.text.toPlainText());
      expect(native.size, normal.size);
      // This property exists on newer SDKs. Compare with the host's own RichText
      // so the same test also runs on Flutter 3.44.9, before the API was added.
      expect(
        diagnostic(native, 'devicePixelRatio'),
        diagnostic(normal, 'devicePixelRatio'),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'retained paragraph semantics follow edits, scrolling and removal',
    (tester) async {
      RichText row(String text) => RichText(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 16, height: 1.25),
        ),
      );
      final rows = ValueNotifier(List.generate(80, (i) => row('row $i')));
      final scroll = ScrollController();
      addTearDown(rows.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                height: 180,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: ValueListenableBuilder<List<RichText>>(
                    valueListenable: rows,
                    builder: (_, value, _) => BlockList(
                      blocks: [value],
                      signature: 0,
                      itemBuilder: (_, _) =>
                          NativeParagraphRun(paragraphs: value, spacing: 10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      String labels() => tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData().label)
          .join('\n');
      expect(labels(), contains('row 0'));
      expect(labels(), isNot(contains('row 79')));
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(labels(), contains('row 79'));
      rows.value = [...rows.value.take(79), row('updated tail')];
      await tester.pumpAndSettle();
      expect(labels(), contains('updated tail'));
      expect(labels(), isNot(contains('row 79')));
      rows.value = [...rows.value, row('new tail')];
      await tester.pumpAndSettle();
      expect(labels(), contains('new tail'));
      rows.value = rows.value.take(79).toList();
      await tester.pumpAndSettle();
      expect(labels(), isNot(contains('updated tail')));
      expect(labels(), isNot(contains('new tail')));
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(labels(), contains('row 0'));
      expect(labels(), isNot(contains('row 78')));
      expect(tester.takeException(), isNull);
    },
  );
}
