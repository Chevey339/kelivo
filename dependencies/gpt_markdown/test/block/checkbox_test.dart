import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Checkboxes', () {
    testWidgets('unchecked checkbox', (tester) async {
      await pumpMarkdown(tester, '[ ] Unchecked item');
      final output = getSerializedOutput(tester);
      expect(output, contains('CHECKBOX'));
      expect(output, contains('checked=false'));
    });

    testWidgets('checked checkbox', (tester) async {
      await pumpMarkdown(tester, '[x] Checked item');
      final output = getSerializedOutput(tester);
      expect(output, contains('CHECKBOX'));
      expect(output, contains('checked=true'));
    });

    testWidgets('multiple checkboxes', (tester) async {
      await pumpMarkdown(tester, '[ ] First\n[x] Second\n[ ] Third');
      final output = getSerializedOutput(tester);
      // Should have 3 checkboxes
      expect('CHECKBOX'.allMatches(output).length, equals(3));
    });

    testWidgets('checkbox with styled text', (tester) async {
      await pumpMarkdown(tester, '[x] **Bold** task');
      final output = getSerializedOutput(tester);
      expect(output, contains('CHECKBOX'));
      expect(output, contains('checked=true'));
    });

    testWidgets('checkbox with inline code', (tester) async {
      await pumpMarkdown(tester, '[ ] Run `npm install`');
      final output = getSerializedOutput(tester);
      expect(output, contains('CHECKBOX'));
      expect(output, contains('checked=false'));
    });
  });
}
