import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Code blocks', () {
    testWidgets('simple code block', (tester) async {
      await pumpMarkdown(tester, '```\ncode here\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('code here'));
    });

    testWidgets('code block with language', (tester) async {
      await pumpMarkdown(tester, '```dart\nvoid main() {}\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('lang="dart"'));
      expect(output, contains('void main()'));
    });

    testWidgets('code block with javascript', (tester) async {
      await pumpMarkdown(tester, '```javascript\nconst x = 1;\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('lang="javascript"'));
    });

    testWidgets('code block with python', (tester) async {
      await pumpMarkdown(tester, '```python\ndef hello():\n    pass\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('lang="python"'));
    });

    testWidgets('code block preserves content', (tester) async {
      await pumpMarkdown(tester, '```\nline1\nline2\nline3\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('line1'));
    });

    testWidgets('unclosed code block', (tester) async {
      await pumpMarkdown(tester, '```dart\nunclosed code');
      final output = getSerializedOutput(tester);
      // Library may handle unclosed blocks gracefully
      expect(output, contains('CODE_BLOCK'));
    });

    testWidgets('empty code block', (tester) async {
      await pumpMarkdown(tester, '```\n```');
      final output = getSerializedOutput(tester);
      expect(output, contains('CODE_BLOCK'));
    });
  });
}
