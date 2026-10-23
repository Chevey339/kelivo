import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import 'markstream_view_test.dart' show host, paragraphs;
import 'rich_blocks_test.dart' show selectAll;

void main() {
  testWidgets('alerts and directives retain source selection without chrome', (
    tester,
  ) async {
    const source =
        '> [!NOTE]\n> First **body**.\n\n:::warning{title="Careful"}\nSecond `body`.\n:::\n\n::tip[Explicit label]\n\n:::unknown\nLast\n:::';
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    String? native;
    await tester.pumpWidget(
      host(
        MarkstreamView(
          source: source,
          selectionController: controller,
          labels: const MarkstreamLabels(note: '备注', tip: '提示'),
        ),
        selectable: true,
        onSelection: (s) => native = s?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MarkstreamDirectiveCard), findsNWidgets(3));
    for (final title in ['备注', 'Careful', '提示'])
      expect(find.text(title), findsOneWidget);
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(native, 'First body.\n\nSecond body.\n\nExplicit label\n\nLast');
    expect(controller.selectedPlainText, native);
    expect(controller.selectedMarkdown, contains('[!NOTE]'));
    expect(controller.selectedMarkdown, contains('title="Careful"'));
    expect(controller.selectedMarkdown, contains('::tip[Explicit label]'));
    expect(find.byType(SelectableRegion), findsOneWidget);
  });
  testWidgets('all default cards wrap at narrow widths and large fonts', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final theme = MarkstreamTheme.fromColorScheme(
        ColorScheme.fromSeed(seedColor: Colors.blue, brightness: brightness),
      );
      for (final kind in MarkstreamDirectiveCard.kinds) {
        await tester.pumpWidget(
          host(
            MarkstreamView(
              source: ':::$kind\nA long body with 中文 and **emphasis**.\n:::',
              theme: theme,
            ),
            width: 180,
            scale: 1.3,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MarkstreamDirectiveCard), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          paragraphs().map((p) => p.text.toPlainText()).join(),
          contains('emphasis'),
        );
      }
    }
  });
  testWidgets('custom registration overrides the default card', (tester) async {
    final extensions = MarkstreamExtensions(
      directiveBuilders: {
        'note': (_, node, rendering) => Column(
          children: [
            const Text('CUSTOM'),
            for (final block in node.children)
              rendering.buildBlock(block as BlockNode),
          ],
        ),
      },
    );
    await tester.pumpWidget(
      host(MarkstreamView(source: '> [!NOTE]\n> Body', extensions: extensions)),
    );
    expect(find.text('CUSTOM'), findsOneWidget);
    expect(find.byType(MarkstreamDirectiveCard), findsNothing);
  });
  testWidgets('open directive updates its body and closes in place', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      host(
        MarkstreamView(key: key, source: ':::danger\nStart', streaming: true),
      ),
    );
    final state = key.currentState;
    await tester.pumpWidget(
      host(
        MarkstreamView(
          key: key,
          source: ':::danger\nStart **end**\n:::',
          streaming: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(key.currentState, same(state));
    expect(find.byType(MarkstreamDirectiveCard), findsOneWidget);
    expect(
      paragraphs().map((p) => p.text.toPlainText()).join(),
      contains('Start end'),
    );
  });
}
