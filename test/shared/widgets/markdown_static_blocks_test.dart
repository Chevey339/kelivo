import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart' show TexEncoderExt;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

const _source = r'''# Skill instructions

Keep **bold**, *italic*, ~~strikethrough~~ and `inline code`. Read [the documentation](https://example.com).

中文段落保留原来的换行和样式。 A paragraph with enough words to wrap onto several lines in the mobile preview.

## Nested and loose lists

1. First step
2. Second step
   - Nested item
   - Another item

- A loose item

- Another loose item

> Quote one
>
> Quote two

- [x] Completed
- [ ] Pending

---

```dart
// Keep code highlighting and blank lines.
final count = 42;

print(count);
```

| Input | Output |
| --- | --- |
| **bold** | `code` |
| Escaped \| pipe | Text |

Inline math $a + b$ and display math:

$$
\frac{a}{b}
$$

<details><summary>More information</summary>

Hidden **content**.

</details>

## Final paragraph

The end of the document retains the same spacing and card padding.''';

Future<Uint8List> _capture(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = boundary.toImageSync();
  try {
    final data = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

double _pixelError(Uint8List original, Uint8List optimized) {
  expect(optimized.length, original.length);
  var difference = 0;
  for (var i = 0; i < original.length; i++) {
    difference += (original[i] - optimized[i]).abs();
  }
  return difference / (original.length * 255);
}

Map<String, Rect> _glyphRects(WidgetTester tester) {
  final result = <String, Rect>{};
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    for (final label in [
      'Skill instructions',
      'Keep bold',
      '中文段落',
      'Nested and loose lists',
      'First step',
      'Quote one',
      'Completed',
      'Input',
      'Inline math',
      'Final paragraph',
      'The end of the',
    ]) {
      final index = text.indexOf(label);
      if (index < 0) continue;
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: index, extentOffset: index + 1),
          )
          .first
          .toRect();
      result[label] = Rect.fromPoints(
        paragraph.localToGlobal(box.topLeft),
        paragraph.localToGlobal(box.bottomRight),
      );
    }
  }
  for (final key in [
    'code-block-surface',
    'markdown-blockquote',
    'details-surface',
  ]) {
    result[key] = tester.getRect(find.byKey(ValueKey(key)));
  }
  result['table'] = tester.getRect(find.byType(Table));
  return result;
}

