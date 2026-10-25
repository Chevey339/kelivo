import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/highlight_adapter.dart';
import 'package:Kelivo/shared/markdown/kelivo_markdown_extensions.dart';
import 'package:Kelivo/shared/markdown/markdown_surface_scope.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/widgets/plantuml_block.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';
import 'package:Kelivo/theme/palettes.dart';

import '../../support/business_test_harness.dart';
import '../../support/markdown_backdrop_host.dart';

double _contrast(Color ink, Color background) {
  final a = Color.alphaBlend(ink, background).computeLuminance();
  final b = background.computeLuminance();
  return a >= b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

Iterable<TextSpan> _spans(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* _spans(child);
  }
}

Future<TextSpan> _highlight(MarkstreamCodeBlock code) async =>
    code.highlighter!.highlight(
      code.node.code,
      language: code.node.info,
      style: code.theme.code.text,
      brightness: code.theme.brightness,
    );

const _source =
    'Body\n\n```dart\n// comment\nfinal count = 1;\n```\n\n'
    '| Header |\n| --- |\n| Cell |';

Future<MarkstreamCodeBlock> _mount(
  WidgetTester tester,
  SettingsProvider settings,
  ColorScheme scheme, {
  String source = _source,
  bool wallpaper = true,
  bool user = false,
  bool exporting = false,
}) async {
  Widget child = SingleChildScrollView(
    child: Builder(
      builder: (context) => buildSharedChatSurface(
        context,
        isUser: user,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(12),
        defaultColor: user
            ? scheme.primary.withValues(
                alpha: scheme.brightness == Brightness.dark ? .15 : .08,
              )
            : null,
        bareOnDefault: !user,
        child: MarkdownWithCodeHighlight(text: source),
      ),
    ),
  );
  if (wallpaper) child = MarkdownWallpaperTestHost(child: child);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        theme: ThemeData(colorScheme: scheme, brightness: scheme.brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExportCaptureScope(enabled: exporting, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return tester.widget<MarkstreamCodeBlock>(find.byType(MarkstreamCodeBlock));
}

void main() {
  for (final dark in [false, true]) {
    final scheme = dark
        ? ThemePalettes.defaultPalette.dark
        : ThemePalettes.defaultPalette.light;
    testWidgets('real bubble contexts retain contrast, dark=$dark', (
      tester,
    ) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      addTearDown(settings.dispose);
      for (final sample in [
        (
          ChatMessageBackgroundStyle.defaultStyle,
          1.0,
          MarkstreamBackdrop.wallpaper,
        ),
        (
          ChatMessageBackgroundStyle.frosted,
          .66,
          MarkstreamBackdrop.frostedBubble,
        ),
        (ChatMessageBackgroundStyle.frosted, .2, MarkstreamBackdrop.wallpaper),
        (ChatMessageBackgroundStyle.solid, .5, MarkstreamBackdrop.wallpaper),
        (
          ChatMessageBackgroundStyle.solid,
          .8,
          MarkstreamBackdrop.frostedBubble,
        ),
        (ChatMessageBackgroundStyle.solid, 1.0, MarkstreamBackdrop.solidBubble),
      ]) {
        final (style, opacity, expected) = sample;
        final overrides = ChatBubbleStyleOverrides(
          frostedOpacity: opacity,
          solidOpacity: opacity,
        );
        await settings.setChatMessageBackgroundStyle(style);
        await settings.setChatBubbleStyleOverrides(overrides);
        final user = style == ChatMessageBackgroundStyle.defaultStyle;
        for (final mask in [0.0, 1.0, 2.0]) {
          await settings.setChatBackgroundMaskStrength(mask);
          final code = await _mount(tester, settings, scheme, user: user);
          expect(code.theme.backdrop, expected);
          final comment = _spans(await _highlight(code))
              .firstWhere((s) => s.style?.fontStyle == FontStyle.italic)
              .style!
              .color!;
          final bubble = user
              ? scheme.primary.withValues(alpha: dark ? .15 : .08)
              : resolveBubbleStyle(
                  scheme,
                  scheme.brightness,
                  style,
                  overrides,
                ).background;
          for (final wallpaper in [Colors.black, Colors.white, Colors.grey]) {
            final background = Color.alphaBlend(
              code.theme.colors.fillBlock,
              Color.alphaBlend(bubble, wallpaper),
            );
            final reason = '$sample mask=$mask wallpaper=$wallpaper';
            expect(
              _contrast(code.theme.colors.ink, background),
              greaterThanOrEqualTo(7),
              reason: reason,
            );
            expect(
              _contrast(comment, background),
              greaterThanOrEqualTo(4.5),
              reason: reason,
            );
            expect(
              _contrast(code.theme.table.body.color!, background),
              greaterThanOrEqualTo(4.5),
              reason: reason,
            );
            expect(
              _contrast(code.theme.colors.ink3, background),
              greaterThanOrEqualTo(3),
              reason: reason,
            );
          }
        }
      }
    });

    testWidgets(
      'custom bubble colors pair ink, syntax and opaque capture, dark=$dark',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(settings.dispose);
        const overrides = ChatBubbleStyleOverrides(
          backgroundArgbLight: 0xff000000,
          textArgbLight: 0xffffffff,
          backgroundArgbDark: 0xffffffff,
          textArgbDark: 0xff000000,
        );
        await settings.setChatBubbleStyleOverrides(overrides);
        MarkstreamTheme? captureTheme;
        for (final style in [
          ChatMessageBackgroundStyle.frosted,
          ChatMessageBackgroundStyle.solid,
        ]) {
          await settings.setChatMessageBackgroundStyle(style);
          for (final wallpaper in [false, true]) {
            final code = await _mount(
              tester,
              settings,
              scheme,
              wallpaper: wallpaper,
            );
            final customInk = dark ? Colors.black : Colors.white;
            expect(code.theme.body.color, customInk);
            expect(
              code.theme.code.text.color,
              wallpaper ? customInk : scheme.onSurface,
            );
            expect(
              code.theme.brightness,
              wallpaper
                  ? (dark ? Brightness.light : Brightness.dark)
                  : scheme.brightness,
            );
            expect(code.theme.colors.fillBlockOpaque.a, 1);
            final bubble = resolveBubbleStyle(
              scheme,
              scheme.brightness,
              style,
              overrides,
            ).background;
            final keyword = _spans(await _highlight(code))
                .firstWhere(
                  (s) => s.toPlainText() == 'final' && s.style?.color != null,
                )
                .style!
                .color!;
            for (final underlay in [Colors.black, Colors.white]) {
              final background = Color.alphaBlend(
                code.theme.colors.fillBlock,
                Color.alphaBlend(bubble, underlay),
              );
              expect(
                _contrast(code.theme.colors.ink, background),
                greaterThanOrEqualTo(7),
              );
              expect(_contrast(keyword, background), greaterThanOrEqualTo(4.5));
              expect(
                _contrast(code.theme.table.body.color!, background),
                greaterThanOrEqualTo(4.5),
              );
            }
            if (wallpaper) captureTheme = code.theme;
          }
        }
        final exported = await _mount(
          tester,
          settings,
          scheme,
          exporting: true,
        );
        expect(exported.theme.backdrop, MarkstreamBackdrop.plain);
        expect(exported.theme.brightness, scheme.brightness);
        expect(exported.theme.colors.ink, scheme.onSurface);
        expect(
          exported.theme.colors.fillBlock,
          MarkstreamTheme.fromColorScheme(scheme).colors.fillBlock,
        );

        late TableActionContext action;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MarkstreamView(
                source: '| Header |\n| --- |\n| Cell |',
                theme: captureTheme,
                extensions: MarkstreamExtensions(
                  tableExtraActions: (_, value) {
                    action = value;
                    return const [];
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final capture = action.capturePng(1);
        await tester.pump();
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(await capture);
          final image = (await codec.getNextFrame()).image;
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final expected = Color.alphaBlend(
            captureTheme!.colors.fillHead,
            captureTheme.colors.fillBlockOpaque,
          );
          final offset = (3 * image.width + image.width ~/ 2 - 4) * 4;
          expect(
            [for (var i = 0; i < 4; i++) pixels.getUint8(offset + i)],
            [
              (expected.r * 255).round(),
              (expected.g * 255).round(),
              (expected.b * 255).round(),
              255,
            ],
          );
          image.dispose();
          codec.dispose();
        });
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'extension code paths choose the resolved highlighter, dark=$dark',
      (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(settings.dispose);
        for (final language in ['html', 'htm', 'rawhtml', 'raw_html', 'xml']) {
          final code = await _mount(
            tester,
            settings,
            scheme,
            source: '```$language\n<!-- comment -->\n<div>text</div>\n```',
          );
          expect(
            code.highlighter,
            same(KelivoCodeHighlighter.forTheme(code.theme)),
          );
          final highlighted = await _highlight(code);
          expect(highlighted.toPlainText(), code.node.code);
          // These aliases already fall back to plain text; keep that behavior.
          if (language != 'html' && language != 'xml') continue;
          final comment = _spans(highlighted)
              .firstWhere((s) => s.style?.fontStyle == FontStyle.italic)
              .style!
              .color!;
          for (final wallpaper in [Colors.black, Colors.white]) {
            expect(
              _contrast(
                comment,
                Color.alphaBlend(code.theme.colors.fillBlock, wallpaper),
              ),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
        final document = const MarkdownParser().parse(
          '```plantuml\nAlice -> Bob\n```',
        );
        final theme = MarkstreamTheme.fromColorScheme(
          scheme,
          backdrop: MarkstreamBackdrop.wallpaper,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final plantuml =
                    kelivoMarkdownExtensions.codeBlockBuilders['plantuml']!(
                          context,
                          document.children.single as CodeBlockNode,
                          MarkstreamRenderContext(
                            document: document,
                            theme: theme,
                            streaming: false,
                            buildBlock: (_) => throw StateError('unused'),
                            buildInline: (_, _) => throw StateError('unused'),
                          ),
                        )
                        as PlantUMLBlock;
                // Inspect the real callback without starting a remote SVG request.
                final content =
                    plantuml.codeBuilder!(context) as MarkstreamCodeContent;
                expect(
                  content.highlighter,
                  same(KelivoCodeHighlighter.forTheme(theme)),
                );
                return const SizedBox();
              },
            ),
          ),
        );
      },
    );
  }

  testWidgets(
    'custom background changes notify even when surface kind stays equal',
    (tester) async {
      final background = ValueNotifier(Colors.black);
      addTearDown(background.dispose);
      var builds = 0;
      Color? resolved;
      final child = Builder(
        builder: (context) {
          builds++;
          resolved = MarkdownSurfaceScope.maybeOf(context)?.customBackground;
          return const SizedBox();
        },
      );
      await tester.pumpWidget(
        ValueListenableBuilder<Color>(
          valueListenable: background,
          builder: (_, color, _) => MarkdownSurfaceScope(
            kind: MarkdownSurfaceKind.solid,
            customBackground: color,
            child: child,
          ),
        ),
      );
      expect(builds, 1);
      background.value = Colors.white;
      await tester.pump();
      expect(builds, 2);
      expect(resolved, Colors.white);
    },
  );
}
