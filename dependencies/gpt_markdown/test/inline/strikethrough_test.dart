import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Strikethrough text', () {
    testWidgets('single strikethrough word', (tester) async {
      await expectMarkdownContains(
        tester,
        '~~striked~~',
        'TEXT("striked")[strike]',
      );
    });

    testWidgets('strikethrough phrase', (tester) async {
      await expectMarkdownContains(
        tester,
        '~~striked text here~~',
        'TEXT("striked text here")[strike]',
      );
    });

    testWidgets('strikethrough in middle of sentence', (tester) async {
      await pumpMarkdown(tester, 'This is ~~striked~~ text');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("striked")[strike]'));
      expect(output, contains('TEXT("This is ")'));
      expect(output, contains('TEXT(" text")'));
    });

    testWidgets('multiple strikethrough sections', (tester) async {
      await pumpMarkdown(tester, '~~first~~ and ~~second~~');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("first")[strike]'));
      expect(output, contains('TEXT("second")[strike]'));
    });

    testWidgets('unclosed strikethrough treated as plain text', (tester) async {
      await pumpMarkdown(tester, '~~unclosed strike');
      final output = getSerializedOutput(tester);
      // Should contain the tildes as text
      expect(output, contains('~~'));
    });
  });
}
