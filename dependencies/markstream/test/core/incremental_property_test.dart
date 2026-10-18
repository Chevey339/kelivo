import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  test('every source prefix agrees with a complete parse', () {
    const fixtures = [
      '<details>\n<summary>outer</summary>\nprefix <details>\n<summary>inner</summary>\n\nbody\n</details>\n\nafter\n</details>',
      'one\n\ntwo\n\n```dart\nvalue\n```\n\nend',
      '> - first\n> - second\n>   continuation\n\nOutside',
      '<details><summary>Title</summary>\n\n- one\n- two\n</details>After',
      'Before \$\$\nx+y\n\nq\n\$\$ after',
      'Before \$\$x+y\n\nq\$\$ after',
      '| A | B |\n| --- | --- |\n| \$|x|\$ | `y` |',
      '[ref]\n\n[ref]: /url "title"\n\nnext',
      '::::note[label]\n:::tip\ninside\n:::\n::::',
      '> **😀one\r\n> two**\r\n\r\nend',
      '<div>one<script>hidden</script><b>two</b></div>',
    ];
    for (final options in [
      const ParserOptions(),
      const ParserOptions.commonMark(),
      const ParserOptions.gfm(),
    ]) {
      final parser = MarkdownParser(options: options);
      for (final source in fixtures) {
        final incremental = IncrementalDocument(parser: parser);
        for (var end = 0; end <= source.length; end++) {
          final prefix = source.substring(0, end);
          expect(
            incremental.update(prefix, streaming: true).toJson(),
            parser.parse(prefix, streaming: true).toJson(),
            reason: '$end: $prefix',
          );
        }
        expect(
          incremental.update(source).toJson(),
          parser.parse(source).toJson(),
        );
      }
    }
  });
  test(
    'append retains preceding block identities and edits reparse safely',
    () {
      final incremental = IncrementalDocument();
      final before = incremental.update('one\n\ntwo\n\nlast', streaming: true);
      final after = incremental.update(
        'one\n\ntwo\n\nlast token',
        streaming: true,
      );
      expect(identical(before.children[0], after.children[0]), true);
      expect(identical(before.children[1], after.children[1]), true);
      expect(identical(before.children.last, after.children.last), false);
      expect(
        identical(after, incremental.update(after.source, streaming: true)),
        true,
      );
      expect(
        incremental.update('edited\n\nlast').toJson(),
        const MarkdownParser().parse('edited\n\nlast').toJson(),
      );
    },
  );
  test('a new reference definition invalidates earlier unresolved links', () {
    final incremental = IncrementalDocument();
    final first = incremental.update('[ref]\n\nnext', streaming: true);
    final source = '[ref]\n\nnext\n\n[ref]: /destination';
    final second = incremental.update(source, streaming: true);
    expect(first.children.first.children.single, isA<TextNode>());
    expect(second.children.first.children.single, isA<LinkNode>());
    expect(
      second.toJson(),
      const MarkdownParser().parse(source, streaming: true).toJson(),
    );
  });
  test(
    'late display-math closers revisit literal prefixes for each policy',
    () {
      const parser = MarkdownParser();
      for (final streaming in [false, true]) {
        for (final optimistic in [false, true]) {
          final policy = StreamingOptions(optimisticBlocks: optimistic);
          for (final source in [
            'head\n\nBefore \$\$a + b\n\nc + d\$\$ after\n\ntail',
            'head\n\nBefore \\[a + b\n\nc + d\\] after\n\ntail',
            '> Before \$\$a\n>\n> b\$\$\n\nnext',
          ]) {
            final incremental = IncrementalDocument(streamingOptions: policy);
            for (var end = 0; end <= source.length; end++) {
              final prefix = source.substring(0, end);
              expect(
                incremental.update(prefix, streaming: streaming).toJson(),
                parser
                    .parse(
                      prefix,
                      streaming: streaming,
                      streamingOptions: policy,
                    )
                    .toJson(),
                reason: '$streaming/$optimistic: $prefix',
              );
            }
          }
        }
      }
    },
  );
  test('resuming an unfinished display body reopens its literal prefix', () {
    const source = 'head\n\nBefore \$\$a\n\nb';
    const parser = MarkdownParser();
    final incremental = IncrementalDocument();
    final initial = incremental.update(source);
    for (final streaming in [true, false, true]) {
      final current = incremental.update(source, streaming: streaming);
      expect(
        current.toJson(),
        parser.parse(source, streaming: streaming).toJson(),
      );
      expect(current.children.first, same(initial.children.first));
    }
  });
  test('random chunk boundaries and truncations match full parsing', () {
    final random = Random(1818);
    const tokens = [
      'word',
      ' ',
      '\n',
      '\r\n',
      '😀',
      '**',
      '[',
      ']',
      ':note[x]',
      '- ',
      '> ',
      '| a |',
      '| --- |',
      '```',
      r'$$',
      '<details>',
      '</details>',
      '[a]: /x',
    ];
    for (var sample = 0; sample < 160; sample++) {
      final source = List.generate(
        random.nextInt(70),
        (_) => tokens[random.nextInt(tokens.length)],
      ).join();
      for (final policy in [
        const StreamingOptions(),
        const StreamingOptions(optimisticInlines: true),
        const StreamingOptions(optimisticBlocks: false),
        const StreamingOptions(
          optimisticBlocks: false,
          optimisticInlines: true,
        ),
      ]) {
        final incremental = IncrementalDocument(streamingOptions: policy);
        var end = 0;
        while (end < source.length) {
          end = min(source.length, end + 1 + random.nextInt(8));
          final prefix = source.substring(0, end);
          expect(
            incremental.update(prefix, streaming: true).toJson(),
            const MarkdownParser()
                .parse(prefix, streaming: true, streamingOptions: policy)
                .toJson(),
            reason: prefix,
          );
        }
        final shortened = source.substring(0, source.length ~/ 2);
        expect(
          incremental.update(shortened).toJson(),
          const MarkdownParser().parse(shortened).toJson(),
          reason: shortened,
        );
      }
    }
  });
}
