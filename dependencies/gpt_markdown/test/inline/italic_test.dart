import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Italic text', () {
    testWidgets('single italic word', (tester) async {
      await expectMarkdownContains(
        tester,
        '*italic*',
        'TEXT("italic")[italic]',
      );
    });

    testWidgets('italic phrase', (tester) async {
      await expectMarkdownContains(
        tester,
        '*italic text here*',
        'TEXT("italic text here")[italic]',
      );
    });

    testWidgets('italic in middle of sentence', (tester) async {
      await pumpMarkdown(tester, 'This is *italic* text');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("italic")[italic]'));
      expect(output, contains('TEXT("This is ")'));
      expect(output, contains('TEXT(" text")'));
    });

    testWidgets('multiple italic sections', (tester) async {
      await pumpMarkdown(tester, '*first* and *second*');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("first")[italic]'));
      expect(output, contains('TEXT("second")[italic]'));
    });

    testWidgets('italic with nested bold', (tester) async {
      await pumpMarkdown(tester, '***italic and bold***');
      final output = getSerializedOutput(tester);
      // Should contain both bold and italic modifiers
      expect(output, contains('bold'));
      expect(output, contains('italic'));
    });

    testWidgets('unclosed italic treated as plain text', (tester) async {
      await pumpMarkdown(tester, '*unclosed italic');
      final output = getSerializedOutput(tester);
      // Should contain the asterisk as text
      expect(output, contains('*'));
    });
  });
}
