import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

void main() {
  testWidgets(
    'source geometry accounts for inline atoms without a SelectionArea',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      const source = r'prefix $a+b+c$ and `code` before needle';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkstreamView(
              source: source,
              selectionController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = source.indexOf('needle');
      final rect = controller.rectForSourceRange(SourceSpan(start, start + 6));
      final richText = find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('needle'),
      );
      final paragraph = tester.renderObject<RenderParagraph>(richText);
      final at = paragraph.text.toPlainText().indexOf('needle');
      final expected = paragraph.localToGlobal(
        paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: at, extentOffset: at + 6),
            )
            .first
            .toRect()
            .center,
      );
      expect(rect!.center.dx, closeTo(expected.dx, .01));
      expect(rect.center.dy, closeTo(expected.dy, .01));
    },
  );
  for (final body in [
    'prefix **needle** after',
    'prefix `inline code` and \$x^2\$ before **needle** after',
    '```dart\nfirst line\nneedle\nlast line\n```',
    '| first | second |\n| --- | --- |\n| cell | needle |',
    '${'long wrapped paragraph ' * 250}needle after',
  ]) {
    testWidgets(
      'source geometry locates the selected occurrence: ${body.substring(0, body.length.clamp(0, 60))}',
      (tester) async {
        final controller = MarkstreamSelectionController();
        addTearDown(controller.dispose);
        final source =
            'needle at the beginning\n\n${'paragraph\n\n' * 50}$body';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionArea(
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: 320,
                    child: MarkstreamView(
                      source: source,
                      selectionController: controller,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final offset = source.lastIndexOf('needle');
        final rect = controller.rectForSourceRange(
          SourceSpan(offset, offset + 6),
        );
        expect(rect, isNotNull);
        final paragraphs = <RenderParagraph>[];
        void visit(RenderObject object) {
          if (object is RenderParagraph &&
              object.text.toPlainText().contains('needle')) {
            paragraphs.add(object);
          }
          object.visitChildren(visit);
        }

        visit(tester.renderObject(find.byType(MarkstreamView)));
        final paragraph = paragraphs.last;
        final textOffset = paragraph.text.toPlainText().indexOf('needle');
        final expected = paragraph.localToGlobal(
          paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: textOffset,
                  extentOffset: textOffset + 6,
                ),
              )
              .first
              .toRect()
              .center,
        );
        expect(rect!.center.dy, closeTo(expected.dy, .01));
        expect(rect.center.dx, closeTo(expected.dx, .01));
        expect(rect.top, greaterThan(600));
        expect(controller.hasSelection, isFalse);
        expect(
          controller.rectForSourceRange(
            SourceSpan(source.length + 1, source.length + 2),
          ),
          isNull,
        );
      },
    );
  }

  for (final line in [150, 1050]) {
    testWidgets('source navigation reveals virtual code line $line', (
      tester,
    ) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      final source =
          '```\n${List.generate(1105, (i) => 'line ${i.toString().padLeft(4, '0')}').join('\n')}\n```';
      final text = 'line ${line.toString().padLeft(4, '0')}';
      final start = source.indexOf(text);
      final range = SourceSpan(start, start + text.length);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: SingleChildScrollView(
                child: MarkstreamView(
                  source: source,
                  selectionController: controller,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var ready = false;
      for (var pass = 0; pass < 8; pass++) {
        ready = controller.prepareSourceRange(range);
        await tester.pump();
        if (ready) break;
      }
      expect(ready, isTrue);
      final rect = controller.rectForSourceRange(range);
      final viewport = tester.getRect(
        find.byKey(const ValueKey('markstream-virtualized-code')),
      );
      expect(rect, isNotNull);
      expect(viewport.contains(rect!.center), isTrue);
      expect(controller.hasSelection, isFalse);
    });
  }

  testWidgets(
    'source navigation exposes a paginated row and a clipped mobile column',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      final source =
          '| one | two | three | four | five |\n| --- | --- | --- | --- | --- |\n${List.generate(65, (i) => '| A $i | B $i | C $i | D $i | target $i |').join('\n')}';
      final start = source.indexOf('target 55');
      final range = SourceSpan(start, start + 'target 55'.length);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 390,
                child: SelectionArea(
                  child: SingleChildScrollView(
                    child: MarkstreamView(
                      source: source,
                      selectionController: controller,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.rectForSourceRange(range), isNull);
      var ready = false;
      for (var pass = 0; pass < 8; pass++) {
        ready = controller.prepareSourceRange(range);
        await tester.pump();
        if (ready) break;
      }
      expect(ready, isTrue);
      final rect = controller.rectForSourceRange(range);
      expect(rect, isNotNull);
      final viewport = tester.getRect(
        find.byKey(const ValueKey('markstream-table-scroll')),
      );
      expect(rect!.center.dx, inInclusiveRange(viewport.left, viewport.right));
      expect(controller.hasSelection, isFalse);
      await tester.ensureVisible(find.text('Collapse'));
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();
      expect(controller.rectForSourceRange(range), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}
