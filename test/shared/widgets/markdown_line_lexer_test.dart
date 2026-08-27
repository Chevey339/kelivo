import 'package:Kelivo/shared/widgets/incremental_markdown_document.dart';
import 'package:Kelivo/shared/widgets/markdown_line_lexer.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:flutter_test/flutter_test.dart';

String _unmatchedBacktickRuns({int maxRun = 200}) {
  final buffer = StringBuffer();
  for (var n = 1; n <= maxRun; n++) {
    if (n > 1) buffer.write(' ');
    buffer.write('`' * n);
  }
  return buffer.toString();
}

void main() {
  tearDown(debugDisableMarkdownScanVisits);

  test('unclosed inline code does not hide a later display-math closer', () {
    const content = '`unclosed\n\$\$ `x` \$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
  });

  test(
    'a mid-line details mention does not hide a later display-math closer',
    () {
      const content = 'Use <details> here\n\$\$b\$\$';
      expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    },
  );

  test('a line-leading details block does hide math inside it', () {
    const content = '<details>\n\$\$b\$\$\n</details>';
    expect(markdownEndsWithDisplayMath(content, content.length), isFalse);
  });

  test('fence markers are recognized before inline backticks', () {
    const content = '```\n`\$\$\n```\n\$\$b\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
  });

  test('a line separator is a logical break for display math', () {
    const content = 'Text\u2028\$\$b\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
  });

  test('a paragraph separator is a logical break for display math', () {
    const content = 'Text\u2029\$\$b\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
  });

  test('a carriage return is a logical break for display math', () {
    const content = 'Text\r\$\$b\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
  });

  test('display-math walk visits stay linear on a long space line', () {
    final content = '${' ' * 4000}\n\$\$x\$\$';
    debugResetMarkdownScanVisits();
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    expect(
      debugMarkdownScanVisits,
      lessThanOrEqualTo(content.length * debugMarkdownScanVisitBudgetFactor),
    );
  });

  test('display-math walk visits stay linear on unmatched backtick runs', () {
    final content = '${_unmatchedBacktickRuns()}\n\$\$x\$\$';
    debugResetMarkdownScanVisits();
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    expect(
      debugMarkdownScanVisits,
      lessThanOrEqualTo(content.length * debugMarkdownScanVisitBudgetFactor),
    );
  });

  test('a longer fence is not closed by a shorter run of the same marker', () {
    const content = '````\n```\n\$\$b\$\$\n````';
    expect(markdownEndsWithDisplayMath(content, content.length), isFalse);
  });

  test('a longer fence still allows math after a matching closer', () {
    const content = '````\n```\n\$\$b\$\$\n````\n\$\$c\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
  });

  test('a tilde fence is not closed by backticks', () {
    const content = '~~~\n```\n\$\$b\$\$\n~~~';
    expect(markdownEndsWithDisplayMath(content, content.length), isFalse);
  });

  test('a backtick fence info string with a backtick does not open', () {
    const content = '```lang`sample\n\$\$b\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    final lexer = MarkdownLineLexer();
    expect(lexer.consumeFence('```lang`sample'), isFalse);
    expect(lexer.fenced, isFalse);
  });

  test('a tilde fence info string may contain backticks', () {
    final lexer = MarkdownLineLexer();
    expect(lexer.consumeFence('~~~lang`sample'), isTrue);
    expect(lexer.fenced, isTrue);
    expect(lexer.consumeFence('~~~'), isTrue);
    expect(lexer.fenced, isFalse);
  });

  test(
    'display-math walk visits stay linear on many short inline-code spans',
    () {
      final spans = List<String>.filled(3000, '`x`').join(' ');
      expect(debugBacktickJumpSlotCount(spans), 3000);
      debugResetMarkdownScanVisits();
      final content = '$spans\n\$\$y\$\$';
      expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
      expect(
        debugMarkdownScanVisits,
        lessThanOrEqualTo(content.length * debugMarkdownScanVisitBudgetFactor),
      );
    },
  );

  test('backtick jump table scales with run count on a long line', () {
    final line = '${'a' * 200000}`x`${'b' * 200000}';
    expect(debugBacktickJumpSlotCount(line), 1);
    debugResetMarkdownScanVisits();
    final content = '$line\n\$\$x\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    expect(
      debugMarkdownScanVisits,
      lessThanOrEqualTo(content.length * debugMarkdownScanVisitBudgetFactor),
    );
  });

  test('a successful dollar span discards an inner bracket opener', () {
    const content = '\$\$\n\\[\n\$\$\n\\]';
    expect(markdownEndsWithDisplayMath(content, content.length), isFalse);
    expect(_scanEnds(content), _rendererEnds(content));
  });

  test('a successful bracket span discards an inner dollar opener', () {
    const content = '\\[\n\$\$\n\\]\n\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isFalse);
    expect(_scanEnds(content), _rendererEnds(content));
  });

  test('an unclosed bracket does not hide a later dollar span', () {
    const content = '\\[\n\$\$\nx\n\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    expect(_scanEnds(content), _rendererEnds(content));
  });

  test('an unclosed dollar does not hide a later bracket span', () {
    const content = '\$\$\n\\[\nx\n\\]';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    expect(_scanEnds(content), _rendererEnds(content));
  });

  test('a tailed closer does not end a later successful dollar span', () {
    const content = '\$\$\n\$\$ tail\n\ninside\n\$\$';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    expect(_normalizedSpans(content), _rendererSpans(content));
  });

  test('crossed nested openers end on the outer bracket closer', () {
    const content = '\\[\n\$\$\n\\[\n\$\$\n\\]';
    expect(markdownEndsWithDisplayMath(content, content.length), isTrue);
    expect(_normalizedSpans(content), _rendererSpans(content));
  });

  test('a successful dollar span treats an inner fence marker as content', () {
    const content = '\$\$\n```\n\$\$';
    expect(markdownScanDisplayMath(content).spans, hasLength(1));
    expect(_normalizedSpans(content), _rendererSpans(content));
  });

  test('an earlier unclosed fence still hides later math', () {
    const content = '```\n\$\$\nx\n\$\$';
    expect(markdownScanDisplayMath(content).spans, isEmpty);
    expect(markdownEndsWithDisplayMath(content, content.length), isFalse);
  });

  test('an unclosed dollar opener does not occupy later details', () {
    const content = '\$\$\n<details><summary>s</summary>body</details>';
    expect(markdownScanDisplayMath(content).spans, isEmpty);
    final registry = MarkdownDetailsRegistry(enableMath: true);
    expect(registry.lookup(registry.rewrite(content)), isNotNull);
  });

  test(
    'details inside a successful dollar span do not steal a later block',
    () {
      const source =
          '\$\$\n<details>\n\$\$\n'
          '<details><summary>real</summary>body</details>';
      final registry = MarkdownDetailsRegistry(enableMath: true);
      expect(registry.lookup(registry.rewrite(source))!.summary, 'real');
    },
  );

  test(
    'an indented dollar line with a details closer does not change depth',
    () {
      const source =
          '\$\$\n'
          '  \$\$ </details>\n'
          '\$\$\n'
          '<details><summary>real</summary>body</details>';
      final registry = MarkdownDetailsRegistry(enableMath: true);
      expect(registry.lookup(registry.rewrite(source))!.summary, 'real');
    },
  );

  test(
    'an indented dollar line with a details opener does not steal a block',
    () {
      const source =
          '\$\$\n'
          '  \$\$ <details>\n'
          '\$\$\n'
          '<details><summary>real</summary>body</details>';
      final registry = MarkdownDetailsRegistry(enableMath: true);
      expect(registry.lookup(registry.rewrite(source))!.summary, 'real');
    },
  );

  test('math inside outer details does not close the outer block', () {
    const source =
        '<details><summary>outer</summary>\n'
        '\$\$\n'
        '  \$\$ </details>\n'
        '\$\$\n'
        'body\n'
        '</details>';
    final registry = MarkdownDetailsRegistry(enableMath: true);
    final block = registry.lookup(registry.rewrite(source));
    expect(block, isNotNull);
    expect(block!.summary, 'outer');
    expect(block.body, contains('body'));
  });

  test('details after a closed formula still extract', () {
    const source =
        '\$\$\nx\n\$\$\n'
        '<details><summary>real</summary>body</details>';
    final registry = MarkdownDetailsRegistry(enableMath: true);
    expect(registry.lookup(registry.rewrite(source))!.summary, 'real');
  });

  test('appending plain text keeps later spans after an unresolved opener', () {
    const first = '\$\$\n```\ncode\n```\n\\[\nx\n\\]\n';
    const next = '${first}plain tail';
    final scanner = MarkdownDisplayMathScanner();
    expect([
      for (final span in scanner.synchronize(first).spans)
        (span.start, span.end),
    ], _normalizedSpans(first));
    expect([
      for (final span in scanner.synchronize(next).spans)
        (span.start, span.end),
    ], _normalizedSpans(next));
  });

  test('chunked scanner spans match one-shot on math-dense input', () {
    final scanner = MarkdownDisplayMathScanner();
    var source = '';
    for (var i = 0; i < 20; i++) {
      source += '\$\$\nx$i\n\$\$\n\n';
      expect(
        [
          for (final span in scanner.synchronize(source).spans)
            (span.start, span.end),
        ],
        [
          for (final span in markdownScanDisplayMath(source).spans)
            (span.start, span.end),
        ],
      );
    }
  });

  test('single-shot and chunked scans stay linear on ordinary text', () {
    _expectLinearScan((_) => '0123456789abcdef', chunks: 200);
  });

  test('single-shot and chunked scans stay linear on math-dense text', () {
    _expectLinearScan((_) => '\$\$\nx\n\$\$\n\n', chunks: 80);
  });

  test('single-shot and chunked scans stay linear on fence-dense text', () {
    _expectLinearScan((_) => '```\nx\n```\n\n', chunks: 80);
  });

  test('fence indent is horizontal whitespace for scanner and renderer', () {
    for (final indent in const [' ', '  ', '\t', ' \t']) {
      _expectFenceWhitespace(indent, isFence: true);
    }
    for (final indent in const ['\u00a0', '\u2003', '\u3000']) {
      _expectFenceWhitespace(indent, isFence: false);
    }
  });

  test(
    'display-math spans match LatexBlockScrollableMd on 1-6 line inputs',
    () {
      const atoms = <String>[r'$$', r'$$ tail', r'\[', r'\]', 'inside', ''];
      var cases = 0;
      void walk(List<String> lines) {
        final content = lines.join('\n');
        expect(
          _normalizedSpans(content),
          _rendererSpans(content),
          reason: content.replaceAll('\n', r'\n'),
        );
        cases++;
      }

      void expand(List<String> prefix, int remaining) {
        if (remaining == 0) {
          walk(prefix);
          return;
        }
        for (final atom in atoms) {
          expand([...prefix, atom], remaining - 1);
        }
      }

      for (var n = 1; n <= 6; n++) {
        expand(const [], n);
      }
      expect(cases, greaterThan(8000));
    },
  );

  test('details walker and DetailsHtmlMd agree on a one-line block', () {
    _expectDetailsContract(
      '<details><summary>s</summary>body</details>',
      isDetails: true,
    );
  });

  test('details walker and DetailsHtmlMd agree on inline-code tags', () {
    const source =
        '<details>\n<summary>s</summary>\nUse `<details>` here\n\nmore\n</details>';
    _expectDetailsContract(source, isDetails: true);
    final parsed = markdownParseDetails(source)!;
    expect(parsed.summary, 's');
    expect(parsed.body, contains('more'));
    expect(parsed.body, contains('`<details>`'));
  });

  test('details walker and DetailsHtmlMd reject a cross-line opener', () {
    const source = '<details\nopen>\n<summary>s</summary>\n\nbody\n</details>';
    _expectDetailsContract(source, isDetails: false);
  });

  test('details walker and DetailsHtmlMd agree on a mid-line nested block', () {
    const source =
        '<details>\n<summary>outer</summary>\n'
        'prefix <details>\n<summary>inner</summary>\n\n'
        'inner body\n</details>\n\nouter body\n</details>';
    _expectDetailsContract(source, isDetails: true);
  });

  test(
    'details walker and DetailsHtmlMd agree on inline-code in a summary',
    () {
      const source =
          '<details><summary>Use `<details>`</summary>\n\nbody\n</details>';
      _expectDetailsContract(source, isDetails: true);
    },
  );

  test('details walker and DetailsHtmlMd accept six nested layers', () {
    _expectDetailsContract(_nestedDetails(6), isDetails: true);
  });

  test('unclosed details with many code spans stays linear', () {
    final source =
        '<details><summary>s</summary>${List.filled(20, '`x`').join(' ')}';
    _expectUnclosedDetailsScan(source);
  });

  test('unclosed details with a long backtick run stays linear', () {
    for (final n in const [40, 60]) {
      _expectUnclosedDetailsScan('<details><summary>s</summary>${'`' * n}');
    }
  });

  test('mixed backtick runs pair the same way as the walker', () {
    _expectDetailsContract(
      r'<details><summary>s</summary>`x```<details>y`</details>',
      isDetails: true,
    );
    const remixed = r'<details><summary>s</summary>``x``<details>y``</details>';
    final walker = MarkdownDetailsWalker()..consumeText(remixed);
    expect(walker.depth, 1);
    expect(markdownParseDetails(remixed), isNull);
    expect(_detailsExpMatches(remixed), isFalse);
  });

  test('a same-line details prefix without > stays body text', () {
    const source =
        '<details><summary>s</summary>before <details missing </details>';
    _expectDetailsContract(source, isDetails: true);
    expect(markdownParseDetails(source)!.body, contains('<details missing'));
  });

  test('details regex does not rematch later backticks as a code span', () {
    const source = r'<details><summary>s</summary>`x`<details>y`</details>';
    final walker = MarkdownDetailsWalker()..consumeText(source);
    expect(walker.depth, 1);
    expect(markdownDetailsExtent(source), -1);
    expect(markdownParseDetails(source), isNull);
    expect(_detailsExpMatches(source), isFalse);
  });

  test(
    'details pattern stays case-insensitive after generate recompiles it',
    () {
      final recompiled = RegExp(
        DetailsHtmlMd().exp.pattern,
        multiLine: true,
        dotAll: true,
      );
      expect(
        recompiled.hasMatch('<DETAILS><SUMMARY>s</SUMMARY>more</DETAILS>'),
        isTrue,
      );
      expect(
        recompiled.hasMatch('<Details><Summary>s</Summary>more</Details>'),
        isTrue,
      );
    },
  );

  test('details walker and DetailsHtmlMd agree on uppercase tags', () {
    _expectDetailsContract(
      '<DETAILS><SUMMARY>s</SUMMARY>more</DETAILS>',
      isDetails: true,
    );
    _expectDetailsContract(
      '<Details><Summary>s</Summary>more</Details>',
      isDetails: true,
    );
  });

  test('a dotted details lookalike stays body text', () {
    const source =
        '<details>\n<summary>s</summary>\n<details.foo>\n\nmore\n</details>';
    _expectDetailsContract(source, isDetails: true);
    expect(markdownParseDetails(source)!.body, contains('<details.foo>'));
  });

  test('a self-closing details lookalike stays body text', () {
    const source =
        '<details>\n<summary>s</summary>\n<details/>\n\nmore\n</details>';
    _expectDetailsContract(source, isDetails: true);
  });

  test('an unclosed details prefix in the body stays body text', () {
    const source =
        '<details>\n<summary>s</summary>\nsee <details\n\nmore\n</details>';
    _expectDetailsContract(source, isDetails: true);
  });

  test('inline-code lookalikes do not hide a details block', () {
    const source =
        '<details>\n<summary>s</summary>\n'
        'Use `<details.foo>` and `<DETAILS>` here\n\nmore\n</details>';
    _expectDetailsContract(source, isDetails: true);
  });

  test('a seventh nested layer overflows and is not one details block', () {
    final source = _nestedDetails(7);
    final walker = MarkdownDetailsWalker()..consumeText(source);
    expect(walker.depth, 0);
    expect(walker.overflowed, isTrue);
    expect(markdownDetailsExtent(source), -1);
    expect(markdownParseDetails(source), isNull);
    expect(MarkdownDetailsRegistry().rewrite(source), source);
    expect(_detailsExpMatches(source), isFalse);
  });

  test('splitter visits stay linear on unmatched backtick runs', () {
    final source = 'before\n\n${_unmatchedBacktickRuns()}\n\nafter';
    debugResetMarkdownScanVisits();
    final blocks = IncrementalMarkdownDocument().update(source);
    expect(blocks, hasLength(3));
    expect(
      debugMarkdownScanVisits,
      lessThanOrEqualTo(source.length * debugMarkdownScanVisitBudgetFactor),
    );
  });

  test('details rewrite leaves ordinary inline code and U+E002 unchanged', () {
    const compare = 'Use `a < b` now';
    const tagged = 'Use `<details>` here';
    const doubled = r'Use ``a < b`` now';
    const unclosed = '<details><summary>s</summary>`a < b` still open';
    const privateUse = 'hello \uE002 world';
    for (final source in [compare, tagged, doubled, unclosed, privateUse]) {
      expect(MarkdownDetailsRegistry().rewrite(source), source);
    }
  });

  test('details rewrite replaces a complete block with a placeholder', () {
    const source = '<details><summary>s</summary>`a < b`</details>';
    final registry = MarkdownDetailsRegistry();
    final rewritten = registry.rewrite(source);
    expect(rewritten, isNot(source));
    expect(registry.hasIssuedPlaceholders, isTrue);
    final parsed = registry.lookup(rewritten)!;
    expect(parsed.summary, 's');
    expect(parsed.body, '`a < b`');
    expect(DetailsHtmlMd(registry).exp.hasMatch(rewritten), isTrue);
  });

  test('extract does not promote a closed block inside an unclosed outer', () {
    const source =
        '<details>\n<summary>A</summary>\nunclosed\n'
        '<details><summary>B</summary>body B</details>';
    final walker = MarkdownDetailsWalker()..consumeText(source);
    expect(walker.depth, 1);
    expect(MarkdownDetailsRegistry().rewrite(source), source);
    expect(_detailsExpMatches(source), isFalse);
  });

  test(
    'extract visits stay linear on consecutive unclosed details openers',
    () {
      final source = List.filled(100, '<details>').join('\n');
      expect(source.length, 999);
      debugResetMarkdownScanVisits();
      expect(MarkdownDetailsRegistry().rewrite(source), source);
      expect(
        debugMarkdownScanVisits,
        lessThanOrEqualTo(source.length * debugMarkdownScanVisitBudgetFactor),
      );
    },
  );

  test('a same-line tail is not rewritten to a placeholder', () {
    const source = '<details><summary>s</summary>body</details> tail';
    expect(markdownParseDetails(source), isNotNull);
    expect(MarkdownDetailsRegistry().rewrite(source), source);
    expect(_detailsExpMatches(source), isFalse);
  });

  test('trailing spaces stay a block-boundary placeholder', () {
    const source = '<details><summary>s</summary>body</details>  ';
    final registry = MarkdownDetailsRegistry();
    final rewritten = registry.rewrite(source);
    expect(registry.hasIssuedPlaceholders, isTrue);
    expect(DetailsHtmlMd(registry).exp.hasMatch(rewritten), isTrue);
    expect(registry.lookup(rewritten)!.summary, 's');
  });

  test('same-line adjacent details are not rewritten', () {
    const source =
        '<details><summary>A</summary>a</details>'
        '<details><summary>B</summary>b</details>';
    expect(MarkdownDetailsRegistry().rewrite(source), source);
    expect(_detailsExpMatches(source), isFalse);
  });

  test('a leading-indent details block is rewritten', () {
    const source = '  <details><summary>s</summary>body</details>';
    final registry = MarkdownDetailsRegistry();
    expect(registry.lookup(registry.rewrite(source))!.summary, 's');
  });

  test('extract skips details inside display math when math is enabled', () {
    const source = '\$\$\n<details><summary>s</summary>body</details>\n\$\$';
    expect(MarkdownDetailsRegistry(enableMath: true).rewrite(source), source);
    final off = MarkdownDetailsRegistry(enableMath: false);
    expect(off.rewrite(source), isNot(source));
    expect(off.hasIssuedPlaceholders, isTrue);
  });

  test('nonce selection visits stay linear in used-prefix count', () {
    final prefixes = StringBuffer();
    for (var i = 0; i < 4000; i++) {
      prefixes.write('\uE010$i:');
    }
    final source = '$prefixes\n<details><summary>s</summary>x</details>';
    debugResetMarkdownScanVisits();
    final registry = MarkdownDetailsRegistry();
    expect(registry.lookup(registry.rewrite(source)), isNotNull);
    expect(
      debugMarkdownScanVisits,
      lessThanOrEqualTo(source.length * debugMarkdownScanVisitBudgetFactor),
    );
  });

  test('a literal placeholder token does not steal a rewritten block', () {
    const literal = '\uE010DETAILS0\uE011';
    const details = '<details><summary>real</summary>body</details>';
    final source = '$details\n\n$literal';
    final registry = MarkdownDetailsRegistry();
    final rewritten = registry.rewrite(source);
    expect(rewritten, contains(literal));
    expect(registry.lookup(rewritten.split('\n').first)!.summary, 'real');
    expect(registry.lookup(literal), isNull);
  });

  test('nonce is chosen from the root even when details are nested', () {
    const literal = '\uE0100:0\uE011';
    const source =
        '- <details><summary>real</summary>body</details>\n- $literal';
    final registry = MarkdownDetailsRegistry();
    expect(registry.rewrite(source), source);
    final item = registry.rewrite(
      '<details><summary>real</summary>body</details>',
    );
    expect(registry.lookup(item)!.summary, 'real');
    expect(registry.lookup(literal), isNull);
    expect(item, isNot(literal));
  });
}

