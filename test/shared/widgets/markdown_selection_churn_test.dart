import 'dart:ui' as ui;
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:markstream/markstream.dart' show StableSelectionContainer;
import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';

void main() {
  for (final blocks in [false, true]) {
    testWidgets(
      'active Markdown drag survives appended and removed math, blocks=$blocks',
      (tester) async {
        String source(int count) =>
            'Before ${List.generate(count, (i) => 'word$i ${i.isEven ? '\$x_$i\$ ' : ''}').join()}After';
        final value = ValueNotifier(source(24));
        addTearDown(value.dispose);
        String? selected;
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SelectionArea(
                  onSelectionChanged: (content) =>
                      selected = content?.plainText,
                  child: StableSelectionContainer(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 350,
                        child: ValueListenableBuilder<String>(
                          valueListenable: value,
                          builder: (_, text, _) => MarkdownWithCodeHighlight(
                            text: text,
                            streaming: true,
                            useBlockRendering: blocks,
                          ),
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
        Offset edge(String word, bool end) {
          final p = markdownParagraph(tester, word);
          final index =
              p.text.toPlainText().indexOf(word) + (end ? word.length - 1 : 0);
          final b = p
              .getBoxesForSelection(
                TextSelection(baseOffset: index, extentOffset: index + 1),
              )
              .single;
          return p.localToGlobal(
            Offset(end ? b.right - 1 : b.left + 1, (b.top + b.bottom) / 2),
          );
        }

        final gesture = await tester.startGesture(
          edge('Before', false),
          kind: ui.PointerDeviceKind.mouse,
        );
        await gesture.moveTo(edge('After', true));
        await tester.pumpAndSettle();
        for (final count in [25, 23, 1, 0, 30]) {
          value.value = source(count);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'count=$count');
          await gesture.moveTo(edge('After', true));
          await tester.pumpAndSettle();
          expect(selected, source(count));
        }
        value.value = '';
        await tester.pumpAndSettle();
        await gesture.moveTo(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await gesture.up();
        await gesture.removePointer();
        value.value = source(30);
        await tester.pumpAndSettle();
        tester
            .state<SelectableRegionState>(find.byType(SelectableRegion))
            .selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        expect(selected, source(30));
      },
    );
  }
}
