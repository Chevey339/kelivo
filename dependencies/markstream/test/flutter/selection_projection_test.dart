import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'markstream_view_test.dart' show host;
import 'document_selection_test.dart' show drag;
import 'rich_blocks_test.dart' show selectAll;

void main() {
  testWidgets(
    'extension selection has literal plain and HTML projections without duplicate nested documents',
    (tester) async {
      final selection = MarkstreamSelectionController();
      var value = 'Amount: -3 <literal> `ticks`\nSecond: 7';
      String? native;
      final extensions = MarkstreamExtensions(
        codeBlockBuilders: {
          'card': (context, node, rendering) => MarkstreamSelectionProjection(
            node: node,
            project: (selected, complete) => complete ? value : selected,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Label'),
                Text('Actual value'),
                MarkstreamView(source: '**Nested**'),
              ],
            ),
          ),
        },
      );
      final view = MarkstreamView(
        source: 'Before\n\n```card\nRAW SECRET\n```\n\nAfter',
        selectionController: selection,
        extensions: extensions,
        cullToViewport: false,
      );
      await tester.pumpWidget(
        host(
          view,
          selectable: true,
          onSelection: (content) => native = content?.plainText,
        ),
      );
      await tester.pumpAndSettle();
      selectAll(tester);
      await tester.pumpAndSettle();
      expect(selection.hasSelection, isTrue);
      expect(native, 'Before\n\n$value\n\nAfter');
      expect(selection.selectedPlainText, native);
      expect(selection.selectedDocuments, hasLength(1));
      final html = toHtml(selection.selectedDocuments.single);
      expect(html, contains('Amount: -3 &lt;literal&gt; `ticks`'));
      expect(html, contains('<br />\nSecond: 7'));
      expect(html, isNot(contains('RAW SECRET')));
      expect(html, isNot(contains('Nested')));
      expect(selection.selectedMarkdown, isNot(contains('```card')));
      value = 'Amount: 9';
      expect(selection.selectedPlainText, contains('Amount: 9'));
      expect(toHtml(selection.selectedDocuments.single), contains('Amount: 9'));
      await tester.pumpWidget(
        host(SelectionContainer.disabled(child: view), selectable: true),
      );
      await tester.pumpAndSettle();
      expect(selection.hasSelection, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      selection.dispose();
    },
  );

  testWidgets(
    'partial extension selection retains actual glyphs, not invented source offsets',
    (tester) async {
      final selection = MarkstreamSelectionController();
      final extensions = MarkstreamExtensions(
        codeBlockBuilders: {
          'card': (context, node, rendering) => MarkstreamSelectionProjection(
            node: node,
            project: (selected, complete) =>
                complete ? 'Whole semantic state' : selected,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('Label'), Text('Actual value')],
            ),
          ),
        },
      );
      await tester.pumpWidget(
        host(
          MarkstreamView(
            source: 'Before\n\n```card\nRAW SECRET\n```\n\nAfter',
            extensions: extensions,
            selectionController: selection,
          ),
          selectable: true,
        ),
      );
      await tester.pumpAndSettle();
      await drag(tester, 'Actual value', 0, 'Actual value', 6);
      expect(selection.selectedPlainText, 'Actual');
      expect(selection.selectedMarkdown, 'Actual');
      expect(toHtml(selection.selectedDocuments.single), '<p>Actual</p>\n');
      expect(selection.selections.single.sourceRanges, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      selection.dispose();
    },
  );
}
