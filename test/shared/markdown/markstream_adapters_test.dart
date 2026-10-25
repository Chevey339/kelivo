import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/citation_syntax.dart';
import 'package:Kelivo/shared/markdown/highlight_adapter.dart';
import 'package:Kelivo/shared/markdown/link_image_handlers.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/markdown/math_adapter.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import '../../support/business_test_harness.dart';

Widget host(
  Widget child, {
  SettingsProvider? settings,
  bool dark = false,
  double width = 390,
  Locale locale = const Locale('en'),
}) => ChangeNotifierProvider.value(
  value: settings ?? SettingsProvider(createBusinessTestPreferences()),
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    home: AppSnackBarOverlay(
      child: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);
List<MarkdownNode> nodes(MarkdownNode root) {
  final result = <MarkdownNode>[], pending = [root];
  while (pending.isNotEmpty) {
    final node = pending.removeLast();
    result.add(node);
    pending.addAll(node.children.reversed);
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('directive cards follow the app locale when it changes', (
    tester,
  ) async {
    for (final pair in [
      (const Locale('en'), 'Note'),
      (const Locale('zh'), '备注'),
      (const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'), '备注'),
      (const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), '備註'),
    ]) {
      await tester.pumpWidget(
        host(
          const MarkdownWithCodeHighlight(text: '> [!NOTE]\n> Body'),
          locale: pair.$1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarkstreamDirectiveCard), findsOneWidget);
      expect(find.text(pair.$2), findsOneWidget);
    }
  });
  testWidgets('app wrapper forwards source ranges and highlight color', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const MarkdownWithCodeHighlight(
          text: '**Search** result',
          highlightRanges: [SourceSpan(2, 8)],
          highlightColor: Colors.amber,
        ),
      ),
    );
    final view = tester.widget<MarkstreamView>(find.byType(MarkstreamView));
    expect(view.highlightRanges, const [SourceSpan(2, 8)]);
    expect(view.highlightColor, Colors.amber);
  });
  final parser = MarkdownParser(
    inlineSyntaxes: const [CitationSyntax(), LocalImagePathSyntax()],
  );
  for (final marker in [
    '[cite:abc]',
    '[cite:abc,def]',
    '[citation](abc)',
    '[citation](3:abc)',
    '[citation:abc]',
    '[citation:1:abc,citation:2:def]',
  ]) {
    test('citation marker preserves mapped source: $marker', () {
      final source = '> before $marker after';
      final node = nodes(
        parser.parse(source),
      ).whereType<NamedInlineNode>().single;
      expect(source.substring(node.span.start, node.span.end), marker);
      expect(toPlainText(node), marker);
    });
  }
  test(
    'plain bracket numbers stay text and nested numbered links remain links',
    () {
      final doc = parser.parse('[1] [[2]](https://example.com)');
      expect(nodes(doc).whereType<NamedInlineNode>(), isEmpty);
      expect(
        nodes(doc).whereType<LinkNode>().single.destination,
        'https://example.com',
      );
      expect(toPlainText(doc), '[1] 2');
    },
  );
  test(
    'citation grammar excludes code, formulas, escaped and unfinished markers',
    () {
      final doc = parser.parse(
        '`[cite:a]`\n\n```\n[cite:b]\n```\n\n'
        r'$\text{[cite:c]}$ \[cite:d] [cite:e',
      );
      expect(nodes(doc).whereType<NamedInlineNode>(), isEmpty);
      expect(
        toPlainText(doc.children.last),
        r'$\text{[cite:c]}$ [cite:d] [cite:e',
      );
    },
  );
  test(
    'local image paths keep spaces, parentheses, titles and source spans',
    () {
      const source = '> ![image](/tmp/my folder/a (copy).png "Caption")';
      final image = nodes(parser.parse(source)).whereType<ImageNode>().single;
      expect(image.destination, '/tmp/my folder/a (copy).png');
      expect(image.title, 'Caption');
      expect(
        source.substring(image.span.start, image.span.end),
        source.substring(2),
      );
      expect(toPlainText(image), 'image');
      expect(
        nodes(parser.parse('`![image](/tmp/a b.png)`')).whereType<ImageNode>(),
        isEmpty,
      );
    },
  );
  test('local image titles and escaped alt labels keep their structure', () {
    const source = r'![**image** \]](/tmp/my folder/a.png "Title ) suffix")';
    final node = nodes(parser.parse(source)).whereType<ImageNode>().single;
    expect(node.destination, '/tmp/my folder/a.png');
    expect(node.title, 'Title ) suffix');
    expect(toPlainText(node), 'image ]');
  });
  test(
    'highlight trees survive aliases and themes, and errors retain source',
    () {
      debugResetHighlightNodeCache();
      const highlighter = KelivoCodeHighlighter();
      const source = 'const value = 42;';
      final light = highlighter.highlight(
        source,
        language: 'js',
        style: const TextStyle(fontSize: 13),
        brightness: Brightness.light,
      );
      final dark = highlighter.highlight(
        source,
        language: 'javascript',
        style: const TextStyle(fontSize: 13),
        brightness: Brightness.dark,
      );
      expect(light.toPlainText(), source);
      expect(dark.toPlainText(), source);
      expect(debugHighlightParseCount, 1);
      expect(
        highlighter
            .highlight(
              source,
              language: 'unknown-language',
              style: const TextStyle(),
              brightness: Brightness.dark,
            )
            .toPlainText(),
        source,
      );
    },
  );
  test('SVG reuses styled XML syntax trees', () {
    debugResetHighlightNodeCache();
    const highlighter = KelivoCodeHighlighter();
    const code = '<svg><rect /></svg>';
    for (final language in ['svg', 'xml']) {
      final span = highlighter.highlight(
        code,
        language: language,
        style: const TextStyle(),
        brightness: Brightness.light,
      );
      expect(span.toPlainText(), code);
      expect(span.children, isNotEmpty);
    }
    expect(debugHighlightParseCount, 1);
  });
  test('math normalization repairs visuals and preserves color arguments', () {
    expect(normalizeMathTex(r'\# + #'), r'\# + \#');
    expect(
      normalizeMathTex(r'\textcolor{#aabbcc}{x}'),
      r'\textcolor{#aabbcc}{x}',
    );
    expect(normalizeMathTex(r'{a,b}'), r'\{a,b\}');
    expect(normalizeMathTex(r'\frac{a,b}{c}'), r'\frac{a,b}{c}');
    expect(normalizeMathTex(r'\|x\|'), r'\lVert x \rVert');
  });
  test('image providers support local files with spaces and data URLs', () {
    const data =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS9sAAAAASUVORK5CYII=';
    final provider = markdownImageProvider(data) as MemoryImage;
    expect(provider.bytes, isNotEmpty);
    final dir = Directory.systemTemp.createTempSync('markstream images ');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/image one.png')
      ..writeAsBytesSync(provider.bytes);
    expect(
      (markdownImageProvider(file.uri.toString()) as FileImage).file.path,
      file.path,
    );
    expect(markdownImageProvider('data:image/png;base64,invalid!'), isNull);
    expect(
      markdownImageProvider('https://example.com/a.png'),
      isA<NetworkImage>(),
    );
  });
  testWidgets(
    'citations update indices and taps without recreating the view or losing source selection',
    (tester) async {
      final selection = MarkstreamSelectionController();
      addTearDown(selection.dispose);
      final taps = <String>[];
      Widget content(String index) => MarkstreamSelectionScope(
        controller: selection,
        child: SelectionArea(
          child: MarkdownWithCodeHighlight(
            text: 'Before [cite:abc,def] after [1]',
            citationIndexResolver: (id) => id == 'abc' ? index : '4',
            onCitationTap: taps.add,
          ),
        ),
      );
      await tester.pumpWidget(host(content('2')));
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(MarkstreamView));
      await tester.tap(find.text('2'));
      expect(taps, ['abc']);
      await tester.pumpWidget(host(content('9')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MarkstreamView)), same(state));
      expect(find.text('9'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selection.selectedPlainText, 'Before [cite:abc,def] after [1]');
      expect(selection.selectedMarkdown, contains('[cite:abc,def]'));
    },
  );
  testWidgets('settings map math switches, font weights and code options', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setEnableDollarLatex(false);
    await settings.setAutoCollapseCodeBlock(true);
    await settings.setMobileCodeBlockWrap(true);
    await tester.pumpWidget(
      host(
        const MarkdownWithCodeHighlight(
          text: r'$x$ \(y\)',
          baseStyle: TextStyle(
            fontSize: 21,
            fontFamily: 'CallerFace',
            fontFamilyFallback: ['CallerCjk'],
          ),
        ),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    var view = tester.widget<MarkstreamView>(find.byType(MarkstreamView));
    expect(view.options.inlineMath, isTrue);
    expect(view.options.dollarInlineMath, isFalse);
    expect(view.theme!.body.fontSize, 21);
    for (final style in [
      view.theme!.body,
      ...view.theme!.headings,
      view.theme!.inlineCode.text,
      view.theme!.code.text,
    ]) {
      expect(style.fontFamilyFallback, ['CallerCjk']);
    }
    expect(view.theme!.strongWeight, AppFontWeights.strong);
    expect(view.codeOptions.autoCollapse, isTrue);
    expect(view.codeOptions.mobileWrap, isTrue);
    await settings.setEnableMathRendering(false);
    await tester.pumpAndSettle();
    view = tester.widget<MarkstreamView>(find.byType(MarkstreamView));
    expect(view.options.inlineMath, isFalse);
    expect(view.options.mathBlocks, isFalse);
  });
  testWidgets(
    'streaming retains parser inputs and cached prefix widgets through completion',
    (tester) async {
      const initial = '**prefix** `prefix-code`\n\nlast';
      await tester.pumpWidget(
        host(const MarkdownWithCodeHighlight(text: initial, streaming: true)),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<MarkstreamView>(find.byType(MarkstreamView));
      final before = find
          .byType(RichText)
          .evaluate()
          .where(
            (e) =>
                (e.widget as RichText).text.toPlainText().startsWith('prefix '),
          )
          .single
          .widget;
      await tester.pumpWidget(
        host(
          const MarkdownWithCodeHighlight(
            text: '$initial more',
            streaming: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final after = tester.widget<MarkstreamView>(find.byType(MarkstreamView));
      expect(after.options, same(view.options));
      expect(after.extensions, same(view.extensions));
      final prefix = find
          .byType(RichText)
          .evaluate()
          .where(
            (e) =>
                (e.widget as RichText).text.toPlainText().startsWith('prefix '),
          )
          .single
          .widget;
      expect(prefix, same(before));
      await tester.pumpWidget(
        host(const MarkdownWithCodeHighlight(text: '$initial more')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('export scope disables culling', (tester) async {
    await tester.pumpWidget(
      host(
        const ExportCaptureScope(
          enabled: true,
          child: MarkdownWithCodeHighlight(text: '```dart\ncode();\n```'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final view = tester.widget<MarkstreamView>(find.byType(MarkstreamView));
    expect(view.exporting, isTrue);
    expect(view.cullToViewport, isFalse);
  });
  testWidgets('code, table and formulas share one selectable source document', (
    tester,
  ) async {
    final selection = MarkstreamSelectionController();
    addTearDown(selection.dispose);
    const source =
        '**Before**\n\n```dart\n  x();\n\n  y();\n```\n\n| A | B |\n| - | - |\n| 1 | 2 |\n\n'
        r'$x^2$'
        '\n\n\$\$\ny^2\n\$\$';
    await tester.pumpWidget(
      host(
        MarkstreamSelectionScope(
          controller: selection,
          child: const SelectionArea(
            child: MarkdownWithCodeHighlight(text: source),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableRegion), findsOneWidget);
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(
      selection.selectedPlainText,
      'Before\n\n  x();\n\n  y();\n\nA\tB\n1\t2\n\n'
      r'$x^2$'
      '\n\n\$\$\ny^2\n\$\$',
    );
    expect(selection.selectedMarkdown, contains('**Before**'));
    expect(selection.selectedMarkdown, contains('```dart'));
    expect(selection.selectedMarkdown, contains('\$\$\ny^2\n\$\$'));
  });
}
