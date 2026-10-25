import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/shared/markdown/highlight_adapter.dart';
import 'package:Kelivo/theme/palettes.dart';

Iterable<TextSpan> spans(TextSpan root) sync* {
  yield root;
  for (final child in root.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* spans(child);
  }
}

double contrast(Color foreground, Color background) {
  final visible = Color.alphaBlend(foreground, background);
  final a = visible.computeLuminance(), b = background.computeLuminance();
  return a >= b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

Color commentColor(MarkstreamTheme theme) {
  final span = KelivoCodeHighlighter.forTheme(theme).highlight(
    '// comment',
    language: 'dart',
    style: theme.code.text,
    brightness: theme.brightness,
  );
  return spans(span)
      .firstWhere(
        (s) =>
            s.toPlainText() == '// comment' &&
            s.style?.fontStyle == FontStyle.italic,
      )
      .style!
      .color!;
}

void main() {
  for (final dark in [false, true]) {
    final scheme = dark
        ? ThemePalettes.defaultPalette.dark
        : ThemePalettes.defaultPalette.light;
    test(
      'default palette contrast guards across all mask steps, dark=$dark',
      () {
        final plain = MarkstreamTheme.fromColorScheme(scheme);
        expect(commentColor(plain), Color(dark ? 0xff9da5b0 : 0xff57606a));
        expect(
          contrast(commentColor(plain), plain.colors.fillBlockOpaque),
          greaterThanOrEqualTo(4.5),
        );
        for (var step = 0; step <= 40; step++) {
          final theme = MarkstreamTheme.fromColorScheme(
            scheme,
            backdrop: MarkstreamBackdrop.wallpaper,
            maskStrength: step / 20,
          );
          expect(commentColor(theme), Color(dark ? 0xffbdc5d0 : 0xff4a525c));
          for (final background in [
            Colors.black,
            Colors.white,
            const Color(0xff808080),
          ]) {
            final block = Color.alphaBlend(theme.colors.fillBlock, background);
            final label = 'mask=${step / 20}, background=$background';
            expect(
              contrast(theme.colors.ink, block),
              greaterThanOrEqualTo(7),
              reason: label,
            );
            expect(
              contrast(commentColor(theme), block),
              greaterThanOrEqualTo(4.5),
              reason: label,
            );
            expect(
              contrast(theme.table.body.color!, block),
              greaterThanOrEqualTo(4.5),
              reason: label,
            );
            expect(
              contrast(theme.colors.ink3, block),
              greaterThanOrEqualTo(3),
              reason: label,
            );
          }
        }
      },
    );
    for (final source in [
      ('dart', '// comment'),
      ('markdown', '> quote'),
      ('bash', '#!/bin/bash'),
    ]) {
      test(
        'muted classes retain emphasis and source: ${source.$1}, dark=$dark',
        () {
          final theme = MarkstreamTheme.fromColorScheme(scheme);
          final result = KelivoCodeHighlighter.forTheme(theme).highlight(
            source.$2,
            language: source.$1,
            style: theme.code.text,
            brightness: theme.brightness,
          );
          expect(result.toPlainText(), source.$2);
          final muted = spans(
            result,
          ).where((s) => s.style?.color == commentColor(theme));
          expect(muted, isNotEmpty);
          for (final span in muted) {
            if (source.$1 != 'bash') {
              expect(span.style!.fontStyle, FontStyle.italic);
            }
            if (source.$1 == 'bash' && !dark) {
              expect(span.style!.fontWeight, FontWeight.bold);
            }
          }
        },
      );
    }
  }
  test(
    'backdrop restyling reuses cached syntax and canonical highlighters',
    () {
      debugResetHighlightNodeCache();
      for (final backdrop in MarkstreamBackdrop.values) {
        final theme = MarkstreamTheme.fromColorScheme(
          ThemePalettes.defaultPalette.light,
          backdrop: backdrop,
        );
        final highlighter = KelivoCodeHighlighter.forTheme(theme);
        expect(
          identical(
            highlighter,
            KelivoCodeHighlighter.forTheme(theme.copyWith()),
          ),
          isTrue,
        );
        final result = highlighter.highlight(
          '// comment\nfinal x = "text";',
          language: 'dart',
          style: theme.code.text,
          brightness: theme.brightness,
        );
        expect(result.toPlainText(), '// comment\nfinal x = "text";');
        expect(
          spans(result).any(
            (s) =>
                s.toPlainText() == 'final' &&
                s.style?.color == const Color(0xff333333),
          ),
          isTrue,
        );
        expect(
          spans(result).any((s) => s.style?.color == const Color(0xffdd1144)),
          isTrue,
        );
      }
      expect(debugHighlightParseCount, 1);
    },
  );
}
