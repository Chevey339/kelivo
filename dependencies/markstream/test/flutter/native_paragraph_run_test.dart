import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/src/flutter/render/block_list.dart';
import 'package:markstream/src/flutter/render/native_paragraph_run.dart';

void main() {
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
