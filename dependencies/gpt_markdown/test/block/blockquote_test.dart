import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Block quotes', () {
    testWidgets('simple blockquote', (tester) async {
      await pumpMarkdown(tester, '> This is a quote');
      final output = getSerializedOutput(tester);
      expect(output, contains('BLOCKQUOTE'));
    });

    testWidgets('multiline blockquote', (tester) async {
      await pumpMarkdown(tester, '> Line 1\n> Line 2');
      final output = getSerializedOutput(tester);
      expect(output, contains('BLOCKQUOTE'));
    });

    testWidgets('blockquote with styled text', (tester) async {
      await pumpMarkdown(tester, '> **Bold** quote');
      final output = getSerializedOutput(tester);
      expect(output, contains('BLOCKQUOTE'));
    });

    testWidgets('blockquote with inline code', (tester) async {
      await pumpMarkdown(tester, '> Use `code` in quote');
      final output = getSerializedOutput(tester);
      expect(output, contains('BLOCKQUOTE'));
    });

    testWidgets('blockquote with italic', (tester) async {
      await pumpMarkdown(tester, '> *Italic* quote');
      final output = getSerializedOutput(tester);
      expect(output, contains('BLOCKQUOTE'));
    });

    testWidgets('multiple blockquotes', (tester) async {
      await pumpMarkdown(tester, '> Quote 1\n\n> Quote 2');
      final output = getSerializedOutput(tester);
      // Should have 2 blockquotes
      expect('BLOCKQUOTE'.allMatches(output).length, equals(2));
    });
  });
}
