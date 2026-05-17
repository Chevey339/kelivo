import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Indented content', () {
    testWidgets('two-space indent renders', (tester) async {
      await pumpMarkdown(tester, '  Indented text');
      // Verify content is rendered
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('four-space indent renders', (tester) async {
      await pumpMarkdown(tester, '    More indented');
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('indented with styled text renders', (tester) async {
      await pumpMarkdown(tester, '  **Bold** indented');
      final output = getSerializedOutput(tester);
      expect(output, contains('bold'));
    });

    testWidgets('indented with inline code renders', (tester) async {
      await pumpMarkdown(tester, '  Use `code` here');
      final output = getSerializedOutput(tester);
      expect(output, contains('highlight'));
    });

    testWidgets('multiple indented lines render', (tester) async {
      await pumpMarkdown(tester, '  Line 1\n  Line 2');
      expect(find.byType(RichText), findsWidgets);
    });
  });
}
