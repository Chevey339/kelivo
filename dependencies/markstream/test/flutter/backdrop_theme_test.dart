import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'markstream_view_test.dart' show host;

void main() {
  for (final brightness in Brightness.values) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    );
    test('plain palette preserves every legacy color ($brightness)', () {
      final p = MarkstreamTheme.fromColorScheme(scheme).colors;
      final on = scheme.onSurface;
      final tint = dark ? Colors.white : on;
      expect(
        [
          p.ink,
          p.ink2,
          p.ink3,
          p.border,
          p.divider,
          p.borderStrong,
          p.fillBlock,
          p.fillHead,
          p.fillInline,
          p.quoteBar,
          p.accent,
          p.surface,
          p.tip,
          p.warning,
          p.danger,
          p.important,
        ],
        [
          on,
          on.withValues(alpha: dark ? .70 : .72),
          on.withValues(alpha: dark ? .48 : .50),
          tint.withValues(alpha: .10),
          tint.withValues(alpha: .07),
          tint.withValues(alpha: dark ? .32 : .30),
          Color.alphaBlend(
            Colors.white.withValues(alpha: dark ? .04 : .70),
            scheme.surface,
          ),
          tint.withValues(alpha: dark ? .06 : .04),
          tint.withValues(alpha: dark ? .10 : .06),
          tint.withValues(alpha: dark ? .20 : .14),
          scheme.primary,
          scheme.surface,
          Color(dark ? 0xff75dfa3 : 0xff16a34a),
          Color(dark ? 0xffffd17b : 0xffb45309),
          scheme.error,
          scheme.tertiary,
        ],
      );
      expect(p.fillBlockOpaque, p.fillBlock);
      expect(p.fillRaised, scheme.surface);
    });
    test('backdrop tokens and value equality ($brightness)', () {
      MarkstreamTheme make(MarkstreamBackdrop backdrop, [double mask = 1]) =>
          MarkstreamTheme.fromColorScheme(
            scheme,
            backdrop: backdrop,
            maskStrength: mask,
          );
      final wallpaper = make(MarkstreamBackdrop.wallpaper);
      expect(wallpaper.colors.fillBlock.a, closeTo(dark ? .74 : .80, 1e-12));
      expect(
        make(MarkstreamBackdrop.wallpaper, 0).colors.fillBlock.a,
        closeTo(dark ? .84 : .90, 1e-12),
      );
      expect(make(MarkstreamBackdrop.wallpaper, 2), wallpaper);
      expect(
        make(MarkstreamBackdrop.plain, 0),
        make(MarkstreamBackdrop.plain, 2),
      );
      expect(
        make(MarkstreamBackdrop.frostedBubble).colors.fillBlock,
        scheme.surface.withValues(alpha: dark ? .36 : .42),
      );
      expect(
        make(MarkstreamBackdrop.solidBubble).colors.fillBlock,
        (dark ? Colors.white : scheme.onSurface).withValues(
          alpha: dark ? .05 : .035,
        ),
      );
      for (final kind in MarkstreamBackdrop.values) {
        final a = make(kind), b = make(kind);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a.copyWith(colors: a.colors.copyWith()), a);
        expect(a.colors.fillBlockOpaque.a, 1);
        expect(
          a.copyWith(backdrop: MarkstreamBackdrop.values[(kind.index + 1) % 4]),
          isNot(a),
        );
        expect(a.colors.copyWith(fillRaised: Colors.red), isNot(a.colors));
        expect(a.colors.copyWith(fillBlockOpaque: Colors.red), isNot(a.colors));
      }
    });
    test('block ink stays paired with its surface ($brightness)', () {
      final bodyInk = dark ? Colors.black : Colors.white;
      for (final backdrop in MarkstreamBackdrop.values) {
        final theme = MarkstreamTheme.fromColorScheme(
          scheme,
          bodyStyle: TextStyle(color: bodyInk),
          backdrop: backdrop,
        );
        expect(theme.body.color, bodyInk);
        expect(theme.code.text.color, scheme.onSurface);
        expect(theme.table.heading.color, scheme.onSurface);
        expect(theme.colors.ink, scheme.onSurface);
        final inheritedInk = backdrop == MarkstreamBackdrop.plain
            ? scheme.onSurface
            : bodyInk;
        expect(theme.proseInk, inheritedInk);
        expect(
          theme.quote.textColor,
          inheritedInk.withValues(alpha: dark ? .70 : .72),
        );
        expect(theme.headings.last.color, theme.quote.textColor);
        expect(
          theme.task.checkedText.color,
          inheritedInk.withValues(alpha: theme.colors.ink3.a),
        );
        final content = theme.blockContentTheme;
        expect(content.body.color, scheme.onSurface);
        expect(content.proseInk, scheme.onSurface);
        expect(content.headings.first.color, scheme.onSurface);
        expect(content.quote.textColor, content.colors.ink2);
        expect(content.task.checkedText.color, content.colors.ink3);
        expect(content.blockContentTheme, same(content));
      }
    });
    testWidgets(
      'wallpaper table capture composites an opaque header ($brightness)',
      (tester) async {
        final theme = MarkstreamTheme.fromColorScheme(
          scheme,
          backdrop: MarkstreamBackdrop.wallpaper,
        );
        late TableActionContext action;
        await tester.pumpWidget(
          host(
            MarkstreamView(
              source: '| Name | Value |\n| --- | --- |\n| one | two |',
              theme: theme,
              extensions: MarkstreamExtensions(
                tableExtraActions: (_, a) {
                  action = a;
                  return const [];
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final capture = action.capturePng(1);
        await tester.pump();
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(await capture);
          final frame = await codec.getNextFrame();
          final pixels = (await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final expected = Color.alphaBlend(
            theme.colors.fillHead,
            theme.colors.fillBlockOpaque,
          );
          final offset =
              (3 * frame.image.width + frame.image.width ~/ 2 - 4) * 4;
          expect(
            [for (var i = 0; i < 4; i++) pixels.getUint8(offset + i)],
            [
              (expected.r * 255).round(),
              (expected.g * 255).round(),
              (expected.b * 255).round(),
              255,
            ],
          );
          frame.image.dispose();
          codec.dispose();
        });
        await tester.pumpAndSettle();
        expect(
          tester.widget<MarkstreamView>(find.byType(MarkstreamView)).theme,
          theme,
        );
      },
    );
  }

  testWidgets('cached details use the latest document with their own ink', (
    tester,
  ) async {
    final source = ValueNotifier(
      '<details>\n<summary>Fold</summary>\n\nInside\n\n</details>\n\nTail',
    );
    addTearDown(source.dispose);
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final theme = MarkstreamTheme.fromColorScheme(
      scheme,
      bodyStyle: const TextStyle(color: Colors.white),
      backdrop: MarkstreamBackdrop.wallpaper,
    );
    DocumentNode? renderedDocument;
    Color? renderedInk;
    final extensions = MarkstreamExtensions(
      nodeBuilders: NodeBuilderRegistry(
        blocks: {
          ParagraphNode: (context, node, rendering) {
            final text = toPlainText(node);
            if (text == 'Inside') {
              renderedDocument = rendering.document;
              renderedInk = rendering.theme.body.color;
            }
            return Text(text, style: rendering.theme.body);
          },
        },
      ),
    );
    await tester.pumpWidget(
      host(
        ValueListenableBuilder<String>(
          valueListenable: source,
          builder: (_, value, _) => MarkstreamView(
            source: value,
            streaming: true,
            theme: theme,
            extensions: extensions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderedDocument, isNull);
    source.value += '\n\nNew tail';
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fold'));
    await tester.pumpAndSettle();
    expect(renderedDocument?.source, source.value);
    expect(renderedInk, scheme.onSurface);
    expect(tester.takeException(), isNull);
  });
}