List<(int, int)> _normalizedSpans(String text) {
  return [
    for (final span in markdownScanDisplayMath(text).spans)
      (span.start, span.end),
  ];
}

List<(int, int)> _rendererSpans(String text) {
  return [
    for (final match in LatexBlockScrollableMd().exp.allMatches(text))
      (_skipWsStart(text, match.start, match.end), _trimWsEnd(text, match.end)),
  ];
}

bool _scanEnds(String text) => markdownEndsWithDisplayMath(text, text.length);

bool _rendererEnds(String text) {
  final spans = _rendererSpans(text);
  return spans.isNotEmpty && spans.last.$2 == text.length;
}

int _skipWsStart(String text, int start, int end) {
  var i = start;
  while (i < end && markdownIsWhitespace(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

int _trimWsEnd(String text, int end) {
  var i = end;
  while (i > 0 && markdownIsWhitespace(text.codeUnitAt(i - 1))) {
    i--;
  }
  return i;
}

String _nestedDetails(int levels) {
  final out = StringBuffer();
  for (var i = 1; i <= levels; i++) {
    out.writeln('<details>');
    out.writeln('<summary>L$i</summary>');
  }
  out.write('deep-body');
  for (var i = 0; i < levels; i++) {
    out.write('</details>');
    if (i < levels - 1) out.writeln();
  }
  return out.toString();
}

void _expectDetailsContract(
  String source, {
  required bool isDetails,
  bool overflowed = false,
}) {
  final walker = MarkdownDetailsWalker();
  walker.consumeText(source);
  expect(walker.depth, 0);
  expect(walker.overflowed, overflowed);
  expect(markdownDetailsExtent(source) >= 0, isDetails);
  expect(markdownParseDetails(source) != null, isDetails);
  expect(_detailsExpMatches(source), isDetails);
}

bool _detailsExpMatches(String source) {
  final registry = MarkdownDetailsRegistry();
  final rewritten = registry.rewrite(source);
  return registry.hasIssuedPlaceholders &&
      DetailsHtmlMd(registry).exp.hasMatch(rewritten);
}

void _expectLinearScan(
  String Function(int index) chunk, {
  required int chunks,
}) {
  final full = StringBuffer();
  for (var i = 0; i < chunks; i++) {
    full.write(chunk(i));
  }
  final text = full.toString();
  debugResetMarkdownScanVisits();
  markdownScanDisplayMath(text);
  expect(
    debugMarkdownScanVisits,
    lessThanOrEqualTo(text.length * debugMarkdownScanVisitBudgetFactor),
  );

  final scanner = MarkdownDisplayMathScanner();
  var source = '';
  debugResetMarkdownScanVisits();
  for (var i = 0; i < chunks; i++) {
    source += chunk(i);
    scanner.synchronize(source);
  }
  expect(
    debugMarkdownScanVisits,
    lessThanOrEqualTo(source.length * debugMarkdownScanVisitBudgetFactor),
  );
}

void _expectFenceWhitespace(String indent, {required bool isFence}) {
  final probed = '$indent```\n\$\$\nx\n\$\$\n```';
  expect(
    markdownScanDisplayMath(probed).spans.isEmpty,
    isFence,
    reason: 'scanner indent ${indent.codeUnits}',
  );
  expect(
    FencedCodeBlockMd(streaming: false).exp.matchAsPrefix(probed) != null,
    isFence,
    reason: 'renderer indent ${indent.codeUnits}',
  );
}

void _expectUnclosedDetailsScan(String source) {
  debugResetMarkdownScanVisits();
  expect(_detailsExpMatches(source), isFalse);
  final walker = MarkdownDetailsWalker()..consumeText(source);
  expect(walker.depth, 1);
  expect(markdownParseDetails(source), isNull);
  expect(
    debugMarkdownScanVisits,
    lessThanOrEqualTo(source.length * debugMarkdownScanVisitBudgetFactor),
  );
}
