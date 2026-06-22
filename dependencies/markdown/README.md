[![Build Status](https://github.com/dart-lang/tools/actions/workflows/markdown.yaml/badge.svg)](https://github.com/dart-lang/tools/actions/workflows/markdown.yaml)
[![pub package](https://img.shields.io/pub/v/markdown.svg)](https://pub.dev/packages/markdown)
[![package publisher](https://img.shields.io/pub/publisher/markdown.svg)](https://pub.dev/packages/markdown/publisher)

A portable Markdown library written in Dart. It can parse Markdown into HTML on
both the client and server.

Play with it at
[dart-lang.github.io/tools/markdown](https://dart-lang.github.io/tools/markdown).

### Usage

```dart
import 'package:markdown/markdown.dart';

void main() {
  print(markdownToHtml('Hello *Markdown*'));
  //=> <p>Hello <em>Markdown</em></p>
}
```

### Syntax extensions

A few Markdown extensions, beyond what was specified in the original
[Perl Markdown][] implementation, are supported. By default, the ones supported
in [CommonMark] are enabled. Any individual extension can be enabled by
specifying an Array of extension syntaxes in the `blockSyntaxes` or
`inlineSyntaxes` argument of `markdownToHtml`.

The currently supported inline extension syntaxes are:

* `InlineHtmlSyntax()` - approximately CommonMark's
  [definition][commonmark-raw-html] of "Raw HTML".

The currently supported block extension syntaxes are:

* `const FencedCodeBlockSyntax()` - Code blocks familiar to Pandoc and PHP
  Markdown Extra users.
* `const HeaderWithIdSyntax()` - ATX-style headers have generated IDs, for link
  anchors (akin to Pandoc's [`auto_identifiers`][pandoc-auto_identifiers]).
* `const SetextHeaderWithIdSyntax()` - Setext-style headers have generated IDs
  for link anchors (akin to Pandoc's
  [`auto_identifiers`][pandoc-auto_identifiers]).
* `const TableSyntax()` - Table syntax familiar to GitHub, PHP Markdown Extra,
  and Pandoc users.

For example:

```dart
import 'package:markdown/markdown.dart';

void main() {
  print(markdownToHtml('Hello <span class="green">Markdown</span>',
      inlineSyntaxes: [InlineHtmlSyntax()]));
  //=> <p>Hello <span class="green">Markdown</span></p>
}
```

### Extension sets

To make extension management easy, you can also just specify an extension set.
Both `markdownToHtml()` and `Document()` accept an `extensionSet` named
parameter. Currently, there are four pre-defined extension sets:

* `ExtensionSet.none` includes no extensions. With no extensions, Markdown
  documents will be parsed with a default set of block and inline syntax
  parsers that closely match how the document might be parsed by the original
  [Perl Markdown][] implementation.

* `ExtensionSet.commonMark` includes two extensions in addition to the default
  parsers to bring the parsed output closer to the [CommonMark] specification:

  * Block Syntax Parser
    * `const FencedCodeBlockSyntax()`
  
  * Inline Syntax Parser
    * `InlineHtmlSyntax()`

* `ExtensionSet.gitHubFlavored` includes five extensions in addition to the default
  parsers to bring the parsed output close to the [GitHub Flavored] Markdown
  specification: 

  * Block Syntax Parser
    * `const FencedCodeBlockSyntax()`
    * `const TableSyntax()`
  
  * Inline Syntax Parser
    * `InlineHtmlSyntax()`
    * `StrikethroughSyntax()`
    * `AutolinkExtensionSyntax()`

* `ExtensionSet.gitHubWeb` includes eight extensions. The same set of parsers use
   in the `gitHubFlavored` extension set with the addition of the block syntax parsers,
   HeaderWithIdSyntax and SetextHeaderWithIdSyntax, which add `id` attributes to
   headers and inline syntax parser, EmojiSyntax, for parsing GitHub style emoji
   characters:

  * Block Syntax Parser
    * `const FencedCodeBlockSyntax()`
    * `const HeaderWithIdSyntax()`, which adds `id` attributes to ATX-style
      headers, for easy intra-document linking.
    * `const SetextHeaderWithIdSyntax()`, which adds `id` attributes to
      Setext-style headers, for easy intra-document linking.
    * `const TableSyntax()`
  
  * Inline Syntax Parser
    * `InlineHtmlSyntax()`
    * `StrikethroughSyntax()`
    * `EmojiSyntax()`
    * `AutolinkExtensionSyntax()`

### Custom syntax extensions

You can create and use your own syntaxes.

```dart
import 'package:markdown/markdown.dart';

void main() {
  var syntaxes = [TextSyntax('nyan', sub: '~=[,,_,,]:3')];
  print(markdownToHtml('nyan', inlineSyntaxes: syntaxes));
  //=> <p>~=[,,_,,]:3</p>
}
```

### HTML sanitization

This package offers no features in the way of HTML sanitization. Read Estevão
Soares dos Santos's great article, ["Markdown's XSS Vulnerability (and how to
mitigate it)"], to learn more.

The authors recommend that you perform any necessary sanitization on the
resulting HTML, for example via `dart:html`'s [NodeValidator].

### CommonMark compliance

This package contains a number of files in the `tool` directory for tracking
compliance with [CommonMark].

#### Updating CommonMark stats when changing the implementation

 1. Update the library and test code, making sure that tests still pass.
 2. Run `dart run tool/stats.dart --update-files` to update the
    per-test results `tool/common_mark_stats.json` and the test summary
    `tool/common_mark_stats.txt`.
 3. Verify that more tests now pass – or at least, no more tests fail.
 4. Make sure you include the updated stats files in your commit.

#### Updating the CommonMark test file for a spec update

 1. Check out the [CommonMark source]. Make sure you checkout a *major* release.
 2. Dump the test output overwriting the existing tests file.

    ```console
    > cd /path/to/common_mark_dir
    > python3 test/spec_tests.py --dump-tests > \
      /path/to/markdown.dart/tool/common_mark_tests.json
    ```

 3. Update the stats files as described above. Note any changes in the results.
 4. Update any references to the existing spec by search for
    `https://spec.commonmark.org/0.30/` in the repository. (Including this one.)
    Verify the updated links are still valid.
 5. Commit changes, including a corresponding note in `CHANGELOG.md`.

[Perl Markdown]: https://daringfireball.net/projects/markdown/
[CommonMark]: https://commonmark.org/
[commonMark-raw-html]: https://spec.commonmark.org/0.30/#raw-html
[CommonMark source]: https://github.com/commonmark/commonmark-spec
[GitHub Flavored]: https://github.github.io/gfm/
[pandoc-auto_identifiers]: https://pandoc.org/MANUAL.html#extension-auto_identifiers
["Markdown's XSS Vulnerability (and how to mitigate it)"]: https://github.com/showdownjs/showdown/wiki/Markdown%27s-XSS-Vulnerability-(and-how-to-mitigate-it)
[NodeValidator]: https://api.dart.dev/stable/dart-html/NodeValidator-class.html
