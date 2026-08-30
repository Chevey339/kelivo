import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

import 'load_fonts.dart';

void main() {
  setUpAll(loadKaTeXFonts);
  group('Flutter Math', () {
    testWidgets('Should show default error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Math.tex(r'\Gaarbled$')),
        ),
      );
      final finder = find.byType(SelectableText);
      expect(finder, findsOneWidget);
      expect(
          (finder.evaluate().single.widget as SelectableText)
              .data!
              .startsWith('Parser Error:'),
          isTrue);
    });
    testWidgets('Should show onErrorFallback widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Math.tex(
              r'\Gaarbled$',
              onErrorFallback: (_) => Container(
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );
      final finder = find.byType(Container);
      expect(finder, findsOneWidget);
    });
    testWidgets('Should use the surrounding text fonts as glyph fallbacks', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Math.tex(
              r'0 = \textbf{非零常数}',
              textStyle: const TextStyle(
                fontFamily: 'AppBody',
                fontFamilyFallback: ['CjkFallback'],
              ),
            ),
          ),
        ),
      );

      final cjkGlyph = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((widget) => widget.text.toPlainText() == '非');

      expect(cjkGlyph.text.style?.fontFamily, contains('KaTeX_Main'));
      expect(cjkGlyph.text.style?.fontFamilyFallback, [
        'AppBody',
        'CjkFallback',
      ]);
    });
    testWidgets('SelectableMath should use the same glyph fallbacks', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectableMath.tex(
              r'0 = \text{非零常数}',
              textStyle: const TextStyle(
                fontFamily: 'AppBody',
                fontFamilyFallback: ['CjkFallback'],
              ),
            ),
          ),
        ),
      );

      final cjkGlyph = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((widget) => widget.text.toPlainText() == '非');

      expect(cjkGlyph.text.style?.fontFamilyFallback, [
        'AppBody',
        'CjkFallback',
      ]);
    });
  });
}
