import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Radio buttons', () {
    testWidgets('unchecked radio button', (tester) async {
      await pumpMarkdown(tester, '( ) Unchecked option');
      final output = getSerializedOutput(tester);
      expect(output, contains('RADIO'));
      expect(output, contains('checked=false'));
    });

    testWidgets('checked radio button', (tester) async {
      await pumpMarkdown(tester, '(x) Checked option');
      final output = getSerializedOutput(tester);
      expect(output, contains('RADIO'));
      expect(output, contains('checked=true'));
    });

    testWidgets('multiple radio buttons', (tester) async {
      await pumpMarkdown(tester, '( ) Option A\n(x) Option B\n( ) Option C');
      final output = getSerializedOutput(tester);
      // Should have 3 radio buttons
      expect('RADIO'.allMatches(output).length, equals(3));
    });

    testWidgets('radio button with styled text', (tester) async {
      await pumpMarkdown(tester, '(x) **Bold** option');
      final output = getSerializedOutput(tester);
      expect(output, contains('RADIO'));
      expect(output, contains('checked=true'));
    });

    testWidgets('radio button with inline code', (tester) async {
      await pumpMarkdown(tester, '( ) Select `option1`');
      final output = getSerializedOutput(tester);
      expect(output, contains('RADIO'));
      expect(output, contains('checked=false'));
    });
  });
}
