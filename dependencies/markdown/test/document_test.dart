// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:markdown/markdown.dart';
import 'package:markdown/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('Document', () {
    test('encodeHtml prevents less than and ampersand escaping', () {
      final document = Document(encodeHtml: false);
      final result = document.parseInline('< &');
      expect(result, hasLength(1));
      expect(
        result[0],
        const TypeMatcher<Text>().having((e) => e.text, 'text', equals('< &')),
      );
    });

    group('with encodeHtml enabled', () {
      final document = Document();

      test('encodes HTML in an inline code snippet', () {
        final result = document.parseInline(
          '``<p>Hello <em>Markdown</em></p>``',
        );
        final codeSnippet = result.single as Element;
        expect(
          codeSnippet.textContent,
          equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;'),
        );
      });

      test('encodes HTML in a fenced code block', () {
        final lines = '```\n<p>Hello <em>Markdown</em></p>\n```\n'.toLines();
        final result = document.parseLineList(lines);
        final codeBlock = result.single as Element;
        expect(
          codeBlock.textContent,
          equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;\n'),
        );
      });

      test('encodes HTML in an indented code block', () {
        final lines = '    <p>Hello <em>Markdown</em></p>\n'.toLines();
        final result = document.parseLineList(lines);
        final codeBlock = result.single as Element;
        expect(
          codeBlock.textContent,
          equals('&lt;p&gt;Hello &lt;em&gt;Markdown&lt;/em&gt;&lt;/p&gt;\n'),
        );
      });

      test('encodeHtml spaces are preserved in text', () {
        // Example to get a <p> tag rendered before a text node.
        const contents = 'Sample\n\n<pre>\n A\n B\n</pre>';
        final document = Document();
        final nodes = BlockParser(contents.toLines(), document).parseLines();
        final result = HtmlRenderer().render(nodes);
        expect(result, '<p>\n</p>\n<pre>\n A\n B\n</pre>');
      });

      test(
        'encode double quotes, greater than, and less than when escaped',
        () {
          const contents = r'\>\"\< Hello';
          final document = Document();
          final nodes = document.parseInline(contents);
          expect(nodes, hasLength(1));
          expect(
            nodes.single,
            const TypeMatcher<Text>().having(
              (e) => e.text,
              'text',
              '&gt;&quot;&lt; Hello',
            ),
          );
        },
      );
    });

    group('with encodeHtml disabled', () {
      final document = Document(encodeHtml: false);

      test('leaves HTML alone, in a code snippet', () {
        final result = document.parseInline(
          '```<p>Hello <em>Markdown</em></p>```',
        );
        final codeSnippet = result.single as Element;
        expect(
          codeSnippet.textContent,
          equals('<p>Hello <em>Markdown</em></p>'),
        );
      });

      test('leaves HTML alone, in a fenced code block', () {
        final lines = '```\n<p>Hello <em>Markdown</em></p>\n```\n'.toLines();
        final result = document.parseLineList(lines);
        final codeBlock = result.single as Element;
        expect(
          codeBlock.textContent,
          equals('<p>Hello <em>Markdown</em></p>\n'),
        );
      });

      test('leaves HTML alone, in an indented code block', () {
        final lines = '    <p>Hello <em>Markdown</em></p>\n'.toLines();
        final result = document.parseLineList(lines);
        final codeBlock = result.single as Element;
        expect(
          codeBlock.textContent,
          equals('<p>Hello <em>Markdown</em></p>\n'),
        );
      });

      test('leave double quotes, greater than, and less than when escaped', () {
        const contents = r'\>\"\< Hello';
        final document = Document(encodeHtml: false);
        final nodes = document.parseInline(contents);
        expect(nodes, hasLength(1));
        expect(
          nodes.single,
          const TypeMatcher<Text>().having((e) => e.text, 'text', '>"< Hello'),
        );
      });
    });
  });
}
