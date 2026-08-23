import 'package:Kelivo/shared/widgets/incremental_markdown_document.dart';
import 'package:Kelivo/shared/widgets/markdown_line_lexer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('append-only updates retain completed block identities', () {
    final document = IncrementalMarkdownDocument();
    final initial = document.update('first paragraph\n\nsecond');
    final firstBlock = initial.first;

    final updated = document.update('first paragraph\n\nsecond grows');

    expect(identical(updated.first, firstBlock), isTrue);
    expect(updated.last.text, 'second grows');
  });

  test('a line separator before a fence keeps blanks inside the fence', () {
    for (final mark in const ['\u2028', '\u2029']) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(
        'before\n\nText$mark```dart\ncode\n\ninside\n```\n\nafter',
      );
      expect(blocks, hasLength(3), reason: mark);
      expect(blocks[1].text, contains('code\n\ninside'));
      expect(blocks.last.text, 'after');
    }
  });

  test(
    'a line separator before a tilde fence keeps blanks inside the fence',
    () {
      for (final mark in const ['\u2028', '\u2029']) {
        final document = IncrementalMarkdownDocument();
        final blocks = document.update(
          'before\n\nText$mark~~~\ncode\n\ninside\n~~~\n\nafter',
        );
        expect(blocks, hasLength(3), reason: mark);
        expect(blocks[1].text, contains('code\n\ninside'));
      }
    },
  );

  test('a line separator before details keeps blanks inside the details', () {
    for (final mark in const ['\u2028', '\u2029']) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(
        'before\n\nText$mark<details>\n\nbody\n</details>\n\nafter',
      );
      expect(blocks, hasLength(3), reason: mark);
      expect(blocks[1].text, contains('body'));
      expect(blocks.last.text, 'after');
    }
  });

  test('a shorter fence run does not close a longer opening fence', () {
    for (final item in const [
      ('````dart\na\n```\n\nb\n````', 'a\n```\n\nb'),
      ('~~~~\na\n~~~\n\nb\n~~~~', 'a\n~~~\n\nb'),
      ('`````\na\n```\n\nb\n`````', 'a\n```\n\nb'),
    ]) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update('before\n\n${item.$1}\n\nafter');
      expect(blocks, hasLength(3), reason: item.$1);
      expect(blocks[1].text, contains(item.$2), reason: item.$1);
      expect(blocks.last.text, 'after');
    }
  });

  test('a closer with an info string does not close the fence', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      'before\n\n```\na\n``` dart\n\nb\n```\n\nafter',
    );
    expect(blocks, hasLength(3));
    expect(blocks[1].text, contains('a\n``` dart\n\nb'));
    expect(blocks.last.text, 'after');
  });

  test('blank lines inside fences do not split source blocks', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('before\n\n```dart\na\n\nb\n```\n\nafter');

    expect(blocks, hasLength(3));
    expect(blocks[1].text, contains('a\n\nb'));
  });

  test('blank lines inside display math do not split source blocks', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      'before\n\n\$\$\na + b\n\nc + d\n\$\$\n\nafter',
    );

    expect(blocks, hasLength(3));
    expect(blocks[1].text, contains('a + b\n\nc + d'));
    expect(blocks[1].text, contains('\$\$'));
  });

  test(
    'blank lines inside bracket display math do not split source blocks',
    () {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(
        'before\n\n\\[\na + b\n\nc + d\n\\]\n\nafter',
      );

      expect(blocks, hasLength(3));
      expect(blocks[1].text, contains('a + b\n\nc + d'));
    },
  );

  test('blank lines inside details html do not split source blocks', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      'before\n\n<details>\n<summary>s</summary>\n\nbody\n\n</details>\n\nafter',
    );

    expect(blocks, hasLength(3));
    expect(blocks[1].text, contains('body'));
    expect(blocks[1].text, contains('</details>'));
  });

  test('blank lines inside a loose list do not split source blocks', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('- first\n\n- second\n\nnext paragraph\n');

    expect(blocks, hasLength(2));
    expect(blocks.first.text, contains('- first\n\n- second'));
    expect(blocks.last.text, 'next paragraph\n');
  });

  test('indented list continuation stays in the same source block', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('- item\n\n  still the item\n\nnext\n');

    expect(blocks, hasLength(2));
    expect(blocks.first.text, contains('still the item'));
    expect(blocks.last.text, 'next\n');
  });

  test('single-line display math does not swallow the next paragraph', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('\$\$ a + b \$\$\n\nnext');

    expect(blocks, hasLength(2));
    expect(blocks.first.text, r'$$ a + b $$');
    expect(blocks.last.text, 'next');
  });

  test('mid-paragraph display math follows successful spans only', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('说明文字 \$\$\na + b\n\nc + d\n\$\$\n\nafter');

    expect(blocks.length, greaterThanOrEqualTo(2));
    expect(blocks.last.text, contains('after'));
  });

  test('mid-paragraph bracket display math follows successful spans only', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('说明文字 \\[\na + b\n\nc + d\n\\]\n\nafter');

    expect(blocks.length, greaterThanOrEqualTo(2));
    expect(blocks.last.text, 'after');
  });

  test('list-item display math follows successful spans only', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      '- see \$\$\na + b\n\nc + d\n\$\$\n\nafter\n',
    );

    expect(blocks.length, greaterThanOrEqualTo(2));
    expect(blocks.last.text, contains('after'));
  });

  test('inline code dollars do not start display math protection', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      'Use `\$\$` as currency.\n\nFirst paragraph.\n\nSecond paragraph.',
    );

    expect(blocks, hasLength(3));
    expect(blocks[1].text, startsWith('First paragraph.'));
    expect(blocks.last.text, 'Second paragraph.');
  });

  test(
    'closed display math on a line can still open a later bracket block',
    () {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(
        'text \$\$ a \$\$ \\[\nb\n\nc\n\\]\n\nafter',
      );

      expect(blocks.length, greaterThanOrEqualTo(2));
      expect(blocks.last.text, 'after');
    },
  );

  test('an unclosed math blank is not committed before the closer arrives', () {
    final document = IncrementalMarkdownDocument();
    final first = document.update('\$\$\na\n\n');
    expect(first, hasLength(1));
    expect(first.single.stable, isFalse);

    final second = document.update('\$\$\na\n\nb\n\$\$\n\nafter');
    expect(second, hasLength(2));
    expect(second.first.text, contains('a\n\nb'));
    expect(second.last.text, 'after');
  });

  test('splitter math scan visits stay linear across append chunks', () {
    _expectDocumentLinearScan((_) => '0123456789abcdef', chunks: 200);
  });

  test('math-dense splitter scans stay linear one-shot and chunked', () {
    _expectDocumentLinearScan((_) => '\$\$\nx\n\$\$\n\n', chunks: 80);
  });

  test('fence-dense splitter scans stay linear one-shot and chunked', () {
    _expectDocumentLinearScan((_) => '```\nx\n```\n\n', chunks: 80);
  });

  test('fence indent is horizontal whitespace for the splitter', () {
    for (final indent in const [' ', '  ', '\t', ' \t']) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(
        'before\n\n$indent```\ncode\n\ninside\n```\n\nafter',
      );
      expect(blocks, hasLength(3), reason: indent);
      expect(blocks[1].text, contains('code\n\ninside'), reason: indent);
      expect(blocks.last.text, 'after', reason: indent);
    }
    for (final indent in const ['\u00a0', '\u2003', '\u3000']) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(
        'before\n\n$indent```\ncode\n\ninside\n```\n\nafter',
      );
      expect(
        blocks.any(
          (block) =>
              block.text.contains('code') && block.text.contains('inside'),
        ),
        isFalse,
        reason: 'wide space $indent must not keep a fence blank together',
      );
    }
  });

  test('a tailed dollar closer does not split a later successful span', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('\$\$\n\$\$ tail\n\ninside\n\$\$\n\nafter');
    expect(blocks, hasLength(2));
    expect(blocks.first.text, contains('inside'));
    expect(blocks.last.text, 'after');
  });

  test('crossed nested openers stay one successful bracket span', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('\\[\n\$\$\n\\[\n\$\$\n\\]\n\nafter');
    expect(blocks, hasLength(2));
    expect(blocks.last.text, 'after');
  });

  test('inline code details tags do not freeze later paragraph splits', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      'Use `<details>` to create a collapsible section.\n\n'
      'First paragraph.\n\n'
      'Second paragraph.',
    );

    expect(blocks, hasLength(3));
    expect(blocks[1].text, startsWith('First paragraph.'));
    expect(blocks.last.text, 'Second paragraph.');
  });

  test('prose details mention does not freeze later paragraph splits', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      'Use <details> to create a collapsible section.\n\n'
      'First paragraph.\n\n'
      'Second paragraph.',
    );

    expect(blocks, hasLength(3));
  });

  test('seven nested details keep inner blanks in one block', () {
    final document = IncrementalMarkdownDocument();
    final nested = [
      for (var i = 1; i <= 7; i++) '<details>\n<summary>L$i</summary>',
      'deep-body',
      for (var i = 0; i < 7; i++) '</details>',
    ].join('\n');
    final blocks = document.update('before\n\n$nested\n\nafter');
    expect(blocks, hasLength(3));
    expect(blocks[1].text, contains('deep-body'));
    expect(blocks.last.text, 'after');
  });

  test('a cross-line details opener does not protect later blanks', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      'before\n\n<details\nopen>\n<summary>s</summary>\n\nbody\n</details>\n\nafter',
    );
    expect(blocks, hasLength(4));
    expect(blocks.first.text, 'before');
    expect(blocks.last.text, 'after');
  });

  test('mid-line nested details keep the outer block together', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update(
      'before\n\n'
      '<details>\n'
      '<summary>outer</summary>\n'
      'prefix <details>\n'
      '<summary>inner</summary>\n\n'
      'inner body\n'
      '</details>\n\n'
      'outer body\n'
      '</details>\n\n'
      'after',
    );
    expect(blocks, hasLength(3));
    expect(blocks[1].text, contains('inner body'));
    expect(blocks[1].text, contains('outer body'));
    expect(blocks.last.text, 'after');
  });

  test(
    'inline details in a details body do not leave the outer block open',
    () {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(
        '<details>\n<summary>s</summary>\n'
        'Use `<details>` here\n\n'
        'more\n'
        '</details>\n\n'
        'after',
      );
      expect(blocks, hasLength(2));
      expect(blocks.last.text, 'after');
    },
  );

  test(
    'inline details tags inside a details summary do not freeze later splits',
    () {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(
        '<details><summary>Use `<details>`</summary>\n\n'
        'body\n'
        '</details>\n\n'
        'after',
      );

      expect(blocks, hasLength(2));
      expect(blocks.first.text, contains('</details>'));
      expect(blocks.last.text, 'after');
    },
  );

  test('1 MiB append stream scans each source code unit once', () {
    final document = IncrementalMarkdownDocument();
    var source = '';
    final chunk = List<String>.filled(256, '0123456789abcdef').join();
    for (var index = 0; index < 256; index++) {
      source += chunk;
      document.update(source);
    }

    expect(source.length, 1 << 20);
    expect(document.rescannedCodeUnits, source.length);
    expect(document.blocks, hasLength(1));
  });

  test('extra blank lines do not replace a completed block', () {
    final document = IncrementalMarkdownDocument();
    final first = document.update('first paragraph\n\n');
    final firstBlock = first.single;

    final grown = document.update('first paragraph\n\n\n');
    expect(identical(grown.single, firstBlock), isTrue);
    expect(grown.single.text, firstBlock.text);
    expect(grown.single.text, 'first paragraph');

    final again = document.update('first paragraph\n\n\n\n');
    expect(identical(again.single, firstBlock), isTrue);
    expect(again.single.text, 'first paragraph');
  });

  test('C# paragraphs do not collapse into one block', () {
    final paragraphs = [for (var i = 0; i < 20; i++) 'Language: C# sample $i'];
    for (final ending in const ['', '\n', '\n\n']) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update('${paragraphs.join('\n\n')}$ending');
      expect(blocks, hasLength(20), reason: 'ending ${ending.length} LFs');
      expect(_startsAreMonotonicAndUnique(blocks), isTrue);
    }
  });

  test('indented unfinished tail is returned with the previous block', () {
    final document = IncrementalMarkdownDocument();
    final withoutNewline = document.update('A\n\n    # Heading #');
    expect(withoutNewline, hasLength(1));
    expect(withoutNewline.single.text, 'A\n\n    # Heading #');

    final withNewline = document.update('A\n\n    # Heading #\n');
    expect(withNewline, hasLength(1));
    expect(withNewline.single.text, 'A\n\n    # Heading #\n');

    final closed = document.update('A\n\n    # Heading #\n\nNext');
    expect(closed, hasLength(2));
    expect(closed.first.text, 'A\n\n    # Heading #');
    expect(closed.last.text, 'Next');
  });

  test('whitespace-only indent tail keeps the stable block identical', () {
    final document = IncrementalMarkdownDocument();
    final first = document.update('A\n\n').single;
    expect(first.stable, isTrue);

    final afterSpaces = document.update('A\n\n    ');
    expect(identical(afterSpaces.single, first), isTrue);
    expect(afterSpaces.single.stable, isTrue);
    expect(afterSpaces.single.text, 'A');

    final afterHeading = document.update('A\n\n    # Heading #');
    expect(afterHeading, hasLength(1));
    expect(afterHeading.single.stable, isFalse);
    expect(identical(afterHeading.single, first), isFalse);
    expect(afterHeading.single.text, 'A\n\n    # Heading #');
  });

  test('only the unfinished tail is marked unstable', () {
    final document = IncrementalMarkdownDocument();
    final blocks = document.update('first\n\nsecond');
    expect(blocks.first.stable, isTrue);
    expect(blocks.last.stable, isFalse);
  });

  test('CR then LF across updates is one newline', () {
    final document = IncrementalMarkdownDocument();
    document.update('A\r');
    final blocks = document.update('A\r\n\nB');
    expect(blocks, hasLength(2));
    expect(blocks.first.text, 'A');
    expect(blocks.last.text, 'B');
  });

  test('a CR-free append reuses the caller source string', () {
    final document = IncrementalMarkdownDocument();
    var source = 'Hello';
    document.update(source);
    expect(document.debugReusesCallerSource, isTrue);

    source += ' world';
    document.update(source);
    expect(document.debugReusesCallerSource, isTrue);
    expect(document.blocks.single.text, 'Hello world');
  });

  test('a CR forces a normalized copy of the source', () {
    final document = IncrementalMarkdownDocument();
    document.update('A\r\nB');
    expect(document.debugReusesCallerSource, isFalse);
    expect(document.blocks.single.text, 'A\nB');
  });

  test('a CR in an earlier chunk does not rescan the whole source', () {
    final document = IncrementalMarkdownDocument();
    var source = 'A\r';
    document.update(source);
    final afterCR = document.rescannedCodeUnits;
    for (var i = 0; i < 100; i++) {
      source += 'x';
      document.update(source);
    }
    expect(document.rescannedCodeUnits, afterCR + 100);
  });

  test('line-separator and paragraph-separator are not safe boundaries', () {
    for (final mark in const ['\u2028', '\u2029']) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update('A\n$mark\nB');
      expect(
        blocks,
        hasLength(1),
        reason: 'U+${mark.codeUnitAt(0).toRadixString(16)}',
      );
      expect(blocks.single.text, 'A\n$mark\nB');
    }
  });

  test('CRLF and bare CR split like LF after normalization', () {
    for (final pair in const [
      ('A\r\n\r\nB', 'A'),
      ('A\r\rB', 'A'),
      ('A\n\nB', 'A'),
    ]) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(pair.$1);
      expect(blocks, hasLength(2), reason: pair.$1);
      expect(blocks.first.text, pair.$2);
      expect(blocks.last.text, 'B');
    }
  });

  test('nbsp and next-line are content inside a blank run', () {
    for (final mark in const ['\u00a0', '\u0085', ' ', '\t']) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update('A\n$mark\nB');
      expect(blocks, hasLength(1), reason: 'mark ${mark.codeUnits}');
    }
  });

  test('ATX opening hashes do not span a blank line', () {
    for (final source in const ['#\n\nHeading #', '###\n\nHeading ###']) {
      for (final ending in const ['', '\n', '\n\n']) {
        final document = IncrementalMarkdownDocument();
        final blocks = document.update('$source$ending');
        expect(
          blocks.length,
          greaterThanOrEqualTo(2),
          reason: '$source ending ${ending.length}',
        );
      }
    }
  });

  test('seven or more hashes after a heading stay their own block', () {
    for (final hashes in const [1, 6, 7, 20]) {
      final closer = '#' * hashes;
      final document = IncrementalMarkdownDocument();
      final blocks = document.update('# Heading\n\n$closer\n\nNext');
      expect(blocks, hasLength(3), reason: '$hashes closing hashes');
      expect(blocks[1].text, closer);
    }
  });

  test('same-line closing hashes do not merge the next paragraph', () {
    for (final hashes in const [1, 6, 7, 20]) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update('# Heading ${'#' * hashes}\n\nNext');
      expect(blocks, hasLength(2), reason: '$hashes closing hashes');
      expect(blocks.last.text, 'Next');
    }
  });

  test(
    'leading spaces and tabs keep an unfinished heading with the block above',
    () {
      for (final indent in const ['', ' ', '   ', '    ', '\t']) {
        for (final ending in const ['', '\n', '\n\n']) {
          final document = IncrementalMarkdownDocument();
          final source = 'A\n\n$indent# Heading #$ending';
          final blocks = document.update(source);
          expect(_startsAreMonotonicAndUnique(blocks), isTrue, reason: source);
          expect(blocks, hasLength(indent.isEmpty ? 2 : 1), reason: source);
        }
      }
    },
  );

  test('ordinary paragraphs grow one stable block per paragraph', () {
    final document = IncrementalMarkdownDocument();
    var source = 'paragraph 1\n\n';
    var blocks = document.update(source);
    expect(blocks, hasLength(1));
    final first = blocks.single;
    for (var i = 2; i <= 8; i++) {
      source = '${source}paragraph $i\n\n';
      blocks = document.update(source);
      expect(blocks, hasLength(i));
      expect(_startsAreMonotonicAndUnique(blocks), isTrue);
      expect(identical(blocks.first, first), isTrue);
    }
  });

  test('lists, fences, details and tables still split on the far side', () {
    const cases = <(String, int)>[
      ('- one\n\n- two\n\nnext\n', 2),
      ('```dart\na\n\nb\n```\n\nafter\n', 2),
      ('<details>\n<summary>s</summary>\n\nbody\n</details>\n\nafter\n', 2),
      ('| a | b |\n| --- | --- |\n| 1 | 2 |\n\nafter\n', 2),
      ('before\n\n- one\n\n- two\n', 2),
      ('before\n\n```\ncode\n```\n', 2),
      ('before\n\n<details>\nbody\n</details>\n', 2),
      ('before\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n', 2),
    ];
    for (final item in cases) {
      final document = IncrementalMarkdownDocument();
      final blocks = document.update(item.$1);
      expect(blocks, hasLength(item.$2), reason: item.$1);
    }
  });

  test(
    'a second standalone formula does not freeze the following paragraph',
    () {
      for (final math in const [
        r'$$a$$'
            '\ntext\n'
            r'$$b$$',
        r'\[a\]'
            '\ntext\n'
            r'\[b\]',
        r'$$a$$'
            '\ntext\n'
            r'\[b\]',
        r'\[a\]'
            '\ntext\n'
            r'$$b$$',
      ]) {
        final document = IncrementalMarkdownDocument();
        final blocks = document.update('$math\n\nNext');
        expect(blocks, hasLength(2), reason: math);
        expect(blocks.last.text, 'Next');
      }
    },
  );

  test('streaming prefixes of an indented tail stay one visible block', () {
    const full = 'A\n\n    # Heading #\n\nNext';
    final document = IncrementalMarkdownDocument();
    IncrementalMarkdownBlock? first;
    for (var end = 1; end <= full.length; end++) {
      final blocks = document.update(full.substring(0, end));
      expect(_startsAreMonotonicAndUnique(blocks), isTrue, reason: '[:$end]');
      if (blocks.isEmpty) continue;
      first ??= blocks.first;
      expect(blocks.first.start, first.start);
    }
    expect(first, isNotNull);
    expect(document.blocks, hasLength(2));
    expect(document.blocks.first.stable, isTrue);
    expect(document.blocks.last.stable, isFalse);
  });

  test('long italic paragraph prefixes preserve every source character', () {
    final full = List<String>.generate(
      120,
      (index) =>
          '*动作$index：懒懒地、黏糊糊地伸了个懒腰*\n\n'
          '正文$index：反而笑得更甜，然后理直气壮地继续说话。',
    ).join('\n\n');
    expect(full.length, greaterThan(5000));

    final document = IncrementalMarkdownDocument();
    for (var end = 1; end <= full.length; end++) {
      final prefix = full.substring(0, end);
      final blocks = document.update(prefix);
      final blockSource = blocks.map((block) => block.text).join();
      expect(
        blockSource.replaceAll('\n', ''),
        prefix.replaceAll('\n', ''),
        reason: 'prefix ending at UTF-16 code unit $end',
      );
    }
  });
}

void _expectDocumentLinearScan(
  String Function(int index) chunk, {
  required int chunks,
}) {
  final full = StringBuffer();
  for (var i = 0; i < chunks; i++) {
    full.write(chunk(i));
  }
  final text = full.toString();
  debugResetMarkdownScanVisits();
  IncrementalMarkdownDocument().update(text);
  expect(
    debugMarkdownScanVisits,
    lessThanOrEqualTo(text.length * debugMarkdownScanVisitBudgetFactor),
  );

  final document = IncrementalMarkdownDocument();
  var source = '';
  debugResetMarkdownScanVisits();
  for (var i = 0; i < chunks; i++) {
    source += chunk(i);
    document.update(source);
  }
  expect(
    debugMarkdownScanVisits,
    lessThanOrEqualTo(source.length * debugMarkdownScanVisitBudgetFactor),
  );
}

bool _startsAreMonotonicAndUnique(List<IncrementalMarkdownBlock> blocks) {
  final seen = <int>{};
  var previous = -1;
  for (final block in blocks) {
    if (block.start <= previous) return false;
    if (!seen.add(block.start)) return false;
    previous = block.start;
  }
  return true;
}
