import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

Iterable<CodeBlockNode> _codeBlocks(MarkdownNode node) sync* {
  if (node is CodeBlockNode) yield node;
  for (final child in node.children) {
    yield* _codeBlocks(child);
  }
}

const _body =
    'ui 1 catalog "kelivo.native/1"\n'
    'root = Column(children=[answer])\n'
    'answer = Text(text="你好 😀")';

void main() {
  const parser = MarkdownParser();
  final fixtures = <String>[
    '```kelivo-ui\n$_body\n```',
    '```kelivo-ui\r\n${_body.replaceAll('\n', '\r\n')}\r\n```',
    '  ```kelivo-ui\n${_body.split('\n').map((s) => '  $s').join('\n')}\n  ```',
    '> ```kelivo-ui\n${_body.split('\n').map((s) => '> $s').join('\n')}\n> ```',
    '- item\n\n  ```kelivo-ui\n${_body.split('\n').map((s) => '  $s').join('\n')}\n  ```',
    '~~~kelivo-ui\n$_body\n~~~~\n\nAfter',
  ];

  for (final (index, source) in fixtures.indexed) {
    test('fixture $index: every UTF-16 prefix matches a fresh parse', () {
      final incremental = IncrementalDocument();
      for (var end = 0; end <= source.length; end++) {
        final prefix = source.substring(0, end);
        expect(
          incremental.update(prefix, streaming: true).toJson(),
          parser.parse(prefix, streaming: true).toJson(),
          reason: 'fixture=$index, UTF-16 offset=$end',
        );
      }
      expect(
        incremental.update(source).toJson(),
        parser.parse(source).toJson(),
      );
      final block = _codeBlocks(incremental.document).single;
      expect(block.info, 'kelivo-ui');
      expect(block.closed, isTrue);
      expect(block.code, '$_body\n');
    });
  }

  test('every UTF-8 split preserves Unicode before Markdown parsing', () async {
    final source = fixtures.first;
    final bytes = utf8.encode(source);
    for (var split = 0; split <= bytes.length; split++) {
      final incremental = IncrementalDocument();
      var received = '';
      await for (final chunk in Stream<List<int>>.fromIterable([
        bytes.sublist(0, split),
        bytes.sublist(split),
      ]).transform(utf8.decoder)) {
        received += chunk;
        incremental.update(received, streaming: true);
      }
      expect(received, source);
      expect(
        incremental.update(received).toJson(),
        parser.parse(source).toJson(),
      );
    }
  });

  test('fence closure is independent of host streaming completion', () {
    const open = '```kelivo-ui\n$_body';
    for (final streaming in [true, false]) {
      expect(
        _codeBlocks(parser.parse(open, streaming: streaming)).single.closed,
        isFalse,
      );
      expect(
        _codeBlocks(
          parser.parse('$open\n```', streaming: streaming),
        ).single.closed,
        isTrue,
      );
    }
  });

  test(
    'unterminated last line has a synthetic LF with an empty source span',
    () {
      const source = '```kelivo-ui\n$_body';
      final block = _codeBlocks(parser.parse(source, streaming: true)).single;
      expect(block.code, '$_body\n');
      final last = block.children.last;
      expect(last.text, '\n');
      expect(last.span.start, source.length);
      expect(last.span.end, source.length);
      // The adapter must not feed this display-only LF to the DSL reducer.
      expect(last.span.slice(source), isEmpty);
    },
  );

  test('CRLF and quote prefixes retain original source coordinates', () {
    final source =
        '> ```kelivo-ui\r\n'
        '${_body.split('\n').map((s) => '> $s').join('\r\n')}\r\n'
        '> ```';
    final block = _codeBlocks(parser.parse(source)).single;
    expect(block.code, '$_body\n');
    final originals = block.children.map((n) => n.span.slice(source)).toList();
    expect(originals.where((s) => s == '\r\n'), hasLength(3));
    for (final child in block.children) {
      if (child.text != '\n') expect(child.span.slice(source), child.text);
    }
    expect(originals.join(), '${_body.replaceAll('\n', '\r\n')}\r\n');
    expect(block.span.slice(source), contains('> answer ='));
  });

  test(
    'rewrites, truncation, cancellation and regeneration reparse reliably',
    () {
      final incremental = IncrementalDocument();
      final source = fixtures.first;
      final changed = source.replaceAll('你好', 'Hello');
      for (final (text, streaming) in [
        (source, true),
        (source, false),
        (changed, false),
        (changed.substring(0, changed.length - 5), true),
        (changed.substring(0, changed.length - 5), false),
        ('', true),
        (source, true),
        (source, false),
      ]) {
        final result = incremental.update(text, streaming: streaming);
        expect(
          result.toJson(),
          parser.parse(text, streaming: streaming).toJson(),
        );
        expect(incremental.update(text, streaming: streaming), same(result));
      }
    },
  );

  test('identical declarations at different positions remain distinct', () {
    const source = '```kelivo-ui\n$_body\n$_body\n```';
    final block = _codeBlocks(parser.parse(source)).single;
    final headers = block.children
        .where((n) => n.text == 'ui 1 catalog "kelivo.native/1"')
        .toList();
    expect(headers, hasLength(2));
    expect(headers[0].span.start, lessThan(headers[1].span.start));
  });
}
