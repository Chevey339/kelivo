// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:markdown/markdown.dart';
import 'package:test/test.dart';

import 'util.dart';

void main() async {
  testDirectory('original');

  // Block syntax extensions.
  testFile(
    'extensions/fenced_blockquotes.unit',
    blockSyntaxes: [const FencedBlockquoteSyntax()],
  );
  testFile(
    'extensions/fenced_code_blocks.unit',
    blockSyntaxes: [const FencedCodeBlockSyntax()],
  );
  testFile(
    'extensions/headers_with_ids.unit',
    blockSyntaxes: [const HeaderWithIdSyntax()],
  );
  testFile(
    'extensions/ordered_list_with_checkboxes.unit',
    blockSyntaxes: [const OrderedListWithCheckboxSyntax()],
  );
  testFile(
    'extensions/setext_headers_with_ids.unit',
    blockSyntaxes: [const SetextHeaderWithIdSyntax()],
  );
  testFile('extensions/tables.unit', blockSyntaxes: [const TableSyntax()]);
  testFile(
    'extensions/unordered_list_with_checkboxes.unit',
    blockSyntaxes: [const UnorderedListWithCheckboxSyntax()],
  );
  testFile(
    'extensions/alert_extension.unit',
    blockSyntaxes: [const AlertBlockSyntax()],
  );

  // Inline syntax extensions
  testFile(
    'extensions/autolink_extension.unit',
    inlineSyntaxes: [AutolinkExtensionSyntax()],
  );

  testFile('extensions/emojis.unit', inlineSyntaxes: [EmojiSyntax()]);
  testFile('extensions/inline_html.unit', inlineSyntaxes: [InlineHtmlSyntax()]);
  testFile(
    'extensions/strikethrough.unit',
    inlineSyntaxes: [StrikethroughSyntax()],
  );
  testFile(
    'extensions/footnote_block.unit',
    blockSyntaxes: [const FootnoteDefSyntax()],
  );

  testDirectory('common_mark');
  testDirectory('gfm');

  group('Corner cases', () {
    validateCore(
      'Incorrect Links',
      '''
5 Ethernet ([Music](
''',
      '''
<p>5 Ethernet ([Music](</p>
''',
    );

    validateCore(
      'Incorrect Links - Issue #623 - 1 - Bracketed link 1',
      '''
[](<
''',
      '''
<p>[](&lt;</p>
''',
    );

    validateCore(
      'Incorrect Links - Issue #623 - 2 - Bracketed link 2',
      '''
[](<>
''',
      '''
<p>[](&lt;&gt;</p>
''',
    );

    validateCore(
      'Incorrect Links - Issue #623 - 3 - Bracketed link 3',
      r'''
[](<\
''',
      r'''
<p>[](&lt;\</p>
''',
    );

    validateCore(
      'Incorrect Links - Issue #623 - 4 - Link title 1',
      '''
[](www.example.com "
''',
      '''
<p>[](www.example.com &quot;</p>
''',
    );

    validateCore(
      'Incorrect Links - Issue #623 - 5 - Link title 2',
      r'''
[](www.example.com "\
''',
      r'''
<p>[](www.example.com &quot;\</p>
''',
    );

    validateCore(
      'Incorrect Links - Issue #623 - 6 - Reference link label',
      r'''
[][\
''',
      r'''
<p>[][\</p>
''',
    );

    validateCore(
      'Escaping code block language',
      '''
```"/><a/href="url">arbitrary_html</a>
```
''',
      '''
<pre><code class="language-&quot;/&gt;&lt;a/href=&quot;url&quot;&gt;arbitrary_html&lt;/a&gt;"></code></pre>
''',
    );

    validateCore(
      'Unicode ellipsis as punctuation',
      '''
"Connecting dot **A** to **B.**…"
''',
      '''
<p>&quot;Connecting dot <strong>A</strong> to <strong>B.</strong>…&quot;</p>
''',
    );
  });

  group('Resolver', () {
    Node? nyanResolver(String text, [_]) =>
        text.isEmpty ? null : Text('~=[,,_${text}_,,]:3');
    validateCore(
      'simple link resolver',
      '''
resolve [this] thing
''',
      '''
<p>resolve ~=[,,_this_,,]:3 thing</p>
''',
      linkResolver: nyanResolver,
    );

    validateCore(
      'simple image resolver',
      '''
resolve ![this] thing
''',
      '''
<p>resolve ~=[,,_this_,,]:3 thing</p>
''',
      imageLinkResolver: nyanResolver,
    );

    validateCore(
      'can resolve link containing inline tags',
      '''
resolve [*star* _underline_] thing
''',
      '''
<p>resolve ~=[,,_*star* _underline__,,]:3 thing</p>
''',
      linkResolver: nyanResolver,
    );

    validateCore(
      'link resolver uses un-normalized link label',
      '''
resolve [TH  IS] thing
''',
      '''
<p>resolve ~=[,,_TH  IS_,,]:3 thing</p>
''',
      linkResolver: nyanResolver,
    );

    validateCore(
      'can resolve escaped brackets',
      r'''
resolve [\[\]] thing
''',
      '''
<p>resolve ~=[,,_[]_,,]:3 thing</p>
''',
      linkResolver: nyanResolver,
    );

    validateCore(
      'can choose to _not_ resolve something, like an empty link',
      '''
resolve [[]] thing
''',
      '''
<p>resolve ~=[,,_[]_,,]:3 thing</p>
''',
      linkResolver: nyanResolver,
    );
  });

  group('Custom inline syntax', () {
    final nyanSyntax = <InlineSyntax>[TextSyntax('nyan', sub: '~=[,,_,,]:3')];
    validateCore(
      'simple inline syntax',
      '''
nyan''',
      '''<p>~=[,,_,,]:3</p>
''',
      inlineSyntaxes: nyanSyntax,
    );

    validateCore(
      'dart custom links',
      'links [are<foo>] awesome',
      '<p>links <a>are&lt;foo></a> awesome</p>\n',
      linkResolver: (String text, [String? _]) =>
          Element.text('a', text.replaceAll('<', '&lt;')),
    );

    // TODO(amouravski): need more tests here for custom syntaxes, as some
    // things are not quite working properly. The regexps are sometime a little
    // too greedy, I think.
  });

  group('Inline only', () {
    validateCore(
      'simple line',
      '''
        This would normally create a paragraph.
        ''',
      '''
        This would normally create a paragraph.
        ''',
      inlineOnly: true,
    );
    validateCore(
      'strong and em',
      '''
        This would _normally_ create a **paragraph**.
        ''',
      '''
        This would <em>normally</em> create a <strong>paragraph</strong>.
        ''',
      inlineOnly: true,
    );
    validateCore(
      'link',
      '''
        This [link](http://www.example.com/) will work normally.
        ''',
      '''
        This <a href="http://www.example.com/">link</a> will work normally.
        ''',
      inlineOnly: true,
    );
    validateCore(
      'references do not work',
      '''
        [This][] shouldn't work, though.
        ''',
      '''
        [This][] shouldn't work, though.
        ''',
      inlineOnly: true,
    );
    validateCore(
      'less than and ampersand are escaped',
      '''
        < &
        ''',
      '''
        &lt; &amp;
        ''',
      inlineOnly: true,
    );
    validateCore(
      'keeps newlines',
      '''
        This paragraph
        continues after a newline.
        ''',
      '''
        This paragraph
        continues after a newline.
        ''',
      inlineOnly: true,
    );
    validateCore(
      'ignores block-level markdown syntax',
      '''
        1. This will not be an <ol>.
        ''',
      '''
        1. This will not be an <ol>.
        ''',
      inlineOnly: true,
    );
  });

  group('ExtensionSet', () {
    test('3 asterisks separated with spaces horizontal rule while it is '
        'gitHubFlavored', () {
      // Because `gitHubFlavored` will put `UnorderedListWithCheckboxSyntax`
      // before `HorizontalRuleSyntax`, the `* * *` will be parsed into an
      // empty unordered list if `ListSyntax` does not skip the horizontal
      // rule structure.
      expect(
        markdownToHtml('* * *', extensionSet: ExtensionSet.gitHubFlavored),
        '<hr />\n',
      );
    });
  });
}
