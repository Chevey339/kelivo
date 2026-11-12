import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/utils/svg_image_provider.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/markdown/math_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';

Widget _host(Widget child, {SettingsProvider? settings, bool dark = false}) =>
    ChangeNotifierProvider.value(
      value: settings ?? SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SelectionArea(child: child)),
      ),
    );

void main() {
  for (final supplied in [false, true]) {
    testWidgets(
      'SVG viewer refreshes cached colors on theme change, supplied=$supplied',
      (tester) async {
        final source = Uri.dataFromString(
          '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="currentColor"/></svg>',
          mimeType: 'image/svg+xml',
        ).toString();
        var dark = true;
        late StateSetter rebuild;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: ImageViewerPage(
                  images: [source],
                  imageProviders: {
                    if (supplied)
                      source: SvgImageProvider(
                        source,
                        currentColor: ThemeData.dark().colorScheme.onSurface,
                      ),
                  },
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        SvgImageProvider provider() =>
            (tester.widgetList<Image>(find.byType(Image)).first.image
                        as SafeResizeImage)
                    .imageProvider
                as SvgImageProvider;
        final initial = provider();
        rebuild(() => dark = false);
        await tester.pumpAndSettle();
        final expected = Theme.of(
          tester.element(find.byType(ImageViewerPage)),
        ).colorScheme.onSurface;
        expect(provider().currentColor, expected);
        expect(provider(), isNot(initial));
        final png = await tester.runAsync(() => provider().pngBytes());
        expect(png, isNotEmpty);
      },
    );
  }

  testWidgets('SVG Markdown loads in the message and opens the image viewer', (
    tester,
  ) async {
    final source = Uri.dataFromString(
      '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="32"><rect width="64" height="32" fill="blue"/></svg>',
      mimeType: 'image/svg+xml',
    ).toString();
    await tester.pumpWidget(
      _host(MarkdownWithCodeHighlight(text: '![64x32]($source)')),
    );
    Future<void> waitForImage() async {
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        if (tester
            .widgetList<RawImage>(find.byType(RawImage))
            .any((image) => image.image != null)) {
          return;
        }
      }
      fail('SVG did not decode into a visible image');
    }

    await waitForImage();
    expect(tester.getSize(find.byType(Image).first), const Size(64, 32));
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewerPage), findsOneWidget);
    final viewer = tester.widget<ImageViewerPage>(find.byType(ImageViewerPage));
    expect(viewer.imageProviders[source], isA<SvgImageProvider>());
    final surface = find.byKey(const ValueKey('image-viewer-svg-surface-0'));
    expect(
      tester.widget<ColoredBox>(surface).color,
      Theme.of(tester.element(surface)).colorScheme.surface,
    );
    await waitForImage();
    expect(tester.takeException(), isNull);
  });

  testWidgets('highlight has themed paint and preserves all copy formats', (
    tester,
  ) async {
    final selection = MarkstreamSelectionController();
    addTearDown(selection.dispose);
    Color? previousBackground;
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        _host(
          MarkstreamSelectionScope(
            controller: selection,
            child: const MarkdownWithCodeHighlight(
              text: 'Before ==**marked**== After',
            ),
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pumpAndSettle();
      expect(selection.selectedPlainText, 'Before marked After');
      expect(selection.selectedMarkdown, 'Before ==**marked**== After');
      expect(
        toHtml(selection.selectedDocuments.single),
        contains('<mark><strong>marked</strong></mark>'),
      );
      TextStyle? style;
      void visit(InlineSpan span, TextStyle inherited) {
        final effective = inherited.merge(span.style);
        if (span is TextSpan) {
          if (span.text == 'marked') style = effective;
          for (final child in span.children ?? <InlineSpan>[]) {
            visit(child, effective);
          }
        }
      }

      visit(markdownParagraph(tester, 'marked').text, const TextStyle());
      expect(style?.backgroundColor, isNotNull);
      expect(style?.fontWeight, isNot(FontWeight.normal));
      if (previousBackground != null) {
        expect(style!.backgroundColor, isNot(previousBackground));
      }
      previousBackground = style!.backgroundColor;
    }
  });

  testWidgets('closed math fences render and copy the original code syntax', (
    tester,
  ) async {
    final selection = MarkstreamSelectionController();
    addTearDown(selection.dispose);
    const source = 'Before\n\n```math\nx^2 + y^2\n```\n\nAfter';
    await tester.pumpWidget(
      _host(
        MarkstreamSelectionScope(
          controller: selection,
          child: const MarkdownWithCodeHighlight(text: source),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsOneWidget);
    expect(find.byType(MarkstreamCodeBlock), findsNothing);
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selection.selectedPlainText, 'Before\n\nx^2 + y^2\n\nAfter');
    expect(selection.selectedMarkdown, source);
  });

  testWidgets(
    'math fences honor settings and keep incomplete or invalid code readable',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      addTearDown(settings.dispose);
      for (final source in [
        '```math\nx^2',
        '```math\n\n```',
        '```math\n\\notARealMacro{x}\n```',
      ]) {
        await tester.pumpWidget(
          _host(
            MarkdownWithCodeHighlight(text: source, streaming: true),
            settings: settings,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Math), findsNothing);
        expect(find.byType(MarkstreamCodeBlock), findsOneWidget);
      }
      await settings.setEnableMathRendering(false);
      await tester.pumpWidget(
        _host(
          const MarkdownWithCodeHighlight(text: '```math\nx^2\n```'),
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Math), findsNothing);
      expect(find.byType(MarkstreamCodeBlock), findsOneWidget);
    },
  );

  testWidgets('callout custom titles render outside the selectable body', (
    tester,
  ) async {
    final selection = MarkstreamSelectionController();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      _host(
        MarkstreamSelectionScope(
          controller: selection,
          child: const MarkdownWithCodeHighlight(
            text: '> [!note] Custom &amp; title\n> Body',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Custom & title'), findsOneWidget);
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    expect(selection.selectedPlainText, 'Body');
    expect(selection.selectedMarkdown, '> [!NOTE] Custom &amp; title\n> Body');
  });

  testWidgets('cached formulas keep independent size, color and math style', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    addTearDown(settings.dispose);
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Column(
              children: [
                const KelivoMathRenderer().build(
                  context,
                  'x^2',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  displayMode: false,
                ),
                const KelivoMathRenderer().build(
                  context,
                  'x^2',
                  style: const TextStyle(color: Colors.blue, fontSize: 24),
                  displayMode: true,
                ),
              ],
            ),
          ),
          settings: settings,
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      final formulas = tester.widgetList<Math>(find.byType(Math)).toList();
      expect(formulas, hasLength(2));
      expect(formulas[0].ast, isNot(same(formulas[1].ast)));
      expect(formulas[0].textStyle!.color, Colors.red);
      expect(formulas[1].textStyle!.color, Colors.blue);
      expect(formulas[0].mathStyle, MathStyle.text);
      expect(formulas[1].mathStyle, MathStyle.display);
      expect(
        tester.getSize(find.byType(Math).at(1)).height,
        greaterThan(tester.getSize(find.byType(Math).at(0)).height),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
