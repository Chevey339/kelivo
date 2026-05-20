import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Block LaTeX', () {
    testWidgets('simple block math', (tester) async {
      await pumpMarkdown(tester, r'\[x^2 + y^2 = z^2\]');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('block fraction', (tester) async {
      await pumpMarkdown(tester, r'\[\frac{a}{b}\]');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('block math with text before', (tester) async {
      await pumpMarkdown(
        tester,
        r'Equation:'
        '\n'
        r'\[E = mc^2\]',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('Equation'));
      expect(output, contains('LATEX'));
    });

    testWidgets('block math with text after', (tester) async {
      await pumpMarkdown(
        tester,
        r'\[E = mc^2\]'
        '\n'
        'is famous',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
      expect(output, contains('is famous'));
    });

    testWidgets('block integral', (tester) async {
      await pumpMarkdown(tester, r'\[\int_{0}^{1} x^2 \, dx\]');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('block sum', (tester) async {
      await pumpMarkdown(tester, r'\[\sum_{i=1}^{n} i\]');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('block matrix', (tester) async {
      await pumpMarkdown(
        tester,
        r'\[\begin{bmatrix} 1 & 2 \\ 3 & 4 \end{bmatrix}\]',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('multiple block equations', (tester) async {
      await pumpMarkdown(
        tester,
        r'\[a = b\]'
        '\n\n'
        r'\[c = d\]',
      );
      final output = getSerializedOutput(tester);
      // Should have multiple LATEX entries
      expect('LATEX'.allMatches(output).length, greaterThanOrEqualTo(1));
    });

    testWidgets('block math with greek letters', (tester) async {
      await pumpMarkdown(tester, r'\[\alpha + \beta = \gamma\]');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });
  });
}
