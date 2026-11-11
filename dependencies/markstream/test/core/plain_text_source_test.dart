import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  for (final source in [
    '**one**\n\nsecond',
    '# Title\n\n> quoted **body**',
    '1. 1.\n2. **second**',
    '- [x] task\n- [ ] next',
    '| left | right |\n| --- | --- |\n| a"b | **value** |',
    '<ul><li>first</li><li><b>second</b></li></ul>',
    'Before\n\n```dart\n  value();\n```\n\nAfter',
    '<!doctype html><html><body>body</body></html>',
    r'$a+b$',
    '',
  ]) {
    test(
      'plain source projection preserves clipboard serialization: $source',
      () {
        final document = const MarkdownParser().parse(source);
        final index = plainTextIndex(document);
        expect(index.text, toPlainText(document));
        for (final word in [
          'one',
          'second',
          'body',
          'task',
          'value',
          'After',
        ]) {
          final start = index.text.lastIndexOf(word);
          if (start < 0) continue;
          final range = index.sourceSpanForRange(start, start + word.length);
          expect(range.slice(source), word);
        }
      },
    );
  }
  test(
    'generated list markers and separators cannot steal actual source positions',
    () {
      const source = '1. **1.**\n\nsecond';
      final index = plainTextIndex(const MarkdownParser().parse(source));
      final start = index.text.lastIndexOf('1.');
      final range = index.sourceSpanForRange(start, start + 4);
      expect(range.start, 5);
      expect(range.end, 7);
    },
  );
}
