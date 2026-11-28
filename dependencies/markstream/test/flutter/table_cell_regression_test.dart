import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'document_selection_test.dart' show drag;
import 'markstream_view_test.dart' show host, paragraphs;
import 'rich_blocks_test.dart' show selectAll;

const _wide =
    '''| checkpoint_identifier | distance_kilometres | duration_minutes | elevation_metres | supplies_required | instructions_final |
| :--- | :---: | ---: | :--- | :---: | ---: |
| start | 12 | 60 | 320 | water | target_last_column |
| finish | 24 | 120 | 640 | food | last |''';

void main() {
  testWidgets(
    'expanded quoted table stays open when streamed prose changes direction',
    (tester) async {
      final prefix = [
        '> | Item | Result |',
        '> | - | - |',
        for (var i = 1; i <= 45; i++) '> | Value $i | Result $i |',
        '',
        'English paragraph.',
        '',
      ].join('\n');
      Future<void> show(String source) async {
        await tester.pumpWidget(
          host(
            MarkstreamView(source: source, streaming: true),
            selectable: true,
          ),
        );
        await tester.pumpAndSettle();
      }

      bool lastRowVisible() =>
          paragraphs().any((p) => p.text.toPlainText() == 'Value 45');

      await show(prefix);
      final more = find.textContaining('more rows');
      expect(lastRowVisible(), isFalse);
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(lastRowVisible(), isTrue);

      await show('$prefix\nשלום');
      expect(lastRowVisible(), isTrue);
      expect(more, findsNothing);
    },
  );

  testWidgets('ordinary cells preserve TSV, plain and Markdown drag copy', (
    tester,
  ) async {
    const source =
        '| Left | Right | Empty |\n| - | - | - |\n| AAA | BBB | |\n| CCC | DDD | ZZZ |';
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    String? selected;
    await tester.pumpWidget(
      host(
        MarkstreamView(source: source, selectionController: controller),
        selectable: true,
        onSelection: (value) => selected = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    const all = 'Left\tRight\tEmpty\nAAA\tBBB\t\nCCC\tDDD\tZZZ';
    expect(selected, all);
    expect(controller.selectedPlainText, all);
    expect(
      controller.selectedMarkdown,
      toMarkdown(MarkdownParser().parse(source)),
    );
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .clearSelection();
    await tester.pumpAndSettle();
    await drag(tester, 'BBB', 1, 'CCC', 2);
    expect(controller.selectedPlainText, selected);
    expect(selected, 'BB\t\nCC');
    expect(controller.selectedMarkdown, contains('|  | BB |  |'));
    expect(controller.selectedMarkdown, contains('| CC |  |  |'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('source-range reveal scrolls ordinary cells without selecting', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        MarkstreamView(source: _wide, selectionController: controller),
        width: 300,
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    final start = _wide.indexOf('target_last_column');
    final range = SourceSpan(start, start + 'target_last_column'.length);
    for (var i = 0; i < 8 && !controller.prepareSourceRange(range); i++) {
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    final rect = controller.rectForSourceRange(range);
    expect(rect, isNotNull);
    expect(rect!.left, greaterThanOrEqualTo(-1));
    expect(rect.right, lessThanOrEqualTo(301));
    expect(controller.hasSelection, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('plain cell selection survives append and streaming completion', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    Future<void> pump(String tail, bool streaming) async {
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: '| Left | Right |\n| - | - |\n| AAA | BBB |\n$tail',
            streaming: streaming,
            selectionController: controller,
          ),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump('', true);
    await drag(tester, 'AAA', 0, 'BBB', 3);
    expect(controller.selectedPlainText, '\nAAA\tBBB');
    await pump('| CCC | DDD |', true);
    expect(controller.selectedPlainText, 'AAA\tBBB');
    await pump('| CCC | DDD |', false);
    expect(controller.selectedPlainText, 'AAA\tBBB');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('only short built-in text cells share their cell delegate', (
    tester,
  ) async {
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    final long = List.filled(520, 'x').join();
    await tester.pumpWidget(
      host(
        MarkstreamView(
          selectionController: controller,
          source:
              '| Plain | Styled |\n| - | - |\n| ordinary | **bold** |\n| | `code` |\n| $long | [link](https://example.com) |',
        ),
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    final fragments = tester.widgetList<MarkstreamSelectionFragment>(
      find.byType(MarkstreamSelectionFragment),
    );
    final cells = fragments
        .where((fragment) => fragment.node is TableCellNode)
        .toList();
    expect(cells, hasLength(8));
    for (final cell in cells) {
      final text = toPlainText(cell.node);
      expect(
        cell.selectionDelegate != null,
        ['Plain', 'Styled', 'ordinary', ''].contains(text),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom text cells retain the embedded selection path', (
    tester,
  ) async {
    final extensions = MarkstreamExtensions(
      nodeBuilders: NodeBuilderRegistry(
        inlines: {
          TextNode: (_, node, _) {
            final text = (node as TextNode).text;
            return RenderedInline(
              span: WidgetSpan(
                child: SelectableSpanAdapter(
                  selectedText: text,
                  child: Text(text),
                ),
              ),
              segments: [
                TextSegment(text: text, sourceSpan: node.span, node: node),
              ],
            );
          },
        },
      ),
    );
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: '| First | Second |\n| - | - |\n| custom | content |',
          extensions: extensions,
          selectionController: controller,
        ),
        selectable: true,
      ),
    );
    await tester.pumpAndSettle();
    final fragments = tester.widgetList<MarkstreamSelectionFragment>(
      find.byType(MarkstreamSelectionFragment),
    );
    expect(
      fragments.where((fragment) => fragment.node is TableCellNode),
      hasLength(4),
    );
    expect(
      fragments.every((fragment) => fragment.selectionDelegate == null),
      isTrue,
    );
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(controller.selectedPlainText, 'First\tSecond\ncustom\tcontent');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'delegate handoff and selection-area removal do not dispose the cell delegate',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      Future<void> pump(bool styled, bool bold, bool selectable) async {
        await tester.pumpWidget(
          host(
            MediaQuery(
              data: MediaQueryData(boldText: bold),
              child: MarkstreamView(
                source:
                    '| First | Second |\n| - | - |\n| ${styled ? '**AAA**' : 'AAA'} | BBB |',
                selectionController: controller,
              ),
            ),
            selectable: selectable,
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final (styled, bold, selectable) in [
        (false, false, true),
        (true, false, true),
        (false, true, true),
        (false, false, true),
        (false, false, false),
        (false, false, true),
      ]) {
        await pump(styled, bold, selectable);
        if (selectable) {
          selectAll(tester);
          await tester.pumpAndSettle();
          expect(controller.selectedPlainText, 'First\tSecond\nAAA\tBBB');
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
