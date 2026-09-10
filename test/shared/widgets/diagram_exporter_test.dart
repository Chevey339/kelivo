import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/diagram_exporter.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/mermaid_bridge.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  test('extracts Mermaid, SVG and XML SVG while respecting outer fences', () {
    const markdown = '''
```mermaid
graph TD; A-->B
```
~~~~SVG
<svg/>
~~~~
```xml
<?xml version="1.0"?><svg/>
```
```xml
<config/>
```
````text
```svg
<svg id="quoted"/>
```
````
''';
    expect(extractDiagramCodes(markdown), [
      (code: 'graph TD; A-->B', isSvg: false),
      (code: '<svg/>', isSvg: true),
      (code: '<?xml version="1.0"?><svg/>', isSvg: true),
    ]);
  });

  test('extracts CRLF, longer closers and an unfinished final fence', () {
    expect(extractDiagramCodes('```svg\r\n<svg/>\r\n````\r\n'), [
      (code: '<svg/>', isSvg: true),
    ]);
    expect(extractDiagramCodes('~~~xml\n<svg/>'), [
      (code: '<svg/>', isSvg: true),
    ]);
  });

  test('cache keys normalize source but distinguish format and theme', () {
    final first = diagramImageCacheKey(' \r\n<svg/>\r\n', false, {
      'b': '2',
      'a': '1',
    }, isSvg: true);
    expect(
      first,
      diagramImageCacheKey('<svg/>', false, {'a': '1', 'b': '2'}, isSvg: true),
    );
    expect(
      first,
      isNot(diagramImageCacheKey('<svg/>', false, {'a': '1', 'b': '2'})),
    );
    expect(
      first,
      isNot(
        diagramImageCacheKey('<svg/>', true, {'a': '1', 'b': '2'}, isSvg: true),
      ),
    );
  });

  for (final language in ['svg', 'xml', 'mermaid']) {
    for (final dark in [false, true]) {
      testWidgets(
        'cold $language export consumes the prerendered image (dark=$dark)',
        (tester) async {
          MermaidImageCache.clear();
          addTearDown(MermaidImageCache.clear);
          addTearDown(() => debugDiagramExportViewFactory = null);
          final rendered = <DiagramCode>[];
          debugDiagramExportViewFactory = (diagram) {
            rendered.add(diagram);
            return MermaidViewHandle(
              widget: const SizedBox(),
              exportPng: () async => true,
              exportPngBytes: () async => base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
              ),
            );
          };
          final source = language == 'mermaid'
              ? 'graph TD; A-->B'
              : '<svg viewBox="0 0 20 20"><circle r="5"/></svg>';
          final markdown = '```$language\n\n$source\n\n```';
          final showExport = ValueNotifier(false);
          addTearDown(showExport.dispose);
          final hostKey = GlobalKey();
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
              child: MaterialApp(
                theme: dark ? ThemeData.dark() : ThemeData.light(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    key: hostKey,
                    builder: (_) => ValueListenableBuilder(
                      valueListenable: showExport,
                      builder: (_, show, __) => show
                          ? ExportCaptureScope(
                              enabled: true,
                              child: MarkdownWithCodeHighlight(text: markdown),
                            )
                          : const SizedBox(),
                    ),
                  ),
                ),
              ),
            ),
          );
          final diagrams = extractDiagramCodes(markdown);
          final rendering = preRenderDiagramCodesForExport(
            hostKey.currentContext!,
            [...diagrams, ...diagrams],
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await rendering;
          expect(rendered, [(code: source, isSvg: language != 'mermaid')]);

          // A subsequent export reuses the same cache instead of another WebView.
          await preRenderDiagramCodesForExport(
            hostKey.currentContext!,
            diagrams,
          );
          expect(rendered, hasLength(1));
          showExport.value = true;
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsOneWidget);
          expect(find.byType(SelectableHighlightView), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
