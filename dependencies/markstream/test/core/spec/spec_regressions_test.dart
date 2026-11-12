import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  const parser = MarkdownParser(options: ParserOptions.commonMark());
  test('HTML encodes quotes in text and code', () {
    expect(
      toHtml(parser.parse('"text" `"code"`')),
      '<p>&quot;text&quot; <code>&quot;code&quot;</code></p>\n',
    );
  });
  test(
    'HTML destinations encode Unicode without normalizing URI structure',
    () {
      final cases = {
        '[x](/föö)': '/f%C3%B6%C3%B6',
        '[x](a%20b)': 'a%20b',
        '[x](<foo bar>)': 'foo%20bar',
        '[x](HTTP://FOO.BAR)': 'HTTP://FOO.BAR',
        '[x](http://[::1]/)': 'http://[::1]/',
        r'[x](https://example.com?find=\*)': 'https://example.com?find=*',
        '<https://foo.bar.`baz>': 'https://foo.bar.%60baz',
      };
      for (final entry in cases.entries) {
        expect(
          toHtml(parser.parse(entry.key)),
          contains('href="${entry.value}"'),
          reason: entry.key,
        );
      }
    },
  );
  test('tight lists start non-paragraph blocks on a new line', () {
    expect(
      toHtml(parser.parse('- ```\n  code\n  ```')),
      '<ul>\n<li>\n<pre><code>code\n</code></pre>\n</li>\n</ul>\n',
    );
    expect(toHtml(parser.parse('- ***')), '<ul>\n<li>\n<hr />\n</li>\n</ul>\n');
  });
  test('ATX closing hash runs can leave an empty heading', () {
    for (final source in ['### ###', '# #', '## ###  ']) {
      final doc = parser.parse(source);
      final heading = doc.children.single as HeadingNode;
      expect(heading.children, isEmpty, reason: source);
      expect(toHtml(doc), '<h${heading.level}></h${heading.level}>\n');
    }
    expect(toHtml(parser.parse(r'### \###')), '<h3>###</h3>\n');
    expect(toHtml(parser.parse('### ###text')), '<h3>###text</h3>\n');
  });
}
