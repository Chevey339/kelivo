import 'dart:io';

import "../../support/business_test_harness.dart";

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The AST renderer keeps its block layout when streaming completes. If the
/// streaming and finished states render at different heights, the
/// timeline — which is pinned to the tail during generation — jumps by the
/// difference on the frame the reply ends. Every case here must measure the
/// same height on both paths.
void main() {
  setUpAll(() async {
    // The default test font reports whole-pixel metrics for every size, which
    // hides the per-line rounding a real font goes through. Lay these cases out
    // with a real font so a separator that only matches on paper still fails.
    final bytes = File(
      'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      'markdown-metrics',
    )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('streaming and finished markdown are the same height', () {
    late WidgetTester boundTester;

    Future<double> heightFor(
      String text, {
      required bool streaming,
      required String tag,
      required TextStyle style,
      double textScale = 1.0,
    }) async {
      await boundTester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: SingleChildScrollView(
                    child: MarkdownWithCodeHighlight(
                      key: ValueKey<String>(tag),
                      text: text,
                      streaming: streaming,
                      baseStyle: style,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await boundTester.pump(const Duration(milliseconds: 300));
      return boundTester.getSize(find.byType(MarkdownWithCodeHighlight)).height;
    }

    /// The chat bubble's own base style, with the test font substituted in.
    const baseStyle = TextStyle(
      fontFamily: 'markdown-metrics',
      fontSize: 15.7,
      height: 1.5,
    );

    Future<void> expectStableText(
      String label,
      String text, {
      TextStyle style = baseStyle,
      double textScale = 1.0,
      int minBlocks = 2,
    }) async {
      final streamingHeight = await heightFor(
        text,
        streaming: true,
        style: style,
        textScale: textScale,
        tag: '$label-streaming',
      );
      expect(find.byType(BlockList), findsWidgets);
      final renderedBlocks = const MarkdownParser()
          .parse(text, streaming: true)
          .children
          .length;
      expect(
        renderedBlocks,
        greaterThanOrEqualTo(minBlocks),
        reason: '$label: the fixture must cross actual AST block boundaries',
      );
      final finishedHeight = await heightFor(
        text,
        streaming: false,
        style: style,
        textScale: textScale,
        tag: '$label-finished',
      );
      expect(
        streamingHeight,
        finishedHeight,
        reason:
            '$label: the reply would jump '
            '${finishedHeight - streamingHeight}px when it finishes',
      );
    }

    Future<void> expectStableHeight(
      String label,
      List<String> blocks, {
      TextStyle style = baseStyle,
      double textScale = 1.0,
      String terminator = '\n',
    }) {
      return expectStableText(
        label,
        '${blocks.join('\n\n')}$terminator',
        style: style,
        textScale: textScale,
      );
    }

    // Exercise both native paragraph and chunked long-paragraph layouts.
    String pad(int index) =>
        'Body $index. ${'The rain kept falling on the quiet street. ' * 16}';

    testWidgets('across block shapes', (tester) async {
      boundTester = tester;
      tester.view.physicalSize = const Size(1170, 2100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await expectStableHeight('two paragraphs', [pad(1), pad(2)]);
      await expectStableHeight('four paragraphs', [
        pad(1),
        pad(2),
        pad(3),
        pad(4),
      ]);
      await expectStableHeight('headings between paragraphs', [
        '# Heading one',
        pad(1),
        '## Heading two',
        pad(2),
      ]);
      await expectStableHeight('paragraph then list', [
        pad(1),
        '- one\n- two\n- three',
        pad(2),
      ]);
      await expectStableHeight('list then paragraph', [
        '- one\n- two\n- three',
        pad(1),
      ]);
      await expectStableHeight('ordered and nested lists', [
        '1. one\n2. two',
        pad(1),
        '- one\n  - a\n  - b\n- two',
        pad(2),
      ]);
      await expectStableHeight('a list that trails off into prose', [
        '- one\n- two\ntrailing prose on the list',
        pad(1),
      ]);
      await expectStableHeight('a loose list', ['- one\n\n- two', pad(1)]);
      await expectStableHeight('paragraph then code', [
        pad(1),
        '```dart\nvar a = 1;\n```',
        pad(2),
      ]);
      await expectStableHeight('code then paragraph', [
        '```dart\nvar a = 1;\n```',
        pad(1),
      ]);
      await expectStableHeight('blockquote and table', [
        '> quoted line one\n> quoted line two',
        pad(1),
        '| a | b |\n| --- | --- |\n| 1 | 2 |',
        pad(2),
      ]);
      // A horizontal rule and a display-math block both close their pattern
      // with `\s*$`, so the whole-document render folds the blank line after
      // them into the block and leaves no gap to reproduce.
      await expectStableHeight('horizontal rules', [
        pad(1),
        '---',
        pad(2),
        'prose then a rule\n---',
        pad(3),
      ]);
      await expectStableHeight('display math', [
        pad(1),
        r'$$\frac{a}{b}$$',
        pad(2),
        'prose then math\n'
            r'$$a + b = c$$',
        pad(3),
        r'\[a^2 + b^2 = c^2\]',
        pad(4),
      ]);
      await expectStableHeight('crossed display math openers', [
        pad(1),
        '\$\$\n\\[\n\$\$\n\\]',
        pad(2),
      ]);
      await expectStableHeight('crossed display math openers reversed', [
        pad(1),
        '\\[\n\$\$\n\\]\n\$\$',
        pad(2),
      ]);
      await expectStableHeight('tailed dollar closer then real closer', [
        pad(1),
        '\$\$\n\$\$ tail\n\ninside\n\$\$',
        pad(2),
      ]);
      await expectStableHeight('crossed nested openers', [
        pad(1),
        '\\[\n\$\$\n\\[\n\$\$\n\\]',
        pad(2),
      ]);
      // Closing hashes are optional decoration on a one-line heading; they
      // no longer swallow the blank line after it.
      await expectStableHeight('headings that close with hashes', [
        pad(1),
        '# Heading one #',
        pad(2),
        '### Heading three ###',
        pad(3),
      ]);
      // The rule and math patterns spell their line breaks and indents as `\s`,
      // which covers a bare CR and a non-breaking space.
      await expectStableHeight('rules behind unusual whitespace', [
        pad(1),
        'prose then a rule\r---',
        pad(2),
        '\u00a0---',
        pad(3),
        '\u00a0'
            r'$$a + b$$',
        pad(4),
      ]);
      // A reply that has just emitted a paragraph break leaves a blank tail
      // block, which the whole-document render trims away.
      await expectStableHeight('a reply sitting on a paragraph break', [
        pad(1),
        pad(2),
      ], terminator: '\n\n');
      await expectStableHeight('a reply sitting on several blank lines', [
        pad(1),
        pad(2),
      ], terminator: '\n\n\n\n');
      await expectStableHeight('CJK paragraphs', [
        '这是一个中文段落。' * 12,
        '这是另一个中文段落。' * 12,
        pad(1),
      ]);
    });

    testWidgets('across blank runs between blocks', (tester) async {
      boundTester = tester;
      tester.view.physicalSize = const Size(1170, 2100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // `NewLines` collapses a run of line breaks into one blank line, however
      // many it holds.
      for (final breaks in ['\n\n', '\n\n\n', '\n\n\n\n', '\n\n\n\n\n']) {
        await expectStableText(
          '${breaks.length} line breaks between paragraphs',
          '${pad(1)}$breaks${pad(2)}\n',
        );
      }
      // A blank line carrying whitespace is content, not a boundary: the block
      // around it renders whole, so these cases hold the splitter to that.
      final runs = <String, String>{
        'a space on the blank line': '\n \n',
        'a blank line then a space': '\n\n \n',
        'two whitespace lines': '\n\n \n \n\n',
        'a tab on the blank line': '\n\t\n',
        'a no-break space': '\n\u00a0\n',
        'spaces trailing the paragraph': '  \n\n',
      };
      for (final run in runs.entries) {
        // Every one of these absorbs whitespace ahead of itself differently.
        final followers = <String, String>{
          'a paragraph': pad(2),
          'a heading': '# Heading one',
          'a heading with closing hashes': '## Heading two ##',
          'a rule': '---',
          'display math': r'$$a + b$$',
          'a list': '- one\n- two',
          'a code block': '```dart\nvar a = 1;\n```',
        };
        for (final next in followers.entries) {
          await expectStableText(
            '${run.key} before ${next.key}',
            '${pad(1)}\n\n${pad(2)}${run.value}${next.value}\n\n${pad(3)}\n',
          );
        }
      }
      // Indentation is syntax, so an indented line has to reach the renderer
      // with its indent intact.
      for (final indented in <String>[
        '    # Heading #',
        '    # Heading',
        '    indented prose',
        '    ---',
        '  two spaces of indent',
      ]) {
        await expectStableText(
          'indented block ${indented.trim()}',
          '${pad(1)}\n\n$indented\n\n${pad(2)}\n',
        );
      }
      // Opening hashes cannot reach a title on a later line, so these stay
      // ordinary paragraphs on both render paths.
      await expectStableText(
        'hashes and a title on separate lines',
        '${pad(1)}\n\n${pad(2)}\n\n#\nHeading #\n\n${pad(3)}\n',
      );
      await expectStableText(
        'a heading then a lone hash line',
        '${pad(1)}\n\n${pad(2)}\n\n# Heading one\n\n#\nHeading #'
            '\n\n## Heading two\n\n${pad(3)}\n',
      );
      // A closer that leaves prose behind on its line cannot close the math
      // block, so the match runs on to the last one — and a closer that ends
      // its own line closes there, leaving the blank line behind.
      await expectStableText(
        'two math spans on one line',
        '${pad(1)}\n\n'
            r'$$a$$ tail $$b$$'
            '\n\n${pad(2)}\n',
      );
      await expectStableText(
        'a math span then a math line',
        '${pad(1)}\n\n'
            r'$$a$$'
            '\ntail '
            r'$$b$$'
            '\n\n${pad(2)}\n',
      );
      // `String.trim()`, which the whole-document render uses on the source,
      // takes U+0085 with it while a `\s` pattern does not.
      await expectStableText(
        'a reply ending on a next-line character',
        '${pad(1)}\n\n${pad(2)}\n\n\u0085',
      );
    });

    testWidgets('across base font metrics and text scales', (tester) async {
      boundTester = tester;
      tester.view.physicalSize = const Size(1170, 2100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final shapes = <String>[
        pad(1),
        '- one\n- two',
        pad(2),
        '---',
        pad(3),
        '```dart\nvar a = 1;\n```',
        pad(4),
      ];

      for (final fontSize in <double>[11, 14, 15.7, 20, 24]) {
        for (final height in <double>[1.2, 1.5, 1.7]) {
          await expectStableHeight(
            'fontSize $fontSize height $height',
            shapes,
            style: baseStyle.copyWith(fontSize: fontSize, height: height),
          );
        }
      }
      // The chat font scale and the system text scale both land here as a
      // `MediaQuery` text scale, which the blank lines of a whole-document
      // render scale with.
      for (final textScale in <double>[0.7, 0.85, 1.15, 1.3, 2.0]) {
        await expectStableHeight(
          'text scale $textScale',
          shapes,
          textScale: textScale,
        );
      }
    });

    testWidgets('for a long multi-paragraph reply', (tester) async {
      boundTester = tester;
      tester.view.physicalSize = const Size(1170, 2100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await expectStableHeight(
        'thirty paragraphs',
        List<String>.generate(30, pad),
      );
    });

    testWidgets('for streaming prefixes and suffix endings', (tester) async {
      boundTester = tester;
      tester.view.physicalSize = const Size(1170, 2100);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final suffixes = <String, String>{
        'indented heading': '    # Heading #',
        'three-space heading': '   # Heading #',
        'tab heading': '\t# Heading #',
        'one closing hash': '# Heading #',
        'six closing hashes': '# Heading ######',
        'seven closing hashes': '# Heading #######',
        'twenty closing hashes': '# Heading ${'#' * 20}',
        'seven bare hashes': '#######',
        'C# paragraph': 'Language: C#',
        'two dollar formulas':
            r'$$a$$'
            '\ntext\n'
            r'$$b$$',
        'two bracket formulas':
            r'\[a\]'
            '\ntext\n'
            r'\[b\]',
        'mixed math':
            r'$$a$$'
            '\ntext\n'
            r'\[b\]',
        'dollar with tail then bracket':
            r'$$a$$ tail'
            '\ntext\n'
            r'\[b\]',
        'unclosed bracket then dollar':
            r'\['
            '\ntext\n'
            r'$$b$$',
        'fence bracket then dollar':
            '```\n\\[\n```\n'
            r'$$b$$',
        'line separator between paragraphs': 'A\n\u2028\nB',
        'paragraph separator between paragraphs': 'A\n\u2029\nB',
        'crlf paragraphs': 'A\r\n\r\nB',
        'bare cr paragraphs': 'A\r\rB',
        'nbsp blank run': 'A\n\u00a0\nB',
        'next-line blank run': 'A\n\u0085\nB',
        'hash then title across a blank': '#\n\nHeading #',
        'opening hash then indented title': '#\n    #Title #',
        'unclosed backtick then dollar': '`unclosed\n\$\$ `x` \$\$',
        'mid-line details then dollar': 'Use <details> here\n\$\$b\$\$',
        'line separator then dollar': 'Text\u2028\$\$b\$\$',
        'paragraph separator then dollar': 'Text\u2029\$\$b\$\$',
        'line separator then fence': 'Text\u2028```dart\ncode\n\ninside\n```',
        'paragraph separator then fence':
            'Text\u2029```dart\ncode\n\ninside\n```',
        'line separator then tilde fence': 'Text\u2028~~~\ncode\n\ninside\n~~~',
        'line separator then details':
            'Text\u2028<details>\n\nbody\n</details>',
        'four-backtick fence with short closer': '````dart\na\n```\n\nb\n````',
        'four-tilde fence with short closer': '~~~~\na\n~~~\n\nb\n~~~~',
        'fence info closer': '```dart\na\n``` not-a-closer\nfollowing\n```',
        'tilde fence info closer': '~~~\na\n~~~ not-a-closer\nfollowing\n~~~',
        'four-backtick fence info closer':
            '````dart\na\n```` not-a-closer\nfollowing\n````',
        'mid-line nested details':
            '<details>\n<summary>outer</summary>\n'
            'prefix <details>\n<summary>inner</summary>\n\n'
            'inner body\n</details>\n\nouter body\n</details>',
        'details with inline-code tag':
            '<details>\n<summary>s</summary>\n'
            'Use `<details>` here\n\nmore\n</details>',
        'cross-line details opener':
            '<details\nopen>\n<summary>s</summary>\n\nbody\n</details>',
        'seven nested details': [
          for (var i = 1; i <= 7; i++) '<details>\n<summary>L$i</summary>',
          'deep-body',
          for (var i = 0; i < 7; i++) '</details>',
        ].join('\n'),
        'uppercase details tags': '<DETAILS><SUMMARY>s</SUMMARY>more</DETAILS>',
        'dotted details lookalike':
            '<details>\n<summary>s</summary>\n<details.foo>\n\nmore\n</details>',
        'self-closing details lookalike':
            '<details>\n<summary>s</summary>\n<details/>\n\nmore\n</details>',
        'unclosed details with code spans':
            '<details><summary>s</summary>${List.filled(20, '`x`').join(' ')}',
        'rematched details backticks':
            r'<details><summary>s</summary>`x`<details>y`</details>',
        'mixed one and three tick details':
            r'<details><summary>s</summary>`x```<details>y`</details>',
        'mixed two-tick details':
            r'<details><summary>s</summary>``x``<details>y``</details>',
        'same-line details prefix without gt':
            '<details><summary>s</summary>before <details missing </details>',
        'sixty backtick details prefix':
            '<details><summary>s</summary>${'`' * 60}',
      };

      for (final suffix in suffixes.entries) {
        for (final ending in const ['', '\n', '\n\n']) {
          await expectStableText(
            '${suffix.key} ending ${ending.length} LFs',
            '${pad(1)}\n\n${pad(2)}\n\n${suffix.value}$ending',
          );
        }
      }

      await expectStableText(
        'twenty C# paragraphs',
        [
          pad(1),
          for (var i = 0; i < 20; i++) 'Language: C# sample $i',
          pad(2),
        ].join('\n\n'),
      );

      const growth = <String, String>{
        'indented heading growth': '    # Heading #',
        'two dollar formulas growth':
            r'$$a$$'
            '\ntext\n'
            r'$$b$$',
        'hash then title growth': '#\n\nHeading #',
      };
      for (final item in growth.entries) {
        final text = '${pad(1)}\n\n${item.value}\n\n${pad(2)}\n';
        for (var i = 0; i < text.length; i++) {
          if (text.codeUnitAt(i) != 0x0A && i != text.length - 1) continue;
          await expectStableText(
            '${item.key} prefix ${i + 1}',
            text.substring(0, i + 1),
            minBlocks: 1,
          );
        }
      }
    });
  });
}
