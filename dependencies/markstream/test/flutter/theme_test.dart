import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

void main() {
  final light = ColorScheme.fromSeed(seedColor: Colors.blue);
  final dark = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  );
  test('defaults preserve body, heading and inline code geometry', () {
    final theme = MarkstreamTheme.fromColorScheme(light);
    expect(theme.body.fontSize, 15.5);
    expect(theme.body.height, 1.55);
    expect(theme.headings.map((style) => style.fontSize), [
      24,
      20,
      18,
      16,
      15,
      14,
    ]);
    expect(theme.headings.take(3).map((style) => style.height), [
      1.25,
      1.30,
      1.35,
    ]);
    expect(theme.inlineCode.text.fontSize, 13);
    expect(theme.inlineCode.text.height, 1.4);
    expect(
      theme.inlineCode.padding,
      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  });
  test('app font choices and platform weights propagate to all text roles', () {
    final theme = MarkstreamTheme.fromColorScheme(
      light,
      bodyStyle: const TextStyle(
        inherit: false,
        fontFamily: 'AppFont',
        fontFamilyFallback: ['AppCjk'],
        fontSize: 20,
        color: Colors.purple,
      ),
      codeFontFamily: 'AppMono',
      cjk: true,
      medium: FontWeight.w400,
      semibold: FontWeight.w500,
      strong: FontWeight.w600,
    );
    expect(theme.body.fontFamily, 'AppFont');
    expect(theme.body.height, 1.55);
    expect(theme.body.letterSpacing, 0);
    expect(theme.blockSpacing, 23);
    expect(theme.headings.first.fontWeight, FontWeight.w600);
    expect(theme.strongWeight, FontWeight.w600);
    expect(theme.link.fontSize, isNull);
    expect(theme.headings[1].fontWeight, FontWeight.w500);
    expect(theme.details.summary.fontWeight, FontWeight.w400);
    expect(theme.table.heading.fontFamily, 'AppFont');
    expect(theme.table.heading.fontWeight, FontWeight.w500);
    expect(theme.code.text.fontFamily, 'AppMono');
    expect(theme.code.text.fontFamilyFallback, ['AppCjk']);
    expect(theme.inlineCode.text.fontFamilyFallback, ['AppCjk']);
    expect(theme.inlineCode.text.fontFamily, 'AppMono');
    expect(theme.inlineCode.text.color, Colors.purple);
    expect(theme.code.text.color, light.onSurface);
    expect(theme.task.checkedText.decoration, TextDecoration.lineThrough);
    final minimal = MarkstreamTheme.fromColorScheme(
      light,
      bodyStyle: const TextStyle(inherit: false),
    );
    expect(minimal.body.fontSize, 15.5);
    expect(minimal.body.color, light.onSurface);
  });
  test(
    'dark fills and monochrome borders retain the original color policy',
    () {
      final theme = MarkstreamTheme.fromColorScheme(
        dark.copyWith(outlineVariant: Colors.white),
      );
      expect(theme.inlineCode.backgroundColor, Colors.white12);
      expect(theme.code.backgroundColor.a, closeTo(.8, .001));
      expect(theme.table.headerBackgroundColor.a, closeTo(.72, .001));
      expect(theme.details.backgroundColor.a, closeTo(.55, .001));
      expect(
        theme.code.borderColor,
        Color.alphaBlend(
          dark.onSurfaceVariant.withValues(alpha: .32),
          dark.surface,
        ),
      );
      final transparent = MarkstreamTheme.fromColorScheme(
        light,
        fillAlphas: const MarkstreamFillAlphas(
          details: 0,
          inline: 0,
          table: 0,
          content: 0,
        ),
      );
      expect(transparent.inlineCode.backgroundColor.a, 0);
      expect(transparent.code.backgroundColor.a, 0);
      expect(transparent.table.headerBackgroundColor.a, 0);
      expect(transparent.details.backgroundColor.a, 0);
    },
  );
  test(
    'equivalent themes retain cache identity and heading lists are immutable',
    () {
      final first = MarkstreamTheme.fromColorScheme(light);
      final equivalent = MarkstreamTheme.fromColorScheme(light);
      expect(equivalent, first);
      expect(equivalent.hashCode, first.hashCode);
      final headings = [...first.headings];
      final copy = first.copyWith(headings: headings);
      headings[0] = const TextStyle(fontSize: 99);
      expect(copy, first);
      expect(() => copy.headings.clear(), throwsUnsupportedError);
      expect(
        first.copyWith(code: first.code.copyWith(radius: 4)),
        isNot(first),
      );
      expect(
        first.copyWith(body: first.body.copyWith(fontSize: 19)),
        isNot(first),
      );
    },
  );
}
