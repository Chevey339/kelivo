import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  test(
    'code removal keeps source whitespace and unmatched line-local backticks',
    () {
      expect(
        removeCode('one `a` two ``b ` c``\r\nnext'),
        'one   two  \r\nnext',
      );
      expect(
        removeCode('`first\nspoken words\nlast`'),
        '`first\nspoken words\nlast`',
      );
      expect(
        removeCode(r'escaped \`literal\` and `hidden`'),
        r'escaped \`literal\` and  ',
      );
    },
  );
  test('open and nested fences suppress code while retaining line endings', () {
    for (final source in [
      'before\n```dart\nsecret\n\nlast',
      'before\n> ~~~~dart\n> ```\n> secret\n> ~~~~',
      'before\n- ```dart\n  secret\n  ```',
    ]) {
      final result = removeCode(source);
      expect(result, startsWith('before\n'));
      expect(result, isNot(contains('secret')));
      expect('\n'.allMatches(result).length, '\n'.allMatches(source).length);
    }
  });
  test('line state uses original offsets and excludes the following prose', () {
    const source = 'intro\r\n```text\r\ninside\r\n```\r\nafter';
    final structure = MarkdownStructure(source);
    expect(structure.lines.map((e) => e.code), [
      false,
      true,
      true,
      true,
      false,
    ]);
    expect(structure.codeBlocks.single.code, 'inside\n');
    for (final entry in structure.lines) {
      expect(
        source.substring(entry.line.start, entry.line.end),
        entry.line.text,
      );
    }
    expect(structure.protects(source.indexOf('inside')), isTrue);
    expect(structure.protects(source.indexOf('after')), isFalse);
  });
  test('blank lines in math, details and directives remain protected', () {
    for (final body in [
      '\$\$x\n\ny\$\$',
      '\\[x\n\ny\\]',
      '<details>\n\ninside\n\n</details>',
      ':::note\n\ninside\n\n:::',
    ]) {
      final source = 'intro\n\n$body\n\nafter';
      final structure = MarkdownStructure(source);
      expect(
        structure.protects(source.indexOf('\n\n', 7) + 1),
        isTrue,
        reason: body,
      );
      expect(structure.protects(source.lastIndexOf('\n\n') + 1), isFalse);
    }
  });
  test(
    'only matching fence closers end code and four-column fences do not open',
    () {
      final structure = MarkdownStructure('````\n```\ninside\n`````\nafter');
      expect(structure.lines.map((e) => e.code), [
        true,
        true,
        true,
        true,
        false,
      ]);
      expect(MarkdownStructure('    ```\nplain').codeBlocks, isEmpty);
      expect(MarkdownStructure('```lang`bad\nplain').codeBlocks, isEmpty);
    },
  );
  test('Unicode logical breaks are an LLM option with exact source spans', () {
    for (final separator in ['\u2028', '\u2029']) {
      final source =
          'before$separator```dart${separator}secret$separator```${separator}after';
      final structure = MarkdownStructure(source);
      expect(structure.lines.map((e) => e.code), [
        false,
        true,
        true,
        true,
        false,
      ]);
      expect(structure.codeBlocks.single.code, 'secret\n');
      expect(
        removeCode(source),
        'before$separator $separator $separator $separator'
        'after',
      );
      expect(
        MarkdownStructure(
          source,
          options: const ParserOptions.commonMark(),
        ).codeBlocks,
        isEmpty,
      );
      final parser = const MarkdownParser();
      final incremental = IncrementalDocument();
      for (var end = 0; end <= source.length; end++) {
        final prefix = source.substring(0, end);
        expect(
          incremental.update(prefix, streaming: true).toJson(),
          parser.parse(prefix, streaming: true).toJson(),
        );
      }
    }
  });
  test(
    'nested diagram blocks are exposed in source order without quoted fences',
    () {
      final blocks = MarkdownStructure(
        '> ```mermaid title\n> graph TD\n> ```\n\n````text\n```svg\n<svg/>\n```\n````',
      ).codeBlocks;
      expect(blocks.map((n) => n.info), ['mermaid title', 'text']);
      expect(blocks.first.code, 'graph TD\n');
    },
  );
}
