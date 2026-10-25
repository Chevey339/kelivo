import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host;
import 'rich_blocks_test.dart' show selectAll;

void main() {
  final initial =
      '${List.generate(110, (i) => 'Paragraph $i ${List.filled(15, 'word').join(' ')}').join('\n\n')}\n\nTail';
  testWidgets(
    'long stream bursts render their latest source after one interval',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      Future<void> show(String source) async => tester.pumpWidget(
        host(
          MarkstreamView(
            source: source,
            streaming: true,
            selectionController: controller,
          ),
          selectable: true,
        ),
      );
      await show(initial);
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      await show('${initial}A');
      await tester.pump(const Duration(milliseconds: 20));
      await show('${initial}AB');
      await tester.pump(const Duration(milliseconds: 29));
      expect(controller.selections.single.document.source, initial);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.selections.single.document.source, '${initial}AB');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('completion, edits and exports flush without waiting', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    Future<void> show(
      String source, {
      bool streaming = true,
      bool exporting = false,
    }) async => tester.pumpWidget(
      host(
        MarkstreamView(
          source: source,
          streaming: streaming,
          exporting: exporting,
          selectionController: controller,
        ),
        selectable: true,
      ),
    );
    await show(initial);
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    await show('${initial}A');
    await show('${initial}AB', streaming: false);
    await tester.pump();
    selectAll(tester);
    await tester.pump();
    expect(controller.selections.single.document.source, '${initial}AB');
    await show('${initial}ABC');
    await show('${initial}ABCD');
    await show('${initial}ABCDE', exporting: true);
    await tester.pump();
    selectAll(tester);
    await tester.pump();
    expect(controller.selections.single.document.source, '${initial}ABCDE');
    await show('${initial}ABCDEF');
    await show('Edited');
    await tester.pump();
    selectAll(tester);
    await tester.pump();
    expect(controller.selectedMarkdown, 'Edited');
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.selectedMarkdown, 'Edited');
    await show(initial);
    await show('${initial}pending');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
