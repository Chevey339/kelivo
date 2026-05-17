import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Links', () {
    testWidgets('simple link', (tester) async {
      await pumpMarkdown(tester, '[click here](https://example.com)');
      final output = getSerializedOutput(tester);
      // Link should be serialized as LINK
      expect(output, contains('LINK'));
      expect(output, contains('click here'));
    });

    testWidgets('link with path', (tester) async {
      await pumpMarkdown(tester, '[docs](https://example.com/docs/page)');
      final output = getSerializedOutput(tester);
      expect(output, contains('LINK'));
      expect(output, contains('docs'));
    });

    testWidgets('link in middle of sentence', (tester) async {
      await pumpMarkdown(
        tester,
        'Check out [this link](https://example.com) for more',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('LINK'));
      expect(output, contains('Check out'));
      expect(output, contains('for more'));
    });

    testWidgets('multiple links', (tester) async {
      await pumpMarkdown(
        tester,
        '[first](https://a.com) and [second](https://b.com)',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('LINK'));
      expect(output, contains('and'));
    });

    testWidgets('link with styled text', (tester) async {
      await pumpMarkdown(tester, '[**bold link**](https://example.com)');
      final output = getSerializedOutput(tester);
      expect(output, contains('LINK'));
    });

    testWidgets('broken link syntax treated as plain text', (tester) async {
      await pumpMarkdown(tester, '[broken link(https://example.com)');
      final output = getSerializedOutput(tester);
      // Should contain brackets as text
      expect(output, contains('['));
    });
  });
}
