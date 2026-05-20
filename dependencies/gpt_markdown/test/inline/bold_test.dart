import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Bold text', () {
    testWidgets('single bold word', (tester) async {
      await expectMarkdownContains(tester, '**bold**', 'TEXT("bold")[bold]');
    });

    testWidgets('bold phrase', (tester) async {
      await expectMarkdownContains(
        tester,
        '**bold text here**',
        'TEXT("bold text here")[bold]',
      );
    });

    testWidgets('bold in middle of sentence', (tester) async {
      await pumpMarkdown(tester, 'This is **bold** text');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("bold")[bold]'));
      expect(output, contains('TEXT("This is ")'));
      expect(output, contains('TEXT(" text")'));
    });

    testWidgets('multiple bold sections', (tester) async {
      await pumpMarkdown(tester, '**first** and **second**');
      final output = getSerializedOutput(tester);
      expect(output, contains('TEXT("first")[bold]'));
      expect(output, contains('TEXT("second")[bold]'));
    });

    testWidgets('bold with nested italic', (tester) async {
      await pumpMarkdown(tester, '***bold and italic***');
      final output = getSerializedOutput(tester);
      // Should contain both bold and italic modifiers
      expect(output, contains('bold'));
      expect(output, contains('italic'));
    });

    testWidgets('bold not triggered by single asterisk', (tester) async {
      await pumpMarkdown(tester, '*not bold*');
      final output = getSerializedOutput(tester);
      expect(output, isNot(contains('[bold]')));
    });

    testWidgets('unclosed bold treated as plain text', (tester) async {
      await pumpMarkdown(tester, '**unclosed bold');
      final output = getSerializedOutput(tester);
      // Should contain the asterisks as text
      expect(output, contains('**'));
    });
  });
}
