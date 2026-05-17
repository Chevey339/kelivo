import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Unordered lists', () {
    testWidgets('single item with dash', (tester) async {
      await pumpMarkdown(tester, '- Item 1');
      final output = getSerializedOutput(tester);
      expect(output, contains('UL_ITEM'));
    });

    testWidgets('single item with asterisk', (tester) async {
      await pumpMarkdown(tester, '* Item 1');
      final output = getSerializedOutput(tester);
      expect(output, contains('UL_ITEM'));
    });

    testWidgets('multiple items', (tester) async {
      await pumpMarkdown(tester, '- Item 1\n- Item 2\n- Item 3');
      final output = getSerializedOutput(tester);
      // Should have 3 list items
      expect('UL_ITEM'.allMatches(output).length, equals(3));
    });

    testWidgets('item with styled text', (tester) async {
      await pumpMarkdown(tester, '- **Bold** item');
      final output = getSerializedOutput(tester);
      expect(output, contains('UL_ITEM'));
    });

    testWidgets('item with inline code', (tester) async {
      await pumpMarkdown(tester, '- Use `code` here');
      final output = getSerializedOutput(tester);
      expect(output, contains('UL_ITEM'));
    });

    testWidgets('item with link', (tester) async {
      await pumpMarkdown(tester, '- Check [this](https://example.com)');
      final output = getSerializedOutput(tester);
      expect(output, contains('UL_ITEM'));
    });

    testWidgets('mixed dash and asterisk', (tester) async {
      await pumpMarkdown(tester, '- Dash item\n* Asterisk item');
      final output = getSerializedOutput(tester);
      // Should have 2 list items
      expect('UL_ITEM'.allMatches(output).length, equals(2));
    });
  });
}
