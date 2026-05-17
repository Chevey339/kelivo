import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Images', () {
    testWidgets('simple image', (tester) async {
      await pumpMarkdown(tester, '![alt](https://example.com/image.png)');
      final output = getSerializedOutput(tester);
      expect(output, contains('IMAGE'));
      expect(output, contains('https://example.com/image.png'));
    });

    testWidgets('image with dimensions in alt text', (tester) async {
      await pumpMarkdown(tester, '![100x50](https://example.com/image.png)');
      final output = getSerializedOutput(tester);
      expect(output, contains('IMAGE'));
      expect(output, contains('https://example.com/image.png'));
    });

    testWidgets('image with width only', (tester) async {
      await pumpMarkdown(tester, '![200x](https://example.com/image.png)');
      final output = getSerializedOutput(tester);
      expect(output, contains('IMAGE'));
    });

    testWidgets('image with height only', (tester) async {
      await pumpMarkdown(tester, '![x150](https://example.com/image.png)');
      final output = getSerializedOutput(tester);
      expect(output, contains('IMAGE'));
    });

    testWidgets('image in text', (tester) async {
      await pumpMarkdown(
        tester,
        'Check this ![img](https://example.com/image.png) out',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('Check this'));
      expect(output, contains('IMAGE'));
      expect(output, contains('out'));
    });

    testWidgets('multiple images', (tester) async {
      await pumpMarkdown(
        tester,
        '![a](https://example.com/a.png) ![b](https://example.com/b.png)',
      );
      final output = getSerializedOutput(tester);
      expect('IMAGE'.allMatches(output).length, greaterThanOrEqualTo(2));
    });

    testWidgets('image with complex URL', (tester) async {
      await pumpMarkdown(
        tester,
        '![alt](https://example.com/path/to/image.png?query=1&foo=bar)',
      );
      final output = getSerializedOutput(tester);
      expect(output, contains('IMAGE'));
    });

    testWidgets('image not confused with link', (tester) async {
      // Links use [text](url), images use ![alt](url)
      await pumpMarkdown(tester, '[not image](https://example.com)');
      final output = getSerializedOutput(tester);
      expect(output, isNot(contains('IMAGE')));
    });
  });
}
