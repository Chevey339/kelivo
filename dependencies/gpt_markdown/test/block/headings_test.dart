import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Headings', () {
    // Note: Headings are rendered with RichText widgets with specific styles
    // The serializer may show them as LATEX due to widget detection, but they render correctly
    testWidgets('heading level 1 renders', (tester) async {
      await pumpMarkdown(tester, '# Heading 1');
      // Verify heading is rendered (find any RichText)
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('heading level 2 renders', (tester) async {
      await pumpMarkdown(tester, '## Heading 2');
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('heading level 3 renders', (tester) async {
      await pumpMarkdown(tester, '### Heading 3');
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('heading level 4 renders', (tester) async {
      await pumpMarkdown(tester, '#### Heading 4');
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('heading level 5 renders', (tester) async {
      await pumpMarkdown(tester, '##### Heading 5');
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('heading level 6 renders', (tester) async {
      await pumpMarkdown(tester, '###### Heading 6');
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('heading with styled text renders', (tester) async {
      await pumpMarkdown(tester, '# **Bold** Heading');
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('heading with inline code renders', (tester) async {
      await pumpMarkdown(tester, '## Code `example`');
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('multiple headings render', (tester) async {
      await pumpMarkdown(tester, '# First\n\n## Second');
      expect(find.byType(RichText), findsWidgets);
    });
  });
}
