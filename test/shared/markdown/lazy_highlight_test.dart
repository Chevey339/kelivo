import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/markdown/highlight_languages.g.dart';
import 'package:Kelivo/shared/markdown/lazy_highlight.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

class _Tree extends HighlightRenderer {
  DataNode? root;
  @override
  void openNode(DataNode node) => root ??= node;
  @override
  void closeNode(DataNode node) {}
  @override
  void addText(String text) {}
}

Object _tree(HighlightResult? result) {
  final renderer = _Tree();
  result!.render(renderer);
  Object encode(dynamic node) => node is DataNode
      ? {
          'scope': node.scope,
          'language': node.language,
          'children': node.children.map(encode).toList(),
        }
      : node as String;
  return encode(renderer.root!);
}

void main() {
  test('only requested grammars and embedded dependencies are registered', () {
    final lazy = LazyHighlight();
    expect(lazy.loadedLanguages, isEmpty);
    expect(lazy.highlight(code: 'text', language: 'not-a-language'), isNull);
    expect(lazy.getLanguage('not-a-language'), isNull);
    expect(lazy.loadedLanguages, isEmpty);
    lazy.highlight(code: 'def answer(): return 42', language: 'python');
    expect(lazy.loadedLanguages, {'python'});
    lazy.highlight(code: 'const answer = 42;', language: 'ts');
    expect(lazy.loadedLanguages, containsAll(['typescript', 'xml', 'css']));
    expect(lazy.loadedLanguages, isNot(contains('php')));
    expect(lazy.loadedLanguages.length, lessThan(20));
  });

  test('generated definitions and aliases match the entire eager registry', () {
    final eager = Highlight()..registerLanguages(builtinAllLanguages);
    expect(
      highlightLanguageFactories.keys,
      orderedEquals(builtinAllLanguages.keys),
    );
    for (final entry in builtinAllLanguages.entries) {
      expect(highlightLanguageFactories[entry.key]!(), same(entry.value));
      for (final alias in entry.value.aliases ?? <String>[]) {
        final lazy = LazyHighlight();
        expect(
          lazy.getLanguage(alias),
          same(eager.getLanguage(alias)),
          reason: alias,
        );
        expect(
          lazy.getLanguage(alias.toUpperCase()),
          same(eager.getLanguage(alias)),
          reason: alias,
        );
      }
    }
  });

  final samples = <String, String>{
    'python': 'def answer(value: str):\n    return f"Hello {value}" # note\n',
    'py': 'print("alias")',
    'javascript':
        'const css = css`p { color: red; }`; const el = html`<b>hi</b>`;',
    'jsx': 'const el = <div title="hello">{42}</div>;',
    'ts':
        'interface Result { value: number } const result: Result = {value: 42};',
    'html':
        '<style>body { color: red; }</style><script>const n = 42;</script><p>hi</p>',
    'xml': '<root attr="value"><child /></root>',
    'markdown':
        '# Heading\n**bold** and `inline`\n```python\nprint(42)\n```\n<div>text</div>',
    'md': '> Quote\n\n```js\nconst n = 42;\n```',
    'php':
        '<?php function greet(string \$name): string { return "Hi \$name"; } ?>',
    'php-template':
        '<div><?php echo "Hello"; ?></div><script>let n = 1;</script>',
    'handlebars': '<p>{{#if ok}}{{name}}{{/if}}</p>',
    'django':
        '<style>p { color: blue; }</style>{% if user %}{{ user.name }}{% endif %}',
    'erb': '<p><%= user.name %></p>',
    'sql': 'SELECT account_id, COUNT(*) FROM records GROUP BY account_id;',
    'bash': 'echo "hello \$USER"\ncat <<EOF\nhello\nEOF',
    'dockerfile': 'FROM alpine:latest\nRUN echo "hello" && ls /\n',
    'dart': 'Future<int> answer() async => 42;',
    'c#': 'public class Result { public int Value => 42; }',
    'gn': 'executable("hello") { sources = [ "main.cc" ] }',
    'http': 'HTTP/1.1 200 OK\nContent-Type: application/json\n\n{"answer":42}',
    'plaintext': '',
  };
  for (final entry in samples.entries) {
    test('node tree equals eager registry: ${entry.key}', () {
      final lazy = LazyHighlight();
      final eager = Highlight()..registerLanguages(builtinAllLanguages);
      expect(
        _tree(lazy.highlight(code: entry.value, language: entry.key)),
        _tree(eager.highlight(code: entry.value, language: entry.key)),
      );
    });
  }

  test(
    'all languages and aliases preserve token trees for empty and nonempty input',
    () {
      final eager = Highlight()..registerLanguages(builtinAllLanguages);
      for (final name in {
        ...builtinAllLanguages.keys,
        ...highlightLanguageAliases.keys,
      }) {
        final lazy = LazyHighlight();
        for (final code in ['', 'value = "hello"; // 42\n']) {
          expect(
            _tree(lazy.highlight(code: code, language: name)),
            _tree(eager.highlight(code: code, language: name)),
            reason: '$name: $code',
          );
        }
      }
    },
  );

  test('HTTP autodetection preserves eager order after previous requests', () {
    final lazy = LazyHighlight()..getLanguage('python');
    final eager = Highlight()..registerLanguages(builtinAllLanguages);
    const source = 'HTTP/1.1 200 OK\nContent-Type: text/plain\n\nhello world';
    expect(
      _tree(lazy.highlight(code: source, language: 'http')),
      _tree(eager.highlight(code: source, language: 'http')),
    );
    expect(lazy.loadedLanguages, builtinAllLanguages.keys.toSet());
  });
}
