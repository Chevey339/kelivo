import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/utils/markdown_block_scanner.dart';

void main() {
  group('MarkdownBlockScanner - fenced code', () {
    test('triple backtick fence', () {
      final result = MarkdownBlockScanner.scan('```\ncode\n```');
      expect(result.spans, hasLength(1));
      expect(result.spans[0].type, BlockType.fencedCode);
      expect(result.spans[0].start, 0);
      expect(result.spans[0].end, 12);
    });

    test('fenced code with language tag', () {
      final result = MarkdownBlockScanner.scan('```dart\nvoid main() {}\n```');
      expect(result.spans, hasLength(1));
      expect(result.spans[0].type, BlockType.fencedCode);
      expect(result.isProtected(0), isTrue);
      expect(result.isProtected(4), isTrue);
    });

    test('unclosed fence extends to EOF', () {
      final result = MarkdownBlockScanner.scan('```\nunclosed code');
      expect(result.spans, hasLength(1));
      expect(result.spans[0].end, 17);
    });

    test('4+ backtick fence', () {
      final result = MarkdownBlockScanner.scan('````\ncode\n````');
      expect(result.spans, hasLength(1));
      expect(result.spans[0].type, BlockType.fencedCode);
    });

    test('nested backticks: 4 backtick fence with 3 backtick inside', () {
      final result = MarkdownBlockScanner.scan('````\n```\n````');
      expect(result.spans, hasLength(1));
      expect(result.spans[0].type, BlockType.fencedCode);
    });

    test('tilde fence not supported', () {
      final result = MarkdownBlockScanner.scan('~~~\ncode\n~~~');
      expect(
        result.spans.where((s) => s.type == BlockType.fencedCode),
        hasLength(0),
      );
    });

    test('no fence for single backtick at line start', () {
      final result = MarkdownBlockScanner.scan('`not a fence`');
      // Should be inline code, not fenced
      for (final s in result.spans) {
        expect(s.type, isNot(BlockType.fencedCode));
      }
    });
  });

  group('MarkdownBlockScanner - inline code', () {
    test('single backtick inline code', () {
      final result = MarkdownBlockScanner.scan('`code`');
      expect(result.spans, hasLength(1));
      expect(result.spans[0].type, BlockType.inlineCode);
    });

    test('double backtick inline code', () {
      final result = MarkdownBlockScanner.scan('``code``');
      expect(result.spans, hasLength(1));
      expect(result.spans[0].type, BlockType.inlineCode);
    });

    test('inline code with dollar sign', () {
      final result = MarkdownBlockScanner.scan(r'`$variable`');
      expect(result.spans, hasLength(1));
      expect(result.isProtected(0), isTrue);
    });

    test('inline code with escaped backtick', () {
      final result = MarkdownBlockScanner.scan(r'`code \` more`');
      expect(result.spans, hasLength(1));
      expect(result.spans[0].type, BlockType.inlineCode);
    });

    test('inline code does not span lines', () {
      final result = MarkdownBlockScanner.scan('`code\nmore`');
      // The backtick at position 0 starts inline code but \n at 5 closes it
      // without matching closing backtick → no span recorded
      expect(result.spans, isEmpty);
    });

    test('escaped backtick prevents inline code', () {
      final result = MarkdownBlockScanner.scan(r'\`not code`');
      // \` at start → escape, not inline code
      // The ` at position 10 could start inline code, but it's not at line start
      for (final s in result.spans) {
        expect(s.start, isNot(0));
      }
    });
  });

  group('MarkdownBlockScanner - mixed content', () {
    test('fenced code followed by text', () {
      final result = MarkdownBlockScanner.scan('```\ncode\n```\nnormal text');
      expect(result.spans, hasLength(1));
      expect(result.isProtected(0), isTrue);
      expect(result.isProtected(19), isFalse);
    });

    test('text followed by inline code', () {
      final result = MarkdownBlockScanner.scan('hello `world` here');
      expect(result.spans, hasLength(1));
      expect(result.isProtected(0), isFalse);
      expect(result.isProtected(6), isTrue);
      expect(result.isProtected(13), isFalse);
    });

    test('fenced code and inline code coexisting', () {
      final result = MarkdownBlockScanner.scan('```\nblock\n```\n`inline`');
      expect(result.spans, hasLength(2));
      expect(result.spans[0].type, BlockType.fencedCode);
      expect(result.spans[1].type, BlockType.inlineCode);
    });
  });

  group('MarkdownBlockScanner - spanAt', () {
    test('spanAt returns correct span', () {
      final result = MarkdownBlockScanner.scan('```\na\n```');
      final span = result.spanAt(4);
      expect(span, isNotNull);
      expect(span!.type, BlockType.fencedCode);
    });

    test('spanAt returns null for unprotected position', () {
      final result = MarkdownBlockScanner.scan('```\na\n```');
      expect(result.spanAt(100), isNull);
    });
  });

  group('MarkdownBlockScanner.applyMask', () {
    test('mask replaces fenced code block', () {
      final result = MarkdownBlockScanner.scan('```\ncode\n```');
      final (masked, codeMap) = MarkdownBlockScanner.applyMask(
        '```\ncode\n```',
        result.spans,
      );
      expect(masked, '__CODE_MASK_0__');
      expect(codeMap, hasLength(1));
      expect(codeMap['__CODE_MASK_0__'], '```\ncode\n```');
    });

    test('mask replaces inline code with dollar mask', () {
      final result = MarkdownBlockScanner.scan(r'`$variable$`');
      final (masked, codeMap) = MarkdownBlockScanner.applyMask(
        r'`$variable$`',
        result.spans,
      );
      expect(masked, '__CODE_MASK_0__');
      expect(
        codeMap['__CODE_MASK_0__'],
        '`___CODE_DOLLAR_MASK___variable___CODE_DOLLAR_MASK___`',
      );
    });

    test('mask preserves text outside spans', () {
      final text = '```\ncode\n```\ntail';
      final result = MarkdownBlockScanner.scan(text);
      final (masked, _) = MarkdownBlockScanner.applyMask(text, result.spans);
      // The scanner consumes the \n after closing ``` as part of the fence
      expect(masked, '__CODE_MASK_0__tail');
    });

    test('mask with multiple spans', () {
      final text = '```\ncode\n```\nxxx\n`c`';
      final result = MarkdownBlockScanner.scan(text);
      final (masked, codeMap) = MarkdownBlockScanner.applyMask(
        text,
        result.spans,
      );
      expect(masked, '__CODE_MASK_0__xxx\n__CODE_MASK_1__');
      expect(codeMap, hasLength(2));
    });

    test('empty spans returns original text', () {
      final (masked, codeMap) = MarkdownBlockScanner.applyMask(
        'hello world',
        [],
      );
      expect(masked, 'hello world');
      expect(codeMap, isEmpty);
    });
  });
}