void main() {
  setUpAll(() async {
    final bytes = File(
      'dependencies/gpt_markdown/lib/fonts/JetBrainsMono-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      'skill-preview-metrics',
    )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const formula =
      r'说明文字 $$'
      '\na + b\n\nc + d\n'
      r'$$';
  final mathCases = {
    'reported source': formula,
    'surrounding paragraphs': 'Before\n\n$formula\n\nAfter',
    'prose after the closer': '$formula 后续文字',
    'inline delimiters':
        r'说明文字 $$a + b'
        '\n\n'
        r'c + d$$',
    'CRLF': formula.replaceAll('\n', '\r\n'),
    'code literals': '```text\n$formula\n```\n\n$formula',
  };
  for (final entry in mathCases.entries) {
    testWidgets('static preview preserves cross-paragraph math: ${entry.key}', (
      tester,
    ) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      addTearDown(settings.dispose);
      final source = entry.value;

      Future<void> pump(bool blocks) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MarkdownWithCodeHighlight(
                    text: source,
                    useBlockRendering: blocks,
                    baseStyle: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final options in [(true, true), (true, false), (false, true)]) {
        await settings.setEnableMathRendering(options.$1);
        await settings.setEnableDollarLatex(options.$2);
        await pump(false);
        final original = tester
            .widgetList<Math>(find.byType(Math))
            .map((math) => math.ast!.greenRoot.encodeTeX())
            .toList();
        expect(original, hasLength(options.$1 ? 1 : 0));
        final height = tester
            .getSize(find.byType(MarkdownWithCodeHighlight))
            .height;
        await pump(true);
        expect(
          tester
              .widgetList<Math>(find.byType(Math))
              .map((math) => math.ast!.greenRoot.encodeTeX()),
          original,
        );
        expect(
          tester.getSize(find.byType(MarkdownWithCodeHighlight)).height,
          height,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final disableMath in [false, true]) {
    testWidgets(
      'edited preview survives a math setting toggle: all=$disableMath',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(settings.dispose);
        final source = ValueNotifier(r'Original $x$');
        addTearDown(source.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ValueListenableBuilder<String>(
                    valueListenable: source,
                    builder: (_, text, _) => MarkdownWithCodeHighlight(
                      text: text,
                      useBlockRendering: true,
                      baseStyle: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester.state(find.byType(MarkdownWithCodeHighlight));
        expect(find.byType(Math), findsOneWidget);

        source.value += ' appended';
        await tester.pumpAndSettle();
        expect(
          tester.state(find.byType(MarkdownWithCodeHighlight)),
          same(state),
        );
        expect(find.byType(Math), findsOneWidget);
        if (disableMath) {
          await settings.setEnableMathRendering(false);
        } else {
          await settings.setEnableDollarLatex(false);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.state(find.byType(MarkdownWithCodeHighlight)),
          same(state),
        );
        expect(find.byType(Math), findsNothing);
        expect(
          tester
              .widgetList<RichText>(find.byType(RichText))
              .map((text) => text.text.toPlainText()),
          contains(source.value),
        );

        source.value += ' while disabled';
        await tester.pumpAndSettle();
        if (disableMath) {
          await settings.setEnableMathRendering(true);
        } else {
          await settings.setEnableDollarLatex(true);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.state(find.byType(MarkdownWithCodeHighlight)),
          same(state),
        );
        expect(find.byType(Math), findsOneWidget);
        expect(
          tester.widget<Math>(find.byType(Math)).ast!.greenRoot.encodeTeX(),
          contains('x'),
        );

        source.value = r'Replacement $y$';
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.state(find.byType(MarkdownWithCodeHighlight)),
          same(state),
        );
        expect(find.byType(Math), findsOneWidget);
        expect(
          tester.widget<Math>(find.byType(Math)).ast!.greenRoot.encodeTeX(),
          contains('y'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final width in [400.0, 688.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'static blocks preserve preview pixels at width=$width, $brightness',
        (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final settings = SettingsProvider(createBusinessTestPreferences());
          await settings.loaded;
          addTearDown(settings.dispose);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final capture = GlobalKey();

          Future<void> pump(bool blocks, double scale) async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settings,
                child: MaterialApp(
                  theme: brightness == Brightness.dark
                      ? buildDarkThemeForScheme(
                          ThemePalettes.defaultPalette.dark,
                        )
                      : buildLightThemeForScheme(
                          ThemePalettes.defaultPalette.light,
                        ),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: RepaintBoundary(
                    key: capture,
                    child: Scaffold(
                      body: Builder(
                        builder: (context) => MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: TextScaler.linear(scale)),
                          child: ListView(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            children: [
                              SectionCard(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  12,
                                ),
                                child: MarkdownWithCodeHighlight(
                                  text: _source,
                                  useBlockRendering: blocks,
                                  baseStyle: const TextStyle(
                                    fontFamily: 'skill-preview-metrics',
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          Future<List<Uint8List>> snapshots(double extent) async {
            final images = <Uint8List>[];
            for (final fraction in [0.0, .25, .5, .75, 1.0]) {
              controller.jumpTo(
                (extent * fraction).roundToDouble().clamp(0, extent),
              );
              await tester.pumpAndSettle();
              images.add(await _capture(tester, capture));
            }
            return images;
          }

          for (final scale in [1.0, 1.3]) {
            await pump(false, scale);
            final originalExtent = controller.position.maxScrollExtent;
            final originalHeight = tester
                .getSize(find.byType(MarkdownWithCodeHighlight))
                .height;
            final originalRects = _glyphRects(tester);
            final original = await snapshots(originalExtent);
            await pump(true, scale);
            expect(controller.position.maxScrollExtent, originalExtent);
            expect(
              tester.getSize(find.byType(MarkdownWithCodeHighlight)).height,
              originalHeight,
            );
            final optimizedRects = _glyphRects(tester);
            expect(originalRects.length, greaterThanOrEqualTo(14));
            expect(optimizedRects.keys, unorderedEquals(originalRects.keys));
            for (final label in originalRects.keys) {
              final before = originalRects[label]!;
              final after = optimizedRects[label]!;
              expect(after.left, closeTo(before.left, .1), reason: label);
              expect(after.top, closeTo(before.top, .1), reason: label);
              expect(after.width, closeTo(before.width, .1), reason: label);
              expect(after.height, closeTo(before.height, .1), reason: label);
            }
            final optimized = await snapshots(originalExtent);
            for (var i = 0; i < original.length; i++) {
              expect(
                // Separate retained layers can change subpixel antialiasing.
                // Check subpixel geometry separately and allow a small raster error.
                _pixelError(original[i], optimized[i]),
                lessThan(.005),
                reason: 'viewport $i changed at text scale $scale',
              );
            }
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
