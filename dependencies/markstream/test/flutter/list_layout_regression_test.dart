import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:markstream/src/flutter/render/prose_direction.dart';

import 'document_selection_test.dart' show drag;
import 'markstream_view_test.dart' show host;
import 'rich_blocks_test.dart' show selectAll;

class _PreviewImage implements ImageBuilder {
  const _PreviewImage();

  @override
  Widget build(BuildContext context, ImageNode image, MarkstreamTheme theme) =>
      const SizedBox(key: ValueKey('inline-preview'), width: 24, height: 24);
}

void main() {
  for (final nested in [true, false]) {
    testWidgets(
      'streaming keeps the mounted inline preview when ${nested ? 'a list grows' : 'prose direction changes'}',
      (tester) async {
        const item = '- Figure ![image](file.png)';
        final start = nested ? item : '$item\n\nEnglish paragraph.\n\n';
        Future<void> show(String source) async {
          await tester.pumpWidget(
            host(
              MarkstreamView(
                source: source,
                streaming: true,
                imageBuilder: const _PreviewImage(),
              ),
              selectable: true,
            ),
          );
          await tester.pumpAndSettle();
        }

        await show(start);
        final preview = find.byKey(const ValueKey('inline-preview'));
        final element = tester.element(preview);
        await show(nested ? '$start\n  - Nested' : '${start}שלום');
        expect(tester.element(preview), same(element));
      },
    );
  }

  testWidgets(
    'prebuilt prose columns react to width scope and keep loose child widths',
    (tester) async {
      final child = GlobalKey();
      final column = proseColumn(
        children: [SizedBox(key: child, width: 40, height: 20)],
      );
      for (final (enabled, tight, expected) in [
        (false, true, 40.0),
        (true, true, 240.0),
        (true, false, 40.0),
        (false, true, 40.0),
      ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 240,
                child: ProseWidthScope(
                  enabled: enabled,
                  child: tight
                      ? column
                      : Align(alignment: Alignment.topRight, child: column),
                ),
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byKey(child)).width, expected);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'single-paragraph list items preserve selection through streaming updates',
    (tester) async {
      final controller = MarkstreamSelectionController();
      addTearDown(controller.dispose);
      Future<void> show(String tail, bool streaming) async {
        await tester.pumpWidget(
          host(
            MarkstreamView(
              source: '- Alpha\n- Beta\n$tail',
              streaming: streaming,
              selectionController: controller,
            ),
            selectable: true,
          ),
        );
        await tester.pumpAndSettle();
      }

      await show('', true);
      await drag(tester, 'Alpha', 0, 'Beta', 4);
      final selected = controller.selectedPlainText;
      expect(selected, contains('Alpha'));
      await show('- Gamma\n', true);
      expect(controller.selectedPlainText, selected);
      await show('- Gamma\n', false);
      expect(controller.selectedPlainText, selected);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
  testWidgets('list selection order and plain Markdown copy match baseline', (
    tester,
  ) async {
    const source =
        '3. Alpha\n4. Beta with `code`\n   - Nested\n5. Gamma\n\n> - Quoted\n> - Last';
    final controller = MarkstreamSelectionController();
    addTearDown(controller.dispose);
    String? copied;
    await tester.pumpWidget(
      host(
        MarkstreamView(source: source, selectionController: controller),
        selectable: true,
        onSelection: (value) => copied = value?.plainText,
      ),
    );
    await tester.pumpAndSettle();
    selectAll(tester);
    await tester.pumpAndSettle();
    expect(copied, controller.selectedPlainText);
    expect(controller.selectedMarkdown, source);
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .clearSelection();
    await tester.pumpAndSettle();
    await drag(tester, 'Alpha', 1, 'Gamma', 3);
    expect(copied, 'lpha\n4. Beta with code\n  \n  - Nested\n5. Gam');
    expect(controller.selectedPlainText, copied);
    expect(
      controller.selectedMarkdown,
      '3. lpha\n4. Beta with `code`\n   - Nested\n5. Gam',
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
