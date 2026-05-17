import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Underline text', () {
    testWidgets('single underlined word', (tester) async {
      await expectMarkdownContains(
        tester,
        '<u>underlined</u>',
        'TEXT("underlined")[underline]',
      );
    });

    testWidgets('underlined phrase', (tester) async {
      await expectMarkdownContains(
        tester,
        '<u>underlined text here</u>',
        'TEXT("underlined text here")[underline]',
      );
    });

    testWidgets('underline in middle of sentence', (tester) async {
      await pumpMarkdown(tester, 'This is <u>underlined</u> text');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("underlined")[underline]'));
      expect(output, contains('TEXT("This is ")'));
      expect(output, contains('TEXT(" text")'));
    });

    testWidgets('multiple underlined sections', (tester) async {
      await pumpMarkdown(tester, '<u>first</u> and <u>second</u>');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("first")[underline]'));
      expect(output, contains('TEXT("second")[underline]'));
    });

    testWidgets('unclosed underline tag', (tester) async {
      // Library may handle unclosed tags gracefully
      await pumpMarkdown(tester, '<u>unclosed underline');
      final output = getSerializedOutput(tester);
      // Behavior depends on library implementation
      expect(output, isNotEmpty);
    });
  });
}
