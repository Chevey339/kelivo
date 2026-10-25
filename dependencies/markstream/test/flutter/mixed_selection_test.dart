import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

const code = '  first\n\tsecond';
const expected = 'Before code \$x+y\$ end\tB\t\n1\t2\t3  first\n\tsecondAfter';

class MixedDocument extends StatefulWidget {
  const MixedDocument({super.key});
  @override
  State<MixedDocument> createState() => _MixedDocumentState();
}

class _MixedDocumentState extends State<MixedDocument> {
  final table = TableSelectionDelegate();
  final codeSelection = CodeSelectionDelegate(code);
  @override
  void dispose() {
    table.dispose();
    codeSelection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StableSelectionContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSelectableText(
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Before '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: InlineCodeCapsule(
                    text: 'code',
                    style: TextStyle(fontSize: 13, height: 1.4),
                    backgroundColor: Color(0x66F1F3F5),
                    borderColor: Color(0x38666A70),
                  ),
                ),
                TextSpan(text: ' '),
                WidgetSpan(
                  child: SelectableSpanAdapter(
                    selectedText: r'$x+y$',
                    child: Text('x+y'),
                  ),
                ),
                TextSpan(text: ' end'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SelectionContainer(
          delegate: table,
          child: Column(
            children: [
              for (final row in [0, 1])
                Row(
                  children: [
                    for (final column in [0, 1, 2])
                      Expanded(
                        child: TableCellSelection(
                          table: table,
                          row: row,
                          column: column,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              row == 0
                                  ? (column == 1 ? 'B' : '')
                                  : '${column + 1}',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SelectionContainer(
          delegate: codeSelection,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('  first\n'), Text('\tsecond')],
          ),
        ),
        const SizedBox(height: 12),
        const Text('After'),
      ],
    ),
  );
}

RenderParagraph paragraph(String prefix) => find
    .byType(RichText)
    .evaluate()
    .map((e) => e.renderObject)
    .whereType<RenderParagraph>()
    .firstWhere((p) => p.text.toPlainText().startsWith(prefix));
TextBox box(RenderParagraph p, int offset) => p
    .getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    )
    .single;
Offset point(RenderParagraph p, int offset, {bool end = false}) {
  final b = box(p, offset);
  return p.localToGlobal(
    Offset(end ? b.right - 1 : b.left + 1, (b.top + b.bottom) / 2),
  );
}

void main() {
  for (final touch in [false, true]) {
    testWidgets(
      'one selection chain through code capsule, table, fenced code and math: touch=$touch',
      (tester) async {
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: defaultTargetPlatform),
            home: Scaffold(
              body: SelectionArea(
                onSelectionChanged: (value) => selected = value?.plainText,
                child: const Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: 390, child: MixedDocument()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final region = tester.state<SelectableRegionState>(
          find.byType(SelectableRegion),
        );
        region.selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        expect(selected, expected);
        region.clearSelection();
        await tester.pumpAndSettle();
        final first = paragraph('Before'), last = paragraph('After');
        if (touch) {
          await tester.longPressAt(point(first, 2));
          await tester.pumpAndSettle();
          expect(selected, 'Before');
          final overlay = region.selectionOverlay!;
          final controls = overlay.selectionControls!;
          final size = controls.getHandleSize(overlay.lineHeightAtEnd);
          final center =
              Offset(size.width / 2, size.height / 2) -
              controls.getHandleAnchor(
                overlay.endHandleType,
                overlay.lineHeightAtEnd,
              );
          final gesture = await tester.startGesture(
            overlay.endHandleLayerLink.leader!.offset + center,
          );
          final target = box(last, 4);
          final leading =
              (overlay.lineHeightAtEnd - (target.bottom - target.top)) / 2;
          await gesture.moveTo(
            last.localToGlobal(Offset(target.right, target.bottom + leading)) +
                center,
          );
          await tester.pump();
          await gesture.up();
          await gesture.removePointer();
          await tester.pumpAndSettle();
          expect(selected, expected);
        } else {
          for (final reverse in [false, true]) {
            region.clearSelection();
            await tester.pump(const Duration(milliseconds: 600));
            final a = point(first, 0), b = point(last, 4, end: true);
            final gesture = await tester.startGesture(
              reverse ? b : a,
              kind: ui.PointerDeviceKind.mouse,
            );
            await gesture.moveTo(reverse ? a : b);
            await tester.pump();
            await gesture.up();
            await gesture.removePointer();
            await tester.pumpAndSettle();
            expect(selected, expected);
          }
        }
        expect(tester.takeException(), isNull);
      },
      variant: touch
          ? TargetPlatformVariant.only(TargetPlatform.android)
          : TargetPlatformVariant.desktop(),
    );
  }
}
