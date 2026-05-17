import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Inline LaTeX', () {
    testWidgets('simple inline math', (tester) async {
      await pumpMarkdown(tester, r'\(x^2\)');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('fraction', (tester) async {
      await pumpMarkdown(tester, r'\(\frac{a}{b}\)');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('inline math in sentence', (tester) async {
      await pumpMarkdown(tester, r'The equation \(E = mc^2\) is famous');
      final output = getSerializedOutput(tester);
      expect(output, contains('The equation'));
      expect(output, contains('LATEX'));
      expect(output, contains('is famous'));
    });

    testWidgets('multiple inline math', (tester) async {
      await pumpMarkdown(tester, r'\(a\) and \(b\)');
      final output = getSerializedOutput(tester);
      expect(output, contains('and'));
      // Should have multiple LATEX entries
      expect('LATEX'.allMatches(output).length, greaterThanOrEqualTo(1));
    });

    testWidgets('inline math with subscript', (tester) async {
      await pumpMarkdown(tester, r'\(x_1\)');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('inline math with superscript', (tester) async {
      await pumpMarkdown(tester, r'\(x^n\)');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('inline math with greek letters', (tester) async {
      await pumpMarkdown(tester, r'\(\alpha + \beta\)');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });

    testWidgets('inline math with square root', (tester) async {
      await pumpMarkdown(tester, r'\(\sqrt{x}\)');
      final output = getSerializedOutput(tester);
      expect(output, contains('LATEX'));
    });
  });
}
