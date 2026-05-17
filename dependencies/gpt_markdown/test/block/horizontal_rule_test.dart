import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Horizontal rules', () {
    testWidgets('three dashes', (tester) async {
      await pumpMarkdown(tester, '---');
      final output = getSerializedOutput(tester);
      expect(output, contains('HR'));
    });

    testWidgets('many dashes', (tester) async {
      await pumpMarkdown(tester, '----------');
      final output = getSerializedOutput(tester);
      expect(output, contains('HR'));
    });

    testWidgets('hr between content', (tester) async {
      await pumpMarkdown(tester, 'Above\n\n---\n\nBelow');
      final output = getSerializedOutput(tester);
      expect(output, contains('Above'));
      expect(output, contains('HR'));
      expect(output, contains('Below'));
    });

    testWidgets('multiple hrs', (tester) async {
      await pumpMarkdown(tester, '---\n\n---');
      final output = getSerializedOutput(tester);
      // Should have multiple HRs
      expect('HR'.allMatches(output).length, greaterThanOrEqualTo(1));
    });

    testWidgets('unicode hr character', (tester) async {
      // The library supports the ⸻ character
      await pumpMarkdown(tester, '⸻');
      final output = getSerializedOutput(tester);
      expect(output, contains('HR'));
    });
  });
}
