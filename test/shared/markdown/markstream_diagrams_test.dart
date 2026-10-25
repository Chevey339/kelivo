import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/shared/markdown/diagram_code_blocks.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'markstream_adapters_test.dart' show host;

void main() {
  for (final language in ['mermaid', 'svg', 'xml']) {
    testWidgets(
      '$language preview uses a source-indexed code view without a selection island',
      (tester) async {
        MermaidImageCache.clear();
        debugMermaidBitmapRenderOverride = (_, __, ___) async =>
            MermaidBitmapRenderResult.unsupported();
        addTearDown(() => debugMermaidBitmapRenderOverride = null);
        final code = language == 'mermaid'
            ? 'graph TD\nA-->B'
            : '<svg viewBox="0 0 20 20"><circle r="5" /></svg>';
        final selection = MarkstreamSelectionController();
        addTearDown(selection.dispose);
        await tester.pumpWidget(
          host(
            MarkstreamSelectionScope(
              controller: selection,
              child: SelectionArea(
                child: MarkdownWithCodeHighlight(
                  text: 'Before\n\n```$language\n$code\n```\n\nAfter',
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pumpAndSettle();
        expect(find.byType(KelivoDiagramBlock), findsOneWidget);
        expect(find.byType(MarkstreamCodeContent), findsOneWidget);
        expect(find.byType(SelectableRegion), findsOneWidget);
        tester
            .state<SelectableRegionState>(find.byType(SelectableRegion))
            .selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        expect(selection.selectedPlainText, 'Before\n\n$code\n\nAfter');
        expect(selection.selectedMarkdown, contains('```$language'));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('PlantUML source tab participates in surrounding selection', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        final selection = MarkstreamSelectionController();
        addTearDown(selection.dispose);
        const code = '@startuml\nAlice -> Bob: hello\n@enduml';
        await tester.pumpWidget(
          host(
            MarkstreamSelectionScope(
              controller: selection,
              child: const SelectionArea(
                child: MarkdownWithCodeHighlight(
                  text: 'Before\n\n```plantuml\n$code\n```\n\nAfter',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Code'));
        await tester.pumpAndSettle();
        expect(find.byType(MarkstreamCodeContent), findsOneWidget);
        expect(find.byType(SelectableRegion), findsOneWidget);
        tester
            .state<SelectableRegionState>(find.byType(SelectableRegion))
            .selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        expect(selection.selectedPlainText, 'Before\n\n$code\n\nAfter');
        expect(selection.selectedMarkdown, contains('```plantuml'));
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (_) async => http.Response(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><rect width="20" height="20"/></svg>',
          200,
        ),
      ),
    );
  });
  testWidgets(
    'complete HTML and snippets retain code chrome with an explicit preview action',
    (tester) async {
      for (final source in [
        '<!DOCTYPE html>\n<html><body>hello</body></html>',
        '```html\n<div>hello</div>\n```',
        '```html\n<svg viewBox="0 0 20 20"></svg>\n```',
      ]) {
        await tester.pumpWidget(host(MarkdownWithCodeHighlight(text: source)));
        await tester.pumpAndSettle();
        expect(find.byType(MarkstreamCodeBlock), findsOneWidget);
        expect(find.byTooltip('Preview'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('long citation groups fit a narrow preview', (tester) async {
    final ids = List.generate(60, (i) => 'id$i').join(',');
    await tester.pumpWidget(
      host(
        MarkdownWithCodeHighlight(
          text: '[cite:$ids]',
          citationIndexResolver: (_) => '123',
        ),
        width: 280,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('123'), findsNWidgets(60));
    expect(tester.takeException(), isNull);
  });
}
