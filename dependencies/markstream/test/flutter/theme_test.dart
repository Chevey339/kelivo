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
      for (final factor in [1.45, 1.27, 1.13, 1.0, .94, .88]) 15.5 * factor,
    ]);
    expect(theme.headings.map((style) => style.height), [
      1.3,
      1.35,
      1.4,
      1.45,
      1.45,
      1.45,
    ]);
    expect(theme.inlineCode.text.fontSize, 15.5 * .86);
    expect(theme.inlineCode.text.height, 1);
    expect(
      theme.inlineCode.text.leadingDistribution,
      TextLeadingDistribution.even,
    );
    expect(theme.inlineCode.opticalCenter, 15.5 * .35);
    expect(
      theme.inlineCode.padding,
      const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    );
    expect(theme.chrome.height, 36);
    expect(theme.code.radius, 12);
    expect(theme.table.compactRadius, 12);
    expect(theme.table.wideRadius, 12);
    expect(theme.table.toolbarHeight, theme.chrome.height);
    expect(
      theme.details.contentPadding,
      const EdgeInsets.fromLTRB(12, 0, 12, 12),
    );
    expect(theme.task.size, 16);
    expect(theme.task.strokeWidth, 1.5);
    expect(theme.code.text.height, 1.55);
    expect(
      MarkstreamTheme.fromColorScheme(light, desktop: true).code.text.fontSize,
      12.5,
    );
  });
  test(
    'app font families propagate while heading and chrome weights follow tokens',
    () {
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
      expect(theme.blockSpacing, 18);
      expect(theme.headings.first.fontWeight, FontWeight.w700);
      expect(theme.strongWeight, FontWeight.w600);
      expect(theme.link.fontSize, isNull);
      expect(theme.headings[1].fontWeight, FontWeight.w600);
      expect(theme.details.summary.fontWeight, FontWeight.w400);
      expect(theme.table.heading.fontFamily, 'AppFont');
      expect(theme.table.heading.fontWeight, FontWeight.w600);
      expect(theme.code.text.fontFamily, 'AppMono');
      expect(theme.code.text.fontFamilyFallback, ['AppCjk']);
      expect(theme.inlineCode.text.fontFamilyFallback, ['AppCjk']);
      expect(theme.inlineCode.text.fontFamily, 'AppMono');
      expect(
        theme.inlineCode.text.color,
        light.onSurface.withValues(alpha: .92),
      );
      expect(theme.code.text.color, light.onSurface);
      expect(theme.task.checkedText.decoration, TextDecoration.lineThrough);
      final minimal = MarkstreamTheme.fromColorScheme(
        light,
        bodyStyle: const TextStyle(inherit: false),
      );
      expect(minimal.body.fontSize, 15.5);
      expect(minimal.body.color, light.onSurface);
    },
  );
  test(
    'palette tokens ignore extreme outlineVariant and legacy fill alphas',
    () {
      for (final scheme in [light, dark]) {
        final darkMode = scheme.brightness == Brightness.dark;
        final theme = MarkstreamTheme.fromColorScheme(
          scheme.copyWith(
            outlineVariant: darkMode ? Colors.white : Colors.black,
          ),
        );
        expect(
          theme,
          MarkstreamTheme.fromColorScheme(
            scheme.copyWith(outlineVariant: Colors.red),
          ),
        );
        expect(
          theme.colors.border,
          (darkMode ? Colors.white : scheme.onSurface).withValues(alpha: .10),
        );
        expect(theme.table.borderColor, theme.colors.divider);
        expect(theme.table.outerBorderColor, theme.colors.border);
        expect(theme.code.borderColor, theme.colors.border);
        expect(theme.details.borderColor, theme.colors.border);
        expect(theme.ruleColor, theme.colors.border);
        expect(theme.quote.textColor, theme.colors.ink2);
        expect(theme.chrome.background, theme.colors.fillHead);
        expect(theme.inlineCode.borderColor, Colors.transparent);
        expect(
          theme.code.backgroundColor,
          Color.alphaBlend(
            Colors.white.withValues(alpha: darkMode ? .04 : .70),
            scheme.surface,
          ),
        );
        final legacy = MarkstreamTheme.fromColorScheme(
          scheme,
          fillAlphas: const MarkstreamFillAlphas(
            details: 0,
            inline: 0,
            table: 0,
            content: 0,
          ),
        );
        expect(legacy.colors, theme.colors);
        expect(legacy.code, theme.code);
        expect(legacy.table, theme.table);
        expect(legacy.details, theme.details);
        expect(legacy.inlineCode, theme.inlineCode);
      }
    },
  );
  test(
    'equivalent themes retain cache identity and heading lists are immutable',
    () {
      final first = MarkstreamTheme.fromColorScheme(light);
      final equivalent = MarkstreamTheme.fromColorScheme(light);
      expect(equivalent, first);
      expect(equivalent.hashCode, first.hashCode);
      expect(
        first.copyWith(
          colors: first.colors.copyWith(),
          chrome: first.chrome.copyWith(),
          inlineCode: first.inlineCode.copyWith(),
          quote: first.quote.copyWith(),
          task: first.task.copyWith(),
          table: first.table.copyWith(),
          details: first.details.copyWith(),
        ),
        first,
      );
      for (final changed in [
        first.copyWith(colors: first.colors.copyWith(border: Colors.red)),
        first.copyWith(chrome: first.chrome.copyWith(height: 40)),
        first.copyWith(inlineCode: first.inlineCode.copyWith(opticalCenter: 8)),
        first.copyWith(quote: first.quote.copyWith(textColor: Colors.red)),
        first.copyWith(task: first.task.copyWith(strokeWidth: 2)),
        first.copyWith(
          table: first.table.copyWith(outerBorderColor: Colors.red),
        ),
        first.copyWith(
          details: first.details.copyWith(contentPadding: EdgeInsets.zero),
        ),
      ]) {
        expect(changed, isNot(first));
        expect(changed.hashCode, isNot(first.hashCode));
      }
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
