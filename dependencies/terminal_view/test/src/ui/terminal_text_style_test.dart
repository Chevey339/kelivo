import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  group('TerminalStyle.toStrutStyle', () {
    const style = TerminalStyle(
      fontSize: 14,
      height: 1.2,
      fontFamily: 'PrimaryMono',
      fontFamilyFallback: ['SymbolFallback', 'monospace'],
    );

    test('forces the line to the primary font, fallbacks included', () {
      final strut = style.toStrutStyle();

      // Without this every cell takes its baseline from whichever font
      // resolved its glyph, so a symbol picked up from a fallback sits above
      // or below the ordinary text on the same row.
      expect(strut.forceStrutHeight, isTrue);
      expect(strut.fontFamily, 'PrimaryMono');
      expect(strut.fontFamilyFallback, ['SymbolFallback', 'monospace']);
    });

    test('matches the text it is strutting for', () {
      final strut = style.toStrutStyle();
      final text = style.toTextStyle();

      // A strut that disagrees with the text would pin the line to a height
      // the glyphs do not fit in.
      expect(strut.fontSize, text.fontSize);
      expect(strut.height, text.height);
      expect(strut.leading, 0);
    });

    test('the text splits its leading evenly', () {
      // Proportional leading divides the slack by each font's own ascent to
      // descent ratio, which is exactly what pushes a fallback glyph off the
      // shared baseline.
      expect(
        style.toTextStyle().leadingDistribution,
        TextLeadingDistribution.even,
      );
    });
  });
}
