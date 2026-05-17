import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Highlighted/inline code text', () {
    // Note: The library applies bold styling to highlighted/inline code text
    testWidgets('single inline code word', (tester) async {
      await pumpMarkdown(tester, '`code`');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("code")'));
      expect(output, contains('highlight'));
    });

    testWidgets('inline code phrase', (tester) async {
      await pumpMarkdown(tester, '`inline code here`');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("inline code here")'));
      expect(output, contains('highlight'));
    });

    testWidgets('inline code in middle of sentence', (tester) async {
      await pumpMarkdown(tester, 'This is `code` text');
      final output = getSerializedOutput(tester);
      expect(output, contains('highlight'));
      expect(output, contains('TEXT("This is ")'));
      expect(output, contains('TEXT(" text")'));
    });

    testWidgets('multiple inline code sections', (tester) async {
      await pumpMarkdown(tester, '`first` and `second`');
      final output = getSerializedOutput(tester);
      expect(output, contains('first'));
      expect(output, contains('second'));
      expect(output, contains('highlight'));
    });

    testWidgets('inline code with special characters', (tester) async {
      await pumpMarkdown(tester, '`foo(bar)`');
      final output = getSerializedOutput(tester);
      expect(output, contains('foo(bar)'));
      expect(output, contains('highlight'));
    });

    testWidgets('unclosed backtick treated as plain text', (tester) async {
      await pumpMarkdown(tester, '`unclosed code');
      final output = getSerializedOutput(tester);
      // Should contain the backtick as text
      expect(output, contains('`'));
    });
  });
}
